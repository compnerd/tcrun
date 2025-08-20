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
    guard let version = version.split(separator: "-", maxSplits: 1).first else {
      return nil
    }

    let components = version.split(separator: ".").compactMap { Int($0) }
    guard components.count == 3 else { return nil }

    (major, minor, patch) = (components[0], components[1], components[2])
  }
}

extension Version: Comparable {
  public static func < (_ lhs: Version, _ rhs: Version) -> Bool {
    guard lhs.major == rhs.major else { return lhs.major < rhs.major }
    guard lhs.minor == rhs.minor else { return lhs.minor < rhs.minor }
    return lhs.patch < rhs.patch
  }
}

extension Version: CustomStringConvertible {
  public var description: String {
    "\(major).\(minor).\(patch)"
  }
}
