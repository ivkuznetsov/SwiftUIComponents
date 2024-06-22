//
//  View+SwiftUI.swift
//  

import SwiftUI

public struct RoundedCorner: Shape {

    let radius: CGFloat
    let corners: UIRectCorner

    public init(radius: CGFloat, corners: UIRectCorner) {
        self.radius = radius
        self.corners = corners
    }
    
    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

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
