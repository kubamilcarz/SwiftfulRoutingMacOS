//
//  SplitViewConfiguration.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// Erases the container so existing RouterView initializers retain their original availability.
struct SplitViewConfiguration {
    let makeContainer: @MainActor (AnyView, AnyRouter) -> AnyView

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    init<Detail: View>(
        columnVisibility: Binding<NavigationSplitViewVisibility>?,
        emptyDetail: @escaping (AnyRouter) -> Detail
    ) {
        makeContainer = { sidebar, router in
            AnyView(SplitNavigationSupportView(
                sidebar: sidebar,
                router: router,
                columnVisibility: columnVisibility,
                emptyDetail: emptyDetail
            ))
        }
    }
}
