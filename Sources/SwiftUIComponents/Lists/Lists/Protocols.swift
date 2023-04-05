//
//  Protocols.swift
//  

import Foundation
import SwiftUI

public protocol WithConfiguration: AnyObject {
#if os(iOS)
    var contentConfiguration: UIContentConfiguration? { get set }
#endif
}

public protocol DataSource: AnyObject {
    func snapshot() -> DataSourceSnapshot
    func apply(_ snapshot: DataSourceSnapshot, animated: Bool) async
}

public protocol ListView: PlatformView {
    associatedtype Cell: WithConfiguration
    associatedtype CellAdditions
    associatedtype Content: DataSource
    
    var scrollView: PlatformScrollView { get }
    
    func enumerateVisibleCells(_ action: (IndexPath, Cell)->())
}

public protocol ListContainer {
    associatedtype View: ListView
    
    @MainActor var content: ListContent<View> { get }
    
    @MainActor init()
}
