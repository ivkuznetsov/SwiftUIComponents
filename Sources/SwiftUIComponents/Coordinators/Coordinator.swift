//
//  Coordinator.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 02/04/2023.
//

import Foundation
import SwiftUI
import CommonUtils

public extension CoordinateSpace {
    
    static let navController = "CoordinatorSpaceNavigationController"
    static let modal = "CoordinatorSpaceModal"
}

public protocol NavigationPathProtocol {
    mutating func append<V: Hashable>(_ value: V)
    
    mutating func removeLast(_ k: Int)
    
    var count: Int { get }
    
    init<V: Hashable>(_ elements: [V])
}

public protocol ScreenProtocol: Hashable { }

public enum ModalStyle {
    case sheet
    case cover
    case overlay
}

public protocol ModalProtocol: Hashable, Identifiable, Extractable {
    
    var style: ModalStyle { get }
    
    var coordinator: (any Coordinator)? { get }
}

public extension ModalProtocol {
    
    var style: ModalStyle {
        coordinator == nil ? .sheet : .cover
    }
    
    var coordinator: (any Coordinator)? {
        extractValue(of: (any Coordinator).self)
    }
    
    var id: Int { hashValue }
}

public protocol Coordinator: ObservableObject, Hashable {
    associatedtype Path: NavigationPathProtocol
    associatedtype Screen: ScreenProtocol
    associatedtype Modal: ModalProtocol
    associatedtype ModalView: View
    associatedtype ScreenView: View
    
    var state: CoordinatorState<Path, Screen, Modal> { get }
    
    @ViewBuilder func destination(for screen: Screen) -> ScreenView
    
    @ViewBuilder func modalDestination(for modal: Modal) -> ModalView
    
    func dismiss()
}

extension Coordinator {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.hashValue == rhs.hashValue }
}

public extension Coordinator {
    
    func set(presenter: any Coordinator) {
        state.set(presenter: presenter)
    }
    
    func present(_ flow: Modal) {
        InputState.closeKeyboard()
        
        let present = {
            flow.coordinator?.set(presenter: self)
            self.state.presented = flow
        }
        
        if state.presented != nil {
            dismissPresented()
            DispatchQueue.main.async {
                present()
            }
        } else {
            present()
        }
    }
    
    func dismiss() {
        state.presenter?.dismissPresented()
    }
    
    func dismissPresented() {
        InputState.closeKeyboard()
        state.dismiss()
    }
    
    func present(_ screen: Screen) {
        InputState.closeKeyboard()
        state.append(screen)
    }
    
    func pop() {
        InputState.closeKeyboard()
        state.pop()
    }
    
    func popToRoot() {
        InputState.closeKeyboard()
        state.popToRoot()
    }
    
    @discardableResult
    func popTo(where condition: (AnyHashable) -> Bool) -> Bool {
        state.popTo(where: condition)
    }
    
    @discardableResult
    func popTo(_ element: AnyHashable) -> Bool {
        popTo(where: { $0 == element })
    }
}

public enum NoModals: ModalProtocol { }

public extension Coordinator where Modal == NoModals {
    
    func modalDestination(for modal: Modal) -> EmptyView { EmptyView() }
}

public enum NoScreens: ScreenProtocol { }

public extension Coordinator where Screen == NoScreens {
    
    func destination(for screen: Screen) -> EmptyView { EmptyView() }
}
