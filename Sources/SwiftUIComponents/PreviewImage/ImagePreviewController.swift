//
//  ImagePreviewController.swift
//

import UIKit
import SwiftUI

public struct ExpandablePreviewImage: UIViewRepresentable {
    
    final class ExpandButton: UIButton {
        
        var fullImageProvider: ImageProvider?
        
        init() {
            super.init(frame: .zero)
            clipsToBounds = true
            imageView?.contentMode = .scaleAspectFill
            addTarget(self, action: #selector(selectAction), for: .touchUpInside)
            setContentCompressionResistancePriority(.init(1), for: .vertical)
            setContentCompressionResistancePriority(.init(1), for: .horizontal)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            imageView?.frame = self.bounds
        }
        
        @objc private func selectAction() {
            if let vc = searchViewController(),
                let image = image(for: .normal) {
                let imageVC = ImagePreviewController(image: image, fullImageProvider: fullImageProvider)
                imageVC.animation = ExpandAnimation(source: self, dismissingSource: { [weak imageVC] in imageVC?.scrollView.imageView }, contentMode: imageView?.contentMode ?? .scaleAspectFill)
                imageVC.animation?.viewController = imageVC
                vc.present(imageVC, animated: true)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let provider: ImageProvider?
    private let setup: ((UIButton)->())
    
    public init(provider: ImageProvider? = nil, setup: @escaping (UIButton) -> Void) {
        self.provider = provider
        self.setup = setup
    }
    
    public func makeUIView(context: Context) -> UIView {
        let button = ExpandButton()
        setup(button)
        return button
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) { 
        setup(uiView as! ExpandButton)
        (uiView as! ExpandButton).fullImageProvider = provider
    }
}

public enum ImageProvider {
    case image(UIImage)
    case url(URL)
    case loader(() async throws ->UIImage)
}

open class ImagePreviewController: UIViewController {
    
    private var image: UIImage?
    private let fullImageProvider: ImageProvider?
    public let scrollView = PreviewScrollView()
    
    private var downloadTask: Task<Void, Error>?
    public var animation: ExpandAnimation?
    
    public init(image: UIImage? = nil, fullImageProvider: ImageProvider? = nil) {
        self.image = image
        self.fullImageProvider = fullImageProvider
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.set(image: image)
        
        scrollView.didZoom = { [weak self] (zoom) in
            if let wSelf = self {
                wSelf.animation?.interactionDismissing = zoom <= wSelf.scrollView.minimumZoomScale
            }
        }
        scrollView.didZoom?(scrollView.zoomScale)
        
        let completion: (UIImage?)->() = { [weak self] image in
            guard let wSelf = self, let image = image else { return }
            
            Task { @MainActor in
                if wSelf.image == nil {
                    wSelf.scrollView.set(image: image)
                } else {
                    wSelf.scrollView.imageView.image = image
                    
                }
                let transition = CATransition()
                transition.duration = 0.15
                wSelf.scrollView.imageView.layer.add(transition, forKey: nil)
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
