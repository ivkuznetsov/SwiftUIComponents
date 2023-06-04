//
//  Once.swift
//  
//
//  Created by Ilya Kuznetsov on 01/06/2023.
//

import Foundation
import SwiftUI

public final class Once<Content: View, Input> {
    
    let make: (Input)->Content
    var content: Content?
    
    public func content(_ input: Input) -> Content {
        if let content = content {
            return content
        } else {
            let content = make(input)
            self.content = content
            return content
        }
    }
    
    public init(_ make: @escaping (Input)->Content) {
        self.make = make
    }
}
