//
//  ToastSupportView.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

struct ToastSupportView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let presentations: [ToastPresentation]

    var body: some View {
        ZStack {
            ForEach(ToastPosition.allCases, id: \.self) { position in
                VStack(alignment: position.horizontalAlignment, spacing: 8) {
                    ForEach(orderedPresentations(at: position)) { presentation in
                        presentation.toast.destination
                            .transition(transition(for: presentation.toast))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
            }
        }
        .transaction { transaction in
            if reduceMotion, transaction.animation != nil {
                transaction.animation = .easeInOut(duration: 0.2)
            }
        }
    }

    private func orderedPresentations(at position: ToastPosition) -> [ToastPresentation] {
        let items = presentations.filter { $0.toast.position == position }
        return position.isTop ? Array(items.reversed()) : items
    }

    private func transition(for toast: AnyToast) -> AnyTransition {
        reduceMotion ? .opacity : toast.transition
    }
}
