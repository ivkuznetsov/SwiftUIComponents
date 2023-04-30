//
//  File.swift
//  

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Combine
import CommonUtils
import SwiftUI

@MainActor
public protocol PagingLoader {
    associatedtype ContentState: PagingContentState
    
    var contentState: ContentState { get set }
    
    var loadingState: LoadingState { get }
    
    func refresh()
    
    func refresh(userInitiated: Bool)
    
    func loadMore()
}

public typealias ObservablePagingLoader = PagingLoader & ObservableObject

public protocol PagingContentState {
    associatedtype Item: Hashable
    
    var content: Page<Item> { get }
    
    func refresh() async throws
    
    func loadMore() async throws
}

public extension PagingContentState {
    
    var anyContent: Page<AnyHashable> {
        .init(items: content.items, next: content.next)
    }
}

public typealias ObservablePagingContentState = PagingContentState & ObservableObject

public enum Paging<Item: Hashable> {
    
    public struct Cache {
        let save: ([Item])->()
        let load: ()->[Item]
        
        public init(save: @escaping ([Item]) -> Void, load: @escaping () -> [Item]) {
            self.save = save
            self.load = load
        }
    }
}

extension Paging {
    
    @MainActor
    public final class Loader<ContentState: ObservablePagingContentState>: ObservablePagingLoader {
    
        private let initialLoading: LoadingHelper.Presentation
        private let feedId = UUID().uuidString
        private let loader: LoadingHelper
        public let loadingState = LoadingState()
        
        public var performOnRefresh: (()->())? = nil
        
        @RePublish public var contentState: ContentState
        
        public init(initialLoading: LoadingHelper.Presentation = .opaque,
                    loader: LoadingHelper,
                    contentState: ContentState) {
            self.initialLoading = initialLoading
            self.loader = loader
            self.contentState = contentState
        }
        
        public func initalRefresh() {
            if loadingState.value != .loading && contentState.content.items.isEmpty {
                refresh()
            }
        }
        
        public func refresh() {
            refresh(userInitiated: false)
        }
        
        public func refresh(userInitiated: Bool) {
            performOnRefresh?()
            
            loader.run(userInitiated ? .alertOnFail : (contentState.content.items.isEmpty ? initialLoading : .none),
                       id: feedId) { [weak self] _ in
                
                self?.loadingState.value = .loading
                
                do {
                    try await self?.contentState.refresh()
                    self?.loadingState.value = .stop
                } catch {
                    self?.loadingState.process(error)
                    throw error
                }
            }
        }
        
        public func loadMore() {
            guard contentState.content.next != nil else { return }
            loadingState.value = .loading
            
            loader.run(.none, id: feedId) { [weak self] _ in
                do {
                    try await self?.contentState.loadMore()
                    self?.loadingState.value = .stop
                } catch {
                    self?.loadingState.process(error)
                    throw error
                }
            }
        }
    }
}

public enum Direction {
    case bottom
    case top
}

public extension Paging.Loader where ContentState == Paging.CommonState {
    
    convenience init(initialLoading: LoadingHelper.Presentation = .opaque,
                     loader: LoadingHelper) {
        self.init(initialLoading: initialLoading, loader: loader, contentState: .init(direction: .bottom))
    }
}

extension Paging {
    public typealias CommonLoader = Loader<CommonState>
    
    public final class CommonState: PagingContentState, ObservableObject {
        
        private let direction: Direction
        private let cache: Cache?
        @AtomicPublished public var content = Page<Item>()
        
        public var loadPage: ((_ offset: AnyHashable?) async throws -> Page<Item>)!
        
        public init(direction: Direction, cache: Cache? = nil) {
            self.direction = direction
            self.cache = cache
            
            if let items = cache?.load() {
                content = Page(items: items)
            }
        }
        
        public func refresh() async throws {
            let result = try await loadPage(nil)
            let equal = content == result
            
            if !equal {
                content = result
                cache?.save(result.items)
            }
        }
        
        public func loadMore() async throws {
            guard let next = content.next else { return }
            
            let result = try await loadPage(next)
            await append(result)
        }
        
        private func append(_ content: Page<Item>) async {
            let itemsToAdd = direction == .top ? content.items.reversed() : content.items
            var array = direction == .top ? self.content.items.reversed() : self.content.items
            var set = Set(array)
            var allItemsAreTheSame = true // backend returned the same items for the next page, prevent infinit loading
            
            itemsToAdd.forEach {
                if !set.contains($0) {
                    set.insert($0)
                    array.append($0)
                    allItemsAreTheSame = false
                }
            }
            self.content = .init(items: direction == .top ? array.reversed() : array,
                                 next: allItemsAreTheSame ? nil : content.next)
        }
    }
}
