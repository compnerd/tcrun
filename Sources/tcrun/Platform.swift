// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct Platform {
  public let identifier: String
  public let location: URL
  public let SDKs: [SDK]

  public init(location: URL, SDKs: [SDK]) {
    self.identifier = location.lastPathComponent
    self.location = location
    self.SDKs = SDKs
  }
}

extension Platform {
  public func contains(sdk identifier: String) -> Bool {
    return SDKs.contains { $0.identifier == identifier }
  }

  public func sdk(named identifier: String) -> SDK? {
    return SDKs.first { $0.identifier == identifier }
  }
}
