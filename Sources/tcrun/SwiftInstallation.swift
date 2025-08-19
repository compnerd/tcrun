// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WindowsCore

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
  let FileManager = FileManager.default
  // FIXME: can we enumerate the platforms from the installed packages?
  let platforms =
      try FileManager.contentsOfDirectory(at: PlatformsVersioned,
                                          includingPropertiesForKeys: nil)
          .filter { $0.lastPathComponent.hasSuffix(".platform") }
          .map { platform in
            let root = platform.appending(components: "Developer", "SDKs",
                                          directoryHint: .isDirectory)
            let SDKs =
                try FileManager.contentsOfDirectory(at: root,
                                                    includingPropertiesForKeys: nil)
                        .filter { $0.lastPathComponent.hasSuffix(".sdk") }
            return Platform(id: platform.lastPathComponent, SDKs: SDKs)
          }
  return PlatformCollection(root: PlatformsVersioned, platforms: platforms)
}

private func EnumerateToolchains(in DEVELOPER_DIR: URL) throws -> [Toolchain] {
  let ToolchainsRoot =
      DEVELOPER_DIR.appending(component: "Toolchains",
                              directoryHint: .isDirectory)
  let FileManager = FileManager.default
  // FIXME: can we enumerate the toolchains from the installed packages?
  return try FileManager.contentsOfDirectory(at: ToolchainsRoot,
                                             includingPropertiesForKeys: nil)
      .map { toolchain in
        let ToolchainInfo =
            toolchain.appending(component: "ToolchainInfo.plist")

        var info: Dictionary<String, Any>?
        // FIXME: we should propagate an error if the toolchain image is invalid
        if let data = FileManager.contents(atPath: ToolchainInfo.path) {
          info = try PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Any>
        }

        return Toolchain(identifier: info?["Identifier"] as? String ?? "",
                         location: toolchain)
      }
}

extension SwiftInstallation {
  private static func QueryInstallation(_ hKey: ManagedHandle<HKEY>,
                                        _ lpSubKey: String, _ bIsSystem: Bool)
      throws -> SwiftInstallation? {
    let hSubKey = try hKey.OpenKey(lpSubKey, 0, KEY_READ)

    guard let szDisplayName = try? hSubKey.QueryValue(nil, "DisplayName") else {
      return nil
    }

    if !szDisplayName.starts(with: "Swift Developer Toolkit") {
      return nil
    }

    guard let szDisplayVersion = try? hSubKey.QueryValue(nil, "DisplayVersion"),
        let szPublisher = try? hSubKey.QueryValue(nil, "Publisher") else {
      return nil
    }

    let hVariables = try hSubKey.OpenKey("Variables", 0, KEY_READ)
    guard let szInstallPath = try? hVariables.QueryValue(nil, "InstallRoot") else {
      return nil
    }

    guard let version = Version(szDisplayVersion) else {
      throw WindowsError(ERROR_INVALID_DATA)
    }

    // TODO: map the bundle to packages and then use that to determine the
    // InstallRoot
    let DEVELOPER_DIR =
        URL(filePath: szInstallPath, directoryHint: .isDirectory)
    return try .init(system: bIsSystem, vendor: szPublisher, version: version,
                     toolchains: EnumerateToolchains(in: DEVELOPER_DIR),
                     platforms: EnumeratePlatforms(in: DEVELOPER_DIR,
                                                   version: version))
  }

  package static func enumerate() throws -> [SwiftInstallation] {
    var installations: [SwiftInstallation] = []

    if let hKey =
        try? ManagedHandle<HKEY>(HKEY_LOCAL_MACHINE,
                                 #"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"#,
                                 0, KEY_READ) {
      try installations.append(contentsOf: hKey.subkeys.compactMap {
        try QueryInstallation(hKey, $0, true)
      })
    }

    if let hKey =
        try? ManagedHandle<HKEY>(HKEY_CURRENT_USER,
                                 #"Software\Microsoft\Windows\CurrentVersion\Uninstall"#,
                                 0, KEY_READ) {
      try installations.append(contentsOf: hKey.subkeys.compactMap {
        try QueryInstallation(hKey, $0, false)
      })
    }

    // TODO(compnerd): sort by version number
    return installations
  }
}

extension SwiftInstallation {
  internal func platforms(containing sdk: String) -> [Platform] {
    self.platforms.platforms.filter {
      $0.SDKs.filter { $0.lastPathComponent == sdk }.count > 0
    }
  }

  internal func platform(containing sdk: String) -> Platform? {
    return platforms.containing(sdk: sdk).first
  }
}

extension SwiftInstallation: CustomStringConvertible {
  public var description: String {
    return """
    SwiftInstallation {
      System: \(system)
      Vendor: \(vendor)
      Version: \(version)
      Toolchains:
      \(
        toolchains.map {
          "  - \($0.identifier) [\($0.location.path)]"
        }.joined(separator: "\n    ")
      )
      Platforms:
      \(
        platforms.map {
          """
            - \($0.id)
                  SDKs:
                  \(
                    $0.SDKs.map {
                      "  - \($0.lastPathComponent) [\($0.path)]"
                    }.joined(separator: "\n    ")
                  )
          """
        }.joined(separator: "\n    ")
      )
    }
    """
  }
}

extension Array where Element == SwiftInstallation {
  internal func select(toolchain: String?, sdk: String?) -> SwiftInstallation? {
    return first { installation in
      let toolchain = toolchain.map { id in
        installation.toolchains.contains { $0.identifier == id }
      } ?? true

      let sdk = sdk.map { name in
        installation.platforms.contains { platform in
          platform.SDKs.contains { $0.lastPathComponent == name }
        }
      } ?? true

      return toolchain && sdk
    }
  }
}
