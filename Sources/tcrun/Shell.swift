// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

private import Foundation
private import WinSDK

internal func FindExecutable(_ name: String, in directory: String? = nil)
    throws -> String? {
  directory.withUTF16CString { wszDirectory in
    name.withCString(encodedAs: UTF16.self) { wszFile in
      withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(MAX_PATH)) {
        _ = FindExecutableW(wszFile, wszDirectory, $0.baseAddress)
        return String(decodingCString: $0.baseAddress!, as: UTF16.self)
      }
    }
  }
}
