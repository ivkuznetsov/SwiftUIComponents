//
//  Table.swift
//  

#if os(iOS)
import UIKit
import SwiftUI
#else
import AppKit
#endif

public struct TableCellAdditions {
    
    #if os(iOS)
    public enum Editor {
        case delete(()->())
        case insert(()->())
        case actions(()->[UIContextualAction])
        
        var style: UITableViewCell.EditingStyle {
            switch self {
            case .delete(_): return .delete
            case .insert(_): return .insert
            case .actions(_): return .none
            }
        }
    }
    
    let editor: (AnyHashable)->Editor?
    
    #else
    let menuItems: (AnyHashable)->[NSMenuItem]
    #endif
}

extension PlatformTableDataSource: DataSource {
    
    public func apply(_ snapshot: DataSourceSnapshot, animated: Bool) async {
        if #available(iOS 15, *) {
            await apply(snapshot, animatingDifferences: animated)
        } else {
            await withCheckedContinuation { continuation in
                apply(snapshot, animatingDifferences: animated) {
                    continuation.resume()
                }
            }
        }
    }
}

public extension Snapshot where View == PlatformTableView {
    
    mutating func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)->Content,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             editor: ((Item)->TableCellAdditions.Editor?)? = nil) {
        let reuseId = String(describing: Item.self)
        
        addSection(items, section: .init(Item.self,
                                         fill: { item, cell in
            cell.automaticallyUpdatesContentConfiguration = false
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration { fill(item) }.margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfigurationBackport { fill(item).ignoresSafeArea() }.margins(.all, 0)
            }
        }, reuseId: { _ in reuseId }))
    }
}

@MainActor
public final class Table: NSObject, ListContainer, PlatformTableDelegate, PrefetchTableProtocol {
    
    public let content: ListContent<PlatformTableView>
    
    #if os(macOS)
    public var deselectedAll: (()->())?
    
    /*public var selectedItem: AnyHashable? {
        set {
            if let item = newValue, let index = items.firstIndex(of: item) {
                FirstResponderPreserver.performWith(view.window) {
                    view.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                }
            } else {
                view.deselectAll(nil)
            }
        }
        get { item(IndexPath(item: view.selectedRow, section: 0)) }
    }*/
    #endif
    
    static func createDefaultView() -> PlatformTableView {
        #if os(iOS)
        let table = PlatformTableView(frame: CGRect.zero, style: .plain)
        table.backgroundColor = .clear
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 150
        
        table.subviews.forEach {
            if let view = $0 as? UIScrollView {
                view.delaysContentTouches = false
            }
        }
        #else
        let scrollView = NSScrollView()
        let table = TableView(frame: .zero)
        
        scrollView.documentView = table
        scrollView.drawsBackground = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        table.backgroundColor = .clear
        table.intercellSpacing = .zero
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.headerView = nil
        scrollView.retained(by: self)
        #endif
        return table
    }
    
    public convenience override init() {
        self.init(listView: Self.createDefaultView())
    }
    
    public init(listView: PlatformTableView) {
        content = .init(view: listView)
        super.init()
        
        #if os(iOS)
        
        content.dataSource = PlatformTableDataSource(tableView: content.view) { [unowned self] tableView, indexPath, item in
            
            guard let info = content.snapshot.info(indexPath)?.section else {
                fatalError("Please specify cell for \(item)")
            }
            let cell = content.view.createCell(reuseId: info.features.reuseId(item))
            info.fill(item, cell)
            return cell
        }
        #else
        let dataSource = PlatformTableDataSource(tableView: content.view) { tableView, tableColumn, row, identifier in
            NSView()
        }
        dataSource.rowViewProvider = { [unowned self] tableView, index, item in
            guard let info = content.snapshot.info(IndexPath(item: index, section: 0))?.section else {
                fatalError("Please specify cell for \(item)")
            }
            let cell = content.view.createCell(reuseId: info.features.reuseId(item))
            info.fill(item, cell)
            return cell
        }
        #endif
        content.delegate.add(self)
        content.delegate.addConforming(PlatformTableDelegate.self)
        content.view.delegate = content.delegate as? PlatformTableDelegate
        
        #if os(iOS)
        content.view.tableFooterView = UIView()
        #else
        //view.menu = NSMenu()
        //view.menu?.delegate = self
        content.view.wantsLayer = true
        content.view.target = self
        content.view.usesAutomaticRowHeights = true
        #endif
    }
    
    #if os(iOS)
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if let info = content.snapshot.info(indexPath),
            let editor = info.section.features.additions?.editor(info.item) {
            switch editor {
            case .delete(let action): action()
            case .insert(let action): action()
            default: break
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let info = content.snapshot.info(indexPath),
           let editor = info.section.features.additions?.editor(info.item),
           case .actions(let actions) = editor {
            let configuration = UISwipeActionsConfiguration(actions: actions())
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if let info = content.snapshot.info(indexPath),
           let editor = info.section.features.additions?.editor(info.item) {
            return editor.style
        }
        return .none
    }
    
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        content.prefetch(indexPaths)
    }
    
    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        content.cancelPrefetch(indexPaths)
    }
    #else
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selected = view.selectedRowIndexes
        
        if selected.isEmpty {
            deselectedAll?()
        } else {
            selected.forEach {
                view.deselectRow($0)
            }
        }
    }
    /*
    @objc public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let info = snapshot.info(.init(index: view.clickedRow)) {
            info.section.
        }
        
        if let item = item(.init(row: view.clickedRow, section: 0)) {
            cells.info(item)?.menuItems(item).forEach { menu.addItem($0) }
        }
    }*/
    #endif
}
