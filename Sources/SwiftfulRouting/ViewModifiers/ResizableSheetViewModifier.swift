//
//  ResizableSheetViewModifier.swift
//  SwiftfulRouting
//
//  Created by Nick Sarno on 4/19/25.
//
import SwiftUI

/// Wrapper view that uses @Binding to maintain reactive connection to selection binding
private struct ResizableSheetContentWrapper<Content: View>: View {
    let content: Content
    let config: ResizableSheetConfig
    @Binding var selection: PresentationDetentTransformable

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            content
                .presentationDetents(config.detents.setMap({ $0.asPresentationDetent }), selection: Binding(selection: $selection))
                .presentationDragIndicator(config.dragIndicator)
                .applyEnvironmentBackgroundIfAvailable(option: config.background)
                .ifLetCondition(config.cornerRadius, transform: { content, value in
                    content.presentationCornerRadiusIfAvailable(value)
                })
                .presentationBackgroundInteractionIfAvailable(config.backgroundInteraction)
                .presentationContentInteractionIfAvailable(config.contentInteraction)
        } else {
            content
        }
    }
}

extension View {

    @ViewBuilder func applyResizableSheetModifiersIfNeeded(segue: SegueOption) -> some View {
        switch segue {
        case .push:
            self
        case .sheetConfig(config: let config):
            if let selection = config.selection {
                ResizableSheetContentWrapper(content: self, config: config, selection: selection)
            } else {
                if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
                    self
                        .presentationDetents(config.detents.setMap({ $0.asPresentationDetent }))
                        .presentationDragIndicator(config.dragIndicator)
                        .applyEnvironmentBackgroundIfAvailable(option: config.background)
                        .ifLetCondition(config.cornerRadius, transform: { content, value in
                            content.presentationCornerRadiusIfAvailable(value)
                        })
                        .presentationBackgroundInteractionIfAvailable(config.backgroundInteraction)
                        .presentationContentInteractionIfAvailable(config.contentInteraction)
                } else {
                    self
                }
            }
        case .fullScreenCoverConfig(config: let config):
            self
                // Add background color if needed
                .applyEnvironmentBackgroundIfAvailable(option: config.background)
        }
    }

}

extension View {
    
    @ViewBuilder
    func presentationCornerRadiusIfAvailable(_ value: CGFloat) -> some View {
        if #available(iOS 16.4, macOS 13.3, tvOS 16.4, *) {
            self.presentationCornerRadius(value)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func presentationBackgroundInteractionIfAvailable(_ interaction: PresentationBackgroundInteractionBackSupport) -> some View {
        if #available(iOS 16.4, macOS 13.3, tvOS 16.4, *) {
            self.presentationBackgroundInteraction(interaction.backgroundInteraction)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func presentationContentInteractionIfAvailable(_ interaction: PresentationContentInteractionBackSupport) -> some View {
        if #available(iOS 16.4, macOS 13.3, tvOS 16.4, *) {
            self.presentationContentInteraction(interaction.contentInteraction)
        } else {
            self
        }
    }
}
