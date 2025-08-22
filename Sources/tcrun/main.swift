// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

private import ArgumentParser
private import WindowsCore

internal import Foundation

private enum SDKResolver {
  public static func resolve(for invocation: borrowing tcrun) throws -> String {
    // `-sdk` always takes precedence.
    if let sdk = invocation.sdk { return sdk }

    // `SDKROOT` is used as a default value if specified.
    guard let SDKROOT = try GetEnvironmentVariable("SDKROOT") else {
      // Default to the Boot OS SDK.
      return "Windows.sdk"
    }

    // Strip the name of the SDK from the `SDKROOT` environment variable.
    return URL(filePath: SDKROOT).lastPathComponent
  }
}

internal func execute(_ tool: URL, _ arguments: [String]? = nil,
                      sdk: URL? = nil) throws -> Never {
  let process = Process()
  process.executableURL = tool
  process.arguments = arguments

  var environment = ProcessInfo.processInfo.environment
  if let sdk {
    environment.updateValue(sdk.path, forKey: "SDKROOT")
  } else {
    environment.removeValue(forKey: "SDKROOT")
  }
  environment.removeValue(forKey: "TOOLCHAINS")

  process.environment = environment

  try process.run()
  process.waitUntilExit()
  _exit(process.terminationStatus)
}

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
    if version { return }
    if toolchains { return }
    if showSDKPath || showSDKPlatformPath { return }

    if tool.isEmpty {
      throw ValidationError("Missing expected argument '<tool>'")
    }
  }

  public mutating func run() throws {
    if version {
      return print("tcrun \(PackageVersion)")
    }

    // Enumerate installations.
    let installations = try SwiftInstallation.enumerate()

    // Handle toolchain enumeration.
    if toolchains {
      return installations.forEach { print($0) }
    }

    // Resolve the SDK to use.
    let sdk = try SDKResolver.resolve(for: self)

    // Resolve the toolchain to use.
    let TOOLCHAINS = try GetEnvironmentVariable("TOOLCHAINS")
    let toolchain = toolchain ?? TOOLCHAINS

    // Identify the installation matching the toolchain identifier and SDK.
    guard let installation =
        installations.matching(toolchain: toolchain, sdk: sdk) else {
      return
    }

    // Handle Platform/SDK queries.
    guard let platform = installation.platform(containing: sdk) else {
      return
    }

    if showSDKPlatformPath {
      let root =
          installation.platforms.root.appending(component: platform.id,
                                                directoryHint: .isDirectory)
      return print(root.path)
    }

    if showSDKPath {
      guard let sdk = platform.sdk(named: sdk) else { return }
      return print(sdk.path)
    }

    // Handle tool execution.
    if let toolchain = installation.toolchain(matching: toolchain) {
      // TODO(compnerd): if `-sdk` is specified, the tool search should be
      // scoped to the SDK rather than the toolchain.
      guard let path = try toolchain.find(tool) else {
        return
      }

      switch mode {
      case .find:
        print(path)

      case .run:
        try execute(URL(filePath: path), arguments,
                    sdk: self.sdk.map(platform.sdk(named:)) ?? nil)
      }
    }
  }
}
