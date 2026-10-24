//
//  SplitNavigationSupportView.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
struct SplitNavigationSupportView<Detail: View>: View {
    @EnvironmentObject private var viewModel: RouterViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    let sidebar: AnyView
    let router: AnyRouter
    let columnVisibility: Binding<NavigationSplitViewVisibility>?
    let emptyDetail: (AnyRouter) -> Detail

    @State private var localColumnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var navigationState = SplitNavigationState()

    private var destinations: [AnyDestination] { viewModel.splitViewDestinations }
    private var modelBranch: [String] { destinations.map(\.id) }

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #elseif os(watchOS) || os(tvOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: columnVisibility ?? $localColumnVisibility,
            preferredCompactColumn: Binding(
                get: { preferredCompactColumn },
                set: { column in
                    // This setter represents native column navigation, not our model-to-UI updates.
                    if column == .sidebar, isCompact,
                       navigationState.canClearSelection(modelBranch: modelBranch) {
                        viewModel.dismissPushStack(routeId: router.id, animates: true)
                        synchronize()
                    } else if modelBranch.isEmpty || column == .detail || !isCompact {
                        preferredCompactColumn = column
                    }
                }
            )
        ) {
            sidebar
                .resizeableSheetBackgroundModifier(viewModel: viewModel, routerId: router.id)
        } detail: {
            NavigationStack(path: Binding(
                get: { navigationState.path },
                set: { newPath in
                    if let target = navigationState.popTarget(for: newPath, modelBranch: modelBranch) {
                        viewModel.dismissScreens(to: target, animates: true)
                        synchronize()
                    }
                }
            )) {
                Group {
                    if let selected = destinations.first {
                        selected.destination
                    } else {
                        emptyDetail(router)
                    }
                }
                .navigationDestination(for: String.self) { routeID in
                    if let destination = destinations.first(where: { $0.id == routeID })
                        ?? viewModel.allDestinationsById[routeID] {
                        destination.destination
                    }
                }
            }
        }
        .onAppear { synchronize() }
        .onChange(of: modelBranch) { _, _ in synchronize() }
        #if os(iOS)
        .onChange(of: horizontalSizeClass) { _, _ in
            navigationState.layoutDidChange()
        }
        #endif
    }

    private func synchronize() {
        let branch = modelBranch
        let selectionChanged = navigationState.branch.first != branch.first
        navigationState.synchronize(with: branch)
        if branch.isEmpty {
            preferredCompactColumn = .sidebar
        } else if selectionChanged {
            preferredCompactColumn = .detail
        }
    }
}
