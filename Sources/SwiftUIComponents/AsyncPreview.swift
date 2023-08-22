//
//  AsyncPreview.swift
//  
//
//  Created by Ilya Kuznetsov on 23/05/2023.
//

import Foundation
import SwiftUI

public struct AsyncPreview<T>: View {
    
    @State private var value: T?
    
    private let prepare: () async ->T
    private let view: (T)->AnyView
    
    public init<Content: View>(_ prepare: @escaping () async -> T, view: @escaping (T) -> Content) {
        self.prepare = prepare
        self.view = { view($0).asAny }
    }
    
    public var body: some View {
        ZStack {
            if let value = value {
                view(value)
            }
        }.task {
            value = await prepare()
        }
    }
}
