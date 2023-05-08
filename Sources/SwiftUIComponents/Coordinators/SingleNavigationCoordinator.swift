//
//  SingleNavigationCoordinator.swift
//  
//
//  Created by Ilya Kuznetsov on 08/05/2023.
//

import Foundation
import SwiftUI

open class SingleNavigationCoordinator<Path: NavigationPathProtocol>: NavigationCoordinator {
    
    @Published public var path = PathContainer(Path.init([Screen]()))
    
    public var presenter: (any ModalCoordinator)?
    
    public enum Screen: Hashable {
        case none
    }
    
    public init() { }
    
    public func destination(for screen: Screen) -> EmptyView { EmptyView() }
}
