//
//  InputContentView.swift
//
//  Created by Ilya Kuznetsov on 22/05/2023.
//

import Foundation
import UIKit
import SwiftUI
import Combine

private struct InputFieldModifier<Value: Equatable>: ViewModifier {
    
    @State var identifier: UUID
    let inputState: InputState
    
    let validation: (Value)->ValidationResult
    let errorView: (String)->AnyView
    @Binding var value: Value
    @State private var shake = false
    @State private var validationResult = ValidationResult.valid
    
    private func updateFrame(frame: CGRect) -> some View {
        inputState.inputs[identifier] = frame
        return Color.clear
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            if case .invalid(let string) = validationResult, string.count > 0 {
                HStack {
                    errorView(string)
                    Spacer()
                }
            }
        }.shaked(shake)
            .id(identifier)
            .focused(inputState.focused, equals: identifier)
            .background {
                GeometryReader { updateFrame(frame: $0.frame(in: .named(CoordinateSpace.inputView))) }
            }.simultaneousGesture(TapGesture().onEnded { _ in
                inputState.focused.wrappedValue = identifier
            }, including: inputState.focused.wrappedValue == identifier ? .subviews : .all).onAppear {
                inputState.validations[identifier] = {
                    withAnimation {
                        validationResult = validation(value)
                    }
                    if validationResult != .valid {
                        shake.toggle()
                    }
                    return validationResult
                }
            }.onChange(of: value) { newValue in
                if validationResult != .valid {
                    withAnimation {
                        validationResult = .valid
                    }
                }
            }
    }
}

public struct InputErrorView: View {
    
    private let title: String
    
    public init(title: String) {
        self.title = title
    }
    
    public var body: some View {
        Text(title)
            .padding(.horizontal, 15)
            .foregroundColor(.red)
    }
}

public extension View {
    
    func input<Value: Equatable>(_ inputState: InputState,
                                 id: UUID = UUID(),
                                 errorView: @escaping (String)->AnyView = { InputErrorView(title: $0).asAny },
                                 value: Binding<Value>,
                                 validation: @escaping (Value)->ValidationResult) -> some View {
        modifier(InputFieldModifier(identifier: id,
                                    inputState: inputState,
                                    validation: validation,
                                    errorView: { AnyView(errorView($0)) },
                                    value: value))
    }
    
    func input<Value: Equatable>(_ inputState: InputState,
                                 id: UUID = UUID(),
                                 errorView: @escaping (String)->AnyView = { InputErrorView(title: $0).asAny },
                                 value: Binding<Value>,
                                 validation: @escaping (Value)->Bool = { _ in true }) -> some View {
        input(inputState,
              id: id,
              errorView: errorView,
              value: value,
              validation: { validation($0) ? .valid : .invalid() })
    }
    
    func input(_ inputState: InputState) -> some View {
        input(inputState, errorView: { _ in EmptyView().asAny }, value: .constant(true))
    }
}

private extension CoordinateSpace {
    
    static let inputView = "inputView"
}

private struct InputGesturesModifer: ViewModifier {
    
    @ObservedObject var state: InputState
    
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content
                .coordinateSpace(name: CoordinateSpace.inputView)
                .gesture(SpatialTapGesture(coordinateSpace: .named(CoordinateSpace.inputView)).onEnded { value in
                
                if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first,
                   let view = window.hitTest(value.location, with: nil),
                   view as? UITextInput == nil,
                   state.inputs.values.first(where: { $0.contains(value.location) }) == nil {
                    state.closeKeyboard()
                }
            }, including: state.keyboardPresented ? .all : .subviews)
        } else {
            content.gesture(TapGesture().onEnded { _ in
                state.closeKeyboard()
            }, including: state.keyboardPresented ? .all : .subviews)
        }
    }
}

public struct InputContentView<Content: View>: View {
    
    @StateObject private var state = InputState()
    @FocusState private var focus: UUID?
    
    private let content: (InputState)->Content
    
    public init(_ content: @escaping (_ inputState: InputState)->Content) {
        self.content = content
    }
    
    var contentView: some View {
        state.focused = $focus
        return content(state)
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            contentView
                .modifier(InputGesturesModifer(state: state))
                .onReceive(state.scrollToItem.debounce(for: 0.5, scheduler: DispatchQueue.main)) { item in
                    withAnimation {
                        proxy.scrollTo(item)
                    }
                }.onAppear {
                    state.isVisisble = true
                }.onDisappear {
                    state.isVisisble = false
                }
        }
    }
}
