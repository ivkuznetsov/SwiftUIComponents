//
//  OrientationContainer.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 04/04/2023.
//

import Foundation
import SwiftUI

public struct OrientationKey: EnvironmentKey {
    public static let defaultValue = OrientationAttributes(injected: false)
}

public extension EnvironmentValues {
    var orientation: OrientationAttributes {
        get { self[OrientationKey.self] }
        set { self[OrientationKey.self] = newValue }
    }
}

public struct OrientationAttributes: Equatable {
    
    var injected: Bool = true
    
    public enum Orientation {
        case portrait
        case landscape
    }
    
    let internalOrientation: Orientation
    public var orientation: Orientation {
        if !injected { fatalError("The value has not been injected, check that root view wrapped in OrientationContainer { }") }
        return internalOrientation
    }
    
    let internalAppOrientation: Orientation
    public var appOrientation: Orientation {
        if !injected { fatalError("The value has not been injected, check that root view wrapped in OrientationContainer { }") }
        return internalAppOrientation
    }
    
    
    public let isiPad: Bool
    public var isPortrait: Bool {
        if !injected { fatalError("The value has not been injected, check that root view wrapped in OrientationContainer { }") }
        return orientation == .portrait
    }
    
    init(hSize: UserInterfaceSizeClass? = nil, vSize: UserInterfaceSizeClass? = nil, injected: Bool = true) {
        let screen = UIScreen.main
        internalAppOrientation = screen.bounds.width > screen.bounds.height ? .landscape : .portrait
        
        let hSize = hSize ?? .init(screen.traitCollection.horizontalSizeClass)
        let vSize = vSize ?? .init(screen.traitCollection.verticalSizeClass)
        
        if hSize == .compact && vSize == .regular {
            internalOrientation = .portrait
        } else if hSize == .regular && vSize == .compact {
            internalOrientation = .landscape
        } else {
            internalOrientation = internalAppOrientation
        }
        self.injected = injected
        self.isiPad = screen.traitCollection.horizontalSizeClass == .regular && screen.traitCollection.verticalSizeClass == .regular
    }
}

extension UserInterfaceSizeClass {
    
    init(_ uiSizeClass: UIUserInterfaceSizeClass) {
        switch uiSizeClass {
        case .compact: self = .compact
        case .regular: self = .regular
        default: self = .compact
        }
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
        _currentAttributes = .init(initialValue: .init())
        self.content = content
        self.didChange = didChange
    }
    
    public var body: some View {
        return content(currentAttributes)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewSize.self, value: proxy.size)
                        .onPreferenceChange(ViewSize.self) { attr in
                            Task { @MainActor in
                                let attr = OrientationAttributes(hSize: hSize, vSize: vSize)
                                
                                if currentAttributes != attr {
                                    currentAttributes = attr
                                }
                            }
                        }
                }
            }
            .environment(\.orientation, currentAttributes)
            .onChange(of: currentAttributes) {
                didChange?($0)
            }
    }
}
