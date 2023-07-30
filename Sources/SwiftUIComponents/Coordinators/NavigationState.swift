//
//  NavigationState.swift
//  
//
//  Created by Ilya Kuznetsov on 28/07/2023.
//

import Foundation
import SwiftUI

public struct ModalPresentation {
    
    private final class PlaceholderCoordinator: Coordinator { }
    
    public let modalFlow: any ModalProtocol
    
    let coordinator: any Coordinator
    let destination: ()->AnyView
    
    init(modalFlow: any ModalProtocol, destination: @escaping () -> AnyView) {
        self.modalFlow = modalFlow
        
        if let coordinator = modalFlow.extractValue(of: (any Coordinator).self) {
            self.destination = destination
            self.coordinator = coordinator
        } else {
            let coordinator = PlaceholderCoordinator()
            self.destination = { destination().withModal(coordinator).asAny }
            self.coordinator = coordinator
        }
    }
}

public final class NavigationState: ObservableObject {
    
    /// Current navigation path
    @Published public var path: [AnyHashable] = []
    
    /// Modal flow presented over current navigation
    @Published public internal(set) var modalPresented: ModalPresentation?
    
    /// Parent coordinator presented current navigation modally
    public internal(set) weak var presentedBy: (any Coordinator)?
    
    public init() {
        $path.sinkOnMain(retained: self) { _ in
            InputState.closeKeyboard()
        }
        $modalPresented.sinkOnMain(retained: self) { _ in
            InputState.closeKeyboard()
        }
    }
}

