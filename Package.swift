// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ddaka",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "ddaka",
            path: "Sources/ddaka",
            // 🚨 2026-08-12: 입력 모니터링 권한을 요청하려면 IOKit(IOHIDRequestAccess)이 필요
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
