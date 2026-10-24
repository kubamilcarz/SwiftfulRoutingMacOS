//
//  RouterView.swift
//  SwiftfulRouting
//
//  Created by Nick Sarno on 4/19/25.
//
import SwiftUI

/// A SwiftUI view that injects a router system into the environment, enabling navigation and routing for all child views.
/// Use this in place of a `NavigationStack` as the root of your view hierarchy.
///
/// Example usage:
/// ```swift
/// RouterView { router in
///     MyView(router: router)
/// }
///
/// ```
/// The returned router is also added to the child Environment, so you don't have to pass it manually:
/// ```swift
/// RouterView { _ in
///     MyView()
/// }
/// ```
///
/// - Parameters:
///   - id: Identifier for analytics for the first screen.
///   - addNavigationStack: Whether to wrap the root content in a `NavigationStack`. Defaults to `true`.
///   - addModuleSupport: Enables showModule methods for this view heirarchy.
///   - content: A closure that provides the root content view, receiving an `AnyRouter` instance for navigation control.
public struct RouterView<Content: View>: View {
    
    let id: String
    let addNavigationStack: Bool
    let addModuleSupport: Bool
    let transitionBehavior: TransitionMemoryBehavior
    var splitViewConfiguration: SplitViewConfiguration? = nil
    @ViewBuilder var content: (AnyRouter) -> Content
    
    public init(
        id: String? = nil,
        addNavigationStack: Bool = true,
        addModuleSupport: Bool = false,
        transitionBehavior: TransitionMemoryBehavior = .keepPrevious,
        content: @escaping (AnyRouter) -> Content
    ) {
        
        // Validate that ID is provided when module support is enabled
        if addModuleSupport && id == nil {
            let string = "🚨 RouterView: parameter ID is required when addModuleSupport is TRUE."
            assertionFailure(string)
            
            #if DEBUG
            print(string)
            #endif
        }
        
        self.id = id ?? RouterViewModel.rootId
        self.addNavigationStack = addNavigationStack
        self.addModuleSupport = addModuleSupport
        self.transitionBehavior = transitionBehavior
        self.content = content
    }

    /// Uses root content as a sidebar and adapts pushes into detail selection and navigation.
    /// Split mode takes precedence over `addNavigationStack`.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    public init(
        id: String? = nil,
        navigationSplitView: Bool,
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
        addNavigationStack: Bool = true,
        addModuleSupport: Bool = false,
        transitionBehavior: TransitionMemoryBehavior = .keepPrevious,
        @ViewBuilder content: @escaping (AnyRouter) -> Content
    ) {
        self.init(
            id: id,
            navigationSplitView: navigationSplitView,
            columnVisibility: columnVisibility,
            addNavigationStack: addNavigationStack,
            addModuleSupport: addModuleSupport,
            transitionBehavior: transitionBehavior,
            content: content,
            emptyDetail: { _ in Text("Select an item") }
        )
    }

    /// Provides custom content for the detail column when no route is selected.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    public init<Detail: View>(
        id: String? = nil,
        navigationSplitView: Bool,
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
        addNavigationStack: Bool = true,
        addModuleSupport: Bool = false,
        transitionBehavior: TransitionMemoryBehavior = .keepPrevious,
        @ViewBuilder content: @escaping (AnyRouter) -> Content,
        @ViewBuilder emptyDetail: @escaping (AnyRouter) -> Detail
    ) {
        self.init(
            id: id,
            addNavigationStack: addNavigationStack,
            addModuleSupport: addModuleSupport,
            transitionBehavior: transitionBehavior,
            content: content
        )
        if navigationSplitView {
            splitViewConfiguration = SplitViewConfiguration(
                columnVisibility: columnVisibility,
                emptyDetail: emptyDetail
            )
        }
    }

    public var body: some View {
        Group {
            if addModuleSupport {
                ModuleSupportView(
                    rootRouterInfo: (id, transitionBehavior),
                    addNavigationStack: addNavigationStack,
                    splitViewConfiguration: splitViewConfiguration,
                    content: content
                )
            } else {
                RouterViewModelWrapper(navigationSplitView: splitViewConfiguration != nil) {
                    RouterViewInternal(
                        routerId: RouterViewModel.rootId,
                        rootRouterInfo: (id, transitionBehavior),
                        addNavigationStack: addNavigationStack,
                        splitViewConfiguration: splitViewConfiguration,
                        content: content
                    )
                }
            }
        }
    }
}

struct RouterViewModelWrapper<Content: View>: View {
    
    @StateObject private var viewModel: RouterViewModel
    @ViewBuilder var content: Content

    init(navigationSplitView: Bool = false, @ViewBuilder content: () -> Content) {
        _viewModel = StateObject(wrappedValue: RouterViewModel(navigationSplitView: navigationSplitView))
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(viewModel)

            #if DEBUG
            .onChange(of: viewModel.activeScreenStacks) { newValue in
                viewModel.printScreenStack(screenStack: newValue)
            }
            .onChange(of: viewModel.availableScreenQueue) { newValue in
                viewModel.printScreenQueue(screenQueue: newValue)
            }
            #endif
    }
}
