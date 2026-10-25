//
//  ToastRoutingTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if canImport(Testing)
import SwiftUI
import Testing
@testable import SwiftfulRouting

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ToastRoutingTests {
    @Test func fractionalDurationIsPreservedAndLoggedInSeconds() {
        let toast = AnyToast(duration: .milliseconds(250)) { Text("Toast") }
        #expect(toast.duration == .milliseconds(250))
        #expect(toast.eventParameters["toast_duration"] as? Double == 0.25)
    }

    @Test func defaultsAndManualDismissal() {
        let model = RouterViewModel()
        var dismissals: [String] = []
        let toast = AnyToast { Text("Default") }
        #expect(toast.position == .top)
        #expect(toast.duration == .seconds(3))
        for id in ["first", "second"] {
            model.showToast(routerId: "root", toast: AnyToast(id: id, duration: nil, onDismiss: {
                dismissals.append(id)
            }) { Text(id) })
        }
        #expect(model.allToasts["root"]?.map(\.toast.id) == ["first", "second"])
        model.dismissLastToast(routerId: "root")
        #expect(dismissals == ["second"])
        model.dismissToast(routerId: "root", toastId: "second")
        model.dismissAllToasts(routerId: "root")
        model.dismissAllToasts(routerId: "root")
        #expect(dismissals == ["second", "first"])
        #expect(model.allToasts["root"] == nil)
    }

    @Test func independentTimersAndPersistentToast() async throws {
        let clock = ToastTestClock()
        let model = RouterViewModel(toastSleep: clock.sleep)
        var dismissals: [String] = []
        for (id, duration) in [("slow", Duration.seconds(10)), ("fast", .milliseconds(250))] {
            model.showToast(routerId: "root", toast: AnyToast(id: id, duration: duration, onDismiss: {
                dismissals.append(id)
            }) { Text(id) })
        }
        model.showToast(routerId: "root", toast: AnyToast(id: "persistent", duration: nil) { Text("Persistent") })
        await clock.waitForSleeps(2)
        #expect(clock.durations.sorted() == [.milliseconds(250), .seconds(10)])
        let fastIndex = try #require(clock.durations.firstIndex(of: .milliseconds(250)))
        let slowIndex = try #require(clock.durations.firstIndex(of: .seconds(10)))
        await clock.finish(fastIndex)
        #expect(dismissals == ["fast"])
        #expect(model.allToasts["root"]?.map(\.toast.id) == ["slow", "persistent"])
        await clock.finish(slowIndex)
        #expect(dismissals == ["fast", "slow"])
        #expect(model.allToasts["root"]?.map(\.toast.id) == ["persistent"])
    }

    @Test func replacingIDCancelsTimerAndRejectsStalePresentation() async throws {
        let clock = ToastTestClock()
        let model = RouterViewModel(toastSleep: clock.sleep)
        var dismissals = 0
        let toast = AnyToast(id: "same", onDismiss: { dismissals += 1 }) { Text("Toast") }
        model.showToast(routerId: "root", toast: toast)
        let original = try #require(model.allToasts["root"]?.first?.id)
        await clock.waitForSleeps(1)
        model.showToast(routerId: "root", toast: toast)
        await clock.waitForSleeps(2)
        #expect(dismissals == 1)
        #expect(model.allToasts["root"]?.count == 1)
        #expect(model.allToasts["root"]?.first?.id != original)
        await clock.finish(0)
        #expect(clock.cancellations[0] == true)
        model.dismissToast(routerId: "root", presentationId: original)
        #expect(dismissals == 1)
        #expect(model.allToasts["root"]?.count == 1)
        await clock.finish(1)
        #expect(dismissals == 2)
        #expect(model.allToasts["root"] == nil)
    }

    @Test func manuallyDismissedTimerCannotDismissReusedID() async {
        let clock = ToastTestClock()
        let model = RouterViewModel(toastSleep: clock.sleep)
        var dismissals = 0
        model.showToast(routerId: "root", toast: AnyToast(id: "same", onDismiss: { dismissals += 1 }) { Text("Old") })
        await clock.waitForSleeps(1)
        model.dismissToast(routerId: "root", toastId: "same")
        model.showToast(routerId: "root", toast: AnyToast(id: "same", duration: nil) { Text("New") })
        await clock.finish(0)
        #expect(clock.cancellations[0] == true)
        #expect(dismissals == 1)
        #expect(model.allToasts["root"]?.count == 1)
    }

    @Test(arguments: [Duration.zero, .seconds(-1), .milliseconds(-1)])
    func nonpositiveDurationDismissesImmediately(duration: Duration) {
        let model = RouterViewModel()
        var dismissals = 0
        model.showToast(routerId: "root", toast: AnyToast(duration: duration, onDismiss: { dismissals += 1 }) { Text("Toast") })
        #expect(model.allToasts["root"] == nil)
        #expect(dismissals == 1)
    }

    @Test func callbacksCanReplaceAndDismissWithoutDuplicateIDs() {
        let model = RouterViewModel()
        var dismissals: [String] = []
        model.showToast(routerId: "root", toast: AnyToast(id: "same", duration: nil, onDismiss: {
            dismissals.append("old")
            model.showToast(routerId: "root", toast: AnyToast(id: "same", duration: nil) { Text("From callback") })
        }) { Text("Old") })
        model.showToast(routerId: "root", toast: AnyToast(id: "same", duration: nil, onDismiss: {
            dismissals.append("replacement")
        }) { Text("Replacement") })
        #expect(dismissals == ["old", "replacement"])
        #expect(model.allToasts["root"]?.count == 1)

        model.showToast(routerId: "root", toast: AnyToast(id: "last", duration: nil, onDismiss: {
            #expect(model.allToasts["root"] == nil)
            model.dismissAllToasts(routerId: "root")
            model.showToast(routerId: "root", toast: AnyToast(id: "survivor", duration: nil) { Text("Survivor") })
        }) { Text("Last") })
        model.dismissAllToasts(routerId: "root")
        #expect(model.allToasts["root"]?.map(\.toast.id) == ["survivor"])
    }

    @Test(arguments: [false, true])
    func screenRemovalCancelsTimersAndKeepsOtherRoutersIsolated(split: Bool) async {
        let clock = ToastTestClock()
        let model = RouterViewModel(navigationSplitView: split, toastSleep: clock.sleep)
        model.insertRootView(rootRouterId: nil, view: AnyDestination(id: "root", segue: .fullScreenCover) { _ in Text("Root") })
        await model.showScreens(routerId: "root", destinations: [AnyDestination(id: "detail", animates: false) { _ in Text("Detail") }]).value
        var dismissals = 0
        model.showToast(routerId: "root", toast: AnyToast(id: "same", duration: nil) { Text("Root toast") })
        model.showToast(routerId: "detail", toast: AnyToast(id: "same", onDismiss: {
            dismissals += 1
            model.showToast(routerId: "detail", toast: AnyToast(duration: nil) { Text("Stale router") })
        }) { Text("Detail toast") })
        await clock.waitForSleeps(1)
        model.dismissScreen(routeId: "detail", animates: false)
        #expect(dismissals == 1)
        #expect(model.allToasts["detail"] == nil)
        #expect(model.allToasts["root"]?.count == 1)
        await clock.finish(0)
        #expect(clock.cancellations[0] == true)
        #expect(dismissals == 1)
    }

    @Test func splitReselectionRemovesOldToastAndRetainsFreshPresentation() async {
        let model = RouterViewModel(navigationSplitView: true)
        model.insertRootView(rootRouterId: nil, view: AnyDestination(id: "root", segue: .fullScreenCover) { _ in Text("Root") })
        let detail = AnyDestination(id: "detail", animates: false) { _ in Text("Detail") }
        await model.showScreens(routerId: "root", destinations: [detail]).value
        var dismissals = 0
        model.showToast(routerId: "detail", toast: AnyToast(id: "old", duration: nil, onDismiss: {
            dismissals += 1
            model.showToast(routerId: "detail", toast: AnyToast(duration: nil) { Text("During cleanup") })
        }) { Text("Old") })
        await model.showScreens(routerId: "root", destinations: [detail]).value
        #expect(dismissals == 1)
        #expect(model.allToasts["detail"] == nil)
        model.showToast(routerId: "detail", toast: AnyToast(id: "fresh", duration: nil) { Text("Fresh") })
        #expect(model.allToasts["detail"]?.map(\.toast.id) == ["fresh"])
    }

    @Test func timerDoesNotRetainModelAndIsCancelledOnDeinit() async {
        let clock = ToastTestClock()
        var model: RouterViewModel? = RouterViewModel(toastSleep: clock.sleep)
        let weakModel = { [weak model] in model }
        model?.showToast(routerId: "root", toast: AnyToast { Text("Toast") })
        await clock.waitForSleeps(1)
        model = nil
        #expect(weakModel() == nil)
        await clock.finish(0)
        #expect(clock.cancellations[0] == true)
    }
}
#endif
