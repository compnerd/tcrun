// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

private import ArgumentParser
private import Foundation
private import WinSDK

extension Array where Element == SwiftInstallation {
  fileprivate func select(toolchain: String?, sdk: String?)
      -> SwiftInstallation? {
    if let toolchain {
      return self.first(where: {
        $0.toolchains.filter { $0.identifier == toolchain }.count > 0
      })
    }

    if let sdk {
      return self.first(where: {
        $0.platforms.platforms.flatMap(\.SDKs)
                              .filter { $0.lastPathComponent == sdk }.count > 0
      })
    }

    return self.first
  }
}

extension SwiftInstallation {
  fileprivate func platforms(containing sdk: String)
      -> [Platform] {
    self.platforms.platforms.filter {
      $0.SDKs.filter { $0.lastPathComponent == sdk }.count > 0
    }
  }
}

@main
private struct tcrun: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(abstract: "Swift Toolchain Execution Helper")
  }

  enum Mode: EnumerableFlag {
    case find
    case run

    static func name(for value: Self) -> NameSpecification {
      switch value {
      case .find:
        [.short, .customLong("find", withSingleDash: true), .long]
      case .run:
        [.short, .customLong("run", withSingleDash: true), .long]
      }
    }

    static func help(for value: Self) -> ArgumentHelp? {
      switch value {
      case .find:
        "Find the tool in the toolchain and print the path"
      case .run:
        "Find the tool in the toolchain and execute the tool"
      }
    }
  }

  @Flag(name: [.customLong("version", withSingleDash: true), .long],
        help: "Print the version of the tool")
  var version: Bool = false

  @Flag(name: [.customLong("show-sdk-path", withSingleDash: true), .long],
        help: "Print the path to the SDK")
  var showSDKPath: Bool = false

  @Flag(name: [.customLong("show-sdk-platform-path", withSingleDash: true),
               .long],
        help: "Print the path to the SDK platform")
  var showSDKPlatformPath: Bool = false

  // FIXME: should this be moved into a `toolchain-select` tool?
  @Flag(name: [.customLong("toolchains", withSingleDash: true), .long],
        help: "List the available toolchains")
  var toolchains: Bool = false

  @Option(name: .customLong("sdk", withSingleDash: true),
          help: "Use the specified SDK")
  var sdk: String?

  @Option(name: .customLong("toolchain", withSingleDash: true),
          help: "Use the specified toolchain")
  var toolchain: String?

  @Flag()
  var mode: Mode = .run

  @Argument
  var tool: String = ""

  @Argument(parsing: .remaining)
  var arguments: [String] = []

  func validate() throws {
    guard !version else { return }

    guard !showSDKPath, !showSDKPlatformPath else { return }
    guard !toolchains else { return }

    if tool.isEmpty {
      throw ValidationError("Missing expected argument '<tool>'")
    }
  }

  mutating func run() throws {
    guard !version else { return print("tcrun \(version)") }

    let TOOLCHAINS = try GetEnvironmentVariable("TOOLCHAINS")
    let SDKROOT = try GetEnvironmentVariable("SDKROOT")

    let OPT_sdk =
        sdk ?? URL(filePath: SDKROOT ?? "Windows.sdk").lastPathComponent
    let OPT_toolchain = toolchain ?? TOOLCHAINS

    let installations = try SwiftInstallation.enumerate()

    if toolchains {
      for installation in installations { print(installation) }
      return
    }

    let installation =
        installations.select(toolchain: OPT_toolchain, sdk: OPT_sdk)
    guard let installation else { return }

    guard let platform =
        installation.platforms(containing: OPT_sdk).first else {
      return
    }

    if showSDKPlatformPath {
      let root =
          installation.platforms.root.appending(component: platform.id,
                                                directoryHint: .isDirectory)
      return print(root.path)
    }

    guard let sdk =
        platform.SDKs.filter({ $0.lastPathComponent == OPT_sdk }).first else {
      return
    }

    if showSDKPath {
      return print(sdk.path)
    }

    let toolchain =
        installation.toolchains.first(where: {
          OPT_toolchain == nil ? true : $0.identifier == OPT_toolchain
        })

    let tool =
        try FindExecutable(tool, in: toolchain?.location.appending(components: "usr", "bin",
                                                                   directoryHint: .isDirectory).path)
    guard let tool, !tool.isEmpty else { return }

    switch mode {
    case .find:
      print(tool)
    case .run:
      let process = Process()
      process.executableURL = URL(filePath: tool)
      process.arguments = arguments.isEmpty ? nil : arguments

      var environment = ProcessInfo.processInfo.environment
      environment.updateValue(sdk.path, forKey: "SDKROOT")
      environment.removeValue(forKey: "TOOLCHAINS")

      process.environment = environment

      try process.run()
      process.waitUntilExit()

      _exit(process.terminationStatus)
    }
  }
}
