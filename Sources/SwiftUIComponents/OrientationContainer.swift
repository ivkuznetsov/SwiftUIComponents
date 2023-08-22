//
//  OrientationContainer.swift
//  Ivory
//
//  Created by Ilya Kuznetsov on 04/04/2023.
//

import Foundation
import SwiftUI

public struct OrientationAttributes {
    
    public enum Orientation {
        case portrait
        case landscape
    }
    public let orientation: Orientation
    public let isiPad: Bool
}

public struct OrientationContainer<V: View>: View {
    
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    
    @ViewBuilder let content: (OrientationAttributes)->V
    private let didChange: ((OrientationAttributes)->())?

    public init(@ViewBuilder content: @escaping (OrientationAttributes)->V,
                didChange: ((OrientationAttributes)->())? = nil) {
        self.content = content
        self.didChange = didChange
    }
    
    private func orientation(hSize: UserInterfaceSizeClass?, vSize: UserInterfaceSizeClass?) -> OrientationAttributes {
        let isiPad = hSize == .regular && vSize == .regular
        
        if hSize == .regular || (vSize == .compact && hSize == .compact) {
            return .init(orientation: .landscape, isiPad: isiPad)
        } else{
            return .init(orientation: .portrait, isiPad: isiPad)
        }
    }
    
    public var body: some View {
        content(orientation(hSize: hSize, vSize: vSize))
            .onChange(of: hSize ?? .compact) {
                didChange?(orientation(hSize: $0, vSize: vSize))
            }.onChange(of: vSize ?? .compact) {
                didChange?(orientation(hSize: hSize, vSize: $0))
            }
    }
}
