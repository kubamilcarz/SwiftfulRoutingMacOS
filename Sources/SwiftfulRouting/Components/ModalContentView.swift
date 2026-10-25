//
//  ModalContentView.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

struct ModalContentView: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let modal: AnyModal

    var body: some View {
        switch modal.placement {
        case .overlay:
            if modal.ignoreSafeArea {
                modal.destination
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: modal.alignment)
                    .ignoresSafeArea()
            } else {
                modal.destination
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: modal.alignment)
            }
        case .adaptive:
            GeometryReader { proxy in
                let frame = availableFrame(in: proxy)
                // Region frames use physical coordinates. Keep positioning in that
                // coordinate system while preserving the content's language direction.
                ZStack {
                    modal.destination
                        .environment(\.layoutDirection, layoutDirection)
                        .frame(width: frame.width, height: frame.height, alignment: physicalAlignment)
                        .clipped()
                        .position(x: frame.midX, y: frame.midY)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
    }

    private var physicalAlignment: Alignment {
        guard layoutDirection == .rightToLeft else { return modal.alignment }
        let horizontal = modal.alignment.horizontal
        return Alignment(
            horizontal: horizontal == .leading ? .trailing : horizontal == .trailing ? .leading : horizontal,
            vertical: modal.alignment.vertical
        )
    }

    private func availableFrame(in proxy: GeometryProxy) -> CGRect {
        var divisions: [CGRect] = []
        var occlusions: [CGRect] = []
        // Xcode 27.1's compiler and SDK introduce reserved-region queries.
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27.1, *) {
            divisions = proxy.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
                .filter(\.isActive).map(\.frame)
            occlusions = proxy.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)
                .filter(\.isActive).map(\.frame)
        }
        #endif
        return ModalAdaptiveLayout.frame(
            size: proxy.size,
            safeAreaInsets: proxy.safeAreaInsets,
            divisions: divisions,
            occlusions: occlusions,
            alignment: modal.alignment,
            layoutDirection: layoutDirection
        )
    }
}
