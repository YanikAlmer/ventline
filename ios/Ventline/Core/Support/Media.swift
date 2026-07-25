import AVFoundation
import Foundation
import Supabase
import UIKit

/// Downscale + JPEG-compress camera images before upload (max 2048 px edge).
enum ImageDownscaler {
    static func jpegData(from image: UIImage, maxDimension: CGFloat = 2048, quality: CGFloat = 0.8) -> (data: Data, width: Int, height: Int)? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = rendered.jpegData(compressionQuality: quality) else { return nil }
        return (data, Int(target.width), Int(target.height))
    }
}

/// Short-lived signed URLs for private storage objects, cached per path.
actor SignedURLCache {
    static let shared = SignedURLCache()

    private var cache: [String: (url: URL, expires: Date)] = [:]
    private let lifetime: TimeInterval = 55 * 60

    func url(bucket: String, path: String) async throws -> URL {
        let key = "\(bucket)/\(path)"
        if let hit = cache[key], hit.expires > Date() {
            return hit.url
        }
        let url = try await Supa.client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 60 * 60)
        cache[key] = (url, Date().addingTimeInterval(lifetime))
        return url
    }
}

/// Uploads job-site media. Storage RLS requires paths shaped as
/// {company_id}/{project_id}/{group-uuid}/{file} — segments 1 and 2 are
/// checked against the uploader's company and project membership.
enum MediaUploader {
    struct Uploaded {
        let bucket: String
        let path: String
        let mimeType: String
        let byteSize: Int
        var width: Int?
        var height: Int?
        var durationSeconds: Double?

        /// The bucket is the single source of truth for the kind, so a message
        /// attachment and a task attachment can never disagree about it.
        var attachmentKind: AttachmentKind {
            switch bucket {
            case "voice": .voice
            case "video": .video
            default: .photo
            }
        }

        var attachmentPayload: [String: AnyJSON] {
            var payload: [String: AnyJSON] = [
                "kind": .string(attachmentKind.rawValue),
                "storage_bucket": .string(bucket),
                "storage_path": .string(path),
                "mime_type": .string(mimeType),
                "byte_size": .integer(byteSize),
            ]
            if let width { payload["width"] = .integer(width) }
            if let height { payload["height"] = .integer(height) }
            if let durationSeconds { payload["duration_seconds"] = .double(durationSeconds) }
            return payload
        }
    }

    /// The video bucket's limits, mirrored client-side so a 300 MB clip fails
    /// before it is uploaded rather than after.
    static let maxVideoBytes = 200 * 1024 * 1024
    static let allowedVideoTypes = ["video/mp4", "video/quicktime"]

    static func uploadPhoto(_ image: UIImage, companyId: UUID, projectId: UUID) async throws -> Uploaded {
        guard let jpeg = ImageDownscaler.jpegData(from: image) else {
            throw NSError(domain: "Ventline", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode photo"])
        }
        let path = makePath(companyId: companyId, projectId: projectId, ext: "jpg")
        try await Supa.client.storage.from("photos").upload(
            path,
            data: jpeg.data,
            options: FileOptions(contentType: "image/jpeg")
        )
        return Uploaded(
            bucket: "photos", path: path, mimeType: "image/jpeg",
            byteSize: jpeg.data.count, width: jpeg.width, height: jpeg.height
        )
    }

    static func uploadVoice(fileURL: URL, duration: Double, companyId: UUID, projectId: UUID) async throws -> Uploaded {
        let data = try Data(contentsOf: fileURL)
        let path = makePath(companyId: companyId, projectId: projectId, ext: "m4a")
        try await Supa.client.storage.from("voice").upload(
            path,
            data: data,
            options: FileOptions(contentType: "audio/mp4")
        )
        return Uploaded(
            bucket: "voice", path: path, mimeType: "audio/mp4",
            byteSize: data.count, durationSeconds: duration
        )
    }

    /// Uploads a video already on disk (PhotosPicker hands us a file URL).
    /// The clip is sent as-is: transcoding on-device would cost minutes of
    /// battery on a jobsite, and the 200 MB ceiling already bounds the upload.
    static func uploadVideo(fileURL: URL, companyId: UUID, projectId: UUID) async throws -> Uploaded {
        let mime = mimeType(for: fileURL)
        guard allowedVideoTypes.contains(mime) else {
            throw MediaError.unsupportedVideo
        }
        let data = try Data(contentsOf: fileURL)
        guard data.count <= maxVideoBytes else {
            throw MediaError.videoTooLarge
        }
        let path = makePath(
            companyId: companyId, projectId: projectId,
            ext: fileURL.pathExtension.isEmpty ? "mp4" : fileURL.pathExtension.lowercased()
        )
        try await Supa.client.storage.from("video").upload(
            path,
            data: data,
            options: FileOptions(contentType: mime)
        )
        let duration = try? await AVURLAsset(url: fileURL).load(.duration).seconds
        return Uploaded(
            bucket: "video", path: path, mimeType: mime,
            byteSize: data.count,
            durationSeconds: duration.flatMap { $0.isFinite ? $0 : nil }
        )
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mov": "video/quicktime"
        case "mp4", "m4v": "video/mp4"
        default: "application/octet-stream"
        }
    }

    enum MediaError: LocalizedError {
        case unsupportedVideo
        case videoTooLarge

        var errorDescription: String? {
            switch self {
            case .unsupportedVideo:
                String(localized: "Only MP4 and MOV videos can be uploaded.")
            case .videoTooLarge:
                String(localized: "Videos can be at most 200 MB.")
            }
        }
    }

    private static func makePath(companyId: UUID, projectId: UUID, ext: String) -> String {
        "\(companyId.uuidString.lowercased())/\(projectId.uuidString.lowercased())/\(UUID().uuidString.lowercased())/\(UUID().uuidString.lowercased()).\(ext)"
    }
}
