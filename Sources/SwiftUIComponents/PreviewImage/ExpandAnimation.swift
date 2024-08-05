//
//  ExpandAnimation.swift
//

import UIKit

public class ExpandAnimation: NSObject {
    
    fileprivate let source: UIView
    fileprivate let dismissingSource: ()->UIImageView?
    
    public weak var viewController: UIViewController? {
        didSet {
            viewController?.transitioningDelegate = self
            reloadGestures()
        }
    }
    
    fileprivate var yTranslation: CGFloat = 0
    fileprivate var reversed: Bool = false
    fileprivate var location = CGPoint.zero
    fileprivate var interativeContext: UIViewControllerContextTransitioning?
    fileprivate var shouldEndGesture = false
    
    var interactionDismissing: Bool = false {
        didSet { reloadGestures() }
    }
    
    fileprivate let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.clear
        return imageView
    }()
    
    fileprivate let secondImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.clear
        return imageView
    }()
    
    fileprivate let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black
        return view
    }()
    
    fileprivate lazy var pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(pinchAction(_:)))
    fileprivate lazy var panGR = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
    fileprivate lazy var tapGR = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
    fileprivate let contentMode: UIView.ContentMode
    var presenting: Bool = false
    
    public init(source: UIView, dismissingSource: @escaping ()->UIImageView?, contentMode: UIView.ContentMode) {
        self.source = source
        self.dismissingSource = dismissingSource
        self.contentMode = contentMode
        
        super.init()
        
        pinchGR.delegate = self
        panGR.delegate = self
        tapGR.delegate = self
        tapGR.require(toFail: pinchGR)
        tapGR.require(toFail: panGR)
        
        imageView.contentMode = contentMode
        secondImageView.contentMode = contentMode
    }
    
    private func reloadGestures() {
        guard let gesturesView = viewController?.view else { return }
        
        if interactionDismissing {
            gesturesView.addGestureRecognizer(panGR)
            gesturesView.addGestureRecognizer(pinchGR)
            panGR.isEnabled = true
            pinchGR.isEnabled = true
        } else {
            panGR.isEnabled = false
            pinchGR.isEnabled = false
        }
        gesturesView.addGestureRecognizer(tapGR)
        tapGR.isEnabled = true
    }
    
    @objc func panAction(_ gr: UIPanGestureRecognizer) {
        guard let gesturesView = viewController?.view else { return }
        
        let translation = gr.translation(in: gesturesView)
        
        if gr.state == .began {
            viewController?.dismiss(animated: true, completion: nil)
            yTranslation = translation.y
        }
        if gr.state == .changed {
            let value = min(1, (1 - (translation.y / gesturesView.frame.size.height) / 2))
            let scale = max(value, 0.7)
            
            var convertedTranslation = translation
            convertedTranslation.x = abs(translation.x) < 25 ? abs(translation.x) : (sqrt(abs(convertedTranslation.x)) * 5)
            if translation.x < 0 {
                convertedTranslation.x = -convertedTranslation.x
            }
            if translation.y < 0 {
                convertedTranslation.y = translation.y > -25 ? translation.y : (-sqrt(abs(convertedTranslation.y)) * 5)
            }
            imageView.transform = CGAffineTransform(translationX: convertedTranslation.x, y: convertedTranslation.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
            overlayView.alpha = value
            reversed = yTranslation > translation.y
        }
        if gr.state == .cancelled || gr.state == .ended {
            endGesture()
        }
        yTranslation = translation.y
    }
    
    @objc func pinchAction(_ gr: UIPinchGestureRecognizer) {
        guard let gesturesView = viewController?.view else { return }
        
        if gr.state == .began {
            viewController?.dismiss(animated: true, completion: nil)
            location = gr.location(in: gesturesView)
        }
        if gr.state == .changed {
            if gr.numberOfTouches < 2 {
                gr.isEnabled = false
                gr.isEnabled = true
                return
            }
            let scale = pinchGR.scale
            let location = gr.location(in: gesturesView)
            let translation = CGPoint(x: location.x - self.location.x, y: location.y - self.location.y)
            
            imageView.transform = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: translation.x, y: translation.y))
            overlayView.alpha = scale
            reversed = pinchGR.velocity > 0 && scale > 0.4
        }
        if gr.state == .cancelled || gr.state == .ended {
            endGesture()
        }
    }
    
    func endGesture() {
        if let context = interativeContext {
            if reversed {
                cancelInteraction()
            } else {
                dismissController(context: context)
                interativeContext = nil
            }
        } else {
            shouldEndGesture = true
        }
    }
    
    func cancelInteraction() {
        if let context = interativeContext {
            let toVC = context.viewController(forKey: .to)
            let containerView = context.containerView
            
            context.cancelInteractiveTransition()
            
            let frame = imageView.frame
            imageView.transform = .identity
            imageView.frame = frame
            
            UIView.animate(withDuration: transitionDuration(using: context) * 2 / 3,
                           delay: 0,
                           usingSpringWithDamping: 1,
                           initialSpringVelocity: 2,
                           options: .curveEaseOut,
                           animations: {
                            
                self.overlayView.alpha = 1
                guard let dismissingView = self.dismissingSource() else { return }
                self.imageView.frame = dismissingView.convert(dismissingView.bounds, to: containerView)
            }, completion: { (_) in
                
                self.source.isHidden = false
                self.imageView.removeFromSuperview()
                self.overlayView.removeFromSuperview()
                toVC?.view.removeFromSuperview()
                self.interativeContext?.completeTransition(false)
            })
        }
    }
    
    @objc func tapAction(_ gr: UITapGestureRecognizer) {
        interactionDismissing = false
        viewController?.dismiss(animated: true, completion: nil)
    }
}

extension ExpandAnimation: UIViewControllerTransitioningDelegate {
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.presenting = true
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.presenting = false
        return self
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionDismissing ? self : nil
    }
}

extension ExpandAnimation: UIViewControllerInteractiveTransitioning {
    
    public func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        interativeContext = transitionContext
        
        if let dismissingView = dismissingSource() {
            let fromVC = transitionContext.viewController(forKey: .from)!
            let toVC = transitionContext.viewController(forKey: .to)!
            let containerView = transitionContext.containerView
            let finalFrane = transitionContext.finalFrame(for: toVC)
            
            toVC.view.frame = finalFrane
            containerView.addSubview(toVC.view)
            
            overlayView.frame = fromVC.view.bounds
            overlayView.alpha = 1
            containerView.addSubview(overlayView)
            
            imageView.image = dismissingView.image
            imageView.frame = dismissingView.convert(dismissingView.bounds, to: containerView)
            source.isHidden = true
            containerView.addSubview(imageView)
        }
        
        if shouldEndGesture {
            shouldEndGesture = false
            endGesture()
        }
    }
}

extension UIView {
    
    func findTabbar() -> UITabBar? {
        var responder: UIResponder = self
        
        while responder.next != nil {
            responder = responder.next!
            if var vc = responder as? UIViewController {
                
                while vc.parent != nil {
                    if let vc = vc as? UITabBarController {
                        return vc.tabBar
                    }
                    vc = vc.parent!
                }
            }
        }
        return nil
    }
    
    func findViewController() -> UIViewController? {
        var responder: UIResponder = self
        
        while responder.next != nil {
            responder = responder.next!
            if let vc = responder as? UIViewController {
                return vc
            }
        }
        return nil
    }
}

extension ExpandAnimation: UIViewControllerAnimatedTransitioning {
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.45 }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toVC)
        
        if presenting {
            source.isHidden = true
            
            toVC.view.frame = finalFrame
            
            overlayView.frame = finalFrame
            overlayView.alpha = 0
            containerView.addSubview(overlayView)
            
            let oldColor = toVC.view.subviews.first?.backgroundColor
            toVC.view.subviews.first?.backgroundColor = UIColor.clear
            
            if let dismissingView = dismissingSource() {
                imageView.image = dismissingView.image
            }
            
            toVC.view.subviews.first?.backgroundColor = oldColor
            imageView.frame = source.convert(source.bounds, to: containerView)
            containerView.addSubview(imageView)
            
            imageView.layer.cornerRadius = source.layer.cornerRadius
            
            var targetRect = finalFrame
            if let imageSize = imageView.image?.size {
                let scale = min(finalFrame.size.width / imageSize.width, finalFrame.size.height / imageSize.height)
                targetRect.size = CGSize(width:imageSize.width * scale, height: imageSize.height * scale)
                targetRect.origin = CGPoint(x: (finalFrame.size.width - targetRect.size.width) / 2, y: (finalFrame.size.height - targetRect.size.height) / 2)
            }
            
            UIView.animate(withDuration: transitionDuration(using: transitionContext),
                           delay: 0,
                           usingSpringWithDamping: 0.75,
                           initialSpringVelocity: 2,
                           options: .curveEaseOut,
                           animations: {
                            
                            self.imageView.frame = targetRect
                            self.imageView.layer.cornerRadius = 0
            }, completion: { (_) in
                
                self.source.isHidden = false
                containerView.addSubview(toVC.view)
                self.imageView.removeFromSuperview()
                self.overlayView.removeFromSuperview()
                transitionContext.completeTransition(true)
            })
            UIView.animate(withDuration: transitionDuration(using: transitionContext) * 2 / 3, delay: transitionDuration(using: transitionContext) / 3, options: [], animations: {
                
                self.overlayView.alpha = 1
            }, completion: nil)
            
        } else {
            toVC.view.frame = finalFrame
            containerView.addSubview(toVC.view)
            
            overlayView.frame = fromVC.view.bounds
            overlayView.alpha = 1
            containerView.addSubview(overlayView)
            
            if let dismissingView = dismissingSource() {
                imageView.image = dismissingView.image
                imageView.frame = dismissingView.convert(dismissingView.bounds, to: containerView)
            }
            containerView.addSubview(imageView)
            
            dismissController(context: transitionContext)
        }
    }
    
    func dismissController(context: UIViewControllerContextTransitioning) {
        let fromVC = context.viewController(forKey: .from)!
        fromVC.view.removeFromSuperview()
        let containerView = context.containerView
        context.finishInteractiveTransition()
        
        let frame = imageView.frame
        imageView.transform = .identity
        imageView.frame = frame
        source.isHidden = true
        
        let vc = source.findViewController()
        vc?.view.isUserInteractionEnabled = false
        
        let cornerRadius = source.layer.cornerRadius
        
        UIView.animate(withDuration: transitionDuration(using: context),
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 2,
                       options: .curveEaseOut,
                       animations: {
                        self.imageView.frame = self.source.convert(self.source.bounds, to: containerView)
                        self.imageView.layer.cornerRadius = cornerRadius
        }) { (_) in
            
            vc?.view.isUserInteractionEnabled = true
            self.source.isHidden = false
            DispatchQueue.main.async {
                let view = self.imageView.superview
                self.imageView.removeFromSuperview()
                let tranition = CATransition()
                tranition.duration = 0.15
                view?.layer.add(tranition, forKey: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    context.completeTransition(true)
                }
            }
        }
        UIView.animate(withDuration: transitionDuration(using: context) / 3.0) {
            self.overlayView.alpha = 0
        }
    }
}

extension ExpandAnimation: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer != pinchGR || pinchGR.scale < 1.0
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer != pinchGR && gestureRecognizer != panGR
    }
}
