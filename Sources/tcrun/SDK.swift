// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct SDK {
  public let identifier: String
  public let location: URL

  public init(location: URL) {
    self.identifier = location.lastPathComponent
    self.location = location
  }
}
