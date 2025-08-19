// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WindowsCore

extension HKEY: HandleValue {
  internal static func release(_ handle: HKEY?) {
    if let handle {
      let lStatus: LSTATUS = RegCloseKey(handle)
      assert(lStatus == ERROR_SUCCESS,
             "failed to close key: \(WindowsError(lStatus))")
    }
  }
}

extension ManagedHandle where Value == HKEY {
  internal convenience init(_ hKey: HKEY, _ lpSubKey: String?,
                            _ ulOptions: DWORD, _ samDesired: REGSAM) throws {
    var hkResult: HKEY?
    let lStatus: LSTATUS = lpSubKey.withUTF16CString {
      RegOpenKeyExW(hKey, $0, ulOptions, samDesired, &hkResult)
    }
    guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }
    self.init(owning: hkResult)
  }

  internal func OpenKey(_ lpSubKey: String?, _ ulOptions: DWORD,
                        _ samDesired: REGSAM) throws -> ManagedHandle<HKEY> {
    var hkResult: HKEY?
    let lStatus: LSTATUS = lpSubKey.withUTF16CString {
      RegOpenKeyExW(self.value, $0, ulOptions, samDesired, &hkResult)
    }
    guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }
    return ManagedHandle<HKEY>(owning: hkResult)
  }

  internal func QueryValue(_ lpSubKey: String?,
                           _ lpValue: String?) throws -> String {
    try lpSubKey.withUTF16CString { lpSubKey in
      try lpValue.withUTF16CString { lpValue in
        var cbData: DWORD = 0
        var lStatus: LSTATUS

        lStatus = RegGetValueW(self.value, lpSubKey, lpValue, RRF_RT_REG_SZ,
                               nil, nil, &cbData)
        guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }

        return try withUnsafeTemporaryAllocation(of: WCHAR.self,
                                                 capacity: Int(cbData)) {
          lStatus = RegGetValueW(self.value, lpSubKey, lpValue, RRF_RT_REG_SZ,
                                 nil, $0.baseAddress, &cbData)
          guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }

          return String(decodingCString: $0.baseAddress!, as: UTF16.self)
        }
      }
    }
  }
}

extension ManagedHandle where Value == HKEY {
  internal final class SubKeyIterator: IteratorProtocol, Sequence {
    public typealias Element = String

    private var key: ManagedHandle<HKEY>
    private var cSubKeys: DWORD = 0

    private var dwIndex: DWORD
    private var szBuffer: UnsafeMutableBufferPointer<WCHAR>

    internal init(_ key: ManagedHandle<HKEY>) throws {
      self.key = key

      var cbMaxSubKeyLen: DWORD = 0
      let lStatus: LSTATUS =
          RegQueryInfoKeyW(key.value, nil, nil, nil, &cSubKeys, &cbMaxSubKeyLen,
                           nil, nil, nil, nil, nil, nil)
      guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }

      self.dwIndex = 0
      szBuffer = .allocate(capacity: Int(cbMaxSubKeyLen + 1))
    }

    deinit {
      szBuffer.deallocate()
    }

    internal func next() -> String? {
      if dwIndex >= cSubKeys { return nil }

      var cchName: DWORD = DWORD(szBuffer.count)
      // FIXME: we should capture the failure here
      _ = RegEnumKeyExW(key.value, dwIndex, szBuffer.baseAddress, &cchName,
                        nil, nil, nil, nil)
      defer { dwIndex += 1 }

      return String(decoding: Array<WCHAR>(szBuffer.prefix(through: Int(cchName))),
                    as: UTF16.self)
    }
  }

  internal var subkeys: SubKeyIterator {
    get throws { try SubKeyIterator(self) }
  }
}
