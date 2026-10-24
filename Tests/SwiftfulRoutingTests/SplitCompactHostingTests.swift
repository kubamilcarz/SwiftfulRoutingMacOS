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
    func testNativeCompactBackClearsDetailSelection() async throws {
        let sidebarAppeared = expectation(description: "Compact sidebar appeared")
        let detailAppeared = expectation(description: "Compact detail appeared")
        let sidebarReturned = expectation(description: "Native back returned to sidebar")
        var capturedRouter: AnyRouter?
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
                        sidebarReturned.fulfill()
                    }
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
        router.addScreenToQueue(destination: AnyDestination(id: "A", animates: false) { _ in
            Text("Detail A")
                .navigationTitle("Detail A")
                .onAppear { detailAppeared.fulfill() }
        })
        router.showNextScreen()
        controller.view.layoutIfNeeded()
        await fulfillment(of: [detailAppeared], timeout: 5)
        XCTAssertEqual(router.selectedSplitViewDetailID, "A")

        let navigationController = try XCTUnwrap(
            descendants(of: controller).compactMap { $0 as? UINavigationController }
                .last(where: { $0.viewControllers.count > 1 && $0.view.window != nil })
        )
        if let transition = navigationController.transitionCoordinator {
            let settled = expectation(description: "Native column transition completed")
            transition.animate(alongsideTransition: nil) { _ in settled.fulfill() }
            await fulfillment(of: [settled], timeout: 3)
        }
        awaitingReturn = true
        navigationController.popViewController(animated: false)
        controller.view.layoutIfNeeded()
        await fulfillment(of: [sidebarReturned], timeout: 5)
        XCTAssertNil(router.selectedSplitViewDetailID)
    }

    @MainActor
    private func descendants(of controller: UIViewController) -> [UIViewController] {
        [controller] + controller.children.flatMap { descendants(of: $0) }
    }
}
#endif
