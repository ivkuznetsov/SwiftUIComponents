//
//  NavigationCoordinator.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 08/05/2023.
//

import Foundation
import SwiftUI

public protocol NavigationPathProtocol {
    mutating func append<V: Hashable>(_ value: V)
    
    mutating func removeLast(_ k: Int)
    
    var count: Int { get }
    
    init<V: Hashable>(_ elements: [V])
}

public protocol NavigationCoordinator: Coordinator {
    associatedtype Screen: Hashable
    associatedtype ScreenView: View
    associatedtype Path: NavigationPathProtocol
    
    var path: PathContainer<Path> { get }
    
    @ViewBuilder func destination(for screen: Screen) -> ScreenView
}

public extension NavigationCoordinator {
    
    func present(_ screen: Screen) {
        path.append(screen)
    }
    
    func popToRoot() {
        path.popToRoot()
    }
    
    @discardableResult
    func popTo(where condition: (AnyHashable) -> Bool) -> Bool {
        path.popTo(where: condition)
    }
    
    @discardableResult
    func popTo(_ element: AnyHashable) -> Bool {
        popTo(where: { $0 == element })
    }
}

public final class PathContainer<T: NavigationPathProtocol>: ObservableObject {
    
    @Published public var path: T
    private(set) var elements: [AnyHashable] = []
    
    public init(_ path: T) {
        self.path = path
        $path.sinkOnMain(retained: self) { [unowned self] path in
            if path.count < elements.count {
                elements = Array(elements.prefix(path.count))
            }
        }
    }
    
    func append<V: Hashable>(_ value: V) {
        elements.append(value)
        path.append(value)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    func popTo(where condition: (AnyHashable) -> Bool) -> Bool {
        if let index = elements.firstIndex(where: condition) {
            let count = elements.count - index - 1
            path.removeLast(count)
            return true
        }
        return false
    }
}
