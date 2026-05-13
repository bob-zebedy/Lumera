import SwiftUI
import AVFoundation
import CoreMedia
import CoreLocation

enum ExposureMode: String, CaseIterable, Identifiable {
    case auto
    case manual
    var id: String { rawValue }
    var label: String { self == .auto ? "AUTO" : "M" }
}

enum FocusMode: String, CaseIterable, Identifiable {
    case auto
    case manual
    var id: String { rawValue }
    var label: String { self == .auto ? "AF" : "MF" }
}

enum WhiteBalanceMode: String, CaseIterable, Identifiable {
    case auto
    case manual
    var id: String { rawValue }
    var label: String { self == .auto ? "AWB" : "K" }
}

@MainActor
@Observable
final class CameraModel {

    let captureService: CaptureService
    let settings: Settings

    private let locationProvider = LocationProvider()

    var availableLenses: [Lens] = []
    var lensZoomFactors: [Lens: Double] = [:]
    var currentLens: Lens
    var currentFormat: PhotoFormat
    var currentAspectRatio: AspectRatio
    var flashMode: FlashMode
    var hasFlashHardware: Bool = true

    var exposureMode: ExposureMode = .auto
    var iso: Float = 100
    var shutterSeconds: Double = 1.0 / 60.0
    var minISO: Float = 25
    var maxISO: Float = 6400
    var minShutterSeconds: Double = 1.0 / 8000.0
    var maxShutterSeconds: Double = 1.0
    var exposureBias: Float = 0
    var minExposureBias: Float = -2
    var maxExposureBias: Float = 2

    var focusMode: FocusMode = .auto
    var focusLensPosition: Float = 0.5

    var whiteBalanceMode: WhiteBalanceMode = .auto
    var whiteBalanceTemperature: Float = 5500
    var whiteBalanceTint: Float = 0

    var lastThumbnail: UIImage?
    var captureSequence: Int = 0
    var errorMessage: String?
    var isCapturing = false
    var isBurstActive = false
    var burstCount: Int = 0
    var focusReticlePoint: CGPoint?
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    var isCameraReady: Bool = false

    var detectedObjects: [DetectedObject] = []
    var selectedDetectionID: Int?
    private var lastAutoFocusedPoint: CGPoint?
    private var detectionDrivingFocus: Bool = false
    private var nextDetectionID: Int = 1
    private var tracks: [Int: DetectionTrack] = [:]
    private static let detectionFocusMoveThreshold: CGFloat = 0.08
    private static let detectionTrackMatchThreshold: CGFloat = 0.15
    private static let detectionTrackLifetime: TimeInterval = 0.5
    private static let detectionFreshnessWindow: TimeInterval = 0.12
    private static let detectionPruneInterval: Duration = .milliseconds(50)
    private static let detectionConfirmFrames: Int = 2
    private static let detectionBoundsSmoothingSlow: CGFloat = 0.55
    private static let detectionBoundsSmoothingFast: CGFloat = 1.0
    private static let detectionFastMotionDistance: CGFloat = 0.05
    private static let detectionCenterBiasStrength: CGFloat = 0.6
    private static let focusReticleHideDelay: Duration = .milliseconds(800)

    private var cachedDevice: AVCaptureDevice?
    private var detectionListenerInstalled = false
    private var detectionPruneTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var burstTask: Task<Void, Never>?

    init(settings: Settings? = nil) {

        let resolved = settings ?? Settings()
        self.settings = resolved
        self.currentLens = resolved.defaultLens
        self.currentFormat = resolved.defaultFormat
        self.currentAspectRatio = resolved.defaultAspectRatio
        self.flashMode = resolved.defaultFlashMode
        self.captureService = CaptureService(
            initialLens: resolved.defaultLens,
            initialFormat: resolved.defaultFormat
        )
        self.locationAuthStatus = locationProvider.authorizationStatus
        locationProvider.onStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.handleLocationStatusChange(status)
            }
        }
    }

    private func handleLocationStatusChange(_ status: CLAuthorizationStatus) {
        locationAuthStatus = status
        if status == .denied || status == .restricted {
            if settings.embedLocation {
                settings.embedLocation = false
            }
            locationProvider.setEnabled(false)
        }
    }

    func start() async {
        do {
            await captureService.setUseComputational(settings.useComputationalPhotography)
            try await captureService.start()
            availableLenses = await captureService.availableLenses
            lensZoomFactors = DeviceLookup.zoomFactors()
            currentLens = await captureService.currentLens()
            currentFormat = await captureService.currentFormat()
            hasFlashHardware = await captureService.currentDeviceHasFlash()
            cachedDevice = await captureService.currentDevice()
            await captureService.setFlashMode(flashMode.avFlashMode)
            locationProvider.setEnabled(settings.embedLocation)
            await refreshRanges()
            await installDetectionListenerIfNeeded()
            await applyDetectionSettings()
            isCameraReady = true
        } catch {
            isCameraReady = false
            if case CameraError.cameraUnauthorized = error {
                return
            }
            errorMessage = (error as? CameraError)?.errorDescription ?? error.localizedDescription
        }
    }

    func stop() async {
        isCameraReady = false
        stopDetectionPruning()
        captureTask?.cancel()
        burstTask?.cancel()
        isBurstActive = false
        await captureService.stop()
    }

    func applySettings() async {
        await captureService.setUseComputational(settings.useComputationalPhotography)
        locationProvider.setEnabled(settings.embedLocation)
        await applyDetectionSettings()
    }

    private func installDetectionListenerIfNeeded() async {
        guard !detectionListenerInstalled else { return }
        detectionListenerInstalled = true
        await captureService.setDetectionsListener { [weak self] objects in
            Task { @MainActor [weak self] in
                self?.handleDetections(objects)
            }
        }
    }

    func applyDetectionSettings() async {
        let types: [AVMetadataObject.ObjectType] = settings.objectDetectionEnabled ? [.face] : []
        if types.isEmpty {
            stopDetectionPruning()
            detectedObjects = []
            tracks.removeAll()
            lastAutoFocusedPoint = nil
            selectedDetectionID = nil
            if detectionDrivingFocus {
                detectionDrivingFocus = false
                try? await captureService.resetContinuousFocusAndExposure()
            }
        } else {
            startDetectionPruning()
        }
        await captureService.setEnabledDetectionTypes(types)
    }

    private func startDetectionPruning() {
        guard detectionPruneTask == nil else { return }
        detectionPruneTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.detectionPruneInterval)
                guard !Task.isCancelled else { return }
                self?.handleDetections([])
            }
        }
    }

    private func stopDetectionPruning() {
        detectionPruneTask?.cancel()
        detectionPruneTask = nil
    }

    private func handleDetections(_ objects: [DetectedObject]) {
        let tracked = updateTracks(with: objects)
        if tracked != detectedObjects {
            detectedObjects = tracked
        }

        if let pinned = selectedDetectionID, !tracked.contains(where: { $0.id == pinned }) {
            selectedDetectionID = nil
        }

        guard focusMode == .auto else { return }

        guard let target = pickFocusTarget(from: tracked) else {
            if detectionDrivingFocus {
                detectionDrivingFocus = false
                lastAutoFocusedPoint = nil
                Task { try? await captureService.resetContinuousFocusAndExposure() }
            }
            return
        }

        let point = target.center
        if detectionDrivingFocus, let last = lastAutoFocusedPoint {
            let dx = point.x - last.x
            let dy = point.y - last.y
            let moved = (dx * dx + dy * dy).squareRoot()
            if moved < Self.detectionFocusMoveThreshold { return }
        }
        lastAutoFocusedPoint = point
        detectionDrivingFocus = true
        Task { try? await captureService.setContinuousFocusAndExposurePoint(point) }
    }

    private func updateTracks(with current: [DetectedObject]) -> [DetectedObject] {
        let now = Date()

        let trackIDs = Array(tracks.keys)
        var pairs: [(distance: CGFloat, trackID: Int, currIdx: Int)] = []
        for (currIdx, obj) in current.enumerated() {
            for trackID in trackIDs {
                guard let track = tracks[trackID], track.type == obj.type else { continue }
                let dx = track.bounds.midX - obj.bounds.midX
                let dy = track.bounds.midY - obj.bounds.midY
                let dist = (dx * dx + dy * dy).squareRoot()
                if dist < Self.detectionTrackMatchThreshold {
                    pairs.append((dist, trackID, currIdx))
                }
            }
        }
        pairs.sort { $0.distance < $1.distance }

        var usedTracks = Set<Int>()
        var usedCurrent = Set<Int>()
        var assignments: [Int: Int] = [:]
        for pair in pairs {
            if usedTracks.contains(pair.trackID) || usedCurrent.contains(pair.currIdx) { continue }
            assignments[pair.currIdx] = pair.trackID
            usedTracks.insert(pair.trackID)
            usedCurrent.insert(pair.currIdx)
        }

        for (currIdx, obj) in current.enumerated() {
            if let trackID = assignments[currIdx], var track = tracks[trackID] {
                track.bounds = smoothBounds(prev: track.bounds, next: obj.bounds)
                track.lastSeen = now
                track.confirmCount = min(track.confirmCount + 1, Self.detectionConfirmFrames + 1)
                tracks[trackID] = track
            } else {
                let id = nextDetectionID
                nextDetectionID += 1
                tracks[id] = DetectionTrack(
                    id: id,
                    type: obj.type,
                    bounds: obj.bounds,
                    confirmCount: 1,
                    lastSeen: now
                )
            }
        }

        tracks = tracks.filter { _, track in
            now.timeIntervalSince(track.lastSeen) <= Self.detectionTrackLifetime
        }

        return tracks.values
            .filter { $0.confirmCount >= Self.detectionConfirmFrames }
            .filter { now.timeIntervalSince($0.lastSeen) < Self.detectionFreshnessWindow }
            .map { DetectedObject(id: $0.id, type: $0.type, bounds: $0.bounds) }
    }

    private func pickFocusTarget(from tracked: [DetectedObject]) -> DetectedObject? {
        if let id = selectedDetectionID,
           let pinned = tracked.first(where: { $0.id == id }) {
            return pinned
        }
        return tracked.max(by: { Self.detectionScore($0) < Self.detectionScore($1) })
    }

    func selectFaceTrack(_ id: Int) {
        if selectedDetectionID == id {
            selectedDetectionID = nil
        } else {
            selectedDetectionID = id
            lastAutoFocusedPoint = nil
        }
    }

    private static func detectionScore(_ obj: DetectedObject) -> CGFloat {
        let dx = obj.center.x - 0.5
        let dy = obj.center.y - 0.5
        let distFromCenter = (dx * dx + dy * dy).squareRoot()
        let centerFactor = max(0, 1 - detectionCenterBiasStrength * distFromCenter)
        return obj.area * centerFactor
    }

    private func smoothBounds(prev: CGRect, next: CGRect) -> CGRect {
        let dx = next.midX - prev.midX
        let dy = next.midY - prev.midY
        let dist = (dx * dx + dy * dy).squareRoot()
        let alpha: CGFloat = dist >= Self.detectionFastMotionDistance
            ? Self.detectionBoundsSmoothingFast
            : Self.detectionBoundsSmoothingSlow
        let inv = 1 - alpha
        return CGRect(
            x: prev.minX * inv + next.minX * alpha,
            y: prev.minY * inv + next.minY * alpha,
            width: prev.width * inv + next.width * alpha,
            height: prev.height * inv + next.height * alpha
        )
    }

    func selectLens(_ lens: Lens) async {
        do {
            try await captureService.selectLens(lens)
            currentLens = lens
            hasFlashHardware = await captureService.currentDeviceHasFlash()
            cachedDevice = await captureService.currentDevice()
            await resetModesAfterLensChange()
            await refreshRanges()
        } catch {
            errorMessage = (error as? CameraError)?.errorDescription ?? error.localizedDescription
        }
    }

    func cycleFlashMode() async {
        let next = flashMode.next()
        flashMode = next
        await captureService.setFlashMode(next.avFlashMode)
    }

    func toggleHDR() async {
        settings.useComputationalPhotography.toggle()
        await captureService.setUseComputational(settings.useComputationalPhotography)
    }

    func setFlashMode(_ mode: FlashMode) async {
        flashMode = mode
        await captureService.setFlashMode(mode.avFlashMode)
    }

    func setFormat(_ format: PhotoFormat) async {
        await captureService.setFormat(format)
        currentFormat = format
    }

    func cycleAspectRatio() {
        currentAspectRatio = currentAspectRatio.next()
    }

    func capturePhoto(saveToLibrary: Bool = true) {
        guard isCameraReady, !isCapturing, !isBurstActive else { return }
        isCapturing = true
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isCapturing = false
                self.captureTask = nil
            }
            await self.performCapture(saveToLibrary: saveToLibrary)
        }
    }

    private func performCapture(saveToLibrary: Bool) async {
        do {
            let location = settings.embedLocation ? locationProvider.currentLocation : nil
            let aspectRatio = currentAspectRatio
            let photo = try await CameraOperationTimeout.run(seconds: 15, as: .capture) {
                try await self.captureService.capturePhoto(
                    location: location,
                    aspectRatio: aspectRatio
                )
            }

            if saveToLibrary {
                try await CameraOperationTimeout.run(seconds: 35, as: .save) {
                    try await PhotoLibrary.save(photo)
                }
            }
            if let data = photo.thumbnail, let image = UIImage(data: data) {
                lastThumbnail = image
                captureSequence &+= 1
                if isBurstActive {
                    burstCount += 1
                }
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? CameraError)?.errorDescription
                ?? (error as? CameraOperationTimeout)?.errorDescription
                ?? error.localizedDescription
        }
    }

    func startBurst(saveToLibrary: Bool = true) {
        guard isCameraReady, !isBurstActive, burstTask == nil else { return }
        burstCount = 0
        isBurstActive = true
        burstTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isBurstActive = false
                self.isCapturing = false
                self.burstTask = nil
            }
            while !Task.isCancelled, self.isBurstActive {
                self.isCapturing = true
                await self.performCapture(saveToLibrary: saveToLibrary)
                self.isCapturing = false
                if Task.isCancelled { break }
                await Task.yield()
            }
        }
    }

    func stopBurst() {
        isBurstActive = false
        burstCount = 0
    }

    func handleTap(at normalized: CGPoint, viewPoint: CGPoint) async {
        focusReticlePoint = viewPoint
        detectionDrivingFocus = false
        lastAutoFocusedPoint = nil
        selectedDetectionID = nil
        do {
            try await captureService.setFocusAndExposurePoint(normalized)
            focusMode = .auto
            exposureMode = .auto
        } catch {
            errorMessage = (error as? CameraError)?.errorDescription ?? error.localizedDescription
        }
        try? await Task.sleep(for: Self.focusReticleHideDelay)
        if focusReticlePoint == viewPoint {
            focusReticlePoint = nil
        }
    }

    func toggleExposureMode() async {
        let next: ExposureMode = exposureMode == .auto ? .manual : .auto
        await commitDeviceUpdate(\.exposureMode, to: next) {
            switch next {
            case .auto:
                try await self.captureService.setExposureAuto()
            case .manual:
                let dur = CMTime(seconds: self.shutterSeconds, preferredTimescale: 1_000_000)
                try await self.captureService.setExposureCustom(duration: dur, iso: self.iso)
            }
        }
    }

    func applyManualExposureSync() {
        guard let device = cachedDevice else { return }
        let dur = CMTime(seconds: shutterSeconds, preferredTimescale: 1_000_000)
        commitSyncDeviceUpdate(\.exposureMode, to: .manual) {
            try ManualControls.setExposureCustom(on: device, duration: dur, iso: iso)
        }
    }

    func applyExposureBias() async {
        do { try await captureService.setExposureBias(exposureBias) }
        catch { handleError(error) }
    }

    func toggleFocusMode() async {
        let next: FocusMode = focusMode == .auto ? .manual : .auto
        await commitDeviceUpdate(\.focusMode, to: next) {
            switch next {
            case .auto:   try await self.captureService.setFocusAuto()
            case .manual: try await self.captureService.setFocusLocked(lensPosition: self.focusLensPosition)
            }
        }
    }

    func applyManualFocusSync() {
        guard let device = cachedDevice else { return }
        commitSyncDeviceUpdate(\.focusMode, to: .manual) {
            try ManualControls.setFocusLocked(on: device, lensPosition: focusLensPosition)
        }
    }

    func toggleWhiteBalanceMode() async {
        let next: WhiteBalanceMode = whiteBalanceMode == .auto ? .manual : .auto
        await commitDeviceUpdate(\.whiteBalanceMode, to: next) {
            switch next {
            case .auto:
                try await self.captureService.setWhiteBalanceAuto()
            case .manual:
                try await self.captureService.setWhiteBalanceLocked(
                    temperature: self.whiteBalanceTemperature,
                    tint: self.whiteBalanceTint
                )
            }
        }
    }

    func applyManualWhiteBalanceSync() {
        guard let device = cachedDevice else { return }
        commitSyncDeviceUpdate(\.whiteBalanceMode, to: .manual) {
            try ManualControls.setWhiteBalanceLocked(
                on: device,
                temperature: whiteBalanceTemperature,
                tint: whiteBalanceTint
            )
        }
    }

    func enterPanelExpanded() async {
        if let device = cachedDevice {
            focusLensPosition = device.lensPosition
            let gains = device.deviceWhiteBalanceGains
            let value = device.temperatureAndTintValues(for: gains)
            whiteBalanceTemperature = value.temperature
            whiteBalanceTint = value.tint
            iso = clamp(device.iso, minISO, maxISO)
            shutterSeconds = clamp(
                CMTimeGetSeconds(device.exposureDuration),
                minShutterSeconds,
                maxShutterSeconds
            )
        }
        exposureBias = 0
        await commitDeviceUpdate(\.exposureMode, to: .auto) {
            try await self.captureService.setExposureAuto()
        }
        do { try await captureService.setExposureBias(0) } catch { handleError(error) }
        await commitDeviceUpdate(\.focusMode, to: .manual) {
            try await self.captureService.setFocusLocked(lensPosition: self.focusLensPosition)
        }
        await commitDeviceUpdate(\.whiteBalanceMode, to: .manual) {
            try await self.captureService.setWhiteBalanceLocked(
                temperature: self.whiteBalanceTemperature,
                tint: self.whiteBalanceTint
            )
        }
    }

    func enterPanelCollapsed() async {
        exposureBias = 0
        do { try await captureService.setExposureBias(0) } catch { handleError(error) }
        await commitDeviceUpdate(\.exposureMode, to: .auto) {
            try await self.captureService.setExposureAuto()
        }
        await commitDeviceUpdate(\.focusMode, to: .auto) {
            try await self.captureService.setFocusAuto()
        }
        await commitDeviceUpdate(\.whiteBalanceMode, to: .auto) {
            try await self.captureService.setWhiteBalanceAuto()
        }
    }

    private func refreshRanges() async {
        guard let range = await captureService.exposureRange else { return }
        minISO = range.minISO
        maxISO = range.maxISO
        minShutterSeconds = max(CMTimeGetSeconds(range.minDuration), 1.0 / 8000.0)
        maxShutterSeconds = min(CMTimeGetSeconds(range.maxDuration), 1.0)
        minExposureBias = range.minBias
        maxExposureBias = range.maxBias
        iso = clamp(iso, minISO, maxISO)
        shutterSeconds = clamp(shutterSeconds, minShutterSeconds, maxShutterSeconds)
    }

    private func resetModesAfterLensChange() async {
        exposureMode = .auto
        focusMode = .auto
        whiteBalanceMode = .auto
        exposureBias = 0
        do { try await captureService.setExposureBias(0) } catch {}
    }

    private func commitDeviceUpdate<M>(
        _ keyPath: ReferenceWritableKeyPath<CameraModel, M>,
        to value: M,
        apply: () async throws -> Void
    ) async {
        do {
            try await apply()
            self[keyPath: keyPath] = value
        } catch {
            handleError(error)
        }
    }

    private func commitSyncDeviceUpdate<M>(
        _ keyPath: ReferenceWritableKeyPath<CameraModel, M>,
        to value: M,
        apply: () throws -> Void
    ) {
        do {
            try apply()
            self[keyPath: keyPath] = value
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = (error as? CameraError)?.errorDescription ?? error.localizedDescription
    }

    private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
        min(max(v, lo), hi)
    }
}
