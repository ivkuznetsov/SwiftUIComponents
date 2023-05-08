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

public protocol ModalFlowProtocol: Hashable, Identifiable, Extractable {
    
    var style: ModalStyle { get }
    
    var coordinator: (any Coordinator)? { get }
}

public extension ModalFlowProtocol {
    
    var style: ModalStyle { .sheet }
    
    var coordinator: (any Coordinator)? {
        extractValue(of: (any Coordinator).self)
    }
    
    var id: Int { hashValue }
}

public protocol ModalCoordinator: Coordinator {
    associatedtype ModalFlow: ModalFlowProtocol
    associatedtype ModalView: View
    
    var presented: ModalFlow? { get set }
    
    @ViewBuilder func modal(for flow: ModalFlow) -> ModalView
    
    func dismiss()
}
 
public extension ModalCoordinator {
    
    func present(_ flow: ModalFlow) {
        flow.coordinator?.presenter = self
        presented = flow
    }
    
    func dismiss() {
        presenter?.dismissPresented()
    }
    
    func dismissPresented() {
        presented = nil
    }
}

fileprivate struct ModalModifer<Coordinator: ModalCoordinator>: ViewModifier {
    
    @ObservedObject var coordinator: Coordinator
    
    func body(content: Content) -> some View {
        content.overlay {
            if let presented = coordinator.presented, presented.style == .overlay {
                coordinator.modal(for: presented)
            }
        }.sheet(isPresented: .init(get: { coordinator.presented?.style == .sheet },
                                   set: { _ in coordinator.presented = nil })) {
            coordinator.modal(for: coordinator.presented!)
        }.fullScreenCover(isPresented: .init(get: { coordinator.presented?.style == .cover },
                                             set: { _ in coordinator.presented = nil })) {
            coordinator.modal(for: coordinator.presented!)
        }
    }
}

public extension View {
    
    func withModal<C: ModalCoordinator>(_ coordinator: C) -> some View {
        modifier(ModalModifer(coordinator: coordinator))
    }
}

