//
//  ModalAdaptiveLayout.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// Pure geometry so reserved-region behavior can be verified without physical hardware.
enum ModalAdaptiveLayout {
    static func frame(
        size: CGSize,
        safeAreaInsets: EdgeInsets,
        divisions: [CGRect],
        occlusions: [CGRect],
        alignment: Alignment,
        layoutDirection: LayoutDirection
    ) -> CGRect {
        let isRTL = layoutDirection == .rightToLeft
        let left = max(0, isRTL ? safeAreaInsets.trailing : safeAreaInsets.leading)
        let right = max(0, isRTL ? safeAreaInsets.leading : safeAreaInsets.trailing)
        var region = CGRect(
            x: min(left, size.width), y: min(max(0, safeAreaInsets.top), size.height),
            width: max(0, size.width - left - right),
            height: max(0, size.height - max(0, safeAreaInsets.top) - max(0, safeAreaInsets.bottom))
        )

        for division in divisions {
            let intersection = region.intersection(division)
            guard !intersection.isNull, !intersection.isEmpty else { continue }
            let first: CGRect
            let second: CGRect
            let prefersSecond: Bool
            if division.height > division.width {
                first = CGRect(x: region.minX, y: region.minY,
                               width: intersection.minX - region.minX, height: region.height)
                second = CGRect(x: intersection.maxX, y: region.minY,
                                width: region.maxX - intersection.maxX, height: region.height)
                prefersSecond = alignment.horizontal == .leading ? isRTL : !isRTL
            } else {
                first = CGRect(x: region.minX, y: region.minY,
                               width: region.width, height: intersection.minY - region.minY)
                second = CGRect(x: region.minX, y: intersection.maxY,
                                width: region.width, height: region.maxY - intersection.maxY)
                prefersSecond = alignment.vertical == .bottom
            }
            let preferred = prefersSecond ? second : first
            let other = prefersSecond ? first : second
            region = preferred.isEmpty ? other : preferred
        }

        // Preserve the largest available rectangle around cameras or other occlusions.
        // Region frames already include the system's margins; don't add them twice.
        var candidates = [region]
        for occlusion in occlusions {
            candidates = candidates.flatMap { subtract(occlusion, from: $0) }
        }
        return candidates.max { $0.width * $0.height < $1.width * $1.height }
            ?? CGRect(origin: region.origin, size: .zero)
    }

    private static func subtract(_ occlusion: CGRect, from region: CGRect) -> [CGRect] {
        let intersection = region.intersection(occlusion)
        guard !intersection.isNull, !intersection.isEmpty else { return [region] }
        return [
            CGRect(x: region.minX, y: region.minY,
                   width: region.width, height: intersection.minY - region.minY),
            CGRect(x: region.minX, y: intersection.maxY,
                   width: region.width, height: region.maxY - intersection.maxY),
            CGRect(x: region.minX, y: region.minY,
                   width: intersection.minX - region.minX, height: region.height),
            CGRect(x: intersection.maxX, y: region.minY,
                   width: region.maxX - intersection.maxX, height: region.height)
        ].filter { !$0.isEmpty }
    }
}
