//
//  SplitCompactHostingTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit
import XCTest
@testable import SwiftfulRouting

final class SplitCompactHostingTests: XCTestCase {
    @available(iOS 17, *)
    @MainActor
    func testNativeCompactNavigationDrillsAndReturnsToSidebar() async throws {
        let sidebarAppeared = expectation(description: "Compact sidebar appeared")
        let detailAppeared = expectation(description: "Compact detail appeared")
        let nestedDetailAppeared = expectation(description: "Nested compact detail appeared")
        var sidebarReturned: XCTestExpectation?
        var selectionCleared: XCTestExpectation?
        var capturedRouter: AnyRouter?
        var capturedDetailRouter: AnyRouter?
        var awaitingReturn = false
        let root = RouterView(navigationSplitView: true) { router in
            Text("Sidebar")
                .navigationTitle("Sidebar")
                .onAppear {
                    if capturedRouter == nil {
                        capturedRouter = router
                        sidebarAppeared.fulfill()
                    } else if awaitingReturn {
                        awaitingReturn = false
                        sidebarReturned?.fulfill()
                    }
                }
                .onChange(of: router.selectedSplitViewDetailID) { _, selection in
                    if selection == nil { selectionCleared?.fulfill() }
                }
        }
        let controller = UIHostingController(rootView: root)
        controller.traitOverrides.horizontalSizeClass = .compact
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:))
            ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        await fulfillment(of: [sidebarAppeared], timeout: 5)
        let router = try XCTUnwrap(capturedRouter)
        router.addScreenToQueue(destination: AnyDestination(id: "A", animates: false) { detailRouter in
            Text("Detail A")
                .navigationTitle("Detail A")
                .onAppear {
                    if capturedDetailRouter == nil {
                        capturedDetailRouter = detailRouter
                        detailAppeared.fulfill()
                    }
                }
        })
        router.showNextScreen()
        controller.view.layoutIfNeeded()
        await fulfillment(of: [detailAppeared], timeout: 5)
        XCTAssertEqual(router.selectedSplitViewDetailID, "A")
        XCTAssertNotNil(controller.view.window)

        _ = try await navigationController(showing: "Detail A", in: controller)
        let detailRouter = try XCTUnwrap(capturedDetailRouter)
        detailRouter.addScreenToQueue(destination: AnyDestination(id: "B", animates: false) { _ in
            Text("Detail B")
                .navigationTitle("Detail B")
                .onAppear { nestedDetailAppeared.fulfill() }
        })
        detailRouter.showNextScreen()
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A", "B"])
        let nestedNavigation = try await navigationController(showing: "Detail B", in: controller)
        await fulfillment(of: [nestedDetailAppeared], timeout: 5)
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A", "B"])
        nestedNavigation.popViewController(animated: false)
        let navigationController = try await navigationController(showing: "Detail A", in: controller)
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A"])
        XCTAssertEqual(router.selectedSplitViewDetailID, "A")

        let returned = expectation(description: "Native back returned to sidebar")
        let cleared = expectation(description: "Native back cleared model selection")
        sidebarReturned = returned
        selectionCleared = cleared
        awaitingReturn = true
        navigationController.popViewController(animated: false)
        controller.view.layoutIfNeeded()
        await fulfillment(of: [returned, cleared], timeout: 5)
        XCTAssertNil(router.selectedSplitViewDetailID)
        _ = try await self.navigationController(showing: "Sidebar", in: controller, minimumDepth: 1)
    }

    @MainActor
    @available(iOS 17, *)
    func testSizeClassTransitionsPreserveHistoryAndAllowImmediateBack() async throws {
        let sidebarAppeared = expectation(description: "Sidebar appeared")
        let detailAppeared = expectation(description: "Detail appeared")
        var capturedRouter: AnyRouter?
        var capturedDetailRouter: AnyRouter?
        let root = RouterView(navigationSplitView: true, columnVisibility: .constant(.all)) { router in
            Text("Sidebar")
                .navigationTitle("Sidebar")
                .onAppear {
                    if capturedRouter == nil {
                        capturedRouter = router
                        sidebarAppeared.fulfill()
                    }
                }
        }
        let controller = UIHostingController(rootView: root)
        controller.traitOverrides.horizontalSizeClass = .regular
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:))
            ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.layoutIfNeeded()
        await fulfillment(of: [sidebarAppeared], timeout: 5)
        let router = try XCTUnwrap(capturedRouter)
        router.addScreenToQueue(destination: AnyDestination(id: "A", animates: false) { detailRouter in
            Text("Detail A")
                .navigationTitle("Detail A")
                .onAppear {
                    if capturedDetailRouter == nil {
                        capturedDetailRouter = detailRouter
                        detailAppeared.fulfill()
                    }
                }
        })
        router.showNextScreen()
        await fulfillment(of: [detailAppeared], timeout: 5)
        let detailRouter = try XCTUnwrap(capturedDetailRouter)
        detailRouter.addScreenToQueue(destination: AnyDestination(id: "B", animates: false) { _ in
            Text("Detail B").navigationTitle("Detail B")
        })
        detailRouter.showNextScreen()
        _ = try await navigationController(showing: "Detail B", in: controller)

        for sizeClass in [UIUserInterfaceSizeClass.compact, .regular, .compact] {
            controller.traitOverrides.horizontalSizeClass = sizeClass
            controller.view.layoutIfNeeded()
            _ = try await navigationController(showing: "Detail B", in: controller)
            XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A", "B"])
            XCTAssertEqual(router.selectedSplitViewDetailID, "A")
        }

        // No artificial delay after resizing: a completed native transition is enough.
        let nestedNavigation = try await navigationController(showing: "Detail B", in: controller)
        nestedNavigation.popViewController(animated: false)
        let selectedNavigation = try await navigationController(showing: "Detail A", in: controller)
        XCTAssertEqual(router.activeScreens[1].screens.map(\.id), ["A"])
        selectedNavigation.popViewController(animated: false)
        _ = try await navigationController(showing: "Sidebar", in: controller, minimumDepth: 1)
        // The sidebar reconciliation runs after its appearance callback.
        for _ in 0..<100 {
            if router.selectedSplitViewDetailID == nil { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(router.selectedSplitViewDetailID)
        XCTAssertTrue(router.activeScreens[1].screens.isEmpty)
    }

    @MainActor
    private func navigationController(showing title: String, in controller: UIViewController, minimumDepth: Int = 2) async throws -> UINavigationController {
        // Appearance callbacks can precede the native column transition.
        for _ in 0..<100 {
            controller.view.layoutIfNeeded()
            if let navigation = descendants(of: controller).compactMap({ $0 as? UINavigationController })
                .last(where: { $0.topViewController?.navigationItem.title == title && $0.viewControllers.count >= minimumDepth }) {
                if let transition = navigation.transitionCoordinator {
                    let settled = expectation(description: "Native navigation transition completed")
                    transition.animate(alongsideTransition: nil) { _ in settled.fulfill() }
                    await fulfillment(of: [settled], timeout: 3)
                }
                return navigation
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let hierarchy = descendants(of: controller).map { child in
            "\(type(of: child)): title=\(child.navigationItem.title ?? "nil")"
        }.joined(separator: "\n")
        return try XCTUnwrap(nil as UINavigationController?, "Native navigation did not show \(title):\n\(hierarchy)")
    }

    @MainActor
    private func descendants(of controller: UIViewController) -> [UIViewController] {
        [controller] + controller.children.flatMap { descendants(of: $0) }
    }
}
#endif
