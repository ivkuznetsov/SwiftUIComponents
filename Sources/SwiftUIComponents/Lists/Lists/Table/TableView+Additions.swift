//
//  UITableView+Reloading.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension PlatformTableCell: WithConfiguration { }

extension PlatformTableView: ListView {
    public typealias CellAdditions = TableCellAdditions
    public typealias Cell = BaseTableViewCell
    public typealias Content = PlatformTableDataSource
    
    public var scrollView: PlatformScrollView {
        #if os(iOS)
        self
        #else
        enclosingScrollView!
        #endif
    }
}

#if os(macOS)
public class TableView: PlatformTableView {
    
    override public func drawGrid(inClipRect clipRect: NSRect) { }
}
#endif

public extension PlatformTableView {
    
    func setNeedUpdateHeights() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
        perform(#selector(updateHeights), with: nil, afterDelay: 0)
    }
    
    @objc private func updateHeights() {
        beginUpdates()
        endUpdates()
    }
    
    #if os(iOS)
    static var cellsKey = "cellsKey"
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #endif
    
    func createCell(reuseId: String) -> BaseTableViewCell {
        
    #if os(iOS)
        if !registeredCells.contains(reuseId) {
            register(BaseTableViewCell.self, forCellReuseIdentifier: reuseId)
            registeredCells.insert(reuseId)
        }
        return dequeueReusableCell(withIdentifier: reuseId) as! BaseTableViewCell
        #else
        
        let itemId = NSUserInterfaceItemIdentifier(rawValue: reuseId)
        let cell = (makeView(withIdentifier: itemId, owner: nil) ?? type.loadFromNib()) as! BaseTableViewCell
        cell.identifier = itemId
        return cell
        #endif
    }
    
    func enumerateVisibleCells(_ action: (IndexPath, BaseTableViewCell)->()) {
        #if os(iOS)
        visibleCells.forEach { cell in
            if let cell = cell as? BaseTableViewCell, let indexPath = indexPath(for: cell) {
                action(indexPath, cell)
            }
        }
        #else
        let rows = rows(in: visibleRect)
        for i in rows.location..<(rows.location + rows.length) {
            if let view = rowView(atRow: i, makeIfNecessary: false) as? BaseTableViewCell {
                action(IndexPath(item: i, section: 0), view)
            }
        }
        #endif
    }
    
    @available(iOS 15.0, *)
    func reloadVisibleCells() {
        let indexPaths = visibleCells.compactMap { indexPath(for: $0) }
        reconfigureRows(at: indexPaths)
    }
}
