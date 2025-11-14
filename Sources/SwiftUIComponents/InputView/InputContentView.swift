//
//  InputContentView.swift
//
//  Created by Ilya Kuznetsov on 22/05/2023.
//

import Foundation
import UIKit
import SwiftUI
import Combine

public enum ValidationResult: Equatable {
    case valid
    case invalid(String = "")
}

struct WeakWrapper<T: AnyObject> {
    weak var object: T?
    
    func callAsFunction() -> T? { object }
}

public final class FieldState: ObservableObject {
    
    let id: UUID
    weak var inputState: InputState?
    
    @Published var validationResult = ValidationResult.valid
    @Published var shake = false
    var validate: (()->ValidationResult)!
    
    private var inputObserver: AnyCancellable?
    
    init(id: UUID, inputState: InputState, validate: @escaping ()->ValidationResult) {
        self.id = id
        self.inputState = inputState
        self.validate = { [weak self] in
            guard let wSelf = self else { return .valid }
            
            withAnimation {
                wSelf.validationResult = validate()
            }
            if wSelf.validationResult != .valid {
                DispatchQueue.main.async {
                    wSelf.shake.toggle()
                }
            }
            return wSelf.validationResult
        }
        
        inputState.fields[id] = WeakWrapper(object: self)
        
        inputObserver = inputState.$focused.sink { [weak self] _ in
            //if $0 == id {
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            //}
        }
    }
    
    func update(frame: CGRect) {
        inputState?.inputs[id] = frame
    }
    
    func resetValidation() {
        if validationResult != .valid {
            withAnimation {
                validationResult = .valid
            }
        }
    }
    
    deinit {
        inputState?.fields[id] = nil
    }
}

private struct InputFieldModifier<Value: Equatable, ErrorView: View>: ViewModifier {
    
    @StateObject var state: FieldState
    @Binding var value: Value
    @FocusState var focus: Bool
    
    let errorView: (String)->ErrorView
    let errorUnderline: Bool
    
    init(state: @autoclosure @escaping () -> FieldState,
         errorUnderline: Bool,
         errorView: @escaping (String)->ErrorView,
         value: Binding<Value>) {
        _state = .init(wrappedValue: state())
        _value = value
        self.errorView = errorView
        self.errorUnderline = errorUnderline
    }
    
    private func update(frame: CGRect) -> some View {
        state.update(frame: frame)
        return Color.clear
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            if case .invalid(let string) = state.validationResult, string.count > 0 {
                errorView(string)
            }
        }
        .background {
            if errorUnderline, case .invalid = state.validationResult {
                RoundedRectangle(cornerRadius: 8, style: .continuous).foregroundStyle(Color.red.opacity(0.1)).padding(.horizontal, -5)
            }
        }
        .id(state.id)
        .shaked(state.shake)
        .focused($focus)
        .onChange(of: state.inputState?.focused) {
            if $0 == state.id {
                if !focus {
                    focus = true
                }
            } else {
                if focus && $0 == nil {
                    focus = false
                }
            }
        }
        .onChange(of: focus) {
            if $0 {
                if state.inputState?.focused != state.id {
                    state.inputState?.focused = state.id
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if state.inputState?.focused == state.id {
                        state.inputState?.focused = nil
                    }
                }
            }
        }
        .background {
            GeometryReader { update(frame: $0.frame(in: .named(CoordinateSpace.inputView))) }
        }
        .onChange(of: value) { _ in
            state.resetValidation()
        }
    }
}

public struct InputErrorView: View {
    
    private let title: String
    
    public init(title: String) {
        self.title = title
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .padding(.horizontal, 15)
                .foregroundColor(.red)
            Spacer()
        }
    }
}

public extension View {
    
    func input(_ inputState: InputState,
               id: UUID = UUID(),
               errorView: @escaping (String)->AnyView = { InputErrorView(title: $0).asAny }) -> some View {
        input(inputState, id: id, errorView: errorView, value: .init(get: { true }, set: { _ in }), validation: { _ in true })
    }
    
    func input<Value: Equatable>(_ inputState: InputState,
                                 id: UUID = UUID(),
                                 errorUnderline: Bool = false,
                                 errorView: @escaping (String)->AnyView = { InputErrorView(title: $0).asAny },
                                 value: Binding<Value>,
                                 validation: @escaping (Value)->ValidationResult = { _ in .valid }) -> some View {
        modifier(InputFieldModifier(state: .init(id: id, inputState: inputState, validate: { validation(value.wrappedValue) }),
                                    errorUnderline: errorUnderline,
                                    errorView: errorView,
                                    value: value))
    }
    
    func input<Value: Equatable>(_ inputState: InputState,
                                 id: UUID = UUID(),
                                 errorUnderline: Bool = false,
                                 errorView: @escaping (String)->AnyView = { InputErrorView(title: $0).asAny },
                                 value: Binding<Value>,
                                 validation: @escaping (Value)->Bool) -> some View {
        modifier(InputFieldModifier(state: .init(id: id, inputState: inputState, validate: { validation(value.wrappedValue) ? .valid : .invalid() }),
                                    errorUnderline: errorUnderline,
                                    errorView: errorView,
                                    value: value))
    }
    
    func input(_ inputState: InputState) -> some View {
        input(inputState, errorView: { _ in EmptyView().asAny }, value: .constant(true))
    }
}

private extension CoordinateSpace {
    
    static let inputView = "inputView"
}

private struct InputContentModifier: ViewModifier {
    
    @ObservedObject var state: InputState
    @FocusState private var focus: UUID?
    
    private func updateCloseArea(_ proxy: GeometryProxy) -> some View {
        state.closeGesture.touchCloseArea = proxy.frame(in: .global)
        return Color.clear
    }
    
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onReceive(state.scrollToItem.debounce(for: 0.5, scheduler: DispatchQueue.main)) { item in
                    withAnimation {
                        proxy.scrollTo(item.0, anchor: item.1)
                    }
                }.onAppear {
                    state.isVisisble = true
                }.onDisappear {
                    state.isVisisble = false
                }
        }
        .onChange(of: focus) { newValue in
            print(newValue?.uuidString ?? "none")
        }
        .background {
            GeometryReader { updateCloseArea($0) }
        }
        .allowsHitTesting(!state.disableTouch)
    }
}

public struct InputContentView<Content: View>: View {
    
    @State private var state = InputState()
    
    private let content: (InputState)->Content
    
    public init(_ content: @escaping (_ inputState: InputState)->Content) {
        self.content = content
    }
    
    public var body: some View {
        content(state)
            .modifier(InputContentModifier(state: state))
    }
}
