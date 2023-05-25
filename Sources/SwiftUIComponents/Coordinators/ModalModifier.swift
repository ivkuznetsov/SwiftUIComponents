//
//  Modal.swift
//
//  Created by Ilya Kuznetsov on 07/05/2023.
//

import Foundation
import CommonUtils
import SwiftUI

fileprivate struct ModalModifer<C: Coordinator>: ViewModifier {
    
    let coordinator: C
    @ObservedObject var state: CoordinatorState<C.Path, C.Screen, C.Modal>
    
    init(coordinator: C) {
        self.coordinator = coordinator
        self.state = coordinator.state
    }
    
    func body(content: Content) -> some View {
        content.overlay {
            if let presented = coordinator.state.presented, presented.style == .overlay {
                coordinator.modalDestination(for: presented).environmentObject(coordinator)
            }
        }.sheet(isPresented: .init(get: { coordinator.state.presented?.style == .sheet },
                                   set: { _ in coordinator.dismissPresented() })) {
            coordinator.modalDestination(for: coordinator.state.presented!)
        }.fullScreenCover(isPresented: .init(get: { coordinator.state.presented?.style == .cover },
                                             set: { _ in coordinator.dismissPresented() })) {
            coordinator.modalDestination(for: coordinator.state.presented!)
        }
    }
}

public extension View {
    
    func withModal<C: Coordinator>(_ coordinator: C) -> some View {
        modifier(ModalModifer(coordinator: coordinator)).environmentObject(coordinator)
    }
}

