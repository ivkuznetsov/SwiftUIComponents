//
//  OrientationContainer.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 04/04/2023.
//

import Foundation
import SwiftUI

public struct OrientationKey: EnvironmentKey {
    public static let defaultValue = OrientationAttributes.makeDefault()
}

public extension EnvironmentValues {
    var orientation: OrientationAttributes {
        get { self[OrientationKey.self] }
        set { self[OrientationKey.self] = newValue }
    }
}

public struct OrientationAttributes: Equatable {
    
    public enum Orientation {
        case portrait
        case landscape
    }
    public let orientation: Orientation
    public let isiPad: Bool
    public var isPortrait: Bool { orientation == .portrait }
    
    static func makeDefault() -> OrientationAttributes {
        let screen = UIScreen.main
        return .init(orientation: screen.bounds.width > screen.bounds.height ? .landscape : .portrait,
                     isiPad: screen.traitCollection.horizontalSizeClass == .regular &&
                             screen.traitCollection.verticalSizeClass == .regular)
    }
}

public struct OrientationContainer<V: View>: View {
    
    private struct ViewSize: PreferenceKey {
        static var defaultValue: CGSize { .init(width: 0, height: 0) }

        static func reduce(value: inout CGSize, nextValue: () -> CGSize) { }
    }
    
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    
    @State var currentAttributes: OrientationAttributes
    
    let content: (OrientationAttributes)->V
    private let didChange: ((OrientationAttributes)->())?

    public init(@ViewBuilder content: @escaping (OrientationAttributes)->V,
                didChange: ((OrientationAttributes)->())? = nil) {
        _currentAttributes = .init(initialValue: .makeDefault())
        self.content = content
        self.didChange = didChange
    }
    
    private func makeAttributes() -> OrientationAttributes {
        let bounds = UIScreen.main.bounds
        return OrientationAttributes(orientation: bounds.width > bounds.height ? .landscape : .portrait,
                                     isiPad: hSize == .regular && vSize == .regular)
    }
    
    public var body: some View {
        return content(currentAttributes)
            .environment(\.orientation, currentAttributes)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewSize.self, value: proxy.size)
                        .onPreferenceChange(ViewSize.self) { attr in
                            Task { @MainActor in
                                let attr = makeAttributes()
                                
                                if currentAttributes != attr {
                                    currentAttributes = attr
                                }
                            }
                        }
                }
            }
            .onChange(of: currentAttributes) {
                didChange?($0)
            }
    }
}
