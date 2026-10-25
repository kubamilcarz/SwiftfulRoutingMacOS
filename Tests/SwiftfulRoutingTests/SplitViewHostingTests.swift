//
//  SplitViewHostingTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import SwiftfulRouting

final class SplitViewHostingTests: XCTestCase {
    @available(macOS 14, *)
    @MainActor
    func testHostedSplitViewUpdatesEnvironmentSelectionAndRendersDestinations() async throws {
        let sidebarAppeared = expectation(description: "Sidebar appeared")
        let placeholderAppeared = expectation(description: "Placeholder appeared")
        let selectionAppeared = expectation(description: "Selection is visible to environment consumers")
        let detailAppeared = expectation(description: "Selected detail rendered")
        let selectionCleared = expectation(description: "Selection cleared in sidebar")
        var capturedRouter: AnyRouter?
        var didShowPlaceholder = false
        var didShowDetail = false
        let root = RouterView(navigationSplitView: true, columnVisibility: .constant(.all)) { router in
            SplitSelectionProbe { selection in
                if selection == "A" { selectionAppeared.fulfill() }
                if selection == nil { selectionCleared.fulfill() }
            }
            .onAppear {
                if capturedRouter == nil {
                    capturedRouter = router
                    sidebarAppeared.fulfill()
                }
            }
        } emptyDetail: { _ in
            Text("Choose a project")
                .onAppear {
                    if !didShowPlaceholder {
                        didShowPlaceholder = true
                        placeholderAppeared.fulfill()
                    }
                }
        }
        let host = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false
        )
        window.contentView = host
        defer { window.contentView = nil }
        host.layoutSubtreeIfNeeded()
        await fulfillment(of: [sidebarAppeared, placeholderAppeared], timeout: 3)

        let router = try XCTUnwrap(capturedRouter)
        router.addScreenToQueue(destination: AnyDestination(id: "A", animates: false) { _ in
            Text("Detail A").onAppear {
                if !didShowDetail {
                    didShowDetail = true
                    detailAppeared.fulfill()
                }
            }
        })
        router.showNextScreen()
        invalidateLayout(host)
        host.layoutSubtreeIfNeeded()
        await fulfillment(of: [selectionAppeared, detailAppeared], timeout: 3)
        XCTAssertEqual(router.selectedSplitViewDetailID, "A")

        router.dismissPushStack(animates: false)
        invalidateLayout(host)
        host.layoutSubtreeIfNeeded()
        await fulfillment(of: [selectionCleared], timeout: 3)
        XCTAssertNil(router.selectedSplitViewDetailID)
        withExtendedLifetime(window) {}
    }

    @MainActor
    private func invalidateLayout(_ view: NSView) {
        view.needsLayout = true
        for child in view.subviews {
            invalidateLayout(child)
        }
    }
}
#endif
