#if os(iOS)
import UIKit
import SwiftUI

// MARK: - App Entry Point (UIKit lifecycle)

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var viewModel: MainViewModel?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let vm = MainViewModel()
        self.viewModel = vm
        return true
    }

    // MARK: UISceneSession lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}

// MARK: - Scene Delegate (window + hosting)

class SceneDelegate: UIResponder, UISceneDelegate {
    var window: UIWindow?
    weak var viewModel: MainViewModel?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Retrieve the shared ViewModel from AppDelegate
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let vm = appDelegate.viewModel
        else { return }
        self.viewModel = vm

        let rootView = MainView(viewModel: vm)
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.sizingOptions = [.intrinsicContentSize]

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        viewModel?.handleActivation()
    }
}
#endif
