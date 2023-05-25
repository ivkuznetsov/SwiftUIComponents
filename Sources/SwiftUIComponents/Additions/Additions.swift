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
    let edge: ()->Edge
    
    func body(content: Content) -> some View {
        content.offset(x: presented ? 0 : (UIScreen.main.bounds.width * (edge() == .leading ? 1 : -1) * (inverse ? -1 : 1)))
    }
}

public extension AnyTransition {
    
    static func move(edge: @escaping ()->Edge) -> AnyTransition {
        .asymmetric(insertion: .modifier(active: MovePositionModifier(presented: false, inverse: false, edge: edge),
                                         identity: MovePositionModifier(presented: true, inverse: false, edge: edge)),
                    removal: .modifier(active: MovePositionModifier(presented: false, inverse: true, edge: edge),
                                       identity: MovePositionModifier(presented: true, inverse: true, edge: edge)))
        
        
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
