// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal struct Version {
  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  public init?(_ version: String) {
    let components = version.split(separator: "-")[0].split(separator: ".").compactMap { Int($0) }
    guard components.count == 3 else {
      return nil
    }
    self.major = components[0]
    self.minor = components[1]
    self.patch = components[2]
  }
}

extension Version: CustomStringConvertible {
  public var description: String {
    "\(major).\(minor).\(patch)"
  }
}
