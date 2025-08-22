// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WindowsCore

internal func SearchExecutable(_ name: String, in directory: String? = nil)
    throws -> String? {
  func search(_ name: String, in directory: String? = nil, extension: String?) throws -> String? {
    return try directory.withUTF16CString { wszDirectory in
      return try name.withCString(encodedAs: UTF16.self) { wszFileName in
        return try `extension`.withUTF16CString { wszExtension in
          let dwLength = SearchPathW(wszDirectory, wszFileName, wszExtension, 0, nil, nil)
          if dwLength == 0 {
            let dwError = GetLastError()
            if dwError == ERROR_FILE_NOT_FOUND { return nil }
            throw WindowsError(dwError)
          }

          return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
            guard let baseAddress = $0.baseAddress else { return nil }
            let dwResult = SearchPathW(wszDirectory, wszFileName, wszExtension,
                                       DWORD($0.count), baseAddress, nil)
            guard dwResult > 0, dwResult < dwLength else { throw WindowsError() }
            return String(decodingCString: baseAddress, as: UTF16.self)
          }
        }
      }
    }
  }

  guard name.pathExtension.isEmpty else {
    return try search(name, in: directory, extension: nil)
  }

  if let path = try search(name, in: directory, extension: nil) {
    return path
  }

  for `extension` in try GetEnvironmentVariable("PATHEXT")?.split(separator: ";") ?? [] {
    if let result = try search(name, in: directory, extension: String(`extension`)) {
      return result
    }
  }

  return nil
}

internal struct Toolchain {
  public let identifier: String
  public let location: URL

  public init(identifier: String, location: URL) {
    self.identifier = identifier
    self.location = location
  }

  public var bindir: URL {
    location.appending(components: "usr", "bin", directoryHint: .isDirectory)
  }
}

extension Toolchain {
  internal func find(_ tool: String) throws -> String? {
    try SearchExecutable(tool, in: self.bindir.path)
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
}
