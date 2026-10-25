import SwiftUI
import UIKit

/// Makes the fixture's orientation support explicit for native geometry requests.
final class RegressionHostingController: UIHostingController<RegressionRootView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
}
