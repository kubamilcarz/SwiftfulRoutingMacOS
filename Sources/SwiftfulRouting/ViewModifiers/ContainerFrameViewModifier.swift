//
//  ContainerFrameViewModifier.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// Measures without changing the content's proposed or ideal size.
struct ContainerFrameViewModifier: ViewModifier {
    @Binding var frame: CGRect

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { update(size: proxy.size) }
                    .onChange(of: proxy.size) { size in update(size: size) }
            }
        }
    }

    private func update(size: CGSize) {
        let measuredFrame = CGRect(origin: .zero, size: size)
        if frame != measuredFrame {
            frame = measuredFrame
        }
    }
}
