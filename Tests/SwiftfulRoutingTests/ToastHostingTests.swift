//
//  ToastHostingTests.swift
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

@MainActor
struct ToastHostingTests {
    @available(macOS 14, *)
    @Test func environmentConsumersObserveToastPresentationReplacementAndDismissal() async throws {
        var capturedRouter: AnyRouter?
        var observedToasts: [AnyToast] = []
        var observedHasToast = false
        let root = RouterView(addNavigationStack: false) { router in
            ToastStateProbe { toasts, hasToast in
                observedToasts = toasts
                observedHasToast = hasToast
            }
            .onAppear { capturedRouter = router }
        }
        let (window, host) = host(root)
        defer { window.contentView = nil }
        try #require(await waitUntil(host) { capturedRouter != nil })
        let router = try #require(capturedRouter)
        defer { router.dismissAllToasts() }

        router.showToast(id: "toast", animation: .linear(duration: 0), duration: nil) { Text("Persistent") }
        try #require(await waitUntil(host) { observedHasToast && observedToasts.map(\.id) == ["toast"] })

        // A replacement must invalidate consumers even though its public ID is unchanged.
        router.showToast(id: "toast", animation: .linear(duration: 0), duration: .seconds(60)) { Text("Replacement") }
        try #require(await waitUntil(host) { observedToasts.first?.duration == .seconds(60) })

        router.showToast(id: "second", animation: .linear(duration: 0), duration: nil) { Text("Second") }
        try #require(await waitUntil(host) { observedToasts.map(\.id) == ["toast", "second"] })
        router.dismissToast(id: "toast")
        try #require(await waitUntil(host) { observedHasToast && observedToasts.map(\.id) == ["second"] })
        router.dismissAllToasts()
        #expect(await waitUntil(host) { !observedHasToast && observedToasts.isEmpty })
    }

    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func positionsRespectSafeAreasAndLanguageDirection(direction: LayoutDirection) async throws {
        var capturedRouter: AnyRouter?
        var frames: [String: CGRect] = [:]
        let root = RouterView(addNavigationStack: false) { router in
            Color.clear.onAppear { capturedRouter = router }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 40) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 30) }
        .coordinateSpace(name: "toast-test")
        .environment(\.layoutDirection, direction)
        let (window, host) = host(root)
        defer { window.contentView = nil }
        #expect(await waitUntil(host) { capturedRouter != nil })
        let router = try #require(capturedRouter)
        for position in ToastPosition.allCases {
            router.showToast(id: position.rawValue, position: position, animation: .linear(duration: 0), duration: .seconds(60)) {
                ToastHostingProbe(id: position.rawValue, onFrame: { frames[position.rawValue] = $0 }, onAppear: { _ in })
            }
        }
        #expect(await waitUntil(host) { frames.count == 6 })
        #expect(router.activeToasts.allSatisfy { $0.duration == .seconds(60) })
        for position in ToastPosition.allCases {
            let frame = try #require(frames[position.rawValue])
            let expectedX: CGFloat
            switch position {
            case .top, .bottom: expectedX = 260
            case .topLeading, .bottomLeading: expectedX = direction == .leftToRight ? 16 : 504
            case .topTrailing, .bottomTrailing: expectedX = direction == .leftToRight ? 504 : 16
            }
            #expect(abs(frame.minX - expectedX) < 1)
            #expect(abs(frame.minY - (position.isTop ? 56 : 322)) < 1)
        }
        router.dismissAllToasts()
        #expect(!router.hasActiveToast)
    }

    @Test func stackReflowsWithoutRecreatingDestinations() async throws {
        var capturedRouter: AnyRouter?
        var frames: [String: CGRect] = [:]
        var tokens: [String: UUID] = [:]
        var appearances: [String: Int] = [:]
        let root = RouterView(addNavigationStack: false) { router in
            Color.clear.onAppear { capturedRouter = router }
        }
        .coordinateSpace(name: "toast-test")
        let (window, host) = host(root)
        defer { window.contentView = nil }
        #expect(await waitUntil(host) { capturedRouter != nil })
        let router = try #require(capturedRouter)
        for (id, position) in [("top-old", ToastPosition.top), ("top-new", .top), ("bottom-old", .bottom), ("bottom-new", .bottom)] {
            router.showToast(id: id, position: position, animation: .linear(duration: 0), duration: nil) {
                ToastHostingProbe(id: id, onFrame: { frames[id] = $0 }, onAppear: {
                    tokens[id] = $0
                    appearances[id, default: 0] += 1
                })
            }
        }
        #expect(await waitUntil(host) { frames.count == 4 })
        #expect(frames["top-new"]?.minY == 16)
        #expect(frames["top-old"]?.minY == 56)
        #expect(frames["bottom-new"]?.maxY == 384)
        #expect(frames["bottom-old"]?.maxY == 344)
        let originalTokens = tokens
        router.dismissToast(id: "top-new")
        router.dismissToast(id: "bottom-new")
        #expect(await waitUntil(host) { frames["top-old"]?.minY == 16 && frames["bottom-old"]?.maxY == 384 })
        window.setContentSize(CGSize(width: 800, height: 500))
        #expect(await waitUntil(host) { frames["top-old"]?.midX == 400 && frames["bottom-old"]?.maxY == 484 })
        #expect(tokens["top-old"] == originalTokens["top-old"])
        #expect(tokens["bottom-old"] == originalTokens["bottom-old"])
        #expect(appearances.values.allSatisfy { $0 == 1 })
        router.dismissToast()
        #expect(router.activeToasts.map(\.id) == ["top-old"])
        router.dismissAllToasts()
    }

    @Test func controlsReceiveHitsAndToastsAppearAboveCustomModals() async throws {
        var capturedRouter: AnyRouter?
        var underlyingPresses = 0
        var toastPresses = 0
        let root = RouterView(addNavigationStack: false) { router in
            ToastTestButton(id: "underlying", action: { underlyingPresses += 1 })
                .frame(width: 120, height: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { capturedRouter = router }
        }
        let (window, host) = host(root)
        defer { window.contentView = nil }
        #expect(await waitUntil(host) { capturedRouter != nil })
        let router = try #require(capturedRouter)
        router.showToast(id: "custom", transition: .identity, animation: .linear(duration: 0), duration: nil) {
            ToastTestButton(id: "toast", action: {
                toastPresses += 1
                router.dismissToast(id: "custom")
            }).frame(width: 120, height: 40)
        }
        #expect(await waitUntil(host) { findButton("toast", in: host) != nil })
        let underlying = try #require(findButton("underlying", in: host))
        #expect(hit(underlying, in: host) === underlying)
        underlying.performClick(nil)
        #expect(underlyingPresses == 1)

        router.showModal(animation: .linear(duration: 0), alignment: .top, backgroundColor: .red, ignoreSafeArea: false) {
            ToastTestButton(id: "modal", action: {}).frame(width: 120, height: 40)
        }
        #expect(await waitUntil(host) { findButton("modal", in: host) != nil })
        let toast = try #require(findButton("toast", in: host))
        #expect(await waitUntil(host) { hit(toast, in: host) === toast })
        toast.performClick(nil)
        #expect(toastPresses == 1)
        #expect(!router.hasActiveToast)
        router.dismissAllModals()
    }

    private func host<Content: View>(_ root: Content) -> (NSWindow, NSHostingView<AnyView>) {
        let host = NSHostingView(rootView: AnyView(root))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.contentView = host
        return (window, host)
    }

    private func waitUntil(_ host: NSView, _ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    private func findButton(_ id: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.identifier?.rawValue == id { return button }
        return view.subviews.lazy.compactMap { findButton(id, in: $0) }.first
    }

    private func hit(_ button: NSButton, in host: NSView) -> NSView? {
        let center = NSPoint(x: button.bounds.midX, y: button.bounds.midY)
        // NSView.hitTest takes coordinates in the receiver's superview, whose
        // vertical direction differs from the flipped NSHostingView.
        return host.hitTest(button.convert(center, to: host.superview))
    }
}
#endif
