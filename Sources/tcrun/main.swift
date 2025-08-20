// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

private import ArgumentParser
private import WindowsCore

internal import Foundation

@main
private struct tcrun: ParsableCommand {
  public static var configuration: CommandConfiguration {
    CommandConfiguration(abstract: "Swift Toolchain Execution Helper")
  }

  public enum Mode: EnumerableFlag {
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
  public var version: Bool = false

  @Flag(name: [.customLong("show-sdk-path", withSingleDash: true), .long],
        help: "Print the path to the SDK")
  public var showSDKPath: Bool = false

  @Flag(name: [.customLong("show-sdk-platform-path", withSingleDash: true),
               .long],
        help: "Print the path to the SDK platform")
  public var showSDKPlatformPath: Bool = false

  // FIXME: should this be moved into a `toolchain-select` tool?
  @Flag(name: [.customLong("toolchains", withSingleDash: true), .long],
        help: "List the available toolchains")
  public var toolchains: Bool = false

  @Option(name: .customLong("sdk", withSingleDash: true),
          help: "Use the specified SDK")
  public var sdk: String?

  @Option(name: .customLong("toolchain", withSingleDash: true),
          help: "Use the specified toolchain")
  public var toolchain: String?

  @Flag()
  public var mode: Mode = .run

  @Argument
  public var tool: String = ""

  @Argument(parsing: .remaining)
  public var arguments: [String] = []

  public func validate() throws {
    guard !version else { return }

    guard !showSDKPath, !showSDKPlatformPath else { return }
    guard !toolchains else { return }

    if tool.isEmpty {
      throw ValidationError("Missing expected argument '<tool>'")
    }
  }

  private mutating func run(selecting installation: SwiftInstallation,
                            toolchain: String?, sdk: String) throws {
    guard let platform = installation.platform(containing: sdk) else {
      return
    }

    if showSDKPlatformPath {
      let root = installation.platforms.root.appending(component: platform.id,
                                                       directoryHint: .isDirectory)
      return print(root.path)
    }

    guard let sdk = platform.sdk(named: sdk) else { return }

    if showSDKPath {
      return print(sdk.path)
    }

    guard let toolchain = installation.toolchain(matching: toolchain) else {
      return
    }

    guard let tool = try toolchain.find(tool) else {
      return
    }

    switch mode {
    case .find:
      print(tool)

    case .run:
      let tool = URL(filePath: tool)
      try toolchain.execute(tool, sdk: sdk.path, arguments: arguments)
    }
  }

  public mutating func run() throws {
    if version {
      return print("tcrun \(PackageVersion)")
    }

    let installations = try SwiftInstallation.enumerate()

    if toolchains {
      return installations.forEach { print($0) }
    }

    let TOOLCHAINS = try GetEnvironmentVariable("TOOLCHAINS")
    let SDKROOT = try GetEnvironmentVariable("SDKROOT")

    let OPT_sdk =
        sdk ?? URL(filePath: SDKROOT ?? "Windows.sdk").lastPathComponent
    let OPT_toolchain = toolchain ?? TOOLCHAINS

    guard let installation =
        installations.matching(toolchain: OPT_toolchain, sdk: OPT_sdk) else {
      return
    }

    return try run(selecting: installation,
                   toolchain: OPT_toolchain, sdk: OPT_sdk)
  }
}
