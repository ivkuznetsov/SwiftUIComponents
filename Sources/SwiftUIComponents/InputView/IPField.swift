//
//  IPField.swift
//
//
//  Created by Ilya Kuznetsov on 30/06/2024.
//

import Foundation
import SwiftUI
import Combine

public extension String {
    
    var isValidIP: Bool {
        if isEmpty { return false }
        
        let parts = split(separator: ".")
        guard parts.count == 4 else { return false }
        
        return parts.allSatisfy { part in
            if let num = Int(part), num >= 0, num <= 255 {
                return true
            }
            return false
        }
    }
    
    var isStartsWithIP: Bool {
        if isEmpty { return true }
        
        let parts = split(separator: ".")
        guard parts.count <= 4 else { return false }
        
        return parts.allSatisfy { part in
            if let num = Int(part), num >= 0, num <= 255 {
                return true
            }
            return false
        }
    }
}

public struct IPField: View {
    
    let title: String
    @State private var oldValue: String = ""
    @Binding var value: String
    
    public init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
    }
    
    public var body: some View {
        TextField(title, text: $value).onReceive(Just(value)) {
            if !$0.isStartsWithIP {
                value = oldValue
            } else if !$0.isEmpty {
                oldValue = $0
            }
        }.keyboardType(.numbersAndPunctuation)
            .onAppear { oldValue = value }
    }
}
