// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

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
}
