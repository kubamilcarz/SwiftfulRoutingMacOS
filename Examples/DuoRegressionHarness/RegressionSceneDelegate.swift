import UIKit

final class RegressionSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
        .all
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = RegressionHostingController(rootView: RegressionRootView())
        self.window = window
        window.makeKeyAndVisible()
    }
}
