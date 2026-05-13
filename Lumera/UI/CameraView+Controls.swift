import SwiftUI

extension CameraView {

    var thumbnailButton: some View {
        Button {
            if model.lastThumbnail != nil {
                showPreview = true
            } else {
                advanceCoachStep()
            }
        } label: {
            ThumbnailPreview(image: model.lastThumbnail)
                .frame(width: 56, height: 56)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ThumbnailFramePreference.self,
                            value: proxy.frame(in: .global)
                        )
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(!coachAllows(.thumbnail) || (model.lastThumbnail == nil && !showCoach))
        .accessibilityLabel("View Latest Photo")
        .matchedTransitionSource(id: "thumbnail", in: thumbnailNS)
        .coachMark(.thumbnail)
    }

    var shutterButton: some View {
        ShutterButton(
            isCapturing: model.isCapturing,
            burstCount: model.burstCount,
            onTap: {
                haptic(.heavy)
                let inCoach = showCoach
                model.capturePhoto(saveToLibrary: !inCoach)
            },
            onBurstStart: {
                guard !showCoach else { return }
                haptic(.medium)
                model.startBurst()
            },
            onBurstEnd: {
                haptic(.light)
                model.stopBurst()
            }
        )
        .disabled(!model.isCameraReady || !coachAllows(.shutter))
        .opacity(model.isCameraReady ? 1.0 : 0.4)
        .coachMark(.shutter)
    }

    var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .liquidGlassCircle(interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!coachAllows(.settings))
        .accessibilityLabel("Settings")
        .coachMark(.settings)
    }

    var formatButton: some View {
        FormatToggleView(selected: model.currentFormat) { format in
            haptic(.light)
            Task { await model.setFormat(format) }
            showTip("Format: \(format.fullLabel)")
        }
        .coachMark(.format)
        .disabled(!model.isCameraReady || !coachAllows(.format))
        .opacity(model.isCameraReady ? 1.0 : 0.4)
    }

    var hdrButton: some View {
        HDRButton(isOn: model.settings.useComputationalPhotography) {
            haptic(.light)
            let next = !model.settings.useComputationalPhotography
            Task { await model.toggleHDR() }
            showTip("HDR: \(onOffLabel(next))")
        }
        .coachMark(.hdr)
        .disabled(!model.isCameraReady || !coachAllows(.hdr))
        .opacity(model.isCameraReady ? 1.0 : 0.4)
    }

    var aspectRatioButton: some View {
        AspectRatioButton(
            ratio: model.currentAspectRatio,
            isEnabled: model.isCameraReady && coachAllows(.format)
        ) {
            haptic(.light)
            model.cycleAspectRatio()
        }
    }

    var flashButton: some View {
        FlashButton(
            mode: model.flashMode,
            isEnabled: model.hasFlashHardware && model.isCameraReady && coachAllows(.flash)
        ) {
            haptic(.light)
            let next = model.flashMode.next()
            Task { await model.cycleFlashMode() }
            showTip("Flash: \(flashStateLabel(next))")
        }
        .coachMark(.flash)
    }

    private func flashStateLabel(_ mode: FlashMode) -> String {
        switch mode {
        case .auto: return String(localized: "Auto")
        case .off:  return String(localized: "Off")
        case .on:   return String(localized: "On")
        }
    }

    func onOffLabel(_ on: Bool) -> String {
        on ? String(localized: "On") : String(localized: "Off")
    }
}
