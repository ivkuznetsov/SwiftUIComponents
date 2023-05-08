//
//  Coordinator.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 02/04/2023.
//

import Foundation
import SwiftUI
import CommonUtils

public protocol Coordinator: ObservableObject, Hashable {
    
    var presenter: (any ModalCoordinator)? { get set }
}

extension Coordinator {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.hashValue == rhs.hashValue }
}

open class BaseCoordinator<Path: NavigationPathProtocol, Screen: Hashable, ModalFlow: ModalFlowProtocol>: ObservableObject {
    
    public var presenter: (any ModalCoordinator)?
    
    @Published public var path = PathContainer(Path.init([Screen]()))

    @Published public var presented: ModalFlow?
    
    public init() { }
}

