//
//  BecomingVisibleModifier.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 24/01/2023.
//

import SwiftUI

public extension UIApplication {
    var sceneKeyWindow: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    var colorScheme: UIUserInterfaceStyle {
        UIApplication.shared.sceneKeyWindow?.traitCollection.userInterfaceStyle ?? .light
    }
}

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        UIApplication.shared.sceneKeyWindow?.safeAreaInsets.swiftUiInsets ?? EdgeInsets()
    }
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

public extension View {
    
    func onBecomingVisible(perform action: @escaping (Bool)->()) -> some View {
        modifier(BecomingVisible(action: action))
    }
}

private struct BecomingVisible: ViewModifier {
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    let action: (Bool)->()

    var screenWithInset: CGRect {
        var frame = UIScreen.main.bounds
        frame.origin.y += safeAreaInsets.top + 44
        frame.size.height -= safeAreaInsets.top + safeAreaInsets.bottom + 44 + 49
        frame.origin.x += safeAreaInsets.leading
        frame.size.width -= safeAreaInsets.leading + safeAreaInsets.trailing
        return frame
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.overlay {
                Color.clear.ignoresSafeArea().onAppear {
                    action(true)
                }.onDisappear {
                    action(false)
                }
            }
        } else {
            content.overlay {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: VisibleKey.self,
                            value: screenWithInset.intersects(proxy.frame(in: .global))
                        )
                        .onPreferenceChange(VisibleKey.self) {
                            action($0)
                        }.onAppear {
                            if screenWithInset.insetBy(dx: 0, dy: -20).intersects(proxy.frame(in: .global)) {
                                action(true)
                            }
                        }.onDisappear {
                            action(false)
                        }
                }.ignoresSafeArea()
            }
        }
    }

    struct VisibleKey: PreferenceKey {
        static var defaultValue: Bool = false
        static func reduce(value: inout Bool, nextValue: () -> Bool) { }
    }
}
