//
//  Paging+SwiftUI.swift
//  

#if os(iOS)
import SwiftUI
import Combine

public typealias PagingGrid = PagingLayout<Collection>
public typealias PagingList = PagingLayout<Table>

public final class PagingListViewController<List: ListContainer>: ListViewController<List> {
    
    fileprivate var tracker: ListTracker<List>!
    
    init(refreshControl: Bool) {
        super.init(nibName: nil, bundle: nil)
        tracker = ListTracker(list: list, hasRefreshControl: refreshControl)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
public struct PagingLayout<List: ListContainer>: UIViewControllerRepresentable {
    
    private struct InitialSetup {
        let refreshControl: Bool
        let setup: ((ListTracker<List>)->())?
    }
    
    private struct Update {
        let snapshot: Snapshot<List.View>
        let emptyState: any View
        let updatePaging: (ListTracker<List>)->()
    }
    
    private let initialSetup: InitialSetup
    private let update: Update
    
    public init<T: Hashable>(typed paging: Paging<T>?,
                             refreshControl: Bool = true,
                             emptyState: any View = EmptyView(),
                             data: @escaping (inout Snapshot<List.View>, [T])->(),
                             setup: ((ListTracker<List>)->())? = nil) {
        
        self.init(paging,
                  refreshControl: refreshControl,
                  emptyState: emptyState,
                  data: { data(&$0, $1 as! [T]) },
                  setup: setup)
    }
    
    public init(_ paging: (any PagingProtocol)?,
                refreshControl: Bool = true,
                emptyState: any View = EmptyView(),
                data: @escaping (inout Snapshot<List.View>, [AnyHashable])->(),
                setup: ((ListTracker<List>)->())? = nil) {
        
        var snapshot = Snapshot<List.View>()
        data(&snapshot, paging?.content.items ?? [])

        initialSetup = .init(refreshControl: refreshControl,
                             setup: setup)
        
        update = .init(snapshot: snapshot,
                       emptyState: emptyState,
                       updatePaging: { $0.set(paging: paging) })
    }
    
    public func makeUIViewController(context: Context) -> PagingListViewController<List> {
        let vc = PagingListViewController<List>(refreshControl: initialSetup.refreshControl)
        initialSetup.setup?(vc.tracker)
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: PagingListViewController<List>, context: Context) {
        let oldPaging = uiViewController.tracker.paging
        update.updatePaging(uiViewController.tracker)
        uiViewController.list.content.emptyState.rootView = update.emptyState.asAny
        uiViewController.tracker.set(update.snapshot, animated: oldPaging === uiViewController.tracker.paging)
    }
}
#endif
