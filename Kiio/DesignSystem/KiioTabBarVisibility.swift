import SwiftUI
import UIKit

extension View {
    func kiioHidesTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonDisplayMode(.minimal)
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
        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            guard tabBarController.selectedViewController !== viewController else {
                return true
            }

            let transition = CATransition()
            transition.duration = 0.12
            transition.type = .fade
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            tabBarController.view.layer.add(transition, forKey: "kiio-tab-switch")
            return true
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
