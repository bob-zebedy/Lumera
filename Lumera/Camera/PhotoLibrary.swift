import Photos
import Foundation

enum PhotoLibrary {
    
    private static let albumName = "Lumera"

    static func requestAuthorization(for level: PHAccessLevel) async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: level) { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func save(_ photo: CapturedPhoto) async throws {
        var writeStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if writeStatus == .notDetermined {
            writeStatus = await requestAuthorization(for: .readWrite)
        }
        let canManageAlbum = (writeStatus == .authorized)

        let canSave: Bool
        if writeStatus == .authorized || writeStatus == .limited {
            canSave = true
        } else {
            var addStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if addStatus == .notDetermined {
                addStatus = await requestAuthorization(for: .addOnly)
            }
            canSave = (addStatus == .authorized || addStatus == .limited)
        }
        guard canSave else { throw CameraError.photoLibraryUnauthorized }

        do {
            try await CameraOperationTimeout.run(seconds: 30, as: .save) {
                try await performLibraryChange {
                    let request = PHAssetCreationRequest.forAsset()

                    if let rawURL = photo.rawFileURL {
                        let rawOptions = PHAssetResourceCreationOptions()
                        rawOptions.shouldMoveFile = true
                        request.addResource(with: .photo, fileURL: rawURL, options: rawOptions)

                        if let processedURL = photo.processedFileURL {
                            let altOptions = PHAssetResourceCreationOptions()
                            altOptions.shouldMoveFile = true
                            request.addResource(with: .alternatePhoto, fileURL: processedURL, options: altOptions)
                        }
                    } else if let processedURL = photo.processedFileURL {
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        request.addResource(with: .photo, fileURL: processedURL, options: options)
                    }

                    guard canManageAlbum, let placeholder = request.placeholderForCreatedAsset else { return }

                    let fetchOptions = PHFetchOptions()
                    fetchOptions.predicate = NSPredicate(format: "localizedTitle = %@", albumName)
                    let collections = PHAssetCollection.fetchAssetCollections(
                        with: .album, subtype: .albumRegular, options: fetchOptions
                    )
                    let albumChangeRequest: PHAssetCollectionChangeRequest?
                    if let existing = collections.firstObject {
                        albumChangeRequest = PHAssetCollectionChangeRequest(for: existing)
                    } else {
                        albumChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    }
                    albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
                }
            }
        } catch {

            cleanupTempFiles(photo)
            throw error
        }
    }

    private static func cleanupTempFiles(_ photo: CapturedPhoto) {
        let fm = FileManager.default
        if let url = photo.rawFileURL { try? fm.removeItem(at: url) }
        if let url = photo.processedFileURL { try? fm.removeItem(at: url) }
    }

    private static func performLibraryChange(_ changeBlock: @escaping @Sendable () -> Void) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                changeBlock()
            }, completionHandler: { success, error in
                if let error {
                    cont.resume(throwing: error)
                } else if success {
                    cont.resume(returning: ())
                } else {
                    cont.resume(throwing: NSError(
                        domain: PHPhotosErrorDomain,
                        code: PHPhotosError.userCancelled.rawValue,
                        userInfo: nil
                    ))
                }
            })
        }
    }
}
