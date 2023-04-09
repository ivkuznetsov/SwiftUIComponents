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
public protocol PagingProtocol: ObservableObject {
    associatedtype Item: Hashable
    
    var content: PagingContent { get set }
    
    var state: LoadingState { get }
    
    func refresh()
    
    func refresh(userInitiated: Bool)
    
    func loadMore()
    
    func resetFail()
    
    func loadMoreIfAllowed()
    
    func retry()
}

public struct PagingContent {
    public let items: [AnyHashable]
    public let next: AnyHashable?
    
    public init(_ items: [AnyHashable], next: AnyHashable? = nil) {
        self.items = items
        self.next = next
    }
    
    public static var empty: Self { .init([]) }
    
    func isEqual(_ content: Self) async -> Bool {
        if items.count != content.items.count || next != content.next {
            return false
        }
        return items == content.items
    }
}

@MainActor
public class Paging<Item: Hashable>: PagingProtocol {
    
    public var performOnRefresh: (()->())? = nil
    
    public var shouldLoadMore: ()->Bool = { true }
    
    public var firstPageCache: (save: ([Item])->(), load: ()->[Item])? = nil {
        didSet {
            if let items = firstPageCache?.load() {
                content = PagingContent(items, next: nil)
            }
        }
    }
    
    private var paramenters: (loadPage: (_ offset: AnyHashable?) async throws -> PagingContent, loader: LoadingHelper)!
    
    public enum Direction {
        case bottom
        case top
    }
    
    private let direction: Direction
    private let initialLoading: LoadingHelper.Presentation
    private let feedId = UUID().uuidString
    public let state = LoadingState()
    @Published public var content = PagingContent.empty
    
    public init(direction: Direction = .bottom, initialLoading: LoadingHelper.Presentation = .opaque) {
        self.direction = direction
        self.initialLoading = initialLoading
    }
    
    public func set(loadPage: @escaping (_ offset: AnyHashable?) async throws -> PagingContent, with loader: LoadingHelper) {
        paramenters = (loadPage, loader)
    }
    
    nonisolated private func append(_ content: PagingContent) async {
        let itemsToAdd = direction == .top ? content.items.reversed() : content.items
        var array = await direction == .top ? self.content.items.reversed() : self.content.items
        var set = Set(array)
        var allItemsAreTheSame = true // backend returned the same items for the next page, prevent for infinit loading
        
        itemsToAdd.forEach {
            if !set.contains($0) {
                set.insert($0)
                array.append($0)
                allItemsAreTheSame = false
            }
        }
        await update(content: PagingContent(direction == .top ? array.reversed() : array, next: allItemsAreTheSame ? nil : content.next))
    }
    
    private func update(content: PagingContent) {
        self.content = content
    }
    
    public func initalRefresh() {
        if state.value != .loading && content.items.isEmpty {
            refresh()
        }
    }
    
    public func refresh() {
        refresh(userInitiated: false)
    }
    
    public func refresh(userInitiated: Bool) {
        performOnRefresh?()
        
        paramenters.loader.run(userInitiated ? .alertOnFail : (content.items.isEmpty ? initialLoading : .none), id: feedId) { [weak self] _ in
            self?.state.value = .loading
            
            do {
                if let result = try await self?.paramenters.loadPage(nil),
                   let equal = await self?.content.isEqual(result) {
                    
                    self?.state.value = .stop
                    if !equal {
                        self?.content = result
                        self?.firstPageCache?.save(result.items as! [Item])
                    }
                }
            } catch {
                self?.state.process(error)
                throw error
            }
        }
    }
    
    public func loadMore() {
        guard let next = content.next else { return }
        state.value = .loading
        
        paramenters.loader.run(.none, id: feedId) { [weak self] _ in
            do {
                if let result = try await self?.paramenters.loadPage(next) {
                    await self?.append(result)
                    self?.state.value = .stop
                }
            } catch {
                self?.state.process(error)
                throw error
            }
        }
    }
    
    public func resetFail() {
        if case .failed(_) = state.value {
            state.reset()
        }
    }
    
    public func loadMoreIfAllowed() {
        if content.next != nil && state.value == .stop && shouldLoadMore() {
            loadMore()
        }
    }
    
    public func retry() {
        if content.next != nil {
            loadMoreIfAllowed()
        } else {
            refresh(userInitiated: true)
        }
    }
}
