import SwiftUI
import UIKit

extension View {
    func kiioHidesTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
            .background(KiioTabBarVisibilityHost(isHidden: true).frame(width: 0, height: 0))
    }

    func kiioShowsTabBar() -> some View {
        toolbar(.visible, for: .tabBar)
            .background(KiioTabBarVisibilityHost(isHidden: false).frame(width: 0, height: 0))
    }
}

struct KiioTabSwitchAnimator: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> Controller {
        Controller { tabBarController in
            tabBarController.delegate = context.coordinator
        }
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.configure = { tabBarController in
            tabBarController.delegate = context.coordinator
        }
        uiViewController.applyConfiguration()
    }

    final class Controller: UIViewController {
        var configure: (UITabBarController) -> Void

        init(configure: @escaping (UITabBarController) -> Void) {
            self.configure = configure
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyConfiguration()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyConfiguration()
        }

        func applyConfiguration() {
            guard let tabBarController else { return }
            configure(tabBarController)
        }
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        func tabBarController(
            _ tabBarController: UITabBarController,
            animationControllerForTransitionFrom fromVC: UIViewController,
            to toVC: UIViewController
        ) -> UIViewControllerAnimatedTransitioning? {
            guard
                let viewControllers = tabBarController.viewControllers,
                let fromIndex = viewControllers.firstIndex(where: { $0 === fromVC }),
                let toIndex = viewControllers.firstIndex(where: { $0 === toVC }),
                fromIndex != toIndex
            else {
                return nil
            }

            return ContentTransitionAnimator(direction: toIndex > fromIndex ? .forward : .backward)
        }
    }

    private final class ContentTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
        enum Direction: Equatable {
            case forward
            case backward
        }

        let direction: Direction

        init(direction: Direction) {
            self.direction = direction
        }

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            0.24
        }

        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard
                let fromView = transitionContext.view(forKey: .from),
                let toView = transitionContext.view(forKey: .to),
                let toViewController = transitionContext.viewController(forKey: .to)
            else {
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }

            let container = transitionContext.containerView
            let distance = min(container.bounds.width * 0.14, 52)
            let incomingOffset = direction == .forward ? distance : -distance
            let outgoingOffset = -incomingOffset * 0.45

            toView.frame = transitionContext.finalFrame(for: toViewController)
            toView.alpha = 0
            toView.transform = CGAffineTransform(translationX: incomingOffset, y: 0)
            container.addSubview(toView)

            UIView.animate(
                withDuration: transitionDuration(using: transitionContext),
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0.2,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                fromView.alpha = 0.84
                fromView.transform = CGAffineTransform(translationX: outgoingOffset, y: 0)
                toView.alpha = 1
                toView.transform = .identity
            } completion: { _ in
                let wasCancelled = transitionContext.transitionWasCancelled

                fromView.alpha = 1
                fromView.transform = .identity
                toView.alpha = 1
                toView.transform = .identity

                if wasCancelled {
                    toView.removeFromSuperview()
                }

                transitionContext.completeTransition(!wasCancelled)
            }
        }
    }
}

private struct KiioTabBarVisibilityHost: UIViewControllerRepresentable {
    let isHidden: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller(isHidden: isHidden)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.isHidden = isHidden
        uiViewController.applyVisibility()
    }

    final class Controller: UIViewController {
        var isHidden: Bool

        init(isHidden: Bool) {
            self.isHidden = isHidden
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyVisibility()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyVisibility()
        }

        func applyVisibility() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.tabBarController?.tabBar.isHidden = self.isHidden
            }
        }
    }
}
