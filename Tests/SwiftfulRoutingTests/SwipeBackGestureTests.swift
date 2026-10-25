//
//  SwipeBackGestureTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if canImport(Testing)
import SwiftUI
import Testing
@testable import SwiftfulRouting

struct SwipeBackGestureTests {
    @Test(arguments: [
        (TransitionOption.trailing(), LayoutDirection.leftToRight, CGPoint(x: 21, y: 50), CGSize(width: 50, height: 2)),
        (.leading(), .leftToRight, CGPoint(x: 379, y: 50), CGSize(width: -50, height: 2)),
        (.trailing(), .rightToLeft, CGPoint(x: 379, y: 50), CGSize(width: -50, height: 2)),
        (.leading(), .rightToLeft, CGPoint(x: 21, y: 50), CGSize(width: 50, height: 2)),
        (.top(), .leftToRight, CGPoint(x: 200, y: 749), CGSize(width: 2, height: -50)),
        (.bottom(), .leftToRight, CGPoint(x: 200, y: 41), CGSize(width: 2, height: 50))
    ])
    func directionalEdge(transition: TransitionOption, direction: LayoutDirection, start: CGPoint, translation: CGSize) {
        let region = SwipeBackGestureRegion(bounds: CGRect(x: 20, y: 40, width: 360, height: 710))
        #expect(region.contains(start, for: transition, layoutDirection: direction))
        #expect(!region.contains(CGPoint(x: 200, y: 400), for: transition, layoutDirection: direction))
        let offset = SwipeBackGestureRegion.offset(for: translation, transition: transition, layoutDirection: direction)
        #expect(max(abs(offset.width), abs(offset.height)) == 50)
    }

    @Test func horizontalAndVerticalBarsAreOutsideTheGestureRegion() {
        let region = SwipeBackGestureRegion(bounds: CGRect(x: 72, y: 44, width: 600, height: 400))
        #expect(!region.contains(CGPoint(x: 10, y: 200), for: .trailing(), layoutDirection: .leftToRight))
        #expect(!region.contains(CGPoint(x: 75, y: 20), for: .trailing(), layoutDirection: .leftToRight))
        // Content near the top is available; no hardcoded 60-point exclusion remains.
        #expect(region.contains(CGPoint(x: 75, y: 45), for: .trailing(), layoutDirection: .leftToRight))
    }

    @Test func reservedRegionsCannotStartASwipe() {
        let region = SwipeBackGestureRegion(
            bounds: CGRect(x: 0, y: 0, width: 600, height: 400),
            exclusions: [CGRect(x: 0, y: 190, width: 600, height: 20),
                         CGRect(x: 0, y: 0, width: 40, height: 40)]
        )
        #expect(!region.contains(CGPoint(x: 10, y: 200), for: .trailing(), layoutDirection: .leftToRight))
        #expect(!region.contains(CGPoint(x: 10, y: 10), for: .trailing(), layoutDirection: .leftToRight))
        #expect(region.contains(CGPoint(x: 10, y: 100), for: .trailing(), layoutDirection: .leftToRight))
    }

    @Test func resizedHostMovesTheTrailingEdge() {
        var region = SwipeBackGestureRegion(bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(region.contains(CGPoint(x: 790, y: 200), for: .leading(), layoutDirection: .leftToRight))
        region.bounds.size = CGSize(width: 300, height: 500)
        #expect(!region.contains(CGPoint(x: 790, y: 200), for: .leading(), layoutDirection: .leftToRight))
        #expect(region.contains(CGPoint(x: 290, y: 200), for: .leading(), layoutDirection: .leftToRight))
    }

    @Test(arguments: [CGSize(width: -80, height: 1), CGSize(width: 5, height: 80), .zero])
    func wrongDirectionOrScrollingDoesNotMoveContent(translation: CGSize) {
        #expect(SwipeBackGestureRegion.offset(for: translation, transition: .trailing(), layoutDirection: .leftToRight) == .zero)
    }

    @Test func identityHasNoSwipeRegion() {
        let region = SwipeBackGestureRegion(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
        #expect(!region.contains(CGPoint(x: 1, y: 100), for: .identity, layoutDirection: .leftToRight))
    }
}
#endif
