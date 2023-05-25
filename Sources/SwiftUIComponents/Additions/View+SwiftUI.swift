//
//  View+SwiftUI.swift
//  

import SwiftUI

public extension View {
    
    var asAny: AnyView { AnyView(self) }
}

public func withoutAnimation(_ action: @escaping () -> ()) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        action()
    }
}
