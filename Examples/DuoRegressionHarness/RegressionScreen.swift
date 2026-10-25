import SwiftUI
import SwiftfulRouting

struct RegressionScreen: View {
    @Environment(\.router) private var router
    let session: RegressionSession
    let routeID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.status).bold().accessibilityIdentifier("regression-status")
                Text(session.geometry)
                Text(session.hinge)
                Text("History: \(session.history.description)")
                Text("Dismissals: \(session.dismissals.description)")
                Button("Prepare A → B") { session.prepare(withSheet: false) }
                Button("Prepare A → B + sheet + nested push") { session.prepare(withSheet: true) }
                Button("Record checkpoint") { session.checkpoint() }
                Button("Run native rotation checks") { Task { await session.runRotationChecks() } }
                Button("Dismiss sheet and verify callbacks") { session.finishSheet() }
                Button("Prepare native Back check") { session.prepareNativeBack() }
                Button("Check native Back") { session.checkNativeBack() }
                Button("Prepare sidebar Back check") { session.prepareNativeBack() }
                Button("Check sidebar Back") { session.checkSidebarBack() }
                Button("Show custom swipe screen") {
                    router.showTransition(id: "swipe", allowsSwipeBack: true) { _ in
                        RegressionSwipeScreen(session: session)
                    }
                }
                ForEach(session.failures, id: \.self) { Text($0).foregroundStyle(.red) }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(routeID)
        .onAppear { session.routers[routeID] = router }
    }
}
