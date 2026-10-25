//
//  ToastPosition.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// The safe-area edge and horizontal alignment of a toast stack.
public enum ToastPosition: String, CaseIterable, Sendable {
    case top
    case topLeading
    case topTrailing
    case bottom
    case bottomLeading
    case bottomTrailing

    var isTop: Bool {
        switch self {
        case .top, .topLeading, .topTrailing: return true
        case .bottom, .bottomLeading, .bottomTrailing: return false
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .top, .bottom: return .center
        case .topLeading, .bottomLeading: return .leading
        case .topTrailing, .bottomTrailing: return .trailing
        }
    }

    var alignment: Alignment {
        Alignment(horizontal: horizontalAlignment, vertical: isTop ? .top : .bottom)
    }

    var defaultTransition: AnyTransition {
        .move(edge: isTop ? .top : .bottom).combined(with: .opacity)
    }
}
