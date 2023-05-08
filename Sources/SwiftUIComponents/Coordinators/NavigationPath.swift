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
public extension PathContainer {
    
    static func make() -> PathContainer<NavigationPath> { .init(.init()) }
}

@available(iOS 16.0, *)
public extension View {
    
    func withNavigation<C: NavigationCoordinator>(_ coordinator: C) -> some View where C.Path == NavigationPath  {
        modifier(NavigationModifer(coordinator: coordinator))
    }
    
    func with<C: NavigationCoordinator & ModalCoordinator>(_ coordinator: C) -> some View where C.Path == NavigationPath {
        withNavigation(coordinator).withModal(coordinator)
    }
}

@available(iOS 16.0, *)
public struct NavigationModifer<Coordinator: NavigationCoordinator>: ViewModifier where Coordinator.Path == NavigationPath {
    
    let coordinator: Coordinator
    @ObservedObject var path: PathContainer<Coordinator.Path>
    
    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        self.path = coordinator.path
    }
    
    public func body(content: Content) -> some View {
        NavigationStack(path: $path.path) {
            content.navigationDestination(for: Coordinator.Screen.self) {
                coordinator.destination(for: $0)
            }
        }.navigationViewStyle(.stack)
            .environmentObject(coordinator)
    }
}
