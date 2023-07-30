//
//  Coordinator.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 02/04/2023.
//

import Foundation
import SwiftUI
import CommonUtils

public typealias NavigationModalCoordinator = NavigationCoordinator & ModalCoordinator

public extension CoordinateSpace {
    
    static let navController = "CoordinatorSpaceNavigationController"
    static let modal = "CoordinatorSpaceModal"
}

public protocol Coordinator: ObservableObject, Hashable { }

private var coordinatorStateKey = "coordinatorStateKey"

public extension Coordinator {
    
    var state: NavigationState {
        get {
            if let state = objc_getAssociatedObject(self, &coordinatorStateKey) as? NavigationState {
                return state
            } else {
                let state = NavigationState()
                objc_setAssociatedObject(self, &coordinatorStateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return state
            }
        }
        set {
            objc_setAssociatedObject(self, &coordinatorStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.hashValue == rhs.hashValue }
    
    /// Dismiss current modal navigation
    func dismiss() {
        state.presentedBy?.dismissPresented()
    }
    
    /// Dismiss modal navigation presented over current navigation
    func dismissPresented() {
        state.modalPresented = nil
    }
    
    /// Move to previous screen of the current navigation
    func pop() {
        state.path.removeLast()
    }
    
    /// Move to the first screen of the current navigation
    func popToRoot() {
        state.path.removeLast(state.path.count)
    }
}

extension Coordinator {
    
    func present(_ presentation: ModalPresentation, type: PresentationType = .overAll) {
        if let presentedCoordinator = state.modalPresented?.coordinator {
            switch type {
            case .replaceCurrent:
                dismissPresented()
                DispatchQueue.main.async { [weak self] in
                    self?.present(presentation, type: type)
                }
            case .overAll:
                presentedCoordinator.present(presentation, type: type)
            }
        } else {
            presentation.coordinator.state.presentedBy = self
            state.modalPresented = presentation
        }
    }
}
