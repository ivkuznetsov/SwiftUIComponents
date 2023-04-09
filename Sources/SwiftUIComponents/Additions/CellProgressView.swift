//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 08/04/2023.
//

import Foundation
import SwiftUI

fileprivate struct InCellProgressViewRepresentable: UIViewRepresentable {
    
    @Binding var updater: Bool
    let style: InCellProgressView.Style
    
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView()
        indicator.startAnimating()
        indicator.hidesWhenStopped = false
        indicator.style = style == .big ? .large : .medium
        return indicator
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        _ = updater
        uiView.startAnimating()
    }
}

public struct InCellProgressView: View {
    
    public enum Style {
        case big
        case small
    }
    
    public var style: Style = .small
    @State private var updater: Bool = true
    
    public var body: some View {
        InCellProgressViewRepresentable(updater: $updater, style: style).onAppear {
            updater.toggle()
        }
    }
}
