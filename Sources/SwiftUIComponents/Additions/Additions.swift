//
//  Additions.swift
//  

import SwiftUI

struct SlidePositionModifier: ViewModifier {
    let presented: Bool
    
    func body(content: Content) -> some View {
        content.offset(y: presented ? 0 : -50).opacity(presented ? 1 : 0)
    }
}

public extension AnyTransition {
    
    static var slideWithOpacity: AnyTransition {
        .modifier(active: SlidePositionModifier(presented: false),
                  identity: SlidePositionModifier(presented: true))
    }
}

struct MovePositionModifier: ViewModifier {
    let presented: Bool
    let inverse: Bool
    let multiplier: CGFloat
    let edge: ()->Edge
    
    var xOffset: CGFloat {
        let edge = edge()
        
        if edge == .leading || edge == .trailing {
            return presented ? 0 : (UIScreen.main.bounds.width * multiplier * (edge == .leading ? 1 : -1) * (inverse ? -1 : 1))
        } else {
            return 0
        }
    }
    
    var yOffset: CGFloat {
        let edge = edge()
        
        if edge == .top || edge == .bottom {
            return presented ? 0 : (UIScreen.main.bounds.height * multiplier * (edge == .top ? 1 : -1) * (inverse ? -1 : 1))
        } else {
            return 0
        }
    }
    
    func body(content: Content) -> some View {
        content.offset(x: xOffset, y: yOffset)
    }
}

public extension AnyTransition {
    
    static func move(multiplier: CGFloat = 1, edge: @escaping ()->Edge) -> AnyTransition {
        .asymmetric(insertion: .modifier(active: MovePositionModifier(presented: false, inverse: false, multiplier: multiplier, edge: edge),
                                         identity: MovePositionModifier(presented: true, inverse: false, multiplier: multiplier, edge: edge)),
                    removal: .modifier(active: MovePositionModifier(presented: false, inverse: true, multiplier: multiplier, edge: edge),
                                       identity: MovePositionModifier(presented: true, inverse: true, multiplier: multiplier, edge: edge)))
        
        
    }
}

public extension Binding {
    
    func optional() -> Binding<Value?> {
        Binding<Value?>(get: { wrappedValue }, set: { wrappedValue = $0! })
    }
}

extension CaseIterable where Self: Equatable {
    
    public var asIndex: Self.AllCases.Index {
        get { Self.allCases.firstIndex(of: self)! }
        set { self = Self.allCases[newValue] }
    }
}
