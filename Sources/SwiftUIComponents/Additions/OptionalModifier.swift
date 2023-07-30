//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 28/07/2023.
//

import Foundation
import SwiftUI

private struct WithOptional<Value, Content: View, Result: View>: View {
    
    let value: ()->Value?
    let content: Content
    let result: (Content, Value)->Result
    
    var body: some View {
        if let value = value() {
            result(content, value)
        } else {
            content
        }
    }
}

public extension View {
    
    func with<Value, Result: View>(_ value: Value?, result: @escaping (Self, Value)->Result) -> some View {
        WithOptional(value: { value }, content: self, result: result)
    }
    
    func with<Value, Result: View>(_ value: @escaping ()->Value?, result: @escaping (Self, Value)->Result) -> some View {
        WithOptional(value: value, content: self, result: result)
    }
}
