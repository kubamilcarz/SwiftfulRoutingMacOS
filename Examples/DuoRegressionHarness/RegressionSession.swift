import Observation
import SwiftUI
import SwiftfulRouting
import UIKit

/// Records actual window/hinge changes; this harness never injects device traits or poses.
@MainActor @Observable
final class RegressionSession {
    var routers: [String: AnyRouter] = [:]
    var dismissals: [String] = []
    var failures: [String] = []
    var checkpoints: [String] = []
    var status = "Prepare a branch to begin"
    var geometry = "Waiting for window geometry"
    var hinge = "Waiting for hinge data"
    var taps = 0
    var orientation = "Unrecorded"
    private var expectedHistory: [[String]]?
    private var expectedDismissals: [String] = []
    private var expectedSelection: String? = "A"

    var history: [[String]] { routers["root"]?.activeScreens.map { $0.screens.map(\.id) } ?? [] }

    func prepare(withSheet: Bool) {
        Task {
            expectedHistory = nil
            guard let root = routers["root"] else { return }
            root.dismissAllScreens(animates: false)
            guard await waitFor({ self.history.count == 2 && self.history[1].isEmpty }) else { return }
            routers = ["root": root]
            dismissals = []
            failures = []
            checkpoints = []
            root.addScreenToQueue(destination: AnyDestination(id: "A", animates: false, onDismiss: { self.dismissals.append("A") }) { _ in
                RegressionScreen(session: self, routeID: "A")
            })
            root.showNextScreen()
            guard await waitFor({ self.routers["A"] != nil }) else { return }
            routers["A"]?.addScreenToQueue(destination: AnyDestination(id: "B", animates: false, onDismiss: { self.dismissals.append("B") }) { _ in
                RegressionScreen(session: self, routeID: "B")
            })
            routers["A"]?.showNextScreen()
            guard await waitFor({ self.routers["B"] != nil }) else { return }
            if withSheet {
                routers["B"]?.addScreenToQueue(destination: AnyDestination(id: "sheet",
                    segue: .sheetConfig(config: ResizableSheetConfig(detents: [.medium, .large])),
                    animates: false, onDismiss: { self.dismissals.append("sheet") }) { _ in
                    RegressionScreen(session: self, routeID: "sheet")
                })
                routers["B"]?.showNextScreen()
                guard await waitFor({ self.routers["sheet"] != nil }) else { return }
                routers["sheet"]?.addScreenToQueue(destination: AnyDestination(id: "sheet_detail", animates: false,
                    onDismiss: { self.dismissals.append("sheet_detail") }) { _ in
                    RegressionScreen(session: self, routeID: "sheet_detail")
                })
                routers["sheet"]?.showNextScreen()
                guard await waitFor({ self.routers["sheet_detail"] != nil }) else { return }
            }
            expectedHistory = withSheet ? [["root"], ["A", "B"], ["sheet"], ["sheet_detail"]] : [["root"], ["A", "B"]]
            expectedDismissals = []
            expectedSelection = "A"
            checkpoint()
        }
    }

    func finishSheet() {
        Task {
            expectedHistory = nil
            routers["sheet"]?.dismissEnvironment(animates: false)
            guard await waitFor({ self.history.count == 2 }) else { return }
            expectedHistory = [["root"], ["A", "B"]]
            expectedDismissals = ["sheet_detail", "sheet"]
            checkpoint()
        }
    }

    func prepareNativeBack() {
        expectedHistory = nil
        status = "Tap the native Back button once, then Check native Back"
    }

    func checkNativeBack() {
        expectedHistory = [["root"], ["A"]]
        expectedDismissals.append("B")
        checkpoint()
    }

    func checkSidebarBack() {
        expectedHistory = [["root"], []]
        expectedSelection = nil
        expectedDismissals.append("A")
        checkpoint()
    }

    func checkpoint() {
        validate()
        checkpoints.append("\(geometry); \(hinge); orientation=\(orientation); history=\(history); dismissals=\(dismissals); \(status)")
        persist()
    }

    func validate() {
        guard let expectedHistory else { return }
        if history != expectedHistory { recordFailure("History changed: \(history), expected \(expectedHistory)") }
        if routers["root"]?.selectedSplitViewDetailID != expectedSelection { recordFailure("Selection changed") }
        if dismissals != expectedDismissals { recordFailure("Dismissals changed: \(dismissals), expected \(expectedDismissals)") }
        status = failures.isEmpty ? "PASS — history, selection, callbacks" : "FAIL — \(failures.last ?? "")"
    }

    func monitor() async {
        if ProcessInfo.processInfo.arguments.contains("--prepare-branch"),
           await waitFor({ self.routers["root"]?.activeScreens.count == 2 }) {
            prepare(withSheet: ProcessInfo.processInfo.arguments.contains("--sheet"))
            if ProcessInfo.processInfo.arguments.contains("--rotate"),
               await waitFor({ self.expectedHistory != nil }) {
                await runRotationChecks()
            }
        }
        while !Task.isCancelled {
            validate()
            persist()
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func waitFor(_ condition: () -> Bool, failure: String = "Navigation did not reach the expected setup state") async -> Bool {
        for _ in 0..<150 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        recordFailure(failure)
        status = "FAIL — \(failure)"
        persist()
        return false
    }

    /// Requests real scene rotations through UIKit; no traits or bounds are injected.
    func runRotationChecks() async {
        guard await waitFor({ UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive } },
                            failure: "No foreground scene became available for rotation") else { return }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            recordFailure("No active window scene for rotation")
            return
        }
        let rotations: [(UIInterfaceOrientationMask, UIInterfaceOrientation)] = [
            (.landscapeLeft, .landscapeLeft), (.landscapeRight, .landscapeRight), (.portrait, .portrait)
        ]
        for (mask, requested) in rotations {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                self.recordFailure("Rotation request failed: \(error.localizedDescription)")
            }
            guard await waitFor({ scene.effectiveGeometry.interfaceOrientation == requested },
                                failure: "Scene did not rotate to \(requested)") else { return }
            guard await waitFor({ scene.keyWindow?.rootViewController?.transitionCoordinator == nil },
                                failure: "Native rotation did not settle") else { return }
            scene.keyWindow?.layoutIfNeeded()
            await Task.yield()
            orientation = String(describing: scene.effectiveGeometry.interfaceOrientation)
            checkpoint()
        }
    }

    private func recordFailure(_ message: String) {
        if !failures.contains(message) { failures.append(message) }
    }

    private func persist() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let report: [String: Any] = ["status": status, "geometry": geometry, "hinge": hinge, "orientation": orientation,
            "history": history, "dismissals": dismissals, "failures": failures, "checkpoints": checkpoints,
            "fixtureVersion": "2-native-scene",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "sceneDelegate": String(describing: scene?.delegate),
            "rootController": String(describing: scene?.keyWindow?.rootViewController),
            "rootSupportedOrientations": scene?.keyWindow?.rootViewController?.supportedInterfaceOrientations.rawValue ?? 0]
        let url = URL.documentsDirectory.appending(path: "duo-regression.json")
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
