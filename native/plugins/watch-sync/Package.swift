// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlushbucketWatchSync",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "PlushbucketWatchSync", targets: ["WatchSyncPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "WatchSyncPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/WatchSyncPlugin")
    ]
)
