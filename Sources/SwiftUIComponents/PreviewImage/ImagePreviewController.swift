//
//  ImagePreviewController.swift
//

import UIKit
import SwiftUI

public struct ExpandablePreviewImage: UIViewRepresentable {
    
    final class ExpandButton: UIButton {
        
        var fullImageProvider: FullImageProvider?
        
        init() {
            super.init(frame: .zero)
            clipsToBounds = true
            imageView?.contentMode = .scaleAspectFill
            addTarget(self, action: #selector(selectAction), for: .touchUpInside)
            setContentCompressionResistancePriority(.init(1), for: .vertical)
            setContentCompressionResistancePriority(.init(1), for: .horizontal)
        }
        
        override func setImage(_ image: UIImage?, for state: UIControl.State) {
            super.setImage(image, for: state)
            imageView?.frame = self.bounds
        }
        
        @objc private func selectAction() {
            if let vc = searchViewController(),
                let image = image(for: .normal) {
                vc.present(ImagePreviewController(image: image,
                                                  fullImageProvider: fullImageProvider,
                                                  sourceView: self,
                                                  contentMode: .scaleAspectFill),
                           animated: true)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let provider: FullImageProvider?
    private let setup: ((UIButton)->())
    
    public init(provider: FullImageProvider? = nil, setup: @escaping (UIButton) -> Void) {
        self.provider = provider
        self.setup = setup
    }
    
    public func makeUIView(context: Context) -> UIView {
        let button = ExpandButton()
        setup(button)
        return button
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) { 
        (uiView as! ExpandButton).fullImageProvider = provider
    }
}

public enum FullImageProvider {
    case image(UIImage)
    case url(URL)
    case loader(() async throws ->UIImage)
}

open class ImagePreviewController: UIViewController {
    
    private let image: UIImage
    private let fullImageProvider: FullImageProvider?
    private let scrollView = PreviewScrollView()
    
    private var downloadTask: Task<Void, Error>?
    let animation: ExpandAnimation
    
    public init(image: UIImage, fullImageProvider: FullImageProvider? = nil, sourceView: UIView, contentMode: UIView.ContentMode) {
        self.image = image
        self.fullImageProvider = fullImageProvider
        animation = ExpandAnimation(source: sourceView, dismissingSource: scrollView.imageView, contentMode: contentMode)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.set(image: image)
        
        animation.viewController = self
        self.transitioningDelegate = animation
        
        scrollView.didZoom = { [weak self] (zoom) in
            if let wSelf = self {
                wSelf.animation.interactionDismissing = zoom <= wSelf.scrollView.minimumZoomScale
            }
        }
        scrollView.didZoom?(scrollView.zoomScale)
        
        let completion: (UIImage?)->() = { [weak self] image in
            guard let image = image else { return }
            
            Task { @MainActor in
                self?.scrollView.imageView.image = image
                let transition = CATransition()
                transition.duration = 0.15
                self?.scrollView.imageView.layer.add(transition, forKey: nil)
            }
        }
        
        switch fullImageProvider {
        case .image(let image):
            scrollView.imageView.image = image
        case .url(let url):
            downloadTask = Task {
                let data = try await URLSession.shared.data(from: url).0
                completion(UIImage(data: data))
            }
        case .loader(let operation):
            downloadTask = Task { completion(try? await operation()) }
        case .none: break
        }
    }
    
    deinit {
        downloadTask?.cancel()
    }
}
