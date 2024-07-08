//
//  IntField.swift
//
//
//  Created by Ilya Kuznetsov on 30/06/2024.
//

import Foundation
import SwiftUI
import Combine

public struct IntField: View {
    
    let title: String
    @Binding var value: Int
    @State private var intString: String  = ""
    
    public init(title: String, value: Binding<Int>) {
        self.title = title
        self._value = value
    }
    
    public var body: some View {
        TextField(title, text: $intString).onReceive(Just(intString)) {
            if let i = Int($0) {
                value = i
            } else if !$0.isEmpty {
                intString = "\(value)"
            }
        }.keyboardType(.numberPad)
            .onAppear { intString = "\(value)" }
    }
}
