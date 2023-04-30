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
    
    private let refreshControl: Bool
    private let setup: ((ListTracker<List>)->())?
    
    private let snapshot: Snapshot<List.View>
    private let emptyState: any View
    private let updatePaging: (ListTracker<List>)->()
    
    public init<Loader: ObservablePagingLoader>(_ paging: Loader?,
                                      refreshControl: Bool = true,
                                      emptyState: any View = EmptyView(),
                                      data: @escaping (inout Snapshot<List.View>, [Loader.ContentState.Item])->(),
                                      setup: ((ListTracker<List>)->())? = nil) {
        self.init(any: paging,
                  refreshControl: refreshControl,
                  emptyState: emptyState,
                  data: { data(&$0, $1 as! [Loader.ContentState.Item]) },
                  setup: setup)
    }
    
    public init(any paging: (any ObservablePagingLoader)?,
                refreshControl: Bool = true,
                emptyState: any View = EmptyView(),
                data: @escaping (inout Snapshot<List.View>, [AnyHashable])->(),
                setup: ((ListTracker<List>)->())? = nil) {
        
        var snapshot = Snapshot<List.View>()
        data(&snapshot, paging?.contentState.anyContent.items ?? [])
        
        self.snapshot = snapshot
        self.refreshControl = refreshControl
        self.setup = setup
        self.emptyState = emptyState
        self.updatePaging = { $0.set(paging: paging) }
    }
    
    public func makeUIViewController(context: Context) -> PagingListViewController<List> {
        let vc = PagingListViewController<List>(refreshControl: refreshControl)
        setup?(vc.tracker)
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: PagingListViewController<List>, context: Context) {
        let oldPaging = uiViewController.tracker.paging
        updatePaging(uiViewController.tracker)
        uiViewController.list.content.emptyState.rootView = emptyState.asAny
        uiViewController.tracker.set(snapshot, animated: oldPaging === uiViewController.tracker.paging)
    }
}
#endif
