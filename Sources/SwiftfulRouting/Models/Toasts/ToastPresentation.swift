//
//  ToastPresentation.swift
//  SwiftfulRouting
//
//  Created by Kuba Milcarz on 25/10/2026.
//  Copyright © 2026 Kuba Milcarz. All rights reserved.
//

import SwiftUI

/// Identity belongs to a presentation, independently of its reusable public toast ID.
struct ToastPresentation: Identifiable {
    let id = UUID()
    let toast: AnyToast
}
