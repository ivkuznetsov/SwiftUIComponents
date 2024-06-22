//
//  CloseButton.swift
//

import Foundation
import SwiftUI

public struct CloseButton: View {
    
    @EnvironmentObject private var contentStyle: ContentStyle
    @Environment(\.dismiss) private var dismiss
    
    let icon: String
    let title: String
    var iconColor: Color = .clear
    var background: Color = .clear
    let action: (()->())?
    
    public init(icon: String = "xmark",
                title: String = "Close",
                iconColor: Color? = nil,
                background: Color? = nil,
                action: (()->())? = nil) {
        self.icon = icon
        self.title = title
        self.action = action
        self.iconColor = iconColor ?? contentStyle.labelColor
        self.background = background ?? contentStyle.controlColor
    }
    
    var button: some View {
        Button(action: {
            if let action = action {
                withAnimation {
                    action()
                }
            } else {
                dismiss()
            }
        }, label: {
            Image(systemName: icon)
        })
        .accessibilityLabel(title)
    }
    
    public var body: some View {
        button
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(iconColor)
            .frame(width: 33, height: 33)
            .background(background)
            .buttonStyle(PlainButtonStyle())
            .clipShape(Circle())
            .padding(.horizontal, 3)
    }
}

public extension View {
    
    func withCloseButton(action: (()->())? = nil) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CloseButton(action: action)
            }
        }
    }
    
    func withBackButton(action: (()->())? = nil) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CloseButton(icon: "chevron.left", action: action)
            }
        }.navigationBarBackButtonHidden()
    }
}
