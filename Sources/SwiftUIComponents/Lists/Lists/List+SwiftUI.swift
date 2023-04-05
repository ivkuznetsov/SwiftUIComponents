//
//  List+SwiftUI.swift
//  

#if os(iOS)
import UIKit
import SwiftUI
import Combine

public typealias GridLayout = Layout<Collection>

public typealias ListLayout = Layout<Table>

public class ListViewController<List: ListContainer>: PlatformViewController {
    
    let list = List()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.attach(list.content.view.scrollView)
    }
}

@MainActor
public struct Layout<List: ListContainer>: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ListViewController<List>
    
    private let snapshot: Snapshot<List.View>
    private let setup: ((List)->())?
    private let emptyState: any View
    
    public init(_ views: [ViewContainer], setup: ((List)->())? = nil) {
        self.init({ $0.addSection(views) }, setup: setup)
    }
    
    public init(emptyState: any View = EmptyView(), _ data: (inout Snapshot<List.View>)->(), setup: ((List)->())? = nil) {
        var snapshot = Snapshot<List.View>()
        data(&snapshot)
        self.snapshot = snapshot
        self.setup = setup
        self.emptyState = emptyState
    }
    
    public func makeUIViewController(context: Context) -> UIViewControllerType {
        UIViewControllerType()
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        uiViewController.list.content.emptyState.rootView = emptyState.asAny
        uiViewController.list.content.set(snapshot, animated: true)
    }
}
#endif
