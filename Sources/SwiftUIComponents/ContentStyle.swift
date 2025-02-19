//
//  ContentStyle.swift
//

import Foundation
import SwiftUI
import Combine

public struct Chevron: View {
    
    public var body: some View {
        Image(systemName: "chevron.right")
            .font(Font.system(.footnote)
                .weight(.semibold)).opacity(0.5)
    }
    
    public init() {}
}

@MainActor
public final class ContentStyle: ObservableObject {
    
    @Published public var content: [String:Any] = [:]
    
    public var labelColor: Color {
        set { content["label"] = newValue }
        get { content["label"] as? Color ?? Color(.label) }
    }
    
    public var invertedLabelColor: Color {
        set { content["invertedLabel"] = newValue }
        get { content["invertedLabel"] as? Color ?? Color(.systemBackground) }
    }
    
    public var controlColor: Color {
        set { content["control"] = newValue }
        get { content["control"] as? Color ?? Color(.secondarySystemBackground) }
    }
    
    public var accentTint: Color {
        set { content["accent"] = newValue }
        get { content["accent"] as? Color ?? Color(.systemBlue) }
    }
    
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
        public let supportAccessibility: Bool
        public let font: (FontSize)->Font
        public let uiFont: (FontSize, UIFont.Weight)->UIFont
        
        public init(supportAccessibility: Bool = false, font: @escaping (FontSize) -> Font = { .system(size: $0.rawValue) },
             uiFont: @escaping (FontSize, UIFont.Weight) -> UIFont =  { .systemFont(ofSize: $0.rawValue, weight: $1) }) {
            self.supportAccessibility = supportAccessibility
            self.font = font
            self.uiFont = uiFont
        }
    }
    
    private var dynamicTypeObserver: AnyCancellable?
    
    public init(labelColor: Color = Color(.label),
         invertedLabelColor: Color = Color(.systemBackground),
         controlColor: Color = .black,
         accentTint: Color = Color(.systemBlue),
         fonts: FontsProvider = .init(),
         maxControlWidth: CGFloat = 330,
         maxContentWidth: CGFloat = 600) {
        self.fonts = fonts
        self.maxControlWidth = maxControlWidth
        self.maxContentWidth = maxContentWidth
        self.labelColor = labelColor
        self.invertedLabelColor = invertedLabelColor
        self.controlColor = controlColor
        self.accentTint = accentTint
        
        dynamicTypeObserver = NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification).sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

struct AppFontModifier: ViewModifier {
    
    @EnvironmentObject var contentStyle: ContentStyle
    
    private let size: ContentStyle.FontSize
    @ScaledMetric private var scaledSize: CGFloat
    
    init(size: ContentStyle.FontSize) {
        self.size = size
        _scaledSize = .init(wrappedValue: size.rawValue)
    }
    
    public func body(content: Content) -> some View {
        content.font(contentStyle.fonts.font(contentStyle.fonts.supportAccessibility ? .init(rawValue: scaledSize) : size))
    }
}

public struct MaxControlWidthModifier: ViewModifier {
    
    @EnvironmentObject var contentStyle: ContentStyle
    
    public func body(content: Content) -> some View {
        content.frame(maxWidth: contentStyle.maxControlWidth)
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
