//
//  SplitSelectionProbe.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if os(macOS)
import SwiftUI
@testable import SwiftfulRouting

@available(macOS 14, *)
struct SplitSelectionProbe: View {
    @Environment(\.router) private var router
    let selectionChanged: (String?) -> Void

    var body: some View {
        Text(router.selectedSplitViewDetailID ?? "No selection")
            .onChange(of: router.selectedSplitViewDetailID) { _, selection in
                selectionChanged(selection)
            }
    }
}
#endif
