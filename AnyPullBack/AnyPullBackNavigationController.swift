//
//  ViewController.swift
//  AnyPullBack
//
//  Created by Vhyme on 2017/7/17.
//  Copyright © 2017 Vhyme Riku. All rights reserved.
//

import UIKit

public protocol AnyPullBackCustomizable {
    func apb_shouldPull(inDirection direction: SwipeOutDirection) -> Bool
}

open class AnyPullBackNavigationController: UINavigationController, UINavigationControllerDelegate, UIViewControllerTransitioningDelegate, UIGestureRecognizerDelegate {
    
    public var defaultPushAnimator: PushAnimator = ScaleInAnimator(sourceRect: .zero)
    
    public var defaultPopAnimator: PopAnimator = SwipeOutAnimator(direction: .downFromTop)
    
    private var nextAnimator: UIViewControllerAnimatedTransitioning?
    
    public var pullableWidthFromLeft: CGFloat = 50
    
    public var canPullFromLeft = true
    
    public var canPullFromTop = true
    
    public var canPullFromBottom = true
    
    private var dispatchingTo: UIScrollView?
    
    private var interactiveDirection: SwipeOutDirection?
    
    private var interactionTransition: UIPercentDrivenInteractiveTransition?
    
    private var beginPoint: CGPoint?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        self.isNavigationBarHidden = true
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleGesture(gesture:)))
        gestureRecognizer.delegate = self
        gestureRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(gestureRecognizer)
        
        let frame = view.frame
        defaultPushAnimator = ScaleInAnimator(sourceRect: CGRect(x: frame.minX, y: 240, width: frame.width, height: frame.height - 480))
    }
    
    public func pushViewController(_ viewController: UIViewController, fromView view: UIView) {
        self.nextAnimator = ScaleInAnimator(sourceRect: view.convert(view.bounds, to: self.view), sourceView: view)
        pushViewController(viewController, animated: true)
    }
    
    public func pushViewController(_ viewController: UIViewController, fromRect rect: CGRect) {
        self.nextAnimator = ScaleInAnimator(sourceRect: rect, sourceView: nil)
        pushViewController(viewController, animated: true)
    }
    
    public func pushViewController(_ viewController: UIViewController, inDirection direction: SwipeInDirection) {
        self.nextAnimator = SwipeInAnimator(direction: direction)
        pushViewController(viewController, animated: true)
    }
    
    public func popViewController(inDirection direction: SwipeOutDirection) -> UIViewController? {
        if viewControllers.count <= 1 { return nil }
        self.nextAnimator = SwipeOutAnimator(direction: direction)
        return popViewController(animated: true)
    }
    
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        if let animator = nextAnimator {
            nextAnimator = nil
            return animator
        }
        
        if operation == .push {
            return defaultPushAnimator
        } else if operation == .pop {
            if let direction = interactiveDirection {
                return SwipeOutAnimator(direction: direction)
            } else {
                return defaultPopAnimator
            }
        }
        return nil
    }
    
    @objc internal func handleGesture(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginPoint = gesture.location(in: view)
        case .changed:
            if let beginPoint = beginPoint, interactiveDirection == nil {
                
                let currentPoint = gesture.location(in: view)
                let dx = currentPoint.x - beginPoint.x
                let dy = currentPoint.y - beginPoint.y
                
                let pullableWidth = pullableWidthFromLeft
                
                if dx > 5 &&
                    canPullFromLeft &&
                    (pullableWidth <= 0 || beginPoint.x <= pullableWidth) &&
                    (visibleViewController as? AnyPullBackCustomizable)?.apb_shouldPull(inDirection: .rightFromLeft) ?? true {
                    
                    interactiveDirection = .rightFromLeft
                    
                } else if dy > 5 &&
                    canPullFromTop &&
                    (visibleViewController as? AnyPullBackCustomizable)?.apb_shouldPull(inDirection: .downFromTop) ?? true {
                    
                    interactiveDirection = .downFromTop
                    
                } else if dy < -5 &&
                    canPullFromBottom &&
                    (visibleViewController as? AnyPullBackCustomizable)?.apb_shouldPull(inDirection: .upFromBottom) ?? true {
                    
                    interactiveDirection = .upFromBottom
                }
                
                if let direction = interactiveDirection {
                    updateDispatch(gesture: gesture, toView: view, inDirection: direction)
                }
            }
            
            if dispatchingTo == nil {
                if beginPoint != nil, let direction = interactiveDirection {
                    if interactionTransition == nil {
                        interactionTransition = UIPercentDrivenInteractiveTransition()
                        popViewController(animated: true)
                    }
                    if let transition = interactionTransition {
                        let translation = gesture.translation(in: view)
                        switch direction {
                        case .rightFromLeft:
                            transition.update(makeLinear(with: translation.x / view.bounds.width))
                        case .downFromTop:
                            transition.update(makeEase(with: translation.y / view.bounds.height) / 2)
                        case .upFromBottom:
                            transition.update(makeEase(with: -translation.y / view.bounds.height) / 2)
                        default:
                            break
                        }
                    }
                }
            }
        case .ended, .cancelled, .failed:
            if dispatchingTo == nil && beginPoint != nil,
                let direction = interactiveDirection,
                let transition = interactionTransition {
                
                let translation = gesture.translation(in: view)
                let velocity = gesture.velocity(in: view)
                
                var remainingDistance: CGFloat = 0
                var lastVelocity: CGFloat = 1
                
                switch direction {
                case .rightFromLeft:
                    remainingDistance = view.bounds.width - translation.x
                    lastVelocity = velocity.x + 200
                case .downFromTop:
                    remainingDistance = view.bounds.height - translation.y
                    lastVelocity = velocity.y
                case .upFromBottom:
                    remainingDistance = view.bounds.height + translation.y
                    lastVelocity = -velocity.y
                default:
                    break
                }
                
                if lastVelocity != 0 && remainingDistance / lastVelocity > 0 && remainingDistance / lastVelocity < 0.3 {
                    interactionTransition?.completionSpeed = 1
                    transition.finish()
                } else {
                    interactionTransition?.completionSpeed = (interactionTransition?.percentComplete ?? 1) * 2.5
                    transition.cancel()
                }
            } else {
                interactionTransition?.cancel()
            }
            beginPoint = nil
            interactiveDirection = nil
            interactionTransition = nil
            dispatchingTo = nil
        default:
            break
        }
    }
    
    internal func makeLinear(with linear: CGFloat) -> CGFloat {
        let x = min(1, max(0, linear))
        return x
    }
    
    internal func makeEase(with linear: CGFloat) -> CGFloat {
        let x = min(1, max(0, linear))
        return x - x * x / 2
    }
    
    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return self.interactionTransition
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if viewControllers.count > 1,
            let scrollView = otherGestureRecognizer.view as? UIScrollView {
            
            scrollView.bounces = false
            return otherGestureRecognizer.state == .failed
        }
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.interactiveDirection == nil
    }
    
    internal func updateDispatch(gesture: UIGestureRecognizer, toView view: UIView, inDirection direction: SwipeOutDirection) {
        
        if let scrollView = view as? UIScrollView {
            let inset = scrollView.contentInset
            let offset = scrollView.contentOffset
            let height = scrollView.frame.height
            let sheight = scrollView.contentSize.height
            
            if direction == .downFromTop && offset.y > -inset.top {
                dispatchingTo = scrollView
            }
            
            if direction == .rightFromLeft && offset.x > -inset.left {
                dispatchingTo = scrollView
            }
            
            if direction == .upFromBottom && offset.y + height < sheight + inset.bottom {
                dispatchingTo = scrollView
            }
        }
        
        let point = gesture.location(in: view)
        
        for subview in view.subviews {
            if subview.frame.contains(point) {
                updateDispatch(gesture: gesture, toView: subview, inDirection: direction)
            }
        }
    }
}
