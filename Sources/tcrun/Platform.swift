// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct Platform {
  public let id: String
  public let SDKs: [URL]

  public init(id: String, SDKs: [URL]) {
    self.id = id
    self.SDKs = SDKs
  }

  public func contains(sdk named: String) -> Bool {
    SDKs.contains { $0.lastPathComponent == named }
  }

  public func sdk(named name: String) -> URL? {
    SDKs.first { $0.lastPathComponent == name }
  }
}
