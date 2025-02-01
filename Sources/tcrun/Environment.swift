// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WinSDK

internal func GetEnvironmentVariable(_ name: String) throws -> String? {
  try name.withCString(encodedAs: UTF16.self) { szVariable in
    let dwResult: DWORD = GetEnvironmentVariableW(szVariable, nil, 0)
    if dwResult == 0 {
      let dwError: DWORD = GetLastError()
      if dwError == ERROR_ENVVAR_NOT_FOUND { return nil }
      throw Error(win32: dwError)
    }

    return try withUnsafeTemporaryAllocation(of: WCHAR.self,
                                             capacity: Int(dwResult)) {
      if GetEnvironmentVariableW(szVariable, $0.baseAddress, dwResult) == 0 {
        throw Error(win32: GetLastError())
      }
      return String(decodingCString: $0.baseAddress!, as: UTF16.self)
    }
  }
}
