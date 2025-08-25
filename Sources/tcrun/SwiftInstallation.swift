// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WindowsCore

private nonisolated(unsafe) let kRegistryPaths = [
  (HKEY_LOCAL_MACHINE, #"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"#),
  (HKEY_CURRENT_USER, #"Software\Microsoft\Windows\CurrentVersion\Uninstall"#),
]

package struct SwiftInstallation {
  let system: Bool
  let vendor: String
  let version: Version
  let toolchains: [Toolchain]
  let platforms: PlatformCollection
}

private func EnumeratePlatforms(in DEVELOPER_DIR: URL, version: Version)
    throws -> PlatformCollection {
  let PlatformsVersioned =
      DEVELOPER_DIR.appending(components: "Platforms", version.description,
                              directoryHint: .isDirectory)
  // FIXME: can we enumerate the platforms from the installed packages?
  let platforms =
      try FileManager.default
          .contentsOfDirectory(at: PlatformsVersioned,
                               includingPropertiesForKeys: [.isDirectoryKey])
          .lazy
          .filter { entry in
            try entry.lastPathComponent.hasSuffix(".platform") &&
                entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
          }
          .map { platform in
            let root = platform.appending(components: "Developer", "SDKs",
                                          directoryHint: .isDirectory)
            let SDKs =
                try FileManager.default
                    .contentsOfDirectory(at: root,
                                         includingPropertiesForKeys: [.isDirectoryKey])
                    .filter { entry in
                      try entry.lastPathComponent.hasSuffix(".sdk") &&
                          entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                    }
                    .map(SDK.init(location:))

            return Platform(location: platform, SDKs: SDKs)
          }
  return PlatformCollection(root: PlatformsVersioned, platforms: platforms)
}

private func EnumerateToolchains(in DEVELOPER_DIR: URL) throws -> [Toolchain] {
  let ToolchainsRoot =
      DEVELOPER_DIR.appending(component: "Toolchains",
                              directoryHint: .isDirectory)
  // FIXME: can we enumerate the toolchains from the installed packages?
  return try FileManager.default
      .contentsOfDirectory(at: ToolchainsRoot,
                           includingPropertiesForKeys: [.isDirectoryKey])
      .lazy
      .filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
      }
      .map { toolchain in
        let ToolchainInfo =
            toolchain.appending(component: "ToolchainInfo.plist")

        guard let info =
            try PropertyListSerialization.propertyList(from: Data(contentsOf: ToolchainInfo),
                                                       format: nil) as? Dictionary<String, Any> else {
          throw WindowsError(ERROR_INVALID_DATA)
        }

        // FIXME: we should propagate an error if the toolchain image is invalid
        return Toolchain(identifier: info["Identifier"] as? String ?? "",
                         location: toolchain)
      }
}

private func QueryInstallation(_ hKey: ManagedHandle<HKEY>, _ lpSubKey: String,
                               _ bIsSystem: Bool) throws -> SwiftInstallation? {
  let hSubKey = try hKey.OpenKey(lpSubKey, 0, KEY_READ)

  guard let szDisplayName = try? hSubKey.QueryValue("DisplayName") else {
    return nil
  }

  if !szDisplayName.starts(with: "Swift Developer Toolkit") {
    return nil
  }

  guard let szDisplayVersion = try? hSubKey.QueryValue("DisplayVersion"),
      let szPublisher = try? hSubKey.QueryValue("Publisher") else {
    return nil
  }

  let hVariables = try hSubKey.OpenKey("Variables", 0, KEY_READ)
  guard let szInstallPath = try? hVariables.QueryValue("InstallRoot") else {
    return nil
  }

  guard let version = Version(szDisplayVersion) else {
    throw WindowsError(ERROR_INVALID_DATA)
  }

  // TODO: map the bundle to packages and then use that to determine the
  // InstallRoot
  let DEVELOPER_DIR =
      URL(filePath: szInstallPath, directoryHint: .isDirectory)
  return try SwiftInstallation(system: bIsSystem, vendor: szPublisher,
                               version: version,
                               toolchains: EnumerateToolchains(in: DEVELOPER_DIR),
                               platforms: EnumeratePlatforms(in: DEVELOPER_DIR,
                                                             version: version))
}

extension SwiftInstallation {
  package static func enumerate() throws -> [SwiftInstallation] {
    return try kRegistryPaths.lazy.compactMap { hive, path in
      guard let hKey = try? ManagedHandle<HKEY>(hive, path, 0, KEY_READ) else {
        return Array<SwiftInstallation>()
      }
      return try hKey.subkeys.compactMap {
        try QueryInstallation(hKey, $0, hive == HKEY_LOCAL_MACHINE)
      }
    }
    .flatMap { $0 }
    .sorted { $0.version > $1.version }
  }
}

extension SwiftInstallation {
  internal func contains(toolchain identifier: String) -> Bool {
    return toolchains.contains { $0.identifier == identifier }
  }

  internal func contains(sdk identifier: String) -> Bool {
    return platforms.contains { platform in
      return platform.SDKs.contains { $0.identifier == identifier }
    }
  }
}

extension SwiftInstallation {
  internal func toolchain(matching identifier: String? = nil) -> Toolchain? {
    return toolchains.first { toolchain in
      return identifier.map { toolchain.identifier == $0 } ?? true
    }
  }
}

extension SwiftInstallation {
  internal func platforms(containing sdk: String) -> [Platform] {
    return self.platforms.filter { platform in
      return platform.SDKs.contains { $0.identifier == sdk }
    }
  }

  internal func platform(containing sdk: String) -> Platform? {
    return platforms.containing(sdk: sdk).first
  }
}

extension SwiftInstallation: CustomStringConvertible {
  public var description: String {
    let toolchains =
        self.toolchains.map { "    - \($0.identifier) [\($0.location.path)]" }

    let platforms = self.platforms.map { platform in
      let sdks = platform.SDKs.map { sdk in
        "          - \(sdk.identifier) [\(sdk.location.path)]"
      }
      return (
        [
          "    - \(platform.identifier)",
          "        SDKs:",
        ] + sdks
      ).joined(separator: "\n")
    }

    return """
    SwiftInstallation {
      System: \(system)
      Vendor: \(vendor)
      Version: \(version)
      Toolchains:
    \(toolchains.joined(separator: "\n"))
      Platforms:
    \(platforms.joined(separator: "\n"))
    }
    """
  }
}

extension Array where Element == SwiftInstallation {
  internal func matching(toolchain: String?, sdk: String?) -> SwiftInstallation? {
    return first { installation in
      (toolchain.map(installation.contains(toolchain:)) ?? true) &&
      (sdk.map(installation.contains(sdk:)) ?? true)
    }
  }
}
