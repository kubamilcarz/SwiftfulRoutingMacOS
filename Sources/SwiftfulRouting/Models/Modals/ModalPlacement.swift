//
//  ModalPlacement.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

/// Controls the area used to position custom modal content. Backgrounds always fill the host.
public enum ModalPlacement: Equatable {
    /// Uses the whole host and the modal's `ignoreSafeArea` setting (the existing behavior).
    case overlay

    /// Respects safe areas and, on iOS 27.1+, avoids active folds and occlusions.
    /// Alignment chooses a side of the fold. Centered content prefers the trailing
    /// side of a vertical fold and the upper side of a horizontal fold.
    /// Content must fit the available region; overflowing content is clipped.
    /// This placement takes precedence over `ignoreSafeArea`.
    case adaptive
}
