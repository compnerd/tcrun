// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
private import WindowsCore

internal func GetEnvironmentVariable(_ name: String) throws -> String? {
  try name.withCString(encodedAs: UTF16.self) { szVariable in
    let dwResult = GetEnvironmentVariableW(szVariable, nil, 0)
    if dwResult == 0 {
      let dwError = GetLastError()
      if dwError == ERROR_ENVVAR_NOT_FOUND { return nil }
      throw WindowsError(dwError)
    }

    return try withUnsafeTemporaryAllocation(of: WCHAR.self,
                                             capacity: Int(dwResult)) {
      if GetEnvironmentVariableW(szVariable, $0.baseAddress, dwResult) == 0 {
        throw WindowsError()
      }
      return String(decodingCString: $0.baseAddress!, as: UTF16.self)
    }
  }
}

internal func SearchExecutable(_ name: String, in directory: String? = nil)
    throws -> String? {
  func search(_ name: String, in directory: String? = nil, extension: String?) throws -> String? {
    return try directory.withUTF16CString { wszDirectory in
      return try name.withCString(encodedAs: UTF16.self) { wszFileName in
        return try `extension`.withUTF16CString { wszExtension in
          let dwLength = SearchPathW(wszDirectory, wszFileName, wszExtension, 0, nil, nil)
          if dwLength == 0 {
            let dwError = GetLastError()
            if dwError == ERROR_FILE_NOT_FOUND { return nil }
            throw WindowsError(dwError)
          }

          return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
            guard let baseAddress = $0.baseAddress else { return nil }
            let dwResult = SearchPathW(wszDirectory, wszFileName, wszExtension,
                                       DWORD($0.count), baseAddress, nil)
            guard dwResult > 0, dwResult < dwLength else { throw WindowsError() }
            return String(decodingCString: baseAddress, as: UTF16.self)
          }
        }
      }
    }
  }

  guard name.pathExtension.isEmpty else {
    return try search(name, in: directory, extension: nil)
  }

  if let path = try search(name, in: directory, extension: nil) {
    return path
  }

  for `extension` in try GetEnvironmentVariable("PATHEXT")?.split(separator: ";") ?? [] {
    if let result = try search(name, in: directory, extension: String(`extension`)) {
      return result
    }
  }

  return nil
}

