//
//  FooterLoadingView.swift
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Combine
import SwiftUI
import CommonUtils

public struct FoolterLoadingView: View {
    
    @ObservedObject var state: LoadingState
    let retry: ()->()
    
    public var body: some View {
        ZStack {
            switch state.value {
            case .stop:
                EmptyView()
            case .failed(_):
                Button("Retry") {
                    retry()
                }
            case .loading:
                InCellProgressView()
            }
        }.frame(height: 44)
    }
}
