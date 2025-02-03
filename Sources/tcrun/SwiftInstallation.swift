// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WinSDK

package struct SwiftInstallation {
  let system: Bool
  let vendor: String
  let version: Version
  let toolchains: [(identifier: String, location: URL)]
  let platforms: (root: URL, platforms: [(id: String, SDKs: [URL])])
}

private func EnumeratePlatforms(in DEVELOPER_DIR: URL, version: Version)
    throws -> (root: URL, platforms: [(id: String, SDKs: [URL])]) {
  let PlatformsVersioned: URL =
      DEVELOPER_DIR.appending(components: "Platforms", version.description,
                              directoryHint: .isDirectory)
  let FileManager: Foundation.FileManager = .default
  // FIXME: can we enumerate the platforms from the installed packages?
  let platforms: [(id: String, SDKs: [URL])] =
      try FileManager.contentsOfDirectory(at: PlatformsVersioned,
                                          includingPropertiesForKeys: nil)
          .filter { $0.lastPathComponent.hasSuffix(".platform") }
          .map { platform in
            let root: URL = platform.appending(components: "Developer", "SDKs",
                                                directoryHint: .isDirectory)
            let SDKs: [URL] =
                try FileManager.contentsOfDirectory(at: root,
                                                    includingPropertiesForKeys: nil)
                        .filter { $0.lastPathComponent.hasSuffix(".sdk") }
            return (id: platform.lastPathComponent, SDKs: SDKs)
          }
  return (root: PlatformsVersioned, platforms: platforms)
}

private func EnumerateToolchains(in DEVELOPER_DIR: URL)
    throws -> [(identifier: String, location: URL)] {
  let ToolchainsRoot: URL =
      DEVELOPER_DIR.appending(component: "Toolchains",
                              directoryHint: .isDirectory)
  let FileManager: Foundation.FileManager = .default
  // FIXME: can we enumerate the toolchains from the installed packages?
  return try FileManager.contentsOfDirectory(at: ToolchainsRoot,
                                             includingPropertiesForKeys: nil)
      .map { toolchain in
        let ToolchainInfo: URL =
            toolchain.appending(component: "ToolchainInfo.plist")

        var info: Dictionary<String, Any>?
        if let data: Data = FileManager.contents(atPath: ToolchainInfo.path) {
          info = try PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Any>
        }

        return (identifier: info?["Identifier"] as? String ?? "",
                location: toolchain)
      }
}

extension SwiftInstallation {
  private static func QueryInstallation(_ hKey: ManagedHandle<HKEY>,
                                        _ lpSubKey: String, _ bIsSystem: Bool)
      throws -> SwiftInstallation? {
    let hSubKey: ManagedHandle<HKEY> = try hKey.OpenKey(lpSubKey, 0, KEY_READ)

    guard let szDisplayName: String =
            try? hSubKey.QueryValue(nil, "DisplayName"),
        let szDisplayVersion: String =
            try? hSubKey.QueryValue(nil, "DisplayVersion"),
        let szPublisher: String =
            try? hSubKey.QueryValue(nil, "Publisher") else {
      return nil
    }

    if !szDisplayName.starts(with: "Swift Developer Toolkit") {
      return nil
    }

    guard let szInstallPath: String =
        try? hSubKey.QueryValue("Variables", "InstallRoot") else {
      return nil
    }

    guard let version: Version = Version(szDisplayVersion) else {
      throw Error(win32: ERROR_INVALID_DATA)
    }

    // TODO: map the bundle to packages and then use that to determine the
    // InstallRoot
    let DEVELOPER_DIR: URL =
        URL(filePath: szInstallPath, directoryHint: .isDirectory)
    return try .init(system: bIsSystem, vendor: szPublisher, version: version,
                     toolchains: EnumerateToolchains(in: DEVELOPER_DIR),
                     platforms: EnumeratePlatforms(in: DEVELOPER_DIR,
                                                   version: version))
  }

  package static func enumerate() throws -> [SwiftInstallation] {
    var installations: [SwiftInstallation] = []

    if let hKey: ManagedHandle<HKEY> =
        try? .init(HKEY_LOCAL_MACHINE,
                   #"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"#,
                   0, KEY_READ) {
      try installations.append(contentsOf: hKey.subkeys.compactMap {
        try QueryInstallation(hKey, $0, true)
      })
    }

    if let hKey: ManagedHandle<HKEY> =
        try? .init(HKEY_CURRENT_USER,
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
        platforms.platforms.map {
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
