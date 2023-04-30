//
//  ListTracker.swift
//  

import Foundation
import SwiftUI
import Combine
import CommonUtils

#if os(iOS)
final class RefreshControl: UIRefreshControl {
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window != nil && isRefreshing, let scrollView = superview as? UIScrollView {
            let offset = scrollView.contentOffset
            UIView.performWithoutAnimation { endRefreshing() }
            beginRefreshing()
            scrollView.contentOffset = offset
        }
    }
}
#endif

fileprivate let pagingLoadingSectionId = "loadingId"

public extension Snapshot {
    
    mutating func addLoading() {
        addViewSectionId(pagingLoadingSectionId)
    }
}

@MainActor
public final class ListTracker<List: ListContainer>: NSObject {
    
    public let list: List
    public var loadMoreView: ((LoadingState, _ retry: @escaping ()->())->any View) = { FoolterLoadingView(state: $0, retry: $1) }
    
    private var loadingObserver: AnyCancellable?
    private(set) var paging: (any ObservablePagingLoader)?
    private var footerVisible = false
    
    public func set(paging: (any ObservablePagingLoader)?) {
        if self.paging === paging { return }
        self.paging = paging
        
        #if os(iOS)
        loadingObserver = paging?.loadingState.$value.sink { [weak self] in
            if $0 != .loading {
                self?.endRefreshing()
            }
        }
        #endif
    }
    
    public init(list: List, hasRefreshControl: Bool = true) {
        self.list = list
        super.init()
        list.content.delegate.add(self)
        
        #if os(iOS)
        let refreshControl = hasRefreshControl ? RefreshControl() : nil
        refreshControl?.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
        list.content.view.scrollView.refreshControl = refreshControl
        #endif
    }
    
    public func set(_ snapshot: Snapshot<List.View>, animated: Bool = false) {
        var result = snapshot
        
        if let paging = paging, snapshot.data.sectionIdentifiers.contains(pagingLoadingSectionId) {
            var hasRefresh = false
            #if os(iOS)
            hasRefresh = list.content.view.scrollView.refreshControl != nil
            #endif
             
            let anyContent = paging.contentState.anyContent
            
            if (!hasRefresh && anyContent.items.isEmpty) || anyContent.next != nil {
                
                result.add(loadMoreView(paging.loadingState, { [weak self] in
                    self?.retry()
                }).onBecomingVisible(perform: { [weak self] visible in
                    guard let wSelf = self else { return }
                    
                    wSelf.footerVisible = visible
                    
                    if !visible, case .failed(_) = wSelf.paging?.loadingState.value {
                        wSelf.paging?.loadingState.reset()
                    }
                    wSelf.loadMoreIfAllowed()
                }).inContainer(), sectionId: pagingLoadingSectionId)
            }
        }
        
        Task {
            await list.content.set(result, animated: animated)
            await MainActor.run {
                loadMoreIfAllowed()
            }
        }
    }
    
    private func retry() {
        if let paging = paging {
            if paging.contentState.anyContent.next != nil {
                paging.loadMore()
            } else {
                paging.refresh(userInitiated: true)
            }
        }
    }
    
    private func loadMoreIfAllowed() {
        if isFooterVisible && paging?.loadingState.value == .stop {
            paging?.loadMore()
        }
    }
    
    private var isFooterVisible: Bool { list.content.view.scrollView.contentSize.height > 0 && footerVisible }
    
    #if os(iOS)
    private var performedEndRefreshing = false
    private var performedRefresh = false

    @objc private func refreshAction() {
        performedRefresh = true
    }

    @objc func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        endDecelerating()
        list.content.delegate.without(self) {
            (list.content.delegate as? UIScrollViewDelegate)?.scrollViewDidEndDecelerating?(scrollView)
        }
    }

    @objc func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endDecelerating() }
        list.content.delegate.without(self) {
            (list.content.delegate as? UIScrollViewDelegate)?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }
    }

    func endDecelerating() {
        let scrollView = list.content.view.scrollView
        if performedEndRefreshing && !scrollView.isDecelerating && !scrollView.isDragging {
            performedEndRefreshing = false
            DispatchQueue.main.async { [weak scrollView] in
                scrollView?.refreshControl?.endRefreshing()
            }
        }
        if performedRefresh {
            performedRefresh = false
            paging?.refresh(userInitiated: true)
        }
    }
    
    private func endRefreshing() {
        let scrollView = list.content.view.scrollView
        guard let refreshControl = scrollView.refreshControl else { return }
        
        if scrollView.isDecelerating || scrollView.isDragging {
            performedEndRefreshing = true
        } else if scrollView.window != nil && refreshControl.isRefreshing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                refreshControl.endRefreshing()
            })
        } else {
            refreshControl.endRefreshing()
        }
    }
    #endif
}
