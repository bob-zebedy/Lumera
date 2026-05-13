import AVFoundation
import CoreMedia

struct ExposureRange: Sendable {
    let minISO: Float
    let maxISO: Float
    let minDuration: CMTime
    let maxDuration: CMTime
    let minBias: Float
    let maxBias: Float
}

struct WhiteBalanceRange: Sendable {
    static let minTemperature: Float = 2000
    static let maxTemperature: Float = 9000
    static let minTint: Float = -150
    static let maxTint: Float = 150
}

enum ManualControls {

    static func exposureRange(for device: AVCaptureDevice) -> ExposureRange {
        ExposureRange(
            minISO: device.activeFormat.minISO,
            maxISO: device.activeFormat.maxISO,
            minDuration: device.activeFormat.minExposureDuration,
            maxDuration: device.activeFormat.maxExposureDuration,
            minBias: device.minExposureTargetBias,
            maxBias: device.maxExposureTargetBias
        )
    }

    static func setExposureCustom(
        on device: AVCaptureDevice,
        duration: CMTime,
        iso: Float
    ) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        guard device.isExposureModeSupported(.custom) else { return }
        let range = exposureRange(for: device)
        let clampedISO = min(max(iso, range.minISO), range.maxISO)
        let clampedDuration = clampDuration(duration, min: range.minDuration, max: range.maxDuration)
        device.setExposureModeCustom(duration: clampedDuration, iso: clampedISO, completionHandler: nil)
    }

    static func setExposureAuto(on device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }

    static func setExposureBias(on device: AVCaptureDevice, bias: Float) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        device.setExposureTargetBias(clamped, completionHandler: nil)
    }

    static func setFocusLocked(on device: AVCaptureDevice, lensPosition: Float) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        guard device.isLockingFocusWithCustomLensPositionSupported else { return }
        let pos = min(max(lensPosition, 0), 1)
        device.setFocusModeLocked(lensPosition: pos, completionHandler: nil)
    }

    static func setFocusAuto(on device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
    }

    static func setFocusAndExposurePoint(on device: AVCaptureDevice, point: CGPoint) throws {
        try applyFocusAndExposurePOI(
            on: device, point: point,
            focusMode: .autoFocus, exposureMode: .autoExpose
        )
    }

    static func setContinuousFocusAndExposurePoint(on device: AVCaptureDevice, point: CGPoint) throws {
        try applyFocusAndExposurePOI(
            on: device, point: point,
            focusMode: .continuousAutoFocus, exposureMode: .continuousAutoExposure
        )
    }

    static func resetContinuousFocusAndExposure(on device: AVCaptureDevice) throws {
        try applyFocusAndExposurePOI(
            on: device, point: CGPoint(x: 0.5, y: 0.5),
            focusMode: .continuousAutoFocus, exposureMode: .continuousAutoExposure
        )
    }

    private static func applyFocusAndExposurePOI(
        on device: AVCaptureDevice,
        point: CGPoint,
        focusMode: AVCaptureDevice.FocusMode,
        exposureMode: AVCaptureDevice.ExposureMode
    ) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
            device.focusPointOfInterest = point
            device.focusMode = focusMode
        }

        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
            device.exposurePointOfInterest = point
            device.exposureMode = exposureMode
        }
    }

    static func setFaceDrivenAutoOverride(on device: AVCaptureDevice, override: Bool) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if override {
            device.automaticallyAdjustsFaceDrivenAutoFocusEnabled = false
            if device.isFaceDrivenAutoFocusEnabled {
                device.isFaceDrivenAutoFocusEnabled = false
            }
            device.automaticallyAdjustsFaceDrivenAutoExposureEnabled = false
            if device.isFaceDrivenAutoExposureEnabled {
                device.isFaceDrivenAutoExposureEnabled = false
            }
        } else {
            device.automaticallyAdjustsFaceDrivenAutoFocusEnabled = true
            device.automaticallyAdjustsFaceDrivenAutoExposureEnabled = true
        }
    }

    static func setWhiteBalanceLocked(
        on device: AVCaptureDevice,
        temperature: Float,
        tint: Float
    ) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        guard device.isWhiteBalanceModeSupported(.locked) else { return }

        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: temperature,
            tint: tint
        )
        var gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
        gains = clampGains(gains, maxGain: device.maxWhiteBalanceGain)
        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
    }

    static func setWhiteBalanceAuto(on device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
    }

    private static func clampGains(
        _ gains: AVCaptureDevice.WhiteBalanceGains,
        maxGain: Float
    ) -> AVCaptureDevice.WhiteBalanceGains {
        var g = gains
        let lowerBound: Float = 1.0
        g.redGain   = min(max(g.redGain,   lowerBound), maxGain)
        g.greenGain = min(max(g.greenGain, lowerBound), maxGain)
        g.blueGain  = min(max(g.blueGain,  lowerBound), maxGain)
        return g
    }

    private static func clampDuration(_ value: CMTime, min minVal: CMTime, max maxVal: CMTime) -> CMTime {
        if CMTimeCompare(value, minVal) < 0 { return minVal }
        if CMTimeCompare(value, maxVal) > 0 { return maxVal }
        return value
    }
}
