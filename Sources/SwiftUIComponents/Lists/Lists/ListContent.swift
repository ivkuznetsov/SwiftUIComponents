//
//  ListContent.swift
//  

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import CommonUtils

public struct PrefetchCancel {
    let cancel: ()->()

    public init(_ cancel: @escaping ()->()) {
        self.cancel = cancel
    }
}

@MainActor
public final class ListContent<View: ListView> {
    
    public let view: View
    public let emptyState = UIHostingController(rootView: AnyView(EmptyView()))
    public let delegate = DelegateForwarder()
    
    public internal(set) var dataSource: View.Content!
    private let serialUpdate = SerialTasks()
    var oldSnapshot: Snapshot<View>?
    
    public private(set) var snapshot = Snapshot<View>()
    public var showNoData: (DataSourceSnapshot) -> Bool = { $0.numberOfItems == 0 }
    
    init(view: View) {
        self.view = view
        emptyState.view.backgroundColor = .clear
    }
    
    #if os(iOS)
    private var prefetchTokens: [IndexPath:PrefetchCancel] = [:]

    func prefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            if let info = snapshot.info($0),
               let cancel = info.section.prefetch?(info.item) {
                prefetchTokens[$0] = cancel
            }
        }
    }

    func cancelPrefetch(_ indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchTokens[$0]?.cancel()
            prefetchTokens[$0] = nil
        }
    }
    #endif
    
    public func set(_ snapshot: Snapshot<View>, animated: Bool = false) {
        Task { await set(snapshot, animated: animated) }
    }
    
    private func update(snapshot: Snapshot<View>) {
        oldSnapshot = self.snapshot
        self.snapshot = snapshot
    }
    
    public func set(_ snapshot: Snapshot<View>, animated: Bool = false) async {
        try? await serialUpdate.run { @MainActor [oldSnapshot = self.snapshot] in
            let animatedResult = animated && oldSnapshot.data.numberOfItems > 0 && snapshot.data.numberOfItems > 0
            self.update(snapshot: snapshot)
            await self.dataSource.apply(snapshot.data, animated: animatedResult)
            
            let wasAttached = self.emptyState.view.superview != nil
            
            if self.showNoData(snapshot.data) {
                self.view.attach(self.emptyState.view, type: .safeArea)
                self.view.scrollView.isScrollEnabled = false
            } else {
                self.emptyState.view.removeFromSuperview()
                self.view.scrollView.isScrollEnabled = true
            }
            
            let isAttached = self.emptyState.view.superview != nil
            
            if animated && !isAttached && wasAttached {
                let transition = CATransition()
                transition.type = .fade
                transition.duration = 0.15
                transition.fillMode = .both
                self.view.layer.add(transition, forKey: "fade")
            }
        }
    }
    
    public func reloadVisibleCells() {
        view.enumerateVisibleCells { indexPath, cell in
            if let info = snapshot.info(indexPath) {
                info.section.fill(info.item, cell)
            }
        }
    }
    
    public func item(_ indexPath: IndexPath) -> AnyHashable? {
        let snapshot = dataSource.snapshot()
        if let section = snapshot.sectionIdentifiers[safe: indexPath.section] {
            return snapshot.itemIdentifiers(inSection: section)[safe: indexPath.item]
        }
        return nil
    }
    
    deinit {
        #if os(iOS)
        prefetchTokens.values.forEach { $0.cancel() }
        #endif
    }
}

