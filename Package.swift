// swift-tools-version:6.0

import PackageDescription

let _ =
    Package(name: "tcrun",
            products: [
              .executable(name: "tcrun", targets: ["tcrun"]),
            ],
            dependencies: [
              .package(url: "https://github.com/apple/swift-argument-parser",
                        from: "1.5.0"),
            ],
            targets: [
              .executableTarget(name: "tcrun",
                                dependencies: [
                                  .product(name: "ArgumentParser", package: "swift-argument-parser")
                                ],
                                swiftSettings: [
                                  .enableExperimentalFeature("AccessLevelOnImport"),
                                  .unsafeFlags(["-parse-as-library"])
                                ],
                                plugins: [
                                  .plugin(name: "PackageVersion"),
                                ]),
              .plugin(name: "PackageVersion", capability: .buildTool)
            ])
