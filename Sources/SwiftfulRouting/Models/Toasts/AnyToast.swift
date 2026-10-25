//
//  AnyToast.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// A custom view presented in one of the calling router's toast stacks.
/// Supply all styling and interactive controls in `destination`.
public struct AnyToast: Identifiable, Equatable {
    public private(set) var id: String
    public private(set) var position: ToastPosition
    public private(set) var transition: AnyTransition
    public private(set) var animation: Animation
    public private(set) var duration: TimeInterval?
    public private(set) var destination: AnyView
    public private(set) var onDismiss: (() -> Void)?

    /// - Parameters:
    ///   - id: Identifier used to dismiss or replace a toast on this router.
    ///   - position: Stack position, inside safe areas. Newest toasts sit nearest the edge.
    ///   - transition: Custom insertion/removal transition; nil moves from the selected edge and fades.
    ///   - animation: Animation for presentation, dismissal, and stack reflow.
    ///   - duration: Seconds from presentation until dismissal, even while covered. Nil persists
    ///     until dismissed; nonpositive or nonfinite values dismiss immediately.
    ///   - onDismiss: Called once when removed from routing state, before the exit animation ends.
    ///   - destination: The complete toast view, including any dismissal controls.
    public init<T: View>(
        id: String = UUID().uuidString,
        position: ToastPosition = .top,
        transition: AnyTransition? = nil,
        animation: Animation = .easeInOut(duration: 0.25),
        duration: TimeInterval? = 3,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder destination: () -> T
    ) {
        self.id = id
        self.position = position
        self.transition = transition ?? position.defaultTransition
        self.animation = animation
        self.duration = duration
        self.destination = AnyView(destination())
        self.onDismiss = onDismiss
    }

    public static func == (lhs: AnyToast, rhs: AnyToast) -> Bool {
        lhs.id == rhs.id
    }

    public var eventParameters: [String: Any] {
        var parameters: [String: Any] = [
            "toast_id": id,
            "toast_position": position.rawValue,
            "toast_is_persistent": duration == nil,
            "toast_has_on_dismiss": onDismiss != nil
        ]
        if let duration { parameters["toast_duration"] = duration }
        return parameters
    }
}
