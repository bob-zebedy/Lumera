import SwiftUI
import UIKit

extension CameraView {

    var middleControls: some View {
        VStack {
            Spacer()
            if !model.availableLenses.isEmpty {
                LensSelectorView(
                    lenses: model.availableLenses,
                    selected: model.currentLens,
                    zoomFactors: model.lensZoomFactors
                ) { lens in
                    haptic(.light)
                    Task { await model.selectLens(lens) }
                }
                .coachMark(.lens)
                .disabled(!model.isCameraReady || !coachAllows(.lens))
                .opacity(model.isCameraReady ? 1.0 : 0.4)
                .padding(.bottom, 8)
            }
        }
    }

    var bottomBar: some View {
        VStack(spacing: 12) {
            formatFlashRow
                .padding(.horizontal, 24)

            if showPanel {
                ManualControlPanel(model: model)
                    .coachMark(.panelClose)
                    .disabled(!model.isCameraReady || showCoach)
                    .opacity(model.isCameraReady ? 1.0 : 0.5)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(alignment: .center) {
                thumbnailButton.padding(.leading, 24)
                Spacer()
                shutterButton
                Spacer()
                settingsButton.padding(.trailing, 24)
            }
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var formatFlashRow: some View {
        GlassyContainer(spacing: 8) {
            HStack(spacing: 8) {
                formatButton
                Spacer()
                aspectRatioButton
                hdrButton
                flashButton
            }
        }
    }

    var landscapeOverlay: some View {
        ZStack {
            HStack(spacing: 0) {
                if controlsOnLeft {
                    HStack(alignment: .center, spacing: 8) {
                        landscapeRightColumn
                        landscapeLensColumn
                    }
                    .padding(.leading, 16)
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    Spacer()
                } else {
                    Spacer()
                    HStack(alignment: .center, spacing: 8) {
                        landscapeLensColumn
                        landscapeRightColumn
                    }
                    .padding(.trailing, 16)
                    .contentShape(Rectangle())
                    .onTapGesture { }
                }
            }

            if showPanel {
                VStack {
                    Spacer()
                    ManualControlPanel(model: model)
                        .coachMark(.panelClose)
                        .disabled(!model.isCameraReady || showCoach)
                        .opacity(model.isCameraReady ? 1.0 : 0.5)
                        .frame(maxWidth: 520)
                        .contentShape(Rectangle())
                        .onTapGesture { }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private var landscapeLensColumn: some View {
        if !model.availableLenses.isEmpty {
            LensSelectorView(
                lenses: model.availableLenses,
                selected: model.currentLens,
                zoomFactors: model.lensZoomFactors,
                axis: .vertical,
                onSelect: { lens in
                    haptic(.light)
                    Task { await model.selectLens(lens) }
                }
            )
            .coachMark(.lens)
            .disabled(!model.isCameraReady || !coachAllows(.lens))
            .opacity(model.isCameraReady ? 1.0 : 0.4)
        }
    }

    private var landscapeRightColumn: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                formatButton
                aspectRatioButton
                hdrButton
                flashButton
            }
            Spacer()
            thumbnailButton
            shutterButton
            settingsButton
        }
        .padding(.vertical, 16)
    }

    var cameraPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.6))
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Enable camera in Settings → Lumera to take photos.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.yellow))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85).ignoresSafeArea())
    }
}
