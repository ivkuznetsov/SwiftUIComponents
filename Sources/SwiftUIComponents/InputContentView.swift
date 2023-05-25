//
//  InputContentView.swift
//
//  Created by Ilya Kuznetsov on 22/05/2023.
//

import Foundation
import UIKit
import SwiftUI
import CommonUtils
import Combine

private extension UISpringTimingParameters {
    var mass: Double? { value(forKey: "mass") as? Double }
    var stiffness: Double? { value(forKey: "stiffness") as? Double }
    var damping: Double? { value(forKey: "damping") as? Double }
}

public final class InputState: ObservableObject {
    @Published public var keyboardInset: CGFloat = 0
    
    var focused: UUID?
    var inputs: [UUID:CGRect] = [:]
    
    public var keyboardPresented: Bool { keyboardInset > 0 }
    
    let scrollToItem = ValuePublisher<UUID>()
    
    private func animation(from notification: Notification) -> Animation? {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let uiKitCurve = UIView.AnimationCurve(rawValue: curveValue) else {
            return .easeOut
        }
        
        let timing = UICubicTimingParameters(animationCurve: uiKitCurve)
        if let springParams = timing.springTimingParameters,
           let mass = springParams.mass, let stiffness = springParams.stiffness, let damping = springParams.damping {
            return .interpolatingSpring(mass: mass, stiffness: stiffness, damping: damping)
        } else {
            return .easeOut(duration: duration)
        }
    }
    
    fileprivate init() {
        NotificationCenter.default.publisher(for: UIApplication.keyboardWillChangeFrameNotification)
            .sinkOnMain(retained: self, dropFirst: false) { [unowned self] notification in
            
                let keyboardFrame = notification.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                
                withAnimation(animation(from: notification)) {
                    if keyboardFrame.minY + keyboardFrame.height >= UIScreen.main.bounds.height {
                        keyboardInset = UIScreen.main.bounds.height - keyboardFrame.minY
                        if let focused = focused {
                            scrollToItem.send(focused)
                        }
                    } else {
                        keyboardInset = 0
                        focused = nil
                    }
                }
        }
    }
    
    public func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    public static func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct InputFieldModifier: ViewModifier {
    
    @State private var identifier = UUID()
    @FocusState private var focued: Bool
    let inputState: InputState
    
    func body(content: Content) -> some View {
        content.id(identifier).focused($focued).background {
            GeometryReader { proxy in
                Color.clear.onAppear {
                    inputState.inputs[identifier] = proxy.frame(in: .global)
                }
            }
        }.simultaneousGesture(TapGesture().onEnded { _ in
            focued = true
            inputState.focused = identifier
        }, including: focued ? .subviews : .all)
    }
}

public extension View {
    
    func input(_ inputState: InputState) -> some View {
        modifier(InputFieldModifier(inputState: inputState))
    }
}

public struct InputContentView<Content: View>: View {
    
    @StateObject private var state = InputState()
    
    private let content: (InputState)->Content
    
    public init(_ content: @escaping (_ inputState: InputState)->Content) {
        self.content = content
    }
    
    @ViewBuilder private var contentWithGesture: some View {
        if #available(iOS 16, *) {
            content(state).gesture(SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                
                if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first,
                   let view = window.hitTest(value.location, with: nil),
                   view as? UITextInput == nil {
                    state.closeKeyboard()
                }
            }, including: state.keyboardPresented ? .all : .subviews)
        } else {
            content(state).gesture(TapGesture().onEnded { _ in
                state.closeKeyboard()
            }, including: state.keyboardPresented ? .all : .subviews)
        }
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            contentWithGesture.onReceive(state.scrollToItem) {
                proxy.scrollTo($0, anchor: .center)
            }
        }
    }
}
