//
//  ModuleSupportView.swift
//  SwiftfulRouting
//
//  Created by Nick Sarno on 4/19/25.
//
import Foundation
import SwiftUI
import SwiftfulRecursiveUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ModuleSupportView<Content:View>: View {
    
    @StateObject private var viewModel = ModuleViewModel()

    var rootRouterInfo: (id: String, transitionBehavior: TransitionMemoryBehavior)?
    let addNavigationStack: Bool
    
    @ViewBuilder var content: (AnyRouter) -> Content

    @State private var viewFrame: CGRect = {
        #if canImport(UIKit)
        UIScreen.main.bounds
        #elseif canImport(AppKit)
        NSScreen.main?.frame ?? .zero
        #else
        .zero
        #endif
    }()

    var body: some View {
        ZStack {
            LazyZStack(allowSimultaneous: false, selection: viewModel.modules.last, items: viewModel.modules) { data in
                let dataIndex: Double = Double(viewModel.modules.firstIndex(where: { $0.id == data.id }) ?? 99)

                return Group {
                    if data == viewModel.modules.first {
                        RouterViewModelWrapper {
                            RouterViewInternal(
                                routerId: RouterViewModel.rootId,
                                rootRouterInfo: rootRouterInfo,
                                addNavigationStack: addNavigationStack,
                                content: content
                            )
                        }
                    } else {
                        RouterViewModelWrapper {
                            RouterViewInternal(
                                routerId: RouterViewModel.rootId,
                                rootRouterInfo: rootRouterInfo,
                                addNavigationStack: false,
                                content: { router in
                                    AnyView(data.destination(router))
                                }
                            )
                        }
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: viewModel.currentTransition.insertion,
                        removal: .customRemoval(
                            behavior: .removePrevious,
                            direction: viewModel.currentTransition.reversed,
                            frame: viewFrame
                        )
                    )
                )
                .zIndex(dataIndex)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transactionAnimationIfAvailable(
            value: (viewModel.modules.last?.id ?? "") + viewModel.currentTransition.id,
            transition: viewModel.currentTransition
        )
        .environmentObject(viewModel)
        
        #if DEBUG
        .onChange(of: viewModel.modules) { newValue in
            viewModel.printModuleStack(modules: newValue)
        }
        #endif
    }
}
