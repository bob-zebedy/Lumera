import AVFoundation
import CoreLocation

enum PhotoCapture {

    static func configure(
        _ output: AVCapturePhotoOutput,
        for device: AVCaptureDevice,
        useComputational: Bool
    ) {
        output.maxPhotoQualityPrioritization = useComputational ? .quality : .speed

        if output.isAppleProRAWSupported {
            output.isAppleProRAWEnabled = true
        }

        if let max = device.activeFormat.supportedMaxPhotoDimensions.last {
            output.maxPhotoDimensions = max
        }
    }

    static func makeSettings(
        for format: PhotoFormat,
        from output: AVCapturePhotoOutput,
        useComputational: Bool,
        flashMode: AVCaptureDevice.FlashMode = .off,
        location: CLLocation? = nil
    ) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        switch format {
        case .heif:
            settings = makeHEIFSettings(output)
        case .raw:
            settings = makeRAWSettings(output) ?? makeHEIFSettings(output)
        case .rawPlusHEIF:
            settings = makeRAWPlusHEIFSettings(output) ?? makeHEIFSettings(output)
        }
        applyCommon(
            settings,
            output: output,
            useComputational: useComputational,
            flashMode: flashMode,
            location: location
        )
        return settings
    }

    private static func makeHEIFSettings(_ output: AVCapturePhotoOutput) -> AVCapturePhotoSettings {
        if output.availablePhotoCodecTypes.contains(.hevc) {
            return AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        return AVCapturePhotoSettings()
    }

    private static func makeRAWSettings(_ output: AVCapturePhotoOutput) -> AVCapturePhotoSettings? {
        guard let rawFormat = pickRAWFormat(output) else { return nil }
        return AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
    }

    private static func makeRAWPlusHEIFSettings(_ output: AVCapturePhotoOutput) -> AVCapturePhotoSettings? {
        guard let rawFormat = pickRAWFormat(output) else { return nil }
        let processed: [String: Any]
        if output.availablePhotoCodecTypes.contains(.hevc) {
            processed = [AVVideoCodecKey: AVVideoCodecType.hevc]
        } else {
            processed = [AVVideoCodecKey: AVVideoCodecType.jpeg]
        }
        return AVCapturePhotoSettings(
            rawPixelFormatType: rawFormat,
            processedFormat: processed
        )
    }

    private static func applyCommon(
        _ settings: AVCapturePhotoSettings,
        output: AVCapturePhotoOutput,
        useComputational: Bool,
        flashMode: AVCaptureDevice.FlashMode,
        location: CLLocation?
    ) {
        settings.photoQualityPrioritization = useComputational ? .quality : .speed
        settings.flashMode = output.supportedFlashModes.contains(flashMode) ? flashMode : .off
        settings.isAutoRedEyeReductionEnabled = false
        settings.maxPhotoDimensions = output.maxPhotoDimensions

        if let firstFormat = settings.availablePreviewPhotoPixelFormatTypes.first {
            let target = previewTargetSize(for: output)
            settings.previewPhotoFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: firstFormat,
                kCVPixelBufferWidthKey as String: target,
                kCVPixelBufferHeightKey as String: target
            ]
        }

        if let location {
            var meta = settings.metadata
            meta[kCGImagePropertyGPSDictionary as String] = gpsDictionary(from: location)
            settings.metadata = meta
        }
    }

    private static func previewTargetSize(for output: AVCapturePhotoOutput) -> Int {
        let dim = output.maxPhotoDimensions
        let longest = Int(max(dim.width, dim.height))
        guard longest > 0 else { return 2048 }
        return max(1920, min(4096, longest / 2))
    }

    private static func pickRAWFormat(_ output: AVCapturePhotoOutput) -> OSType? {
        let proRAWEnabled = output.isAppleProRAWEnabled
        let predicate: (OSType) -> Bool = proRAWEnabled
            ? { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }
            : { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
        return output.availableRawPhotoPixelFormatTypes.first(where: predicate)
            ?? output.availableRawPhotoPixelFormatTypes.first
    }

    private static func gpsDictionary(from location: CLLocation) -> [String: Any] {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let alt = location.altitude
        var dict: [String: Any] = [
            kCGImagePropertyGPSLatitude as String:  abs(lat),
            kCGImagePropertyGPSLatitudeRef as String:  lat >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(lon),
            kCGImagePropertyGPSLongitudeRef as String: lon >= 0 ? "E" : "W",
            kCGImagePropertyGPSAltitude as String: abs(alt),
            kCGImagePropertyGPSAltitudeRef as String: alt >= 0 ? 0 : 1
        ]

        dict[kCGImagePropertyGPSTimeStamp as String] = gpsTimeFormatter.string(from: location.timestamp)
        dict[kCGImagePropertyGPSDateStamp as String] = gpsDateFormatter.string(from: location.timestamp)
        return dict
    }

    private static let gpsTimeFormatter = utcFormatter("HH:mm:ss")
    private static let gpsDateFormatter = utcFormatter("yyyy:MM:dd")

    private static func utcFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }
}
