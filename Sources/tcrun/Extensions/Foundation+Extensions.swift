// Copyright © 2025 Saleem Abdulrasool
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

extension URL {
  internal var path: String {
    self.withUnsafeFileSystemRepresentation { String(cString: $0!) }
  }
}
