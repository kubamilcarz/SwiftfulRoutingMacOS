#if os(macOS)
import SwiftUI
import SwiftfulRouting

/// Reads only the public router environment, without subscribing to the routing model.
@available(macOS 14, *)
struct ToastStateProbe: View {
    @Environment(\.router) private var router
    let onUpdate: ([AnyToast], Bool) -> Void

    var body: some View {
        Text(router.hasActiveToast ? "Toast shown" : "No toast")
            .onAppear { onUpdate(router.activeToasts, router.hasActiveToast) }
            .onChange(of: router.activeToasts.map(\.duration)) {
                onUpdate(router.activeToasts, router.hasActiveToast)
            }
    }
}
#endif
