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
    @State private var detailPath: [String] = []
    @State private var isSidebarVisible = false

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
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebar
                .resizeableSheetBackgroundModifier(viewModel: viewModel, routerId: router.id)
                .onAppear {
                    isSidebarVisible = true
                    clearSelectionFromSidebarIfNeeded()
                }
                .onDisappear {
                    isSidebarVisible = false
                    if isCompact, preferredCompactColumn == .detail {
                        navigationState.layoutDidSettle()
                        reconcileDetailPath()
                    }
                }
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let selected = destinations.first {
                        selected.destination
                            .id(selected.presentationID)
                            .onAppear { didPresent(routeID: selected.id) }
                    } else {
                        emptyDetail(router)
                    }
                }
                .navigationDestination(for: String.self) { routeID in
                    if let destination = destinations.first(where: { $0.id == routeID })
                        ?? viewModel.allDestinationsById[routeID] {
                        destination.destination
                            .onAppear { didPresent(routeID: routeID) }
                    }
                }
            }
        }
        .onAppear { synchronize() }
        .onChange(of: modelBranch) { _, _ in synchronize() }
        .onChange(of: detailPath) { _, _ in reconcileDetailPath() }
        .onChange(of: navigationState.isChangingLayout) { _, changing in
            if !changing {
                clearSelectionFromSidebarIfNeeded()
            }
        }
        .onChange(of: preferredCompactColumn) { _, column in
            if column == .sidebar {
                clearSelectionFromSidebarIfNeeded()
            }
        }
        #if os(iOS)
        .onChange(of: horizontalSizeClass) { _, _ in
            navigationState.layoutDidChange()
            // Reparenting columns may briefly prefer the sidebar. Keep the selected
            // column until its appearance (or the sidebar disappearing) settles layout.
            if !modelBranch.isEmpty {
                preferredCompactColumn = .detail
            }
        }
        #endif
    }

    private func didPresent(routeID: String) {
        if navigationState.branch != modelBranch {
            synchronize()
        }
        navigationState.didPresent(routeID: routeID)
        reconcileDetailPath()
    }

    private func reconcileDetailPath() {
        guard viewModel.navigationSplitView else { return }
        if let target = navigationState.popTarget(for: detailPath, modelBranch: modelBranch) {
            viewModel.dismissScreens(to: target, animates: true)
            synchronize()
        } else if !navigationState.isChangingLayout, detailPath != navigationState.path {
            detailPath = navigationState.path
        }
    }

    private func clearSelectionFromSidebarIfNeeded() {
        // Popping detail history can also update the preferred column. Only an actually
        // visible sidebar represents returning across columns, and layout callbacks must settle first.
        Task { @MainActor in
            await Task.yield()
            guard viewModel.navigationSplitView, isCompact, isSidebarVisible, preferredCompactColumn == .sidebar,
                  navigationState.canClearSelection(modelBranch: modelBranch) else { return }
            viewModel.dismissPushStack(routeId: router.id, animates: true)
            synchronize()
        }
    }

    private func synchronize() {
        let branch = modelBranch
        let selectionChanged = navigationState.branch.first != branch.first
        navigationState.synchronize(with: branch)
        if detailPath != navigationState.path {
            detailPath = navigationState.path
        }
        if branch.isEmpty {
            if preferredCompactColumn != .sidebar {
                preferredCompactColumn = .sidebar
            }
        } else if selectionChanged, preferredCompactColumn != .detail {
            preferredCompactColumn = .detail
        }
    }
}
