//
//  ContentStyle.swift
//

import Foundation
import SwiftUI

public struct Chevron: View {
    
    public var body: some View {
        Image(systemName: "chevron.right")
            .font(Font.system(.footnote)
                .weight(.semibold)).opacity(0.5)
    }
    
    public init() {}
}

open class ContentStyle: ObservableObject {
    
    @Published public var labelColor: Color
    @Published public var invertedLabelColor: Color
    @Published public var controlColor: Color
    @Published public var accentTint: Color
    
    @Published public var fonts: FontsProvider
    @Published public var maxControlWidth: CGFloat
    @Published public var maxContentWidth: CGFloat
    
    public struct FontSize: Codable, Hashable, RawRepresentable {
        public var rawValue: CGFloat
        
        public init(rawValue: CGFloat) {
            self.rawValue = rawValue
        }
        
        public static let huge = FontSize(rawValue: 26)
        public static let big = FontSize(rawValue: 20)
        public static let header = FontSize(rawValue: 16)
        public static let normal = FontSize(rawValue: 14)
        public static let small = FontSize(rawValue: 12)
    }
    
    public struct FontsProvider {
        public let font: (FontSize)->Font
        public let uiFont: (FontSize, UIFont.Weight)->UIFont
        
        public init(font: @escaping (FontSize) -> Font = { .system(size: $0.rawValue) },
             uiFont: @escaping (FontSize, UIFont.Weight) -> UIFont =  { .systemFont(ofSize: $0.rawValue, weight: $1) }) {
            self.font = font
            self.uiFont = uiFont
        }
    }
    
    public init(labelColor: Color = Color(.label),
         invertedLabelColor: Color = Color(.systemBackground),
         controlColor: Color = .black,
         accentTint: Color = Color(.systemBlue),
         fonts: FontsProvider = .init(),
         maxControlWidth: CGFloat = 330,
         maxContentWidth: CGFloat = 600) {
        self.labelColor = labelColor
        self.invertedLabelColor = invertedLabelColor
        self.controlColor = controlColor
        self.accentTint = accentTint
        self.fonts = fonts
        self.maxControlWidth = maxControlWidth
        self.maxContentWidth = maxContentWidth
    }
}

struct AppFontModifier: ViewModifier {
    
    @EnvironmentObject var contentStyle: ContentStyle
    
    let size: ContentStyle.FontSize
    
    public func body(content: Content) -> some View {
        content.font(contentStyle.fonts.font(size))
    }
}

public struct MaxControlWidthModifier: ViewModifier {
    
    @EnvironmentObject var contentStyle: ContentStyle
    
    public func body(content: Content) -> some View {
        content.frame(maxWidth: contentStyle.maxContentWidth)
    }
}

public struct MaxContentWidthModifier: ViewModifier {
    
    @EnvironmentObject var contentStyle: ContentStyle
    
    public func body(content: Content) -> some View {
        content.frame(maxWidth: contentStyle.maxContentWidth)
    }
}

public extension View {
    
    func appFont(size: ContentStyle.FontSize = .normal) -> some View {
        modifier(AppFontModifier(size: size))
    }
    
    func maxControlWidth() -> some View {
        modifier(MaxControlWidthModifier())
    }
    
    func maxContentWidth() -> some View {
        modifier(MaxContentWidthModifier())
    }
}
