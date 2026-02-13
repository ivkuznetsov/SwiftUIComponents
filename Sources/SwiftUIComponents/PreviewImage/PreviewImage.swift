//
//  PreviewScrollView.swift
//

import UIKit
import SwiftUI

public struct PreviewImage: UIViewRepresentable {
    
    let setup: (PreviewScrollView)->()
    
    public init(setup: @escaping (PreviewScrollView)->()) {
        self.setup = setup
    }
    
    public func makeUIView(context: Context) -> PreviewScrollView {
        let view = PreviewScrollView()
        setup(view)
        return view
    }
    
    public func updateUIView(_ uiView: PreviewScrollView, context: Context) { }
}

public final class PreviewScrollView: UIScrollView, UIScrollViewDelegate {
    
    final class ContainerView: UIView {
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            (superview as? UIScrollView)?.bounds.contains(point) ?? super.point(inside: point, with: event)
        }
    }
    
    public var aspectFill: Bool = false
    public let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.layer.allowsEdgeAntialiasing = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    let containerView: UIView = {
        let view = ContainerView()
        view.backgroundColor = .clear
        return view
    }()
    
    public var didZoom: ((CGFloat)->())?
    public var minAspectLimit: CGFloat?
    public var maxAspectLimit: CGFloat?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        delegate = self
        clipsToBounds = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
    }
    
    public func set(image: UIImage?) {
        set(image: image, aspect: aspect(size: self.size(image: image)))
    }
    
    private func size(image: UIImage?) -> CGSize {
        if let image = image {
            return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        }
        return .zero
    }
    
    private func aspect(size: CGSize) -> CGFloat {
        if size.width > 0 {
            return size.height / size.width
        }
        return 0
    }
    
    private func set(image: UIImage?, aspect: CGFloat) {
        let size = self.size(image: image)
        
        imageView.image = image
        
        if imageView.superview == nil {
            imageView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            containerView.addSubview(imageView)
            insertSubview(containerView, at: 0)
        }
        
        if image != nil {
            minimumZoomScale = 1
            maximumZoomScale = 1
            zoomScale = 1
            layoutIfNeeded()
            
            let scale = UIScreen.main.scale
            
            containerView.frame = CGRect(x: 0, y: 0, width: size.width / scale, height: size.height / scale)
            imageView.frame = containerView.frame
            contentSize = imageView.bounds.size
            layoutImageView()
            zoomScale = minimumZoomScale
            scrollViewDidZoom(self)
            
            if aspectFill {
                contentOffset = CGPoint(x: contentSize.width / 2 - bounds.size.width / 2, y: contentSize.height / 2 - bounds.size.height / 2)
            }
        }
    }
    
    public func zoomToFill() {
        if containerView.frame.size.height == 0 || bounds.size.height == 0 || imageView.frame.size.width == 0 || imageView.frame.size.height == 0 {
            return
        }
        
        let aspect = (containerView.frame.size.width / zoomScale) / (containerView.frame.size.height / zoomScale)
        let viewAspect = bounds.size.width / bounds.size.height
        
        if aspect < viewAspect {
            zoomScale = bounds.size.width / (imageView.frame.size.width / zoomScale)
        } else {
            zoomScale = bounds.size.height / (imageView.frame.size.height / zoomScale)
        }
        contentOffset = CGPoint(x: contentSize.width / 2 - bounds.size.width / 2, y: contentSize.height / 2 - bounds.size.height / 2)
    }
    
    private func layoutImageView() {
        if imageView.image == nil || bounds.size.width == 0 || bounds.size.height == 0 {
            return
        }
        
        maximumZoomScale = 4
        
        var aspect = (containerView.frame.size.width / zoomScale) / (containerView.frame.size.height / zoomScale)
        
        if let minAspectLimit = minAspectLimit {
            aspect = max(aspect, minAspectLimit)
        }
        if let maxAspectLimit = maxAspectLimit {
            aspect = min(aspect, maxAspectLimit)
        }
        
        let viewAspect = bounds.size.width / bounds.size.height
        
        if (!aspectFill && aspect > viewAspect) || (aspectFill && aspect < viewAspect) {
            minimumZoomScale = bounds.size.width / (imageView.frame.size.height * aspect / zoomScale)
        } else {
            minimumZoomScale = bounds.size.height / (imageView.frame.size.width / aspect / zoomScale)
        }
        
        maximumZoomScale = minimumZoomScale * 4
        
        if zoomScale < minimumZoomScale {
            zoomScale = minimumZoomScale
        }
        if zoomScale > maximumZoomScale {
            zoomScale = maximumZoomScale
        }
    }
    
    public override var frame: CGRect {
        didSet {
            if oldValue != frame {
                layoutImageView()
                zoomScale = minimumZoomScale
                scrollViewDidZoom(self)
            }
        }
    }
    
    public override var bounds: CGRect {
        didSet {
            if oldValue.size != bounds.size {
                layoutImageView()
                scrollViewDidZoom(self)
            }
        }
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        var top: CGFloat = 0
        var left: CGFloat = 0
        
        if contentSize.width < bounds.size.width {
            left = (bounds.size.width - contentSize.width) * 0.5
        }
        if contentSize.height < bounds.size.height {
            top = (bounds.size.height - contentSize.height) * 0.5
        }
        scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        didZoom?(scale)
    }
    
    public func capture() -> UIImage {
        UIGraphicsBeginImageContext(CGSizeMake(frame.size.width, frame.size.height))
        drawHierarchy(in: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height), afterScreenUpdates: true)
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return screenshot
    }
}
