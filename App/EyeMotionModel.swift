import SwiftUI

final class EyeMotionModel: ObservableObject {
    @Published var currentGaze: CGPoint = .zero  // -1...1
    @Published var blinkAmount: CGFloat = 0

    // V2 appearance randomization
    @Published var irisHue: Double = 0.56
    @Published var irisSaturation: Double = 0.70
    @Published var irisBrightness: Double = 0.75
    @Published var pupilScale: CGFloat = 0.30
    @Published var pupilPulse: CGFloat = 0

    private var gazeTask: Task<Void, Never>?
    private var blinkTask: Task<Void, Never>?
    private var pupilTask: Task<Void, Never>?

    func start() {
        guard gazeTask == nil, blinkTask == nil, pupilTask == nil else { return }

        gazeTask = Task { @MainActor in
            while !Task.isCancelled {
                // Add a soft center bias so gaze feels less edge-hugging over long runs.
                let rawTarget = CGPoint(
                    x: CGFloat.random(in: -0.95...0.95),
                    y: CGFloat.random(in: -0.75...0.75)
                )
                let target = CGPoint(
                    x: clamp((rawTarget.x * 0.78) + (CGFloat.random(in: -0.08...0.08) * 0.22), min: -0.95, max: 0.95),
                    y: clamp((rawTarget.y * 0.78) + (CGFloat.random(in: -0.06...0.06) * 0.22), min: -0.75, max: 0.75)
                )

                let entersFocusHold = Int.random(in: 0...5) == 0
                let animatedTarget = entersFocusHold
                    ? CGPoint(
                        x: clamp(target.x * CGFloat.random(in: 0.15...0.32), min: -0.95, max: 0.95),
                        y: clamp(target.y * CGFloat.random(in: 0.15...0.32), min: -0.75, max: 0.75)
                    )
                    : target

                let duration = entersFocusHold
                    ? Double.random(in: 0.55...1.45)
                    : Double.random(in: 0.35...1.25)
                withAnimation(.easeInOut(duration: duration)) {
                    currentGaze = animatedTarget
                }

                // micro-saccades
                if Bool.random() {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 120...260)))
                    withAnimation(.easeOut(duration: 0.08)) {
                        currentGaze.x = clamp(currentGaze.x + CGFloat.random(in: -0.06...0.06), min: -0.95, max: 0.95)
                        currentGaze.y = clamp(currentGaze.y + CGFloat.random(in: -0.05...0.05), min: -0.75, max: 0.75)
                    }
                }

                // occasional quick side-glance and return
                if Int.random(in: 0...10) == 0 {
                    let beforeGlance = currentGaze
                    let glanceDirection: CGFloat = Bool.random() ? 1 : -1

                    withAnimation(.easeOut(duration: 0.09)) {
                        currentGaze.x = clamp(beforeGlance.x + (0.16 * glanceDirection), min: -0.95, max: 0.95)
                        currentGaze.y = clamp(beforeGlance.y + CGFloat.random(in: -0.03...0.03), min: -0.75, max: 0.75)
                    }

                    try? await Task.sleep(for: .milliseconds(Int.random(in: 70...130)))

                    withAnimation(.easeInOut(duration: 0.14)) {
                        currentGaze = beforeGlance
                    }
                }

                // occasional gentle recenter after edge-biased looks
                if abs(animatedTarget.x) > 0.72 || abs(animatedTarget.y) > 0.56, Int.random(in: 0...2) == 0 {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 120...260)))
                    withAnimation(.easeInOut(duration: Double.random(in: 0.28...0.55))) {
                        currentGaze = CGPoint(
                            x: currentGaze.x * CGFloat.random(in: 0.55...0.78),
                            y: currentGaze.y * CGFloat.random(in: 0.50...0.74)
                        )
                    }
                }

                let restRange = entersFocusHold ? 700...1800 : 380...1300
                try? await Task.sleep(for: .milliseconds(Int.random(in: restRange)))
            }
        }

        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 1600...5200)))
                await blink()

                // brief post-blink pupil reflex to add life-like adaptation
                if Int.random(in: 0...2) == 0 {
                    withAnimation(.easeOut(duration: 0.14)) {
                        pupilPulse = CGFloat.random(in: -0.045 ... -0.020)
                    }
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 120...220)))
                    withAnimation(.easeInOut(duration: 0.22)) {
                        pupilPulse = 0
                    }
                }

                // occasional double blink
                if Int.random(in: 0...8) == 0 {
                    try? await Task.sleep(for: .milliseconds(130))
                    await blink(speed: 0.065)
                }
            }
        }

        pupilTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 1800...4200)))
                withAnimation(.easeInOut(duration: Double.random(in: 0.5...1.1))) {
                    pupilPulse = CGFloat.random(in: -0.025...0.035)
                }
            }
        }
    }

    @MainActor
    private func blink(speed: Double = 0.09) async {
        withAnimation(.easeInOut(duration: speed)) {
            blinkAmount = 1
        }
        try? await Task.sleep(for: .milliseconds(Int((speed * 1000) + 20)))
        withAnimation(.easeInOut(duration: speed)) {
            blinkAmount = 0
        }
    }

    @MainActor
    func randomizeAppearance() {
        withAnimation(.easeInOut(duration: 0.28)) {
            irisHue = Double.random(in: 0.02...0.62)          // brown -> blue/green
            irisSaturation = Double.random(in: 0.45...0.95)
            irisBrightness = Double.random(in: 0.45...0.88)
            pupilScale = CGFloat.random(in: 0.22...0.40)
            pupilPulse = 0
        }
    }

    @MainActor
    func restoreDefaultAppearance() {
        withAnimation(.easeInOut(duration: 0.28)) {
            irisHue = 0.56
            irisSaturation = 0.70
            irisBrightness = 0.75
            pupilScale = 0.30
            pupilPulse = 0
        }
    }

    @MainActor
    func triggerBlink() {
        Task { @MainActor in
            await blink(speed: 0.08)
        }
    }

    @MainActor
    func triggerDoubleBlink() {
        Task { @MainActor in
            await blink(speed: 0.07)
            try? await Task.sleep(for: .milliseconds(110))
            await blink(speed: 0.07)
        }
    }

    @MainActor
    func stop() {
        gazeTask?.cancel()
        blinkTask?.cancel()
        pupilTask?.cancel()
        gazeTask = nil
        blinkTask = nil
        pupilTask = nil
    }

    deinit {
        gazeTask?.cancel()
        blinkTask?.cancel()
        pupilTask?.cancel()
    }

    private func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.max(min, Swift.min(max, value))
    }
}
