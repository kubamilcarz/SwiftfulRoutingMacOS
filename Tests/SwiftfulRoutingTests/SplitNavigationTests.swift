//
//  SplitNavigationTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import Combine
import SwiftUI
import XCTest
@testable import SwiftfulRouting

final class SplitNavigationTests: XCTestCase {
    @MainActor
    private func destination(
        _ id: String,
        segue: SegueOption = .push,
        location: SegueLocation = .insert,
        onDismiss: (() -> Void)? = nil
    ) -> AnyDestination {
        AnyDestination(id: id, segue: segue, location: location, animates: false, onDismiss: onDismiss) { _ in
            Text(id)
        }
    }

    @MainActor
    private func model(split: Bool = true) -> RouterViewModel {
        let model = RouterViewModel(navigationSplitView: split)
        model.insertRootView(rootRouterId: nil, view: destination("root", segue: .fullScreenCover))
        return model
    }

    @MainActor
    func testSidebarReplacesBranchInOnePublicationAndDismissesDeepestFirst() async {
        let model = model()
        var dismissed: [String] = []
        await model.showScreens(routerId: "root", destinations: [
            destination("A", onDismiss: { dismissed.append("A") }),
            destination("B", onDismiss: { dismissed.append("B") }),
            destination("C", onDismiss: { dismissed.append("C") })
        ]).value
        var published: [[String]] = []
        let subscription = model.$activeScreenStacks.dropFirst().sink {
            published.append($0[1].screens.map(\.id))
        }

        await model.showScreens(routerId: "root", destinations: [destination("D")]).value

        XCTAssertEqual(published, [["D"]])
        XCTAssertEqual(dismissed, ["C", "B", "A"])
        XCTAssertEqual(model.selectedSplitViewDetailID(routerId: "root"), "D")
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testPushFromEarlierDetailReplacesOnlyDescendants() async {
        let model = model()
        await model.showScreens(routerId: "root", destinations: [destination("A"), destination("B"), destination("C")]).value
        await model.showScreens(routerId: "A", destinations: [destination("D"), destination("E")]).value

        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["A", "D", "E"])
        XCTAssertEqual(model.selectedSplitViewDetailID(routerId: "E"), "A")
    }

    @MainActor
    func testReselectingSameIDResetsHistoryAndRouteState() async {
        let model = model()
        var dismissCount = 0
        await model.showScreens(routerId: "root", destinations: [
            destination("A", onDismiss: { dismissCount += 1 }), destination("B")
        ]).value
        model.showAlert(routerId: "A", alert: AnyAlert(location: .currentScreen, title: "Old alert"))
        await model.showScreens(routerId: "root", destinations: [destination("A")]).value

        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["A"])
        XCTAssertEqual(dismissCount, 1)
        XCTAssertNil(model.activeAlert["A"])
        XCTAssertEqual(model.allTransitions["A"], [.root])
        XCTAssertNotNil(model.allDestinationsById["A"])
        model.dismissPushStack(routeId: "root", animates: false)
        XCTAssertEqual(dismissCount, 1)
    }

    @MainActor
    func testExplicitLocationsKeepTheirExistingSemantics() async {
        let model = model()
        await model.showScreens(routerId: "root", destinations: [destination("A"), destination("B")]).value
        await model.showScreens(routerId: "root", destinations: [destination("C", location: .append)]).value
        await model.showScreens(routerId: "root", destinations: [destination("D", location: .insertAfter(id: "A"))]).value

        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["A", "D", "B", "C"])
    }

    @MainActor
    func testOrdinaryRouterStillInsertsBeforeExistingRootHistory() async {
        let model = model(split: false)
        await model.showScreens(routerId: "root", destinations: [destination("A")]).value
        await model.showScreens(routerId: "root", destinations: [destination("B")]).value

        XCTAssertEqual(model.activeScreenStacks[1].screens.map(\.id), ["B", "A"])
        XCTAssertNil(model.selectedSplitViewDetailID(routerId: "root"))
    }

    @MainActor
    func testSheetsHaveIndependentSelectionAndPushBehavior() async {
        let model = model()
        await model.showScreens(routerId: "root", destinations: [
            destination("A"), destination("sheet", segue: .sheet), destination("sheet_A")
        ]).value
        await model.showScreens(routerId: "sheet", destinations: [destination("sheet_B")]).value

        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["A"])
        XCTAssertEqual(model.activeScreenStacks[3].screens.map(\.id), ["sheet_B", "sheet_A"])
        XCTAssertNil(model.selectedSplitViewDetailID(routerId: "sheet"))
        XCTAssertNil(model.selectedSplitViewDetailID(routerId: "sheet_A"))
        XCTAssertEqual(model.selectedSplitViewDetailID(routerId: "A"), "A")
    }

    @MainActor
    func testReplacementCleansUpPresentationsAndCallbacksOnce() async {
        let model = model()
        var dismissed: [String] = []
        await model.showScreens(routerId: "root", destinations: [
            destination("A", onDismiss: { dismissed.append("A") }),
            destination("sheet", segue: .sheet, onDismiss: { dismissed.append("sheet") }),
            destination("sheet_detail", onDismiss: { dismissed.append("sheet_detail") })
        ]).value
        model.showModal(routerId: "A", modal: AnyModal(destination: { Text("Modal") }, onDismiss: { dismissed.append("modal") }))
        model.showAlert(routerId: "A", alert: AnyAlert(location: .currentScreen, title: "Detail alert"))
        model.showAlert(routerId: "root", alert: AnyAlert(location: .currentScreen, title: "Sidebar alert"))

        await model.showScreens(routerId: "root", destinations: [destination("B")]).value
        model.dismissScreens(toEnvironmentId: "A", animates: false)

        XCTAssertEqual(model.activeScreenStacks.count, 2)
        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["B"])
        XCTAssertEqual(dismissed, ["sheet_detail", "sheet", "modal", "A"])
        XCTAssertNil(model.activeAlert["A"])
        XCTAssertNil(model.allModals["A"])
        XCTAssertNil(model.allTransitions["A"])
        XCTAssertNotNil(model.activeAlert["root"])
    }

    @MainActor
    func testDismissMethodsPreserveOrClearSelectionAtTheRightBoundary() async {
        let model = model()
        await model.showScreens(routerId: "root", destinations: [destination("A"), destination("B"), destination("C")]).value
        model.dismissScreens(to: "A", animates: false)
        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["A"])
        XCTAssertEqual(model.selectedSplitViewDetailID(routerId: "root"), "A")

        model.dismissScreen(routeId: "A", animates: false)
        XCTAssertTrue(model.splitViewDestinations.isEmpty)
        XCTAssertNil(model.selectedSplitViewDetailID(routerId: "root"))

        await model.showScreens(routerId: "root", destinations: [destination("D"), destination("E")]).value
        model.dismissPushStack(routeId: "E", animates: false)
        XCTAssertTrue(model.splitViewDestinations.isEmpty)

        await model.showScreens(routerId: "root", destinations: [destination("F")]).value
        model.dismissAllScreens(animates: false)
        XCTAssertTrue(model.splitViewDestinations.isEmpty)
        XCTAssertEqual(model.activeScreenStacks.count, 2)
    }

    @MainActor
    func testQueueUsesTheCallingRouterToSelectThenDrill() {
        let model = model()
        model.addScreensToQueue(routerId: "root", destinations: [destination("A"), destination("B")])
        model.showNextScreen(routerId: "root")
        model.showNextScreen(routerId: "A")
        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["A", "B"])
        XCTAssertTrue(model.availableScreenQueue.isEmpty)

        model.addScreensToQueue(routerId: "root", destinations: [destination("C")])
        model.showNextScreen(routerId: "root")
        XCTAssertEqual(model.splitViewDestinations.map(\.id), ["C"])
    }

    @MainActor
    func testSelectionIsIsolatedAndMockRouterHasNoSelection() async {
        let first = model()
        let second = model()
        await first.showScreens(routerId: "root", destinations: [destination("A")]).value
        XCTAssertNil(second.selectedSplitViewDetailID(routerId: "root"))
        XCTAssertNil(first.selectedSplitViewDetailID(routerId: "missing"))
        XCTAssertNil(AnyRouter(id: "root", rootRouterId: "", object: MockRouter()).selectedSplitViewDetailID)
    }

    func testNativeDetailPopRetainsSelectionAndCompactBackClearsIt() {
        var state = SplitNavigationState()
        let before = Date(timeIntervalSince1970: 0)
        let after = before.addingTimeInterval(1)
        state.synchronize(with: ["A", "B", "C"], now: before)
        XCTAssertEqual(state.path, ["B", "C"])
        XCTAssertEqual(state.popTarget(for: ["B"], modelBranch: ["A", "B", "C"], now: after), "B")
        XCTAssertEqual(state.popTarget(for: [], modelBranch: ["A", "B", "C"], now: after), "A")
        XCTAssertFalse(state.canClearSelection(modelBranch: ["A", "B", "C"], now: after))

        state.synchronize(with: ["A"], now: after)
        XCTAssertTrue(state.path.isEmpty)
        XCTAssertTrue(state.canClearSelection(modelBranch: ["A"], now: after))
        state.synchronize(with: [], now: after)
        XCTAssertFalse(state.canClearSelection(modelBranch: [], now: after))
    }

    func testTransientLayoutAndStaleBranchCallbacksDoNotDismissRoutes() {
        var state = SplitNavigationState()
        let now = Date(timeIntervalSince1970: 0)
        state.synchronize(with: ["A", "B"], now: now)
        XCTAssertNil(state.popTarget(for: [], modelBranch: ["A", "B"], now: now))
        XCTAssertNil(state.popTarget(for: ["wrong"], modelBranch: ["A", "B"], now: now.addingTimeInterval(1)))
        XCTAssertNil(state.popTarget(for: [], modelBranch: ["C"], now: now.addingTimeInterval(1)))
        state.synchronize(with: ["C"], now: now)
        // A real compact back action must work immediately after selecting a detail.
        XCTAssertTrue(state.canClearSelection(modelBranch: ["C"], now: now))
        XCTAssertTrue(state.canClearSelection(modelBranch: ["C"], now: now.addingTimeInterval(1)))
    }

    func testImmediatePopAfterPresentationRetainsSelectedDetail() {
        var state = SplitNavigationState()
        let now = Date()
        state.synchronize(with: ["A", "B"], now: now)
        XCTAssertNil(state.popTarget(for: [], modelBranch: ["A", "B"], now: now))
        state.didPresent(routeID: "A")
        XCTAssertNil(state.popTarget(for: [], modelBranch: ["A", "B"], now: now))
        state.didPresent(routeID: "B")
        XCTAssertEqual(state.popTarget(for: [], modelBranch: ["A", "B"], now: now), "A")
    }

    func testChangingSizeClassPreservesSelectionAndDetailHistory() {
        var state = SplitNavigationState()
        let before = Date(timeIntervalSince1970: 0)
        let resized = before.addingTimeInterval(10)
        state.synchronize(with: ["A", "B"], now: before)
        state.layoutDidChange(now: resized)
        XCTAssertNil(state.popTarget(for: [], modelBranch: ["A", "B"], now: resized))
        XCTAssertEqual(state.path, ["B"])

        state.synchronize(with: ["A"], now: resized)
        XCTAssertFalse(state.canClearSelection(modelBranch: ["A"], now: resized))
        XCTAssertTrue(state.canClearSelection(modelBranch: ["A"], now: resized.addingTimeInterval(1)))
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    func testInitializerExamplesAndSplitPrecedence() {
        let basic = RouterView(navigationSplitView: true, addNavigationStack: false) { _ in Text("Sidebar") }
        XCTAssertNotNil(basic.splitViewConfiguration)
        let customized = RouterView(
            id: "module_root",
            navigationSplitView: true,
            columnVisibility: .constant(.all),
            addModuleSupport: true
        ) { _ in
            Text("Sidebar")
        } emptyDetail: { _ in
            Text("Choose a project")
            Text("No project selected")
        }
        XCTAssertNotNil(customized.splitViewConfiguration)
        let disabled = RouterView(navigationSplitView: false) { _ in Text("Root") }
        XCTAssertNil(disabled.splitViewConfiguration)
        XCTAssertTrue(disabled.addNavigationStack)
        XCTAssertNil(RouterView { _ in Text("Root") }.splitViewConfiguration)
    }
}
