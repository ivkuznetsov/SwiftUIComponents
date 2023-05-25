//
//  NavigationPath.swift
//  
//
//  Created by Ilya Kuznetsov on 08/05/2023.
//

import Foundation
import SwiftUI

@available(iOS 16.0, *)
extension NavigationPath: NavigationPathProtocol { }

@available(iOS 16.0, *)
typealias CommonCoordinatorState<Screen: ScreenProtocol, Modal: ModalProtocol> = CoordinatorState<NavigationPath, Screen, Modal>

@available(iOS 16.0, *)
public extension View {
    
    func with<C: Coordinator>(_ coordinator: C) -> some View where C.Path == NavigationPath {
        modifier(NavigationModifer(coordinator: coordinator)).withModal(coordinator)
    }
}

@available(iOS 16.0, *)
public extension Coordinator where Path == NavigationPath {
    
    func view(for screen: Screen) -> some View {
        destination(for: screen).with(self)
    }
    
    func view(for modal: Modal) -> some View {
        modalDestination(for: modal).with(self)
    }
}

@available(iOS 16.0, *)
public struct NavigationModifer<C: Coordinator>: ViewModifier where C.Path == NavigationPath {
    
    let coordinator: C
    @ObservedObject var state: CommonCoordinatorState<C.Screen, C.Modal>
    
    init(coordinator: C) {
        self.coordinator = coordinator
        self.state = coordinator.state
    }
    
    public func body(content: Content) -> some View {
        NavigationStack(path: $state.path) {
            content.navigationDestination(for: C.Screen.self) {
                coordinator.destination(for: $0)
            }
        }.navigationViewStyle(.stack)
            .environmentObject(coordinator)
    }
}
