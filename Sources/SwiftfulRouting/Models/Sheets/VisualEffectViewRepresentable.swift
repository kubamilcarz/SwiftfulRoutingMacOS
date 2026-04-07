//
//  UIIntensityVisualEffectViewRepresentable.swift
//  SwiftfulRouting
//
//  Created by Nick Sarno on 4/19/25.
//
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit

struct IntensityVisualEffectViewRepresentable: UIViewRepresentable {

    let backgroundEffect: BackgroundEffect

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        IntensityVisualEffectView(effect: backgroundEffect.effect, intensity: backgroundEffect.intensity)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        guard let uiView = uiView as? IntensityVisualEffectView else { return }
        uiView.update(effect: backgroundEffect.effect, intensity: backgroundEffect.intensity)
    }
}

extension Animation {

    var asUIViewAnimationCurve: UIView.AnimationCurve {
        switch self {
        case .easeInOut:
            return .easeInOut
        default:
            return .linear
        }
    }
}

final class IntensityVisualEffectView: UIVisualEffectView {

    private var animator: UIViewPropertyAnimator!

    init(effect: UIVisualEffect?, intensity: CGFloat) {
        super.init(effect: nil)
        configureAnimator(effect: effect, intensity: intensity)
    }

    func update(effect: UIVisualEffect?, intensity: CGFloat) {
        configureAnimator(effect: effect, intensity: intensity)
    }

    private func configureAnimator(effect: UIVisualEffect?, intensity: CGFloat) {
        animator?.stopAnimation(true)
        animator = UIViewPropertyAnimator(
            duration: ModalSupportView.backgroundAnimationDuration,
            curve: ModalSupportView.backgroundAnimationCurve.asUIViewAnimationCurve,
            animations: { [weak self] in
                self?.effect = effect
            }
        )
        animator.pausesOnCompletion = true
        animator.fractionComplete = max(0, min(1, intensity))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct BackgroundEffect {
    let effect: UIVisualEffect
    let intensity: CGFloat

    public init(effect: UIVisualEffect, intensity: CGFloat) {
        self.effect = effect
        self.intensity = intensity
    }
}

#elseif canImport(AppKit)
import AppKit

struct IntensityVisualEffectViewRepresentable: NSViewRepresentable {

    let backgroundEffect: BackgroundEffect

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = backgroundEffect.material
        view.blendingMode = backgroundEffect.blendingMode
        view.state = backgroundEffect.state
        view.alphaValue = max(0, min(1, backgroundEffect.intensity))
    }
}

public struct BackgroundEffect {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State
    let intensity: CGFloat

    public init(
        material: NSVisualEffectView.Material,
        intensity: CGFloat,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.intensity = intensity
    }
}
#endif
