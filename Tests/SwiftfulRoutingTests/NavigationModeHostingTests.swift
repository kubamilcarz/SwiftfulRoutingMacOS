import SwiftUI
import XCTest
@testable import SwiftfulRouting

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if os(macOS) || os(iOS)
@available(iOS 17, macOS 14, *)
@MainActor
final class NavigationModeHostingTests: XCTestCase {
    func testModeChangesWithNoSelectionPreserveRouterAndNewPushSemantics() async throws {
        let state = ModeHostingState(split: false)
        let host = ModeHostingWindow(state: state)
        defer { host.close() }
        try await waitUntil { state.model?.activeScreenStacks.count == 2 && state.router != nil }
        let router = try XCTUnwrap(state.router)

        for split in [true, false, true] {
            state.split = split
            try await waitUntil { state.model?.navigationSplitView == split }
            XCTAssertTrue(router.activeScreens[1].screens.isEmpty)
            XCTAssertNil(router.selectedSplitViewDetailID)
        }

        router.showScreen(.push, id: "A", animates: false) { _ in Text("A") }
        try await waitUntil { router.selectedSplitViewDetailID == "A" }
        router.showScreen(.push, id: "B", animates: false) { _ in Text("B") }
        try await waitUntil { router.selectedSplitViewDetailID == "B" }
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["B"])

        state.split = false
        try await waitUntil { state.model?.navigationSplitView == false }
        router.showScreen(.push, id: "C", animates: false) { _ in Text("C") }
        try await waitUntil { router.activeScreens[1].screens.count == 2 }
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["C", "B"])
    }

    func testInitialModuleFollowsRuntimeModeChanges() async throws {
        let state = ModeHostingState(split: false, modules: true)
        let host = ModeHostingWindow(state: state)
        defer { host.close() }
        try await waitUntil { state.model?.activeScreenStacks.count == 2 && state.router != nil }
        let router = try XCTUnwrap(state.router)
        router.addScreenToQueue(destination: AnyDestination(id: "A", animates: false) { _ in
            ModeDestinationProbe(id: "A", state: state)
        })
        router.showNextScreen()
        try await waitUntil { state.appearances["A"] != nil }
        for split in [true, false] {
            state.split = split
            try await waitUntil { state.model?.navigationSplitView == split }
            XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A"])
            XCTAssertEqual(router.selectedSplitViewDetailID, split ? "A" : nil)
        }
    }

    func testModeChangesPreserveSelectedAndNestedRoutes() async throws {
        for initialSplit in [false, true] {
            let state = ModeHostingState(split: initialSplit)
            let host = ModeHostingWindow(state: state)
            defer { host.close() }
            try await waitUntil { state.model?.activeScreenStacks.count == 2 && state.router != nil }
            let router = try XCTUnwrap(state.router)
            let model = try XCTUnwrap(state.model)
            var dismissed = 0
            router.addScreenToQueue(destination:
                AnyDestination(id: "A", animates: false, onDismiss: { dismissed += 1 }) { _ in
                    ModeDestinationProbe(id: "A", state: state)
                }
            )
            router.showNextScreen()
            try await waitUntil { state.appearances["A"] != nil }
            let presentationID = model.activeScreenStacks[1].screens[0].presentationID
            for depth in [1, 2] {
                if depth == 2 {
                    await model.showScreens(routerId: "A", destinations: [
                        AnyDestination(id: "B", animates: false, onDismiss: { dismissed += 1 }) { _ in
                            ModeDestinationProbe(id: "B", state: state)
                        }
                    ]).value
                    try await waitUntil { state.appearances["B"] != nil }
                }
                let ids = depth == 1 ? ["A"] : ["A", "B"]
                for split in [!initialSplit, initialSplit] {
                    let top = try XCTUnwrap(ids.last)
                    let previousAppearances = state.appearances[top, default: 0]
                    state.split = split
                    try await waitUntil {
                        state.model?.navigationSplitView == split
                            && state.appearances[top, default: 0] > previousAppearances
                    }
                    XCTAssertTrue(state.model === model)
                    XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ids)
                    XCTAssertEqual(model.activeScreenStacks[1].screens[0].presentationID, presentationID)
                    XCTAssertEqual(router.selectedSplitViewDetailID, split ? "A" : nil)
                    XCTAssertEqual(dismissed, 0)
                }
            }
        }
    }

    func testModeChangesPreserveOpenSheetAndItsHistory() async throws {
        let state = ModeHostingState(split: true)
        let host = ModeHostingWindow(state: state)
        defer { host.close() }
        try await waitUntil { state.model?.activeScreenStacks.count == 2 && state.router != nil }
        let router = try XCTUnwrap(state.router)
        let model = try XCTUnwrap(state.model)
        var dismissed = 0
        await model.showScreens(routerId: router.id, destinations: [
            AnyDestination(id: "A", animates: false) { _ in ModeDestinationProbe(id: "A", state: state) },
            AnyDestination(id: "sheet", segue: .sheet, animates: false, onDismiss: { dismissed += 1 }) { _ in
                ModeDestinationProbe(id: "sheet", state: state)
            }
        ]).value
        try await waitUntil { state.appearances["sheet"] != nil }
        await model.showScreens(routerId: "sheet", destinations: [
            AnyDestination(id: "sheet_detail", animates: false) { _ in
                ModeDestinationProbe(id: "sheet_detail", state: state)
            }
        ]).value
        try await waitUntil { state.appearances["sheet_detail"] != nil }
        let expected = router.activeScreens
        for split in [false, true] {
            state.split = split
            try await waitUntil { state.model?.navigationSplitView == split }
            // Give native dismissal callbacks an opportunity to run after reparenting.
            try await Task.sleep(nanoseconds: 200_000_000)
            XCTAssertEqual(router.activeScreens, expected)
            XCTAssertEqual(dismissed, 0)
            XCTAssertNil(model.selectedSplitViewDetailID(routerId: "sheet_detail"))
        }
    }

    func testReselectingSameIDCreatesFreshViewStateAndDismissesOnce() async throws {
        let state = ModeHostingState(split: true)
        let host = ModeHostingWindow(state: state)
        defer { host.close() }
        try await waitUntil { state.model?.activeScreenStacks.count == 2 && state.router != nil }
        let router = try XCTUnwrap(state.router)
        let model = try XCTUnwrap(state.model)
        var dismissed: [String] = []
        router.addScreenToQueue(destination:
            AnyDestination(id: "A", animates: false, onDismiss: { dismissed.append("A") }) { _ in
                ModeDestinationProbe(id: "A", state: state)
            }
        )
        router.showNextScreen()
        try await waitUntil { state.tokens["A"] != nil }
        let originalToken = state.tokens["A"]
        await model.showScreens(routerId: "A", destinations: [
            AnyDestination(id: "B", animates: false, onDismiss: { dismissed.append("B") }) { _ in
                ModeDestinationProbe(id: "B", state: state)
            }
        ]).value
        try await waitUntil { state.tokens["B"] != nil }
        await model.showScreens(routerId: router.id, destinations: [
            AnyDestination(id: "A", animates: false, onDismiss: { dismissed.append("new_A") }) { _ in
                ModeDestinationProbe(id: "A", state: state)
            }
        ]).value
        try await waitUntil { state.tokens["A"] != originalToken }
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A"])
        XCTAssertEqual(dismissed, ["B", "A"])
        router.dismissPushStack(animates: false)
        XCTAssertEqual(dismissed, ["B", "A", "new_A"])
    }

    func testReusingPrebuiltDestinationCreatesFreshViewState() async throws {
        try await verifyReplacementResetsViewState(nested: false, reuseDestination: true)
    }

    func testReplacingNestedDestinationWithSameIDCreatesFreshViewState() async throws {
        try await verifyReplacementResetsViewState(nested: true, reuseDestination: false)
    }

    private func verifyReplacementResetsViewState(nested: Bool, reuseDestination: Bool) async throws {
        let state = ModeHostingState(split: true)
        let host = ModeHostingWindow(state: state)
        defer { host.close() }
        try await waitUntil { state.model?.activeScreenStacks.count == 2 && state.router != nil }
        let router = try XCTUnwrap(state.router)
        let model = try XCTUnwrap(state.model)
        if nested {
            router.addScreenToQueue(destination:
                AnyDestination(id: "A", animates: false) { _ in ModeDestinationProbe(id: "A", state: state) }
            )
            router.showNextScreen()
            try await waitUntil { state.tokens["A"] != nil }
        }
        let ancestorToken = state.tokens["A"]
        let callerID = nested ? "A" : router.id
        let routeID = nested ? "B" : "A"
        var dismissals = 0
        let makeDestination = {
            AnyDestination(id: routeID, animates: false, onDismiss: { dismissals += 1 }) { _ in
                ModeDestinationProbe(id: routeID, state: state)
            }
        }
        let destination = makeDestination()
        model.addScreensToQueue(routerId: callerID, destinations: [destination])
        model.showNextScreen(routerId: callerID)
        try await waitUntil { state.tokens[routeID] != nil }
        let originalToken = try XCTUnwrap(state.tokens[routeID])

        await model.showScreens(routerId: callerID, destinations: [reuseDestination ? destination : makeDestination()]).value
        try await waitUntil { state.tokens[routeID] != originalToken }
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), nested ? ["A", "B"] : ["A"])
        XCTAssertEqual(dismissals, 1)
        if nested {
            router.dismissLastScreen(animates: false)
            XCTAssertEqual(state.tokens["A"], ancestorToken)
            XCTAssertEqual(router.selectedSplitViewDetailID, "A")
        } else {
            router.dismissPushStack(animates: false)
        }
        XCTAssertEqual(dismissals, 2)
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async throws {
        for _ in 0..<150 {
            #if os(macOS)
            for window in NSApplication.shared.windows {
                if let view = window.contentView {
                    invalidateLayout(view)
                    view.layoutSubtreeIfNeeded()
                }
            }
            #endif
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Hosted navigation did not reach the expected state", file: file, line: line)
        throw HostingTimeout()
    }

    #if os(macOS)
    private func invalidateLayout(_ view: NSView) {
        view.needsLayout = true
        for child in view.subviews { invalidateLayout(child) }
    }
    #endif
}

private struct HostingTimeout: Error {}

@MainActor
private final class ModeHostingState: ObservableObject {
    @Published var split: Bool
    let modules: Bool
    var router: AnyRouter?
    var model: RouterViewModel?
    var appearances: [String: Int] = [:]
    var tokens: [String: UUID] = [:]

    init(split: Bool, modules: Bool = false) {
        self.split = split
        self.modules = modules
    }
}

@available(iOS 17, macOS 14, *)
private struct ModeHostingRoot: View {
    @ObservedObject var state: ModeHostingState

    var body: some View {
        RouterView(
            id: state.modules ? "module" : nil,
            navigationSplitView: state.split,
            columnVisibility: .constant(.all),
            addModuleSupport: state.modules
        ) { router in
            ModeRootProbe(state: state, router: router)
        } emptyDetail: { _ in
            Text("Choose an item")
        }
    }
}

private struct ModeRootProbe: View {
    @EnvironmentObject private var model: RouterViewModel
    let state: ModeHostingState
    let router: AnyRouter

    var body: some View {
        Text("Sidebar")
            .navigationTitle("Sidebar")
            .onAppear {
                state.router = router
                state.model = model
            }
    }
}

private struct ModeDestinationProbe: View {
    @State private var token = UUID()
    let id: String
    let state: ModeHostingState

    var body: some View {
        Text(id)
            .navigationTitle(id)
            .onAppear {
                state.appearances[id, default: 0] += 1
                state.tokens[id] = token
            }
    }
}

@available(iOS 17, macOS 14, *)
@MainActor
private final class ModeHostingWindow {
    #if os(macOS)
    let window: NSWindow
    init(state: ModeHostingState) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: ModeHostingRoot(state: state))
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
    }
    func close() {
        window.orderOut(nil)
        window.contentView = nil
    }
    #else
    let window: UIWindow
    init(state: ModeHostingState) {
        let controller = UIHostingController(rootView: ModeHostingRoot(state: state))
        controller.traitOverrides.horizontalSizeClass = .compact
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        window = scene.map(UIWindow.init(windowScene:))
            ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
    }
    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }
    #endif
}
#endif
