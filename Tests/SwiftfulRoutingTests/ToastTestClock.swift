//
//  ToastTestClock.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if canImport(Testing)
import Foundation

/// A deliberately cancellation-insensitive sleeper: routing must reject a stale wakeup itself.
@MainActor
final class ToastTestClock {
    private(set) var durations: [TimeInterval] = []
    private(set) var cancellations: [Int: Bool] = [:]
    private var sleepers: [Int: CheckedContinuation<Void, Never>] = [:]
    private var startWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var finishWaiters: [Int: CheckedContinuation<Void, Never>] = [:]

    func sleep(_ duration: TimeInterval) async {
        let index = durations.count
        durations.append(duration)
        await withCheckedContinuation { continuation in
            sleepers[index] = continuation
            let ready = startWaiters.filter { durations.count >= $0.0 }
            startWaiters.removeAll { durations.count >= $0.0 }
            for waiter in ready { waiter.1.resume() }
        }
        cancellations[index] = Task.isCancelled
        finishWaiters.removeValue(forKey: index)?.resume()
    }

    func waitForSleeps(_ count: Int) async {
        guard durations.count < count else { return }
        await withCheckedContinuation { startWaiters.append((count, $0)) }
    }

    func finish(_ index: Int) async {
        guard let sleeper = sleepers.removeValue(forKey: index) else { return }
        await withCheckedContinuation { continuation in
            finishWaiters[index] = continuation
            sleeper.resume()
        }
    }
}
#endif
