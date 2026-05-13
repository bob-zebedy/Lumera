import AVFoundation

struct DeviceLookup {
    static let physicalDeviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
        .builtInTelephotoCamera
    ]

    static func availableLenses() -> [Lens] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: physicalDeviceTypes,
            mediaType: .video,
            position: .back
        )
        let presentTypes = Set(session.devices.map { $0.deviceType })
        return Lens.allCases.filter { presentTypes.contains($0.deviceType) }
    }

    static func device(for lens: Lens) -> AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [lens.deviceType],
            mediaType: .video,
            position: .back
        )
        return session.devices.first
    }

    static func defaultLens() -> Lens {
        let available = availableLenses()
        if available.contains(.wide) { return .wide }
        return available.first ?? .wide
    }

    static func zoomFactors() -> [Lens: Double] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualCamera,
                .builtInDualWideCamera
            ],
            mediaType: .video,
            position: .back
        )
        guard let virtual = session.devices.first else {
            return fallbackZoomFactors()
        }

        let constituents = virtual.constituentDevices
        let switchOvers = virtual.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)

        let wideBase: Double
        if constituents.first?.deviceType == .builtInUltraWideCamera {
            wideBase = switchOvers.first ?? 1.0
        } else {
            wideBase = 1.0
        }

        let zoomLevels = [1.0] + switchOvers
        var result: [Lens: Double] = [:]
        for (device, virtualZoom) in zip(constituents, zoomLevels) {
            if let lens = Lens.from(deviceType: device.deviceType) {
                result[lens] = virtualZoom / wideBase
            }
        }

        let fallback = fallbackZoomFactors()
        for lens in availableLenses() where result[lens] == nil {
            result[lens] = fallback[lens]
        }
        return result
    }

    private static func fallbackZoomFactors() -> [Lens: Double] {
        [.ultraWide: 0.5, .wide: 1.0, .telephoto: 3.0]
    }
}
