//
//  ToastPresentation.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// Identity belongs to a presentation, independently of its reusable public toast ID.
struct ToastPresentation: Identifiable {
    let id = UUID()
    let toast: AnyToast

    static func sleep(seconds: TimeInterval) async throws {
        // Bounded chunks avoid overflowing nanoseconds for very large finite durations.
        var remaining = seconds
        while remaining > 0 {
            let interval = min(remaining, 86_400)
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            remaining -= interval
        }
    }
}
