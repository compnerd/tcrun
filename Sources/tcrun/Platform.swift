// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct Platform {
  public let identifier: String
  public let location: URL
  public let SDKs: [URL]

  public init(location: URL, SDKs: [URL]) {
    self.identifier = location.lastPathComponent
    self.location = location
    self.SDKs = SDKs
  }
}

extension Platform {
  public func contains(sdk named: String) -> Bool {
    SDKs.contains { $0.lastPathComponent == named }
  }

  public func sdk(named name: String) -> URL? {
    SDKs.first { $0.lastPathComponent == name }
  }
}
