//
//  SwipeBackSupportContainer.swift
//  SwiftfulRouting
//
//  Created by Nicholas Sarno on 2/27/24.
//
import SwiftUI

struct SwipeBackSupportContainer<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @GestureState private var dragOffset: CGSize = .zero
    @State private var gestureRegion = SwipeBackGestureRegion(bounds: .zero)

    var insertionTransition: TransitionOption = .trailing()
    var swipeThreshold: CGFloat = 30
    @ViewBuilder var content: () -> Content
    var onDidSwipeBack: (() -> Void)? = nil
    let animation: Animation = .snappy(duration: 0.15)

    var body: some View {
        content()
            .offset(dragOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(animation, value: dragOffset)
            .background {
                GeometryReader { proxy in
                    let region = region(in: proxy)
                    Color.clear
                        .onAppear { gestureRegion = region }
                        .onChange(of: region) { gestureRegion = $0 }
                }
            }
            #if !os(tvOS)
            // Observe drags alongside child controls rather than putting an invisible
            // hit-testing rectangle above them. System bars remain outside this content.
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($dragOffset) { value, offset, _ in
                        guard gestureRegion.contains(value.startLocation, for: insertionTransition, layoutDirection: layoutDirection) else { return }
                        offset = SwipeBackGestureRegion.offset(
                            for: value.translation, transition: insertionTransition, layoutDirection: layoutDirection
                        )
                    }
                    .onEnded { value in
                        guard gestureRegion.contains(value.startLocation, for: insertionTransition, layoutDirection: layoutDirection) else { return }
                        let offset = SwipeBackGestureRegion.offset(
                            for: value.translation, transition: insertionTransition, layoutDirection: layoutDirection
                        )
                        if max(abs(offset.width), abs(offset.height)) >= swipeThreshold {
                            onDidSwipeBack?()
                        }
                    }
            )
            #endif
    }

    private func region(in proxy: GeometryProxy) -> SwipeBackGestureRegion {
        let insets = proxy.safeAreaInsets
        let left = layoutDirection == .leftToRight ? insets.leading : insets.trailing
        let right = layoutDirection == .leftToRight ? insets.trailing : insets.leading
        let bounds = CGRect(
            x: max(0, left), y: max(0, insets.top),
            width: max(0, proxy.size.width - max(0, left) - max(0, right)),
            height: max(0, proxy.size.height - max(0, insets.top) - max(0, insets.bottom))
        )
        var exclusions: [CGRect] = []
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27.1, *) {
            exclusions = [.division, .occlusion].flatMap { kind in
                proxy.reservedRegions(kind: kind, layoutDirectionBehavior: .fixed)
                    .filter(\.isActive).map(\.frame)
            }
        }
        #endif
        return SwipeBackGestureRegion(bounds: bounds, exclusions: exclusions)
    }
}

#Preview {
    SwipeBackSupportContainer(insertionTransition: .trailing()) {
        Rectangle().fill(Color.blue)
    }
}
