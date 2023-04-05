//
//  CollectionView.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

class CollectionViewLayout: PlatformCollectionLayout {
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size ?? newBounds.size != newBounds.size
    }
}

extension PlatformCollectionCell: WithConfiguration { }

public final class CollectionView: PlatformCollectionView, ListView {
    public typealias CellAdditions = CollectionCellAdditions
    public typealias Cell = PlatformCollectionCell
    public typealias Content = PlatformCollectionDataSource
    
    public var scrollView: PlatformScrollView {
        #if os(iOS)
        self
        #else
        enclosingScrollView!
        #endif
    }
    
    #if os(iOS)
    public required override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        canCancelContentTouches = true
        delaysContentTouches = false
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .automatic
        showsHorizontalScrollIndicator = false
    }
    
    public override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl ? true : super.touchesShouldCancel(in: view)
    }
    
    #else
    public override var acceptsFirstResponder: Bool { false }
    #endif
}

public extension PlatformCollectionView {
    
    static var cellsKey = "cellsKey"
    
    #if os(iOS)
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #else
    private var registeredCells: Set<String> {
        get { objc_getAssociatedObject(self, &PlatformCollectionView.cellsKey) as? Set<String> ?? Set() }
        set { objc_setAssociatedObject(self, &PlatformCollectionView.cellsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    #endif
    
    func createCell(reuseId: String, at indexPath: IndexPath) -> PlatformCollectionCell {
        
        if !registeredCells.contains(reuseId) {
            #if os(iOS)
            register(PlatformCollectionCell.self, forCellWithReuseIdentifier: reuseId)
            #else
            register(PlatformCollectionCell.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: reuseId))
            #endif
            registeredCells.insert(reuseId)
        }
        #if os(iOS)
        return dequeueReusableCell(withReuseIdentifier: reuseId, for: indexPath)
        #else
        return makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: reuseId), for: indexPath)
        #endif
    }
    
    func enumerateVisibleCells(_ action: (IndexPath, PlatformCollectionCell)->()) {
        #if os(iOS)
        let visibleCells = visibleCells
        #else
        let visibleCells = visibleItems()
        #endif
        visibleCells.forEach { cell in
            if let indexPath = indexPath(for: cell) {
                action(indexPath, cell)
            }
        }
    }
}
