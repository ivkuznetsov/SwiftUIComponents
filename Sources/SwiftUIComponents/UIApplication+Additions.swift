//
//  UIApplication+Additions.swift
//

import Foundation
import UIKit

public extension UIApplication {
    
    static var topViewController: UIViewController? {
        UIApplication.shared.sceneKeyWindow?.rootViewController?.topMostViewController()
    }
}

public extension UIViewController {
    
    func topMostViewController() -> UIViewController {
        if presentedViewController == nil { return self }
        
        if let navigation = presentedViewController as? UINavigationController {
            return navigation.visibleViewController!.topMostViewController()
        }
        
        if let tab = presentedViewController as? UITabBarController {
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            return tab.topMostViewController()
        }
        
        return presentedViewController!.topMostViewController()
    }
}
