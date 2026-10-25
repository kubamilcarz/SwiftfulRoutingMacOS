//
//  ModalAdaptiveLayoutTests.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if canImport(Testing)
import SwiftUI
import Testing
@testable import SwiftfulRouting

struct ModalAdaptiveLayoutTests {
    @Test(arguments: [
        (Alignment.center, LayoutDirection.leftToRight, CGRect(x: 410, y: 0, width: 390, height: 600)),
        (.leading, .leftToRight, CGRect(x: 0, y: 0, width: 390, height: 600)),
        (.trailing, .leftToRight, CGRect(x: 410, y: 0, width: 390, height: 600)),
        (.center, .rightToLeft, CGRect(x: 0, y: 0, width: 390, height: 600)),
        (.leading, .rightToLeft, CGRect(x: 410, y: 0, width: 390, height: 600)),
        (.trailing, .rightToLeft, CGRect(x: 0, y: 0, width: 390, height: 600))
    ])
    func verticalFold(alignment: Alignment, direction: LayoutDirection, expected: CGRect) {
        let frame = ModalAdaptiveLayout.frame(
            size: CGSize(width: 800, height: 600), safeAreaInsets: EdgeInsets(),
            divisions: [CGRect(x: 390, y: 0, width: 20, height: 600)], occlusions: [],
            alignment: alignment, layoutDirection: direction
        )
        #expect(frame == expected)
    }

    @Test(arguments: [
        (Alignment.center, CGRect(x: 0, y: 0, width: 600, height: 390)),
        (.top, CGRect(x: 0, y: 0, width: 600, height: 390)),
        (.bottom, CGRect(x: 0, y: 410, width: 600, height: 390))
    ])
    func horizontalFold(alignment: Alignment, expected: CGRect) {
        let frame = ModalAdaptiveLayout.frame(
            size: CGSize(width: 600, height: 800), safeAreaInsets: EdgeInsets(),
            divisions: [CGRect(x: 0, y: 390, width: 600, height: 20)], occlusions: [],
            alignment: alignment, layoutDirection: .leftToRight
        )
        #expect(frame == expected)
    }

    @Test(arguments: [
        (LayoutDirection.leftToRight, CGRect(x: 20, y: 10, width: 730, height: 560)),
        (.rightToLeft, CGRect(x: 50, y: 10, width: 730, height: 560))
    ])
    func noFoldRespectsAsymmetricSafeAreas(direction: LayoutDirection, expected: CGRect) {
        let frame = ModalAdaptiveLayout.frame(
            size: CGSize(width: 800, height: 600),
            safeAreaInsets: EdgeInsets(top: 10, leading: 20, bottom: 30, trailing: 50),
            divisions: [], occlusions: [], alignment: .center, layoutDirection: direction
        )
        #expect(frame == expected)
    }

    @Test func cameraOcclusionIsAvoidedWithinSelectedSide() {
        let camera = CGRect(x: 740, y: -20, width: 80, height: 100)
        let frame = ModalAdaptiveLayout.frame(
            size: CGSize(width: 800, height: 600), safeAreaInsets: EdgeInsets(),
            divisions: [CGRect(x: 390, y: 0, width: 20, height: 600)],
            occlusions: [camera], alignment: .center, layoutDirection: .leftToRight
        )
        #expect(frame == CGRect(x: 410, y: 80, width: 390, height: 520))
        #expect(frame.intersection(camera).isEmpty)
    }

    @Test func nonIntersectingAndZeroWidthRegionsLeaveLayoutUnchanged() {
        let frame = ModalAdaptiveLayout.frame(
            size: CGSize(width: 300, height: 500), safeAreaInsets: EdgeInsets(),
            divisions: [CGRect(x: 150, y: 0, width: 0, height: 500),
                        CGRect(x: 400, y: 0, width: 20, height: 500)],
            occlusions: [CGRect(x: -100, y: 0, width: 30, height: 30)],
            alignment: .center, layoutDirection: .leftToRight
        )
        #expect(frame == CGRect(x: 0, y: 0, width: 300, height: 500))
    }

    @Test func fullyOccludedAreaDoesNotProduceNegativeDimensions() {
        let frame = ModalAdaptiveLayout.frame(
            size: CGSize(width: 100, height: 100), safeAreaInsets: EdgeInsets(),
            divisions: [], occlusions: [CGRect(x: -10, y: -10, width: 120, height: 120)],
            alignment: .center, layoutDirection: .leftToRight
        )
        #expect(frame == .zero)
    }

    @Test @MainActor func modalPlacementDefaultsToExistingBehaviorAndAllowsOptIn() {
        let defaultModal = AnyModal { Text("Default") }
        #expect(defaultModal.placement == .overlay)
        #expect(defaultModal.ignoreSafeArea)

        let modal = AnyModal(placement: .adaptive) { Text("Adaptive") }
        #expect(modal.placement == .adaptive)
        #expect(modal.ignoreSafeArea)
    }
}
#endif
