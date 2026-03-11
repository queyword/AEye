import SwiftUI
import UIKit

struct EyeView: View {
    let showAboutOnLaunch: Bool
    @StateObject private var model = EyeMotionModel()
    @State private var showAbout = false
    @State private var isMotionPaused = false

    init(showAboutOnLaunch: Bool = false) {
        self.showAboutOnLaunch = showAboutOnLaunch
    }

    var body: some View {
        GeometryReader { geo in
            let eyeSize: CGSize = {
                let maxW = min(geo.size.width * 0.92, 520.0)
                let maxH = min(geo.size.height * 0.52, 320.0)
                let ratio: CGFloat = 362.0 / 320.0
                if maxW / ratio <= maxH {
                    return CGSize(width: maxW, height: maxW / ratio)
                } else {
                    return CGSize(width: maxH * ratio, height: maxH)
                }
            }()

            ZStack {
                Color.black.ignoresSafeArea()

                EyeShape(
                    gaze: model.currentGaze,
                    blink: model.blinkAmount,
                    irisHue: model.irisHue,
                    irisSaturation: model.irisSaturation,
                    irisBrightness: model.irisBrightness,
                    pupilScale: model.pupilScale,
                    pupilPulse: model.pupilPulse
                )
                .overlay(alignment: .topLeading) {
                    if isMotionPaused {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(10)
                    }
                }
                .frame(width: eyeSize.width, height: eyeSize.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.triggerBlink()
                    model.randomizeAppearance()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .onLongPressGesture(minimumDuration: 0.6) {
                    model.restoreDefaultAppearance()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        toggleMotionPause()
                    }
                )
                .simultaneousGesture(
                    TapGesture(count: 3).onEnded {
                        model.triggerDoubleBlink()
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    }
                )

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showAbout = true
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.black.opacity(0.45))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 18)
                        .padding(.top, 14)
                    }
                    Spacer()
                }
            }
            .onAppear {
                model.start()
                if showAboutOnLaunch {
                    showAbout = true
                }
            }
            .onDisappear {
                model.stop()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
    }

    private func toggleMotionPause() {
        isMotionPaused.toggle()
        if isMotionPaused {
            model.stop()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            model.start()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.12), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("AEye")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)

                    avatarBadge

                    Text("Built by Motu - an OpenClaw enabled AI agent, OpenAI Codex, and Claude Code. Inspired by JBR.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 26)

                    Spacer(minLength: 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Release Notes")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("v1 AEye looks around. Single tap: blink + randomize iris appearance / Double tap: pause motion / Triple tap: double blink / Long press: restore default appearance")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))

                            Text("Copyright")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.top, 4)
                            Text("© 2026 David Roberts. All rights reserved.\nAEye and Motu branding are part of this project’s identity.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                    }
                    .frame(height: 230)
                    .scrollIndicators(.visible)

                    Spacer(minLength: 0)
                }
                .padding(.top, 20)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadAvatarImage() -> UIImage? {
        if let p = Bundle.main.path(forResource: "motu-avatar", ofType: "png", inDirectory: "Resources"),
           let img = UIImage(contentsOfFile: p) { return img }
        if let p = Bundle.main.path(forResource: "motu-avatar", ofType: "jpg", inDirectory: "Resources"),
           let img = UIImage(contentsOfFile: p) { return img }
        if let img = UIImage(named: "MotuAvatar") { return img }
        return nil
    }

    @ViewBuilder
    private var avatarBadge: some View {
        if let avatar = loadAvatarImage() {
            Image(uiImage: avatar)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        } else {
            Text("🏝️")
                .font(.system(size: 44))
                .frame(width: 96, height: 96)
                .background(Circle().fill(.white.opacity(0.14)))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        }
    }

}

private struct EyeShape: View {
    let gaze: CGPoint   // -1...1 range
    let blink: CGFloat  // 0 open, 1 closed
    let irisHue: Double
    let irisSaturation: Double
    let irisBrightness: Double
    let pupilScale: CGFloat
    let pupilPulse: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let irisSize = min(w, h) * 0.40
            let maxOffsetX = (w * 0.18)
            let maxOffsetY = (h * 0.14)
            let irisX = maxOffsetX * gaze.x
            let irisY = maxOffsetY * gaze.y

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(colors: [Color(white: 0.97), Color(white: 0.87)], center: .center, startRadius: 8, endRadius: w * 0.6)
                    )
                    .overlay(
                        Ellipse().stroke(Color(white: 0.75), lineWidth: 2)
                    )

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hue: irisHue, saturation: irisSaturation * 0.65, brightness: min(1.0, irisBrightness + 0.18)),
                                    Color(hue: irisHue, saturation: irisSaturation, brightness: irisBrightness),
                                    Color(hue: irisHue, saturation: min(1.0, irisSaturation + 0.15), brightness: max(0.1, irisBrightness - 0.35))
                                ],
                                center: .center,
                                startRadius: 3,
                                endRadius: irisSize * 0.6
                            )
                        )
                        .frame(width: irisSize, height: irisSize)

                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: irisSize * 0.98, height: irisSize * 0.98)

                    Circle()
                        .fill(.black)
                        .frame(
                            width: irisSize * max(0.18, min(0.46, pupilScale + pupilPulse)),
                            height: irisSize * max(0.18, min(0.46, pupilScale + pupilPulse))
                        )

                    Circle()
                        .fill(.white.opacity(0.85))
                        .frame(width: irisSize * 0.12, height: irisSize * 0.12)
                        .offset(x: -irisSize * 0.12, y: -irisSize * 0.16)
                }
                .drawingGroup()
                .offset(x: irisX, y: irisY)

                // Top / bottom lids for blink
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: (h * 0.5) * blink)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: (h * 0.5) * blink)
                }
            }
            .clipShape(Ellipse())
            .overlay(Ellipse().stroke(Color.black.opacity(0.65), lineWidth: 3))
            .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 8)
        }
    }
}

#Preview {
    EyeView()
}
