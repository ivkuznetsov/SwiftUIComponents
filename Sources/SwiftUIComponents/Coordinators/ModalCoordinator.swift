//
//  ModalCoordinator.swift
//
//  Created by Ilya Kuznetsov on 07/05/2023.
//

import Foundation
import CommonUtils
import SwiftUI

public enum ModalStyle {
    case sheet
    case cover
    case overlay
}

public protocol ModalProtocol: Hashable, Identifiable, Extractable {
    
    var style: ModalStyle { get }
}

public extension ModalProtocol {
    
    var style: ModalStyle { .sheet }
    
    var id: Int { hashValue }
}

public protocol ModalCoordinator: Coordinator {
    associatedtype Modal: ModalProtocol
    associatedtype ModalView: View
    
    @ViewBuilder func destination(for modal: Modal) -> ModalView
}

public enum PresentationType {
    case overAll
    case replaceCurrent
}

public extension ModalCoordinator {
    
    ///Present a flow modally over current navigation
    func present(_ modalFlow: Modal, type: PresentationType = .overAll) {
        present(.init(modalFlow: modalFlow, destination: { self.destination(for: modalFlow).asAny }), type: type)
    }
}

private struct ModalModifer: ViewModifier {
    
    @ObservedObject var state: NavigationState
    
    func isPresentedBinding(_ style: ModalStyle) -> Binding<Bool> {
        .init {
            state.modalPresented?.modalFlow.style == style
        } set: { _ in
            if let presented = state.modalPresented,
               let overlayPresented = presented.coordinator.state.modalPresented,
               overlayPresented.modalFlow.style == .overlay {
                presented.coordinator.state.modalPresented = nil
            } else {
                state.modalPresented = nil
            }
        }
    }
    
    func body(content: Content) -> some View {
        content.overlay {
            if let presented = state.modalPresented, presented.modalFlow.style == .overlay {
                presented.destination()
                    .coordinateSpace(name: CoordinateSpace.modal)
            }
        }.sheet(isPresented: isPresentedBinding(.sheet)) {
            
            state.modalPresented!.destination()
                .coordinateSpace(name: CoordinateSpace.modal)
            
        }.fullScreenCover(isPresented: isPresentedBinding(.cover)) {
            
            state.modalPresented!.destination()
                .coordinateSpace(name: CoordinateSpace.modal)
        }
    }
}

public extension View {
    
    func withModal<C: Coordinator>(_ coordinator: C) -> some View {
        modifier(ModalModifer(state: coordinator.state)).environmentObject(coordinator)
    }
}

