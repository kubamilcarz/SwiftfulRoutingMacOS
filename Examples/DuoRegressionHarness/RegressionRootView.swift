import SwiftUI
import SwiftfulRouting

struct RegressionRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var session = RegressionSession()

    var body: some View {
        let horizontal = horizontalSizeClass
        let vertical = verticalSizeClass
        RouterView(navigationSplitView: true) { _ in
            RegressionScreen(session: session, routeID: "root")
        }
        .onGeometryChange(for: String.self) { proxy in
            "\(Int(proxy.size.width))×\(Int(proxy.size.height)), h=\(String(describing: horizontal)), v=\(String(describing: vertical))"
        } action: {
            session.geometry = $0
            session.validate()
        }
        .onHingeChange { _, context in
            if let hinge = context.hinge {
                session.hinge = "\(hinge.status), \(Int(hinge.angle.degrees))°"
            } else {
                session.hinge = "No hinge"
            }
            session.validate()
        }
        .task { await session.monitor() }
    }
}
