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
    var iconColor: Color?
    var background: Color?
    let action: (()->())?
    
    public init(icon: String = "xmark",
                title: String = "Close",
                iconColor: Color? = nil,
                background: Color? = nil,
                action: (()->())? = nil) {
        self.icon = icon
        self.title = title
        self.action = action
        self.iconColor = iconColor
        self.background = background
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
            .foregroundColor(iconColor ?? contentStyle.labelColor)
            .frame(width: 33, height: 33)
            .background(background ?? contentStyle.controlColor)
            .buttonStyle(PlainButtonStyle())
            .clipShape(Circle())
            .padding(.horizontal, 3)
    }
}

public extension View {
    
    func withCloseButton(action: (()->())? = nil, hidden: Bool = false) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !hidden {
                    CloseButton(action: action)
                }
            }
        }
    }
    
    func withBackButton(action: (()->())? = nil, hidden: Bool = false) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !hidden {
                    CloseButton(icon: "chevron.left", action: action)
                }
            }
        }.navigationBarBackButtonHidden()
    }
}
