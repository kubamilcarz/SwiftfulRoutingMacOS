//
//  ContainerLayoutHostingTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if os(macOS) && canImport(Testing)
import AppKit
import SwiftUI
import Testing
@testable import SwiftfulRouting

struct ContainerLayoutHostingTests {
    @Test @MainActor func transitionMeasurementTracksHostResizing() async {
        var frame = CGRect.zero
        let content = Color.clear
            .modifier(ContainerFrameViewModifier(frame: Binding(get: { frame }, set: { frame = $0 })))
        let host = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 280, height: 180),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        window.contentView = host
        defer { window.contentView = nil }

        #expect(await waitUntil { host.layoutSubtreeIfNeeded(); return frame.size == CGSize(width: 280, height: 180) })
        window.setContentSize(CGSize(width: 720, height: 450))
        #expect(await waitUntil { host.layoutSubtreeIfNeeded(); return frame.size == CGSize(width: 720, height: 450) })
        window.setContentSize(CGSize(width: 140, height: 500))
        #expect(await waitUntil { host.layoutSubtreeIfNeeded(); return frame.size == CGSize(width: 140, height: 500) })
        #expect(frame.origin == .zero)
    }

    @Test @MainActor func measuringDoesNotExpandIntrinsicContent() async {
        var frame = CGRect.zero
        let content = Color.red.frame(width: 120, height: 70)
            .modifier(ContainerFrameViewModifier(frame: Binding(get: { frame }, set: { frame = $0 })))
        let host = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = host
        defer { window.contentView = nil }
        #expect(await waitUntil { host.layoutSubtreeIfNeeded(); return frame.size == CGSize(width: 120, height: 70) })
    }

    @Test @MainActor func modalRoutingPreservesPlacementAndDismissesOnce() async throws {
        var capturedRouter: AnyRouter?
        var appearances = 0
        var dismissals = 0
        let root = RouterView(addNavigationStack: false) { router in
            Color.clear.onAppear { capturedRouter = router }
        }
        let host = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        window.contentView = host
        defer { window.contentView = nil }
        #expect(await waitUntil { host.layoutSubtreeIfNeeded(); return capturedRouter != nil })
        let router = try #require(capturedRouter)
        router.showModal(id: "adaptive", placement: .adaptive, onDismiss: { dismissals += 1 }) {
            Text("Modal").onAppear { appearances += 1 }
        }
        #expect(await waitUntil { host.layoutSubtreeIfNeeded(); return appearances == 1 })
        #expect(router.activeModals.last?.placement == .adaptive)
        window.setContentSize(CGSize(width: 300, height: 500))
        host.layoutSubtreeIfNeeded()
        // Let appearance/dismissal callbacks run after the new layout.
        await Task.yield()
        #expect(appearances == 1)
        #expect(dismissals == 0)
        router.dismissModal()
        #expect(dismissals == 1)

        router.showBasicModal(placement: .adaptive) { Text("Basic") }
        #expect(router.activeModals.last?.placement == .adaptive)
        router.showBottomModal(placement: .adaptive) { Text("Bottom") }
        #expect(router.activeModals.last?.placement == .adaptive)
        router.dismissAllModals()
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }
}
#endif
