//
//  ToastTestButton.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

#if os(macOS) && canImport(Testing)
import AppKit
import SwiftUI

/// Native control lets hosting tests inspect the actual view selected by hit testing.
struct ToastTestButton: NSViewRepresentable {
    let id: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: id, target: context.coordinator, action: #selector(Coordinator.press))
        button.identifier = NSUserInterfaceItemIdentifier(id)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func press() { action() }
    }
}
#endif
