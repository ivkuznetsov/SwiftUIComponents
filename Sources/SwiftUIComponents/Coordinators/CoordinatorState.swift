//
//  CoordinatorState.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 08/05/2023.
//

import Foundation
import SwiftUI
import CommonUtils

public final class CoordinatorState<T: NavigationPathProtocol, Screen: ScreenProtocol, Modal: ModalProtocol>: ObservableObject {
    
    @Published public var path: T = .init([Screen]())
    @Published public var presented: Modal?
    
    public var presenter: (any Coordinator)?
    
    private(set) var elements: [Screen] = []
    
    public init() {
        $path.sinkOnMain(retained: self) { [weak self] path in
            guard let wSelf = self else { return }
            
            if path.count < wSelf.elements.count {
                wSelf.elements = Array(wSelf.elements.prefix(path.count))
            }
        }
    }
    
    func set(presenter: (any Coordinator)?) {
        self.presenter = presenter
    }
    
    func dismiss() {
        presented = nil
    }
    
    func append(_ value: Screen) {
        elements.append(value)
        path.append(value)
    }
    
    func pop() {
        elements.removeLast()
        path.removeLast(1)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    func popTo(where condition: (Screen) -> Bool) -> Bool {
        if let index = elements.firstIndex(where: condition) {
            let count = elements.count - index - 1
            path.removeLast(count)
            return true
        }
        return false
    }
}
