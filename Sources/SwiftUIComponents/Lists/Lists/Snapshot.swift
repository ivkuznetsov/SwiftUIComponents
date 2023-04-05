//
//  File.swift
//  

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

public typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<String, AnyHashable>

public struct Snapshot<View: ListView> {
    
    struct Section {
        
        struct Features {
            let reuseId: (AnyHashable)->String
            let prefetch: ((AnyHashable)->PrefetchCancel?)?
            let additions: View.CellAdditions?
        }
        
        let fill: (AnyHashable, View.Cell)->()
        let typeCheck: (AnyHashable)->Bool
        let features: Features
        
        init<Item: Hashable>(_ item: Item.Type,
                             fill: @escaping (Item, View.Cell)->(),
                             reuseId: @escaping (Item)->String,
                             prefetch: ((Item)->PrefetchCancel)? = nil,
                             additions: View.CellAdditions? = nil) {
            
            self.fill = { fill($0 as! Item, $1) }
            self.typeCheck = { $0 is Item }
            self.features = .init(reuseId: { reuseId($0 as! Item) },
                                  prefetch: prefetch == nil ? nil : { prefetch!($0 as! Item) },
                                  additions: additions)
        }
    }
    
    public static func with(_ fill: (inout Snapshot<View>)->()) -> Snapshot<View> {
        var snapshot = Snapshot<View>()
        fill(&snapshot)
        return snapshot
    }
    
    private(set) var sections: [Section] = []
    public private(set) var data = DataSourceSnapshot()
    private var sectionIds = Set<String>()
    
    public init() {}
    
    var hasPrefetch: Bool { sections.contains(where: { $0.features.prefetch != nil }) }
    
    private var viewContainerInfo: Section {
        Section(ViewContainer.self, fill: {
            $1.contentConfiguration = $0.configuration
        }, reuseId: { $0.reuseId })
    }
    
    mutating public func addSection<T: SwiftUI.View>(_ view: T) {
        addSection([view.inContainer()])
    }
    
    mutating public func addSection(_ view: ViewContainer) {
        addSection([view])
    }
    
    mutating public func addSection(_ views: [ViewContainer]) {
        addSection(views, section: viewContainerInfo)
    }
    
    mutating func add(_ item: AnyHashable, sectionId: String) {
        data.appendItems([item], toSection: sectionId)
    }
    
    mutating func addSection<T: Hashable>(_ items: [T], section: Section) {
        let className = String(describing: T.self)
        var sectionId = className
        var counter = 0
        while sectionIds.contains(sectionId) {
            counter += 1
            sectionId = className + "\(counter)"
        }
        sectionIds.insert(sectionId)
        data.appendSections([sectionId])
        data.appendItems(items, toSection: sectionId)
        sections.append(section)
    }
    
    func info(_ indexPath: IndexPath) -> (section: Section, item: AnyHashable)? {
        if let section = sections[safe: indexPath.section],
           let sectionId = data.sectionIdentifiers[safe: indexPath.section],
           let item = data.itemIdentifiers(inSection: sectionId)[safe: indexPath.item] {
            return (section, item)
        }
        return nil
    }
    
    mutating public func addViewSectionId(_ id: String) {
        data.appendSections([id])
        sections.append(viewContainerInfo)
    }
}

public extension DataSourceSnapshot {
    
    mutating func add<T: Hashable>(_ items: [T]) {
        let sectionName = String(describing: T.self)
        appendSections([sectionName])
        appendItems(items, toSection: sectionName)
    }
}
