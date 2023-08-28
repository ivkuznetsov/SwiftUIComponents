//
//  InputState.swift
//  
//
//  Created by Ilya Kuznetsov on 27/08/2023.
//

import Foundation
import SwiftUI
import Combine

private extension UISpringTimingParameters {
    var mass: Double? { value(forKey: "mass") as? Double }
    var stiffness: Double? { value(forKey: "stiffness") as? Double }
    var damping: Double? { value(forKey: "damping") as? Double }
}

public enum ValidationResult: Equatable {
    case valid
    case invalid(String = "")
}

public final class InputState: ObservableObject {
    @Published public var keyboardInset: CGFloat = 0
    
    var inputs: [UUID:CGRect] = [:]
    var validations: [UUID:()->ValidationResult] = [:]
    var focused: FocusState<UUID?>.Binding!
    var isVisisble: Bool = false
    
    public var keyboardPresented: Bool { keyboardInset > 0 }
    
    let scrollToItem = PassthroughSubject<UUID, Never>()
    
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
    
    private var observer: AnyCancellable?
    
    init() {
        observer = NotificationCenter.default.publisher(for: UIApplication.keyboardWillChangeFrameNotification)
            .sink(receiveValue: { [weak self] notification in
                guard let wSelf = self, wSelf.isVisisble else { return }
                
                let keyboardFrame = notification.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                
                withAnimation(wSelf.animation(from: notification)) {
                    if keyboardFrame.minY + keyboardFrame.height <= UIScreen.main.bounds.height {
                        let inset = UIScreen.main.bounds.height - keyboardFrame.minY
                        
                        if inset != wSelf.keyboardInset {
                            wSelf.keyboardInset = inset
                            
                            if let focused = wSelf.focused.wrappedValue {
                                wSelf.scrollToItem.send(focused)
                            }
                        }
                    } else {
                        if wSelf.keyboardInset != 0 {
                            wSelf.keyboardInset = 0
                        }
                    }
                }
        })
    }
    
    public func select(_ id: UUID) {
        focused.wrappedValue = id
    }
    
    public func nextInput(_ currentId: UUID) -> UUID? {
        var nextInput: (id: UUID, rect: CGRect)?
        inputs.forEach { id, rect in
            if rect.origin.y > inputs[currentId]!.origin.y &&
                (nextInput == nil || rect.origin.y < nextInput!.rect.origin.y) {
                nextInput = (id, rect)
            }
        }
        return nextInput?.id
    }
    
    public func previousInput(_ currentId: UUID) -> UUID? {
        var previousInput: (id: UUID, rect: CGRect)?
        inputs.forEach { id, rect in
            if rect.origin.y < inputs[currentId]!.origin.y &&
                (previousInput == nil || rect.origin.y > previousInput!.rect.origin.y) {
                previousInput = (id, rect)
            }
        }
        return previousInput?.id
    }
    
    public func selectNext(_ id: UUID? = nil) -> Bool {
        if let id = id ?? focused.wrappedValue, let next = nextInput(id) {
            focused.wrappedValue = next
            return true
        }
        return false
    }
    
    public func selectPrevious(_ id: UUID? = nil) -> Bool {
        if let id = id ?? focused.wrappedValue, let next = previousInput(id) {
            focused.wrappedValue = next
            return true
        }
        return false
    }
    
    public func closeKeyboard() {
        focused.wrappedValue = nil
    }
    
    public static func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    public func validate() -> Bool {
        var result = true
        
        validations.values.forEach {
            if $0() != .valid {
                result = false
            }
        }
        return result
    }
}
