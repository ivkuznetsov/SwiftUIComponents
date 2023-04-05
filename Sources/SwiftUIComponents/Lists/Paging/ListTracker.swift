//
//  ListTracker.swift
//  

import Foundation
import SwiftUI
import Combine

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
    
    private var stateObserver: AnyCancellable?
    private(set) var paging: (any PagingProtocol)?
    private var footerVisible = false
    
    public func set(paging: (any PagingProtocol)?) {
        if self.paging === paging { return }
        self.paging = paging
        
        #if os(iOS)
        stateObserver = paging?.state.$value.sink { [weak self] state in
            if state != .loading {
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
            
            if (!hasRefresh && paging.content.items.isEmpty) || paging.content.next != nil {
                result.add(loadMoreView(paging.state, { [weak self] in
                    self?.paging?.retry()
                }).onBecomingVisible(perform: { [weak self] visible in
                    self?.footerVisible = visible
                    
                    if !visible {
                        self?.paging?.resetFail()
                    }
                    
                    if self?.isFooterVisible == true {
                        self?.paging?.loadMoreIfAllowed()
                    }
                }).inContainer(), sectionId: pagingLoadingSectionId)
            }
        }
        
        Task {
            await list.content.set(result, animated: animated)
            await MainActor.run {
                if isFooterVisible {
                    paging?.loadMoreIfAllowed()
                }
            }
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
