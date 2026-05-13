@preconcurrency import AVFoundation
import CoreLocation
import UIKit

actor CaptureService: PreviewSource {

    nonisolated let session = AVCaptureSession()
    nonisolated let photoOutput = AVCapturePhotoOutput()
    nonisolated let metadataOutput = AVCaptureMetadataOutput()
    private let metadataQueue = DispatchQueue(label: "com.lumera.metadata", qos: .userInitiated)
    private var metadataHandler: MetadataHandler?
    private var detectionListener: (@Sendable ([DetectedObject]) -> Void)?
    private var activeInput: AVCaptureDeviceInput?
    private var activeDevice: AVCaptureDevice?
    private var activeLens: Lens
    private var activeFormat: PhotoFormat
    private var useComputational: Bool = false
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var processors: [Int64: PhotoCaptureProcessor] = [:]
    private var isConfigured = false

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationListener: RotationListener?

    private(set) var availableLenses: [Lens] = []
    private(set) var exposureRange: ExposureRange?

    init(initialLens: Lens = DeviceLookup.defaultLens(), initialFormat: PhotoFormat = .rawPlusHEIF) {
        self.activeLens = initialLens
        self.activeFormat = initialFormat
    }

    nonisolated func connect(to view: PreviewView) {
        let session = self.session
        Task { @MainActor in
            view.session = session

            let shim = PreviewLayerShim(layer: view.previewLayer)
            await self.setPreviewLayer(shim)
        }
    }

    private func setPreviewLayer(_ shim: PreviewLayerShim) {
        self.previewLayer = shim.layer
        tryAttachRotation()
    }

    private func tryAttachRotation() {
        guard let device = activeDevice, let layer = previewLayer else { return }

        let ctx = RotationAttachContext(device: device, layer: layer, output: photoOutput)
        Task { @MainActor in
            let listener = await self.getOrCreateRotationListener()
            listener.attach(device: ctx.device, previewLayer: ctx.layer, photoOutput: ctx.output)
        }
    }

    private func getOrCreateRotationListener() async -> RotationListener {
        if let existing = rotationListener { return existing }
        let listener = await RotationListener()
        rotationListener = listener
        return listener
    }

    func start() async throws {
        try await ensureCameraAuthorization()
        if !isConfigured {
            try configureInitial()
        }
        if !session.isRunning {
            session.startRunning()
        }
        tryAttachRotation()
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func currentLens() -> Lens { activeLens }
    func currentFormat() -> PhotoFormat { activeFormat }
    func currentDevice() -> AVCaptureDevice? { activeDevice }

    func setFormat(_ format: PhotoFormat) {
        activeFormat = format
    }

    func setUseComputational(_ value: Bool) {
        useComputational = value
        if let device = activeDevice {
            PhotoCapture.configure(photoOutput, for: device, useComputational: value)
        }
    }

    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        flashMode = mode
    }

    func currentDeviceHasFlash() -> Bool {
        activeDevice?.hasFlash ?? false
    }

    func selectLens(_ lens: Lens) throws {
        guard lens != activeLens else { return }
        guard let newDevice = DeviceLookup.device(for: lens) else {
            throw CameraError.noDeviceAvailable
        }

        let previousInput = activeInput
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let previousInput {
            session.removeInput(previousInput)
        }

        func restorePrevious() throws {
            if let previousInput, session.canAddInput(previousInput) {
                session.addInput(previousInput)
            } else {
                activeInput = nil
                activeDevice = nil
                throw CameraError.cannotAddInput
            }
        }

        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: newDevice)
        } catch {
            try restorePrevious()
            throw CameraError.cannotAddInput
        }

        guard session.canAddInput(newInput) else {
            try restorePrevious()
            throw CameraError.cannotAddInput
        }
        session.addInput(newInput)
        activeInput = newInput
        activeDevice = newDevice
        activeLens = lens
        exposureRange = ManualControls.exposureRange(for: newDevice)

        PhotoCapture.configure(photoOutput, for: newDevice, useComputational: useComputational)
        configureCameraControls(for: newDevice)
        applyFaceDrivenAutoOverrideToActiveDevice()

        tryAttachRotation()
    }

    func capturePhoto(
        location: CLLocation? = nil,
        aspectRatio: AspectRatio = .fullScreen
    ) async throws -> CapturedPhoto {
        let settings = PhotoCapture.makeSettings(
            for: activeFormat,
            from: photoOutput,
            useComputational: useComputational,
            flashMode: flashMode,
            location: location
        )
        let id = settings.uniqueID

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let processor = PhotoCaptureProcessor(
                    uniqueID: id,
                    aspectRatio: aspectRatio
                ) { [weak self] result in
                    Task { [weak self] in
                        await self?.removeProcessor(id: id)
                    }
                    continuation.resume(with: result)
                }
                processors[id] = processor
                photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        } onCancel: {
            Task { [weak self] in
                await self?.cancelCapture(id: id)
            }
        }
    }

    private func cancelCapture(id: Int64) {
        guard let processor = processors.removeValue(forKey: id) else { return }
        processor.cancel()
    }

    func setExposureCustom(duration: CMTime, iso: Float) throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setExposureCustom(on: device, duration: duration, iso: iso)
    }

    func setExposureAuto() throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setExposureAuto(on: device)
    }

    func setExposureBias(_ bias: Float) throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setExposureBias(on: device, bias: bias)
    }

    func setFocusLocked(lensPosition: Float) throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setFocusLocked(on: device, lensPosition: lensPosition)
    }

    func setFocusAuto() throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setFocusAuto(on: device)
    }

    func setFocusAndExposurePoint(_ point: CGPoint) throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setFocusAndExposurePoint(on: device, point: point)
    }

    func setContinuousFocusAndExposurePoint(_ point: CGPoint) throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setContinuousFocusAndExposurePoint(on: device, point: point)
    }

    func resetContinuousFocusAndExposure() throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.resetContinuousFocusAndExposure(on: device)
    }

    func setWhiteBalanceLocked(temperature: Float, tint: Float) throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setWhiteBalanceLocked(on: device, temperature: temperature, tint: tint)
    }

    func setWhiteBalanceAuto() throws {
        guard let device = activeDevice else { throw CameraError.noDeviceAvailable }
        try ManualControls.setWhiteBalanceAuto(on: device)
    }

    func setDetectionsListener(_ listener: (@Sendable ([DetectedObject]) -> Void)?) {
        detectionListener = listener
    }

    func setEnabledDetectionTypes(_ types: [AVMetadataObject.ObjectType]) {
        guard isConfigured else { return }
        let available = Set(metadataOutput.availableMetadataObjectTypes)
        let intersected = types.filter { available.contains($0) }
        metadataOutput.metadataObjectTypes = intersected
        applyFaceDrivenAutoOverrideToActiveDevice()
    }

    private func applyFaceDrivenAutoOverrideToActiveDevice() {
        guard let device = activeDevice else { return }
        let active = metadataOutput.metadataObjectTypes.contains(.face)
        try? ManualControls.setFaceDrivenAutoOverride(on: device, override: active)
    }

    private func publishDetections(_ objects: [AVMetadataObject]) {
        guard let listener = detectionListener else { return }
        let mapped: [DetectedObject] = objects.compactMap { obj in
            guard let type = DetectionType(metadataObjectType: obj.type) else { return nil }
            return DetectedObject(id: 0, type: type, bounds: obj.bounds)
        }
        listener(mapped)
    }

    private func removeProcessor(id: Int64) {
        processors[id] = nil
    }

    private func ensureCameraAuthorization() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CameraError.cameraUnauthorized }
        default:
            throw CameraError.cameraUnauthorized
        }
    }

    private func configureInitial() throws {
        availableLenses = DeviceLookup.availableLenses()
        if availableLenses.isEmpty {
            throw CameraError.noDeviceAvailable
        }
        if !availableLenses.contains(activeLens) {
            activeLens = availableLenses.first!
        }
        guard let device = DeviceLookup.device(for: activeLens) else {
            throw CameraError.noDeviceAvailable
        }

        session.beginConfiguration()
        var success = false
        var addedInput: AVCaptureDeviceInput?
        var addedPhotoOutput = false
        var addedMetadataOutput = false
        defer {
            if !success {
                if let i = addedInput { session.removeInput(i) }
                if addedPhotoOutput { session.removeOutput(photoOutput) }
                if addedMetadataOutput { session.removeOutput(metadataOutput) }
            }
            session.commitConfiguration()
        }

        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.cannotAddInput
        }
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        addedInput = input

        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        addedPhotoOutput = true
        PhotoCapture.configure(photoOutput, for: device, useComputational: useComputational)

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            addedMetadataOutput = true
            let handler = MetadataHandler { [weak self] objects in
                guard let self else { return }
                Task { await self.publishDetections(objects) }
            }
            metadataHandler = handler
            metadataOutput.setMetadataObjectsDelegate(handler, queue: metadataQueue)
        }

        configureCameraControls(for: device)

        activeInput = input
        activeDevice = device
        exposureRange = ManualControls.exposureRange(for: device)
        success = true
        isConfigured = true
    }

    private func configureCameraControls(for device: AVCaptureDevice) {
        guard session.supportsControls else { return }

        for control in session.controls {
            session.removeControl(control)
        }

        let exposureBiasSlider = AVCaptureSystemExposureBiasSlider(device: device)
        if session.canAddControl(exposureBiasSlider) {
            session.addControl(exposureBiasSlider)
        }

        let zoomSlider = AVCaptureSystemZoomSlider(device: device)
        if session.canAddControl(zoomSlider) {
            session.addControl(zoomSlider)
        }
    }
}

@MainActor
final class RotationListener {
    private var coord: AVCaptureDevice.RotationCoordinator?
    private var previewObservation: NSKeyValueObservation?
    private var captureObservation: NSKeyValueObservation?

    func attach(
        device: AVCaptureDevice,
        previewLayer: AVCaptureVideoPreviewLayer,
        photoOutput: AVCapturePhotoOutput
    ) {
        previewObservation = nil
        captureObservation = nil

        let coord = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.coord = coord

        previewLayer.connection?.videoRotationAngle = coord.videoRotationAngleForHorizonLevelPreview
        photoOutput.connection(with: .video)?.videoRotationAngle = coord.videoRotationAngleForHorizonLevelCapture

        let layerRef = WeakRef(previewLayer)
        let outputRef = WeakRef(photoOutput)

        previewObservation = coord.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new]
        ) { _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                layerRef.value?.connection?.videoRotationAngle = angle
            }
        }
        captureObservation = coord.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                outputRef.value?.connection(with: .video)?.videoRotationAngle = angle
            }
        }
    }
}

private struct RotationAttachContext: @unchecked Sendable {
    let device: AVCaptureDevice
    let layer: AVCaptureVideoPreviewLayer
    let output: AVCapturePhotoOutput
}

private struct PreviewLayerShim: @unchecked Sendable {
    let layer: AVCaptureVideoPreviewLayer
}

private final class WeakRef<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
