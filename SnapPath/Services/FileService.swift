import Cocoa

enum FileService {
    static func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.dateFormat
        let timestamp = formatter.string(from: Date())
        return "\(Constants.screenshotPrefix)_\(timestamp).\(Constants.fileExtension)"
    }

    static func saveScreenshot(_ image: CGImage) throws -> URL {
        let settings = AppSettings.shared
        var directory = settings.saveDirectory

        // Fallback to ~/Downloads if directory doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory) {
            directory = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first
                ?? NSHomeDirectory() + "/Downloads"
        }

        let filename = generateFilename()
        let url = URL(fileURLWithPath: directory).appendingPathComponent(filename)

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw FileServiceError.pngEncodingFailed
        }

        try pngData.write(to: url)
        return url
    }
}

enum FileServiceError: LocalizedError {
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .pngEncodingFailed:
            return "Failed to encode screenshot as PNG"
        }
    }
}
