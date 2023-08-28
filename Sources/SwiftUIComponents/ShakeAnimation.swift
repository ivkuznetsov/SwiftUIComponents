//
//  ShakeAnimation.swift
//

import SwiftUI

struct Shake: ViewModifier {
    
    let value: Bool
    @State private var isAnimating: Bool = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: isAnimating ? 20 : 0)
            .animation(.interpolatingSpring(stiffness: 1000,
                                            damping: 15,
                                            initialVelocity: 0),
                       value: isAnimating)
            .onChange(of: value) { value in
                isAnimating = true
                DispatchQueue.main.async {
                    isAnimating = false
                }
            }
    }
}

public extension View {
    
    func shaked(_ value: Bool) -> some View {
        modifier(Shake(value: value))
    }
}
