// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WallpaperPeek",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WallpaperPeek",
            path: "Sources/WallpaperPeek"
        )
    ]
)
