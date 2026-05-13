import SwiftUI
import UIKit
import AVFoundation
import AVKit

struct CameraView: View {
    @State var model: CameraModel
    @State var showPanel: Bool
    @State var showSettings = false
    @State var showPreview = false
    @State var showCoach = false
    @State var coachIndex = 0
    @State var coachInitialHDR: Bool = false
    @State var coachInitialThumbnail: UIImage?
    @State var coachInitialEV: Float = 0
    @State var coachDidOpenPreview = false
    @State private var showSplash = true
    @State private var splashStart = Date()
    @State var controlsOnLeft: Bool = false
    @State var tipMessage: LocalizedStringKey?
    @State var tipID: UUID = UUID()
    @State private var thumbnailButtonFrame: CGRect = .zero
    @State private var flyInImage: UIImage?
    @State private var flyPhase: CaptureFlyPhase = .start
    @State private var flyInTask: Task<Void, Never>?

    private static let flyInTravelMs: Int = 600
    private static let flyInVanishMs: Int = 180
    @State private var isAdjustingEV = false
    @State private var evDragStartBias: Float = 0
    @State private var dragLockedAxis: DragAxis = .none
    @State private var evDismissTask: Task<Void, Never>?
    @State private var previewView: PreviewView?
    enum DragAxis { case none, horizontal, vertical }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var vSizeClass

    private var isLandscape: Bool { vSizeClass == .compact }

    private func updateControlsSide() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let orientation = scene?.interfaceOrientation ?? .portrait
        controlsOnLeft = orientation == .landscapeLeft
    }

    private static let minSplashDuration: TimeInterval = 0.5
    static let splashMaxDurationMs: Int = 900
    private static let splashWaitPollMs: Int = 50
    private static let evDragPixelsPerStop: CGFloat = 80
    private static let evSnapToZeroThreshold: Float = 0.15
    private static let evIndicatorDismissDelayMs: Int = 700
    private static let panelSwipeThresholdPx: CGFloat = 40
    private static let tipDurationMs: Int = 1500
    private static let errorToastDurationSec: TimeInterval = 3

    @Namespace var thumbnailNS
    @MainActor
    init() {
        let m = CameraModel()
        _model = State(wrappedValue: m)
        _showPanel = State(wrappedValue: m.settings.panelExpandedAtLaunch)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    CameraPreview(source: model.captureService, previewView: $previewView) { devicePoint, viewPoint in
                        guard !showCoach, model.isCameraReady else { return }
                        Task { await model.handleTap(at: devicePoint, viewPoint: viewPoint) }
                    }

                    AspectRatioMaskView(ratio: model.currentAspectRatio)

                    if model.settings.showGrid {
                        GridOverlayView()
                    }

                    if model.settings.objectDetectionEnabled, !model.detectedObjects.isEmpty {
                        DetectionOverlayView(
                            objects: model.detectedObjects,
                            selectedID: model.selectedDetectionID,
                            previewView: previewView,
                            onSelect: { id in
                                haptic(.light)
                                model.selectFaceTrack(id)
                            }
                        )
                    }

                    if let p = model.focusReticlePoint {
                        FocusReticle(position: p).id(p)
                    }
                }
                .ignoresSafeArea()

                if !model.isCameraReady,
                   AVCaptureDevice.authorizationStatus(for: .video) == .denied
                    || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                    cameraPermissionView
                }

                if isLandscape {
                    landscapeOverlay
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                        middleControls
                        Spacer()
                        bottomBar
                    }
                }

                if let message = model.errorMessage {
                    errorToast(message)
                }

                if let tip = tipMessage {
                    tipToast(tip)
                }

                if isAdjustingEV {
                    EVAdjustIndicator(
                        bias: model.exposureBias,
                        range: model.minExposureBias ... model.maxExposureBias
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85)),
                        removal: .modifier(
                            active: DiffuseModifier(scale: 1.08, blur: 8, opacity: 0),
                            identity: DiffuseModifier(scale: 1.0, blur: 0, opacity: 1)
                        )
                    ))
                }

                if let img = flyInImage {
                    CaptureFlyInOverlay(
                        image: img,
                        targetFrame: thumbnailButtonFrame,
                        phase: flyPhase
                    )
                    .zIndex(90)
                }

                if showSplash {
                    LaunchSplash()
                        .transition(.diffuse)
                        .zIndex(100)
                }
            }
            .onPreferenceChange(ThumbnailFramePreference.self) { frame in
                thumbnailButtonFrame = frame
            }
            .onChange(of: model.captureSequence) { _, _ in
                guard !model.isBurstActive else { return }
                triggerFlyIn()
            }
            .onChange(of: model.isCameraReady) { _, ready in
                if ready { dismissSplash() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showPreview) {
                if let image = model.lastThumbnail {
                    let onPreviewCloseStep = showCoach
                        && coachIndex < coachSteps.count
                        && coachSteps[coachIndex].mark == .previewClose
                    PhotoPreviewView(
                        image: image,
                        coachStep: onPreviewCloseStep ? coachSteps[coachIndex] : nil,
                        coachStepIndex: coachIndex,
                        coachTotalSteps: coachSteps.count,
                        onCoachSkip: finishCoach,
                        onCoachNext: {
                            if onPreviewCloseStep {
                                showPreview = false
                            } else {
                                advanceCoachStep()
                            }
                        }
                    )
                    .navigationTransition(.zoom(sourceID: "thumbnail", in: thumbnailNS))
                }
            }
            .overlayPreferenceValue(CoachMarkAnchorPreference.self) { anchors in
                if showCoach, !showPreview, !showSettings, coachIndex < coachSteps.count {
                    GeometryReader { proxy in
                        CoachMarkOverlay(
                            step: coachSteps[coachIndex],
                            stepIndex: coachIndex,
                            totalSteps: coachSteps.count,
                            anchors: anchors,
                            geometry: proxy,
                            onSkip: finishCoach,
                            onNext: advanceCoachStep
                        )
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .task {
            updateControlsSide()
            await model.start()
            while showSplash {
                try? await Task.sleep(for: .milliseconds(Self.splashWaitPollMs))
            }
            if !model.settings.hasShownOnboarding,
               AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                startCoach()
            }
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            evDismissTask?.cancel()
            flyInTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateControlsSide()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(Self.splashMaxDurationMs))
            dismissSplash()
        }
        .onCameraCaptureEvent { event in
            guard model.isCameraReady, event.phase == .ended, coachAllows(.shutter) else { return }
            haptic(.heavy)
            let inCoach = showCoach
            model.capturePhoto(saveToLibrary: !inCoach)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await model.start() }
            case .background:
                Task { await model.stop() }
            default:
                break
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            if !model.settings.hasShownOnboarding {
                startCoach()
            }
        }) {
            SettingsView(
                settings: model.settings,
                availableLenses: model.availableLenses,
                zoomFactors: model.lensZoomFactors,
                locationAuthStatus: model.locationAuthStatus,
                isCameraAvailable: model.isCameraReady
            ) {
                Task { await model.applySettings() }
            }
        }
        .gesture(combinedSwipeGesture)
        .onChange(of: model.currentLens) { _, _ in advanceCoach(matching: .lens) }
        .onChange(of: model.currentFormat) { _, _ in advanceCoach(matching: .format) }
        .onChange(of: model.flashMode) { _, _ in advanceCoach(matching: .flash) }
        .onChange(of: model.settings.useComputationalPhotography) { _, _ in advanceCoach(matching: .hdr) }
        .onChange(of: showPanel) { _, newValue in
            Task {
                if newValue {
                    await model.enterPanelExpanded()
                } else {
                    await model.enterPanelCollapsed()
                }
            }
            if newValue {
                evDismissTask?.cancel()
                if isAdjustingEV {
                    withAnimation(.easeOut(duration: 0.25)) { isAdjustingEV = false }
                }
            }
            advanceCoach(matching: newValue ? .panelOpen : .panelClose)
        }
        .onChange(of: model.isCapturing) { old, new in
            if old, !new {
                advanceCoach(matching: .shutter)
            }
        }
        .onChange(of: showPreview) { _, new in
            if new {
                coachDidOpenPreview = true
                advanceCoach(matching: .thumbnail)
            } else {
                advanceCoach(matching: .previewClose)
            }
        }
        .onChange(of: model.exposureBias) { _, _ in
            advanceCoach(matching: .ev)
        }
        .onChange(of: showSettings) { _, new in
            if new { advanceCoach(matching: .settings) }
        }
    }

    private var combinedSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if dragLockedAxis == .none {
                    if abs(dx) > abs(dy), abs(dx) > 10 {
                        dragLockedAxis = .horizontal
                        evDragStartBias = model.exposureBias
                        if !showPanel, model.isCameraReady, coachAllows(.ev) {
                            evDismissTask?.cancel()
                            if !isAdjustingEV {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    isAdjustingEV = true
                                }
                            }
                        }
                    } else if abs(dy) > abs(dx), abs(dy) > 10 {
                        dragLockedAxis = .vertical
                    }
                }
                if dragLockedAxis == .horizontal, isAdjustingEV, !showPanel {
                    handleEVDrag(dx: dx)
                }
            }
            .onEnded { value in
                if dragLockedAxis == .vertical, (coachAllows(.panelOpen) || coachAllows(.panelClose)) {
                    let dy = value.translation.height
                    if dy < -Self.panelSwipeThresholdPx, !showPanel {
                        haptic(.light)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showPanel = true
                        }
                        showTip("Manual Mode: \(onOffLabel(true))")
                    } else if dy > Self.panelSwipeThresholdPx, showPanel {
                        haptic(.light)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showPanel = false
                        }
                        showTip("Manual Mode: \(onOffLabel(false))")
                    }
                }
                if isAdjustingEV {
                    evDismissTask?.cancel()
                    evDismissTask = Task {
                        do {
                            try await Task.sleep(for: .milliseconds(Self.evIndicatorDismissDelayMs))
                            withAnimation(.smooth(duration: 0.55)) {
                                isAdjustingEV = false
                            }
                        } catch {
                        }
                    }
                }
                dragLockedAxis = .none
            }
    }

    private func handleEVDrag(dx: CGFloat) {
        var newBias = evDragStartBias + Float(dx / Self.evDragPixelsPerStop)
        newBias = max(model.minExposureBias, min(model.maxExposureBias, newBias))

        let snap = Self.evSnapToZeroThreshold
        let crossedIntoSnap = abs(newBias) < snap && abs(model.exposureBias) >= snap
        if abs(newBias) < snap {
            if crossedIntoSnap { haptic(.medium) }
            newBias = 0
        }
        if newBias != model.exposureBias {
            model.exposureBias = newBias
            Task { await model.applyExposureBias() }
        }
    }

    private func dismissSplash() {
        guard showSplash else { return }
        let remaining = Self.minSplashDuration - Date().timeIntervalSince(splashStart)

        if remaining > 0 {
            Task {
                try? await Task.sleep(for: .seconds(remaining))
                guard showSplash else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    showSplash = false
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.38)) {
                showSplash = false
            }
        }
    }

    private func triggerFlyIn() {
        guard let image = model.lastThumbnail else { return }
        flyInTask?.cancel()
        flyInImage = image
        flyPhase = .start
        flyInTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.6, bounce: 0.22)) {
                flyPhase = .landed
            }
            try? await Task.sleep(for: .milliseconds(Self.flyInTravelMs))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                flyPhase = .vanish
            }
            try? await Task.sleep(for: .milliseconds(Self.flyInVanishMs))
            guard !Task.isCancelled else { return }
            flyInImage = nil
            flyPhase = .start
            flyInTask = nil
        }
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard model.settings.hapticFeedbackEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func showTip(_ key: LocalizedStringKey) {
        tipID = UUID()
        tipMessage = key
    }

    private func tipToast(_ key: LocalizedStringKey) -> some View {
        VStack {
            Text(key)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.75)))
                .padding(.top, isLandscape ? 28 : 12)
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .offset(y: -4))
        ))
        .task(id: tipID) {
            do {
                try await Task.sleep(for: .milliseconds(Self.tipDurationMs))
                withAnimation(.easeInOut(duration: 0.45)) {
                    tipMessage = nil
                }
            } catch {
            }
        }
    }

    private func errorToast(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(.red.opacity(0.85)))
                .padding(.bottom, isLandscape ? 60 : 240)
        }
        .transition(.opacity.combined(with: .offset(y: 6)))
        .task(id: message) {
            try? await Task.sleep(for: .seconds(Self.errorToastDurationSec))
            if model.errorMessage == message {
                withAnimation(.easeInOut(duration: 0.45)) {
                    model.errorMessage = nil
                }
            }
        }
    }
}

