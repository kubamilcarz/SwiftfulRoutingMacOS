//
//  SplitNavigationState.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 24/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import Foundation

/// Synchronizes a split column's UI history without treating layout callbacks as user pops.
struct SplitNavigationState {
    private(set) var branch: [String] = []
    private(set) var path: [String] = []
    private var growthGuard: (sourcePath: [String], createdAt: Date)?
    private(set) var isChangingLayout = false
    private var presentedRouteID: String?

    mutating func layoutDidChange() {
        isChangingLayout = true
        presentedRouteID = nil
    }

    mutating func layoutDidSettle() {
        isChangingLayout = false
    }

    mutating func didPresent(routeID: String) {
        presentedRouteID = routeID
        if branch.last == routeID {
            growthGuard = nil
            layoutDidSettle()
        }
    }

    mutating func synchronize(with modelBranch: [String], now: Date = Date()) {
        guard branch != modelBranch else { return }
        if branch.first != modelBranch.first || modelBranch.count > branch.count {
            growthGuard = (sourcePath: modelBranch, createdAt: now)
        } else {
            growthGuard = nil
        }
        branch = modelBranch
        path = Array(modelBranch.dropFirst())
        isChangingLayout = false
        presentedRouteID = nil
    }

    /// A valid detail pop always retains the selected route, even when its history becomes empty.
    func popTarget(for newPath: [String], modelBranch: [String], now: Date = Date()) -> String? {
        let target = newPath.last ?? branch.first
        // A destination appearing at the shortened path confirms a real pop, including
        // one made before the column transition has finished. Layout writes alone do not.
        guard (!isChangingLayout || presentedRouteID == target), branch == modelBranch,
              let selectedID = branch.first,
              isStrictPrefixPath(newPath, of: path),
              !shouldIgnoreTransientPrefixShrink(
                activePath: branch,
                newPath: [selectedID] + newPath,
                guardValue: growthGuard,
                now: now
              ) else { return nil }
        return newPath.last ?? selectedID
    }

    func canClearSelection(modelBranch: [String]) -> Bool {
        !isChangingLayout && branch == modelBranch && !branch.isEmpty && path.isEmpty
    }
}
