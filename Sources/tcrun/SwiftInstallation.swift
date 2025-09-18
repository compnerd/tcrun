// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import FoundationEssentials
internal import WindowsCore

private nonisolated(unsafe) let kRegistryPaths = [
  (HKEY_LOCAL_MACHINE, #"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"#),
  (HKEY_CURRENT_USER, #"Software\Microsoft\Windows\CurrentVersion\Uninstall"#),
]

package struct SwiftInstallation {
  let system: Bool
  let vendor: String
  let version: Version
  let toolchains: MemoizedSequence<Toolchain>
  let platforms: MemoizedSequence<Platform>

  internal init(system: Bool, vendor: String, version: Version,
                toolchains: ToolchainEnumerator,
                platforms: PlatformEnumerator) {
    self.system = system
    self.vendor = vendor
    self.version = version
    self.toolchains = MemoizedSequence(toolchains)
    self.platforms = MemoizedSequence(platforms)
  }
}

private func QueryInstallation(_ hKey: ManagedHandle<HKEY>, _ lpSubKey: String,
                               _ bIsSystem: Bool) throws -> SwiftInstallation? {
  let hSubKey = try hKey.OpenKey(lpSubKey, 0, KEY_READ)

  guard let szDisplayName = try? hSubKey.QueryValue("DisplayName"),
      szDisplayName.starts(with: "Swift Developer Toolkit") else {
    return nil
  }

  let query = Result {
    try (version: hSubKey.QueryValue("DisplayVersion"),
         vendor: hSubKey.QueryValue("Publisher"),
         // TODO: map the bundle to packages and then use that to determine
         // the InstallRoot
         root: hSubKey.OpenKey("Variables", 0, KEY_READ)
                      .QueryValue("InstallRoot"))
  }

  switch query {
  case let .success(info):
    guard let version = Version(info.version) else {
      // FIXME: this should be an internal error type
      throw WindowsError(ERROR_INVALID_DATA)
    }

    let DEVELOPER_DIR = URL(filePath: info.root, directoryHint: .isDirectory)

    return SwiftInstallation(system: bIsSystem, vendor: info.vendor,
                             version: version,
                             toolchains: ToolchainEnumerator(in: DEVELOPER_DIR),
                             platforms: PlatformEnumerator(in: DEVELOPER_DIR, version: version))
  case let .failure(error):
    throw error
  }
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
    return platforms.filter { $0.contains(sdk: sdk) }.first
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
