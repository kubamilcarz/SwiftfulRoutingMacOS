//
//  ToastHostingProbe.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if os(macOS) && canImport(Testing)
import SwiftUI

struct ToastHostingProbe: View {
    @State private var token = UUID()
    let id: String
    let onFrame: (CGRect) -> Void
    let onAppear: (UUID) -> Void

    var body: some View {
        Text(id)
            .frame(width: 80, height: 32)
            .onAppear { onAppear(token) }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("toast-test"))
            } action: { frame in
                onFrame(frame)
            }
    }
}
#endif
