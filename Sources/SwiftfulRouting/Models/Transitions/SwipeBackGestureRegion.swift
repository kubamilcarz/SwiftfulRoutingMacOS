//
//  SwipeBackGestureRegion.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// Local content geometry, excluding system controls, hardware, and active folds.
struct SwipeBackGestureRegion: Equatable {
    var bounds: CGRect
    var exclusions: [CGRect] = []

    func contains(_ point: CGPoint, for transition: TransitionOption, layoutDirection: LayoutDirection) -> Bool {
        guard bounds.contains(point), !exclusions.contains(where: { $0.contains(point) }) else { return false }
        let edge: CGRect
        switch transition {
        case .trailing, .leading:
            let width = min(24, bounds.width)
            let isLeading = transition.reversed.asAlignment == .leading
            let isLeft = isLeading == (layoutDirection == .leftToRight)
            edge = CGRect(x: isLeft ? bounds.minX : bounds.maxX - width,
                          y: bounds.minY, width: width, height: bounds.height)
        case .top:
            let height = min(30, bounds.height)
            edge = CGRect(x: bounds.minX, y: bounds.maxY - height, width: bounds.width, height: height)
        case .bottom:
            edge = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: min(30, bounds.height))
        case .identity:
            return false
        }
        return edge.contains(point)
    }

    static func offset(for translation: CGSize, transition: TransitionOption, layoutDirection: LayoutDirection) -> CGSize {
        switch transition {
        case .trailing, .leading:
            guard abs(translation.width) > abs(translation.height) else { return .zero }
            let isTrailing = transition.asAlignment == .trailing
            let movesRight = isTrailing == (layoutDirection == .leftToRight)
            return CGSize(width: movesRight ? max(translation.width, 0) : min(translation.width, 0), height: 0)
        case .top:
            guard abs(translation.height) > abs(translation.width) else { return .zero }
            return CGSize(width: 0, height: min(translation.height, 0))
        case .bottom:
            guard abs(translation.height) > abs(translation.width) else { return .zero }
            return CGSize(width: 0, height: max(translation.height, 0))
        case .identity:
            return .zero
        }
    }
}
