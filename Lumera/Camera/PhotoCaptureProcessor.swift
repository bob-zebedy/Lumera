import AVFoundation
import UIKit
import ImageIO
import CoreImage
import os

struct CapturedPhoto: Sendable {
    let rawFileURL: URL?
    let processedFileURL: URL?
    let thumbnail: Data?
}

final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {

    let uniqueID: Int64
    private let completion: @Sendable (Result<CapturedPhoto, Error>) -> Void
    private let baseFileName: String
    private let aspectRatio: AspectRatio

    private var rawFileURL: URL?
    private var processedFileURL: URL?
    private var thumbnail: Data?
    private var pendingError: Error?
    private let completionLock = OSAllocatedUnfairLock<Bool>(initialState: false)

    init(
        uniqueID: Int64,
        aspectRatio: AspectRatio = .fullScreen,
        completion: @escaping @Sendable (Result<CapturedPhoto, Error>) -> Void
    ) {
        self.uniqueID = uniqueID
        self.aspectRatio = aspectRatio
        self.completion = completion
        self.baseFileName = Self.makeBaseFileName(uniqueID: uniqueID)
    }

    private static let fileNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return f
    }()

    private static func makeBaseFileName(uniqueID: Int64) -> String {
        "Lumera_\(fileNameFormatter.string(from: Date()))_\(uniqueID)"
    }

    private func finish(_ result: Result<CapturedPhoto, Error>) {
        let firstCompletion = completionLock.withLock { done -> Bool in
            guard !done else { return false }
            done = true
            return true
        }
        guard firstCompletion else { return }
        completion(result)
    }

    func cancel(with error: Error = CancellationError()) {
        finish(.failure(error))
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            pendingError = error
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            if pendingError == nil {
                pendingError = CameraError.captureFailed(underlying: nil)
            }
            return
        }

        let ext: String
        if photo.isRawPhoto {
            ext = "dng"
        } else {
            ext = Self.imageExtension(for: data)
        }

        let outputData: Data
        if photo.isRawPhoto {
            outputData = data
        } else {
            outputData = Self.cropProcessedData(data, to: aspectRatio) ?? data
        }

        let url = makeFileURL(ext: ext)
        do {
            try outputData.write(to: url)
        } catch {
            if pendingError == nil {
                pendingError = CameraError.captureFailed(underlying: error)
            }
            return
        }

        if photo.isRawPhoto {
            rawFileURL = url
        } else {
            processedFileURL = url
        }

        if thumbnail == nil {
            thumbnail = Self.thumbnail(fromPreviewBufferOf: photo)
        }
        if thumbnail == nil, !photo.isRawPhoto, let cgImage = photo.cgImageRepresentation() {
            let orientation = Self.uiImageOrientation(from: photo.metadata)
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
            thumbnail = image.jpegData(compressionQuality: 0.85)
        }
    }

    private static func thumbnail(fromPreviewBufferOf photo: AVCapturePhoto) -> Data? {
        guard let buffer = photo.previewPixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let exif = (photo.metadata[kCGImagePropertyOrientation as String] as? UInt32) ?? 1
        let cgOrientation = CGImagePropertyOrientation(rawValue: exif) ?? .up
        let oriented = ciImage.oriented(cgOrientation)
        let context = CIContext()
        guard let cg = context.createCGImage(oriented, from: oriented.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.85)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            finish(.failure(CameraError.captureFailed(underlying: error)))
            return
        }
        if let pending = pendingError {
            finish(.failure(CameraError.captureFailed(underlying: pending)))
            return
        }
        if rawFileURL == nil && processedFileURL == nil {
            finish(.failure(CameraError.captureFailed(underlying: nil)))
            return
        }
        finish(.success(CapturedPhoto(
            rawFileURL: rawFileURL,
            processedFileURL: processedFileURL,
            thumbnail: thumbnail
        )))
    }

    private func makeFileURL(ext: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(baseFileName).appendingPathExtension(ext)
    }

    private static func cropProcessedData(_ data: Data, to ratio: AspectRatio) -> Data? {
        guard ratio.croppingProcessedPhoto else { return data }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let imageAspect = w / h
        let target = (imageAspect >= 1) ? ratio.widthOverHeight : 1 / ratio.widthOverHeight

        let cropRect: CGRect
        if imageAspect > target {
            let newW = h * target
            cropRect = CGRect(x: ((w - newW) / 2).rounded(), y: 0, width: newW.rounded(), height: h)
        } else {
            let newH = w / target
            cropRect = CGRect(x: 0, y: ((h - newH) / 2).rounded(), width: w, height: newH.rounded())
        }

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let utType = CGImageSourceGetType(source) ?? ("public.heic" as CFString)
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, utType, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cropped, metadata as CFDictionary?)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private static func imageExtension(for data: Data) -> String {
        if data.count >= 3,
           data[0] == 0xFF, data[1] == 0xD8, data[2] == 0xFF {
            return "jpg"
        }
        if data.count >= 12 {
            let ftypBytes = data.subdata(in: 4..<8)
            if let ftyp = String(data: ftypBytes, encoding: .ascii), ftyp == "ftyp" {
                return "heic"
            }
        }
        return "heic"
    }

    private static func uiImageOrientation(from metadata: [String: Any]) -> UIImage.Orientation {
        let key = kCGImagePropertyOrientation as String
        let raw = (metadata[key] as? UInt32) ?? 1
        let cg = CGImagePropertyOrientation(rawValue: raw) ?? .up
        switch cg {
        case .up:             return .up
        case .upMirrored:     return .upMirrored
        case .down:           return .down
        case .downMirrored:   return .downMirrored
        case .left:           return .left
        case .leftMirrored:   return .leftMirrored
        case .right:          return .right
        case .rightMirrored:  return .rightMirrored
        }
    }
}
