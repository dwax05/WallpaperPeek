import AppKit
import CoreGraphics
import UniformTypeIdentifiers

struct Wallpaper: Equatable {
    let url: URL
    var name: String { url.deletingPathExtension().lastPathComponent }
}

final class WallpaperEngine {

    static let supportedExt: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic"]

    static var wallpaperDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/wallpapers")
    }

    static let cacheDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/wallpaperpeek")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func listWallpapers(in dir: URL = wallpaperDir) -> [Wallpaper] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items
            .filter { supportedExt.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
            .map { Wallpaper(url: $0) }
    }

    // Immediate subdirectories of `dir` (non-recursive; descend one level at a
    // time as the user navigates). Hidden dirs skipped.
    static func listSubdirectories(in dir: URL) -> [URL] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
    }

    private static func cacheKey(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int) ?? 0
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let sig = "\(url.path):\(size):\(mtime)"
        return sig.data(using: .utf8)!.md5Hex
    }

    private static let memCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 64   
        return c
    }()

    static func memThumbnail(_ url: URL) -> NSImage? {
        return memCache.object(forKey: url.path as NSString)
    }

    private static func storeMem(_ url: URL, _ img: NSImage) {
        memCache.setObject(img, forKey: url.path as NSString)
    }

    static func prewarm(width: Int, height: Int) {
        DispatchQueue.global(qos: .utility).async {
            for wp in listWallpapers() { _ = thumbnail(for: wp.url, width: width, height: height) }
        }
    }

    static func thumbnail(for url: URL, width: Int, height: Int) -> NSImage? {
        if let mem = memThumbnail(url) { return mem }

        let key = cacheKey(url)
        let cachePath = cacheDir.appendingPathComponent("\(key).png")

        if let cached = NSImage(contentsOf: cachePath) {
            storeMem(url, cached)
            return cached
        }

        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let full = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return nil
        }

        let iw = CGFloat(full.width)
        let ih = CGFloat(full.height)
        let targetRatio = CGFloat(width) / CGFloat(height)
        let imgRatio = iw / ih

        var cropRect: CGRect
        if imgRatio > targetRatio {
            let nw = ih * targetRatio
            cropRect = CGRect(x: (iw - nw) / 2, y: 0, width: nw, height: ih)
        } else {
            let nh = iw / targetRatio
            cropRect = CGRect(x: 0, y: (ih - nh) / 2, width: iw, height: nh)
        }

        guard let cropped = full.cropping(to: cropRect) else { return nil }

        let target = NSSize(width: width, height: height)
        let out = NSImage(size: target)
        out.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .medium
        NSImage(cgImage: cropped, size: target).draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero, operation: .copy, fraction: 1.0
        )
        out.unlockFocus()

        if let tiff = out.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: cachePath)
        }

        return out
    }

    static func currentWallpaper() -> String? {
        let script = "tell application \"System Events\" to tell current desktop to get picture as text"
        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = ["-e", script]
        let pipe = Pipe()
        osa.standardOutput = pipe
        osa.standardError = Pipe()
        try? osa.run()
        osa.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return out
    }

    static func setWallpaper(_ url: URL) {
        let path = url.path

        // Only set the desktop picture on every display. Retheming (pywal +
        // postrun) is owned by the fswatch wal-watch agent, which fires on the
        // Index.plist write this osascript triggers. Running wal/postrun here as
        // well produced a double retheme: two bar reloads and two notifications
        // per wallpaper change. Single source of truth = the watcher (it also
        // covers wallpaper changes made outside WallpaperPeek).
        let script = "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"\(path)\""
        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = ["-e", script]
        try? osa.run()
        osa.waitUntilExit()
    }
}

extension Data {
    var md5Hex: String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in self {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016x", hash)
    }
}
