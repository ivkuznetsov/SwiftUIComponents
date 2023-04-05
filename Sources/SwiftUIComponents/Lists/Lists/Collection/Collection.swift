//
//  Collection.swift
//  

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension PlatformCollectionDataSource: DataSource {
    
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

public struct CollectionCellAdditions {
    let layout: (NSCollectionLayoutEnvironment)->NSCollectionLayoutSection
    
    init(layout: ((NSCollectionLayoutEnvironment)->NSCollectionLayoutSection)?) {
        self.layout = layout ?? { .grid($0) }
    }
}

public extension Snapshot where View == CollectionView {
    
    typealias SectionLayout = (NSCollectionLayoutEnvironment)->NSCollectionLayoutSection
    
    mutating func addSection<Item: Hashable, Content: SwiftUI.View>(_ items: [Item],
                                             fill: @escaping (Item)-> Content,
                                             prefetch: ((Item)->PrefetchCancel)? = nil,
                                             layout: SectionLayout? = nil) {
        let reuseId = String(describing: Item.self)
        
        addSection(items, section: .init(Item.self, fill: { item, cell in
            if #available(iOS 16, *) {
                cell.contentConfiguration = UIHostingConfiguration { fill(item) }.margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfigurationBackport { fill(item).ignoresSafeArea() }.margins(.all, 0)
            }
        }, reuseId: { _ in reuseId }, additions: .init(layout: layout)))
    }
}

@MainActor
public final class Collection: NSObject, ListContainer, PlatformCollectionDelegate, PrefetchCollectionProtocol {
    
    public var content: ListContent<CollectionView>
    
    public static func createDefaultView() -> CollectionView {
        #if os(iOS)
        let collection = CollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        #else
        let scrollView = NSScrollView()
        let collection = CollectionView(frame: .zero)
        collection.isSelectable = true
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.canDrawConcurrently = true
        scrollView.documentView = collection
        scrollView.drawsBackground = true
        collection.backgroundColors = [.clear]
        #endif
        return collection
    }
    
    public convenience override init() {
        self.init(listView: Self.createDefaultView())
    }
    
    public required init(listView: CollectionView) {
        content = .init(view: listView)
        super.init()
        
        content.dataSource = PlatformCollectionDataSource(collectionView: content.view) { [unowned self] collection, indexPath, item in
            var info = content.snapshot.info(indexPath)?.section
            
            if info?.typeCheck(item) != true {
                info = content.oldSnapshot?.info(indexPath)?.section
                
                if info?.typeCheck(item) != true {
                    fatalError("No info for the item")
                }
            }
            
            let cell = content.view.createCell(reuseId: info!.features.reuseId(item), at: indexPath)
            info!.fill(item, cell)
            return cell
        }
        
        let layout = CollectionViewLayout { [unowned self] index, environment in
            if let layout = content.snapshot.sections[safe: index]?.features.additions?.layout {
                return layout(environment)
            }
            return .grid(environment)
        }
        #if os(iOS)
        content.view.setCollectionViewLayout(layout, animated: false)
        #else
        content.view.collectionViewLayout = layout
        #endif
        
        content.delegate.addConforming(PlatformCollectionDelegate.self)
        content.delegate.add(self)
        content.view.delegate = content.delegate as? PlatformCollectionDelegate
    }
    
    #if os(iOS)
    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        content.prefetch(indexPaths)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        content.cancelPrefetch(indexPaths)
    }
    #endif
}
