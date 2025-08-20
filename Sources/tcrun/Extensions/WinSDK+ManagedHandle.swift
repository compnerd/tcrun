// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation
internal import WindowsCore

extension HKEY: HandleValue {
  internal static func release(_ handle: HKEY?) {
    if let handle {
      let lStatus = RegCloseKey(handle)
      assert(lStatus == ERROR_SUCCESS,
             "failed to close key: \(WindowsError(lStatus))")
    }
  }
}

extension ManagedHandle where Value == HKEY {
  internal convenience init(_ hKey: HKEY, _ lpSubKey: String?,
                            _ ulOptions: DWORD, _ samDesired: REGSAM) throws {
    var hkResult: HKEY?
    let lStatus = lpSubKey.withUTF16CString {
      RegOpenKeyExW(hKey, $0, ulOptions, samDesired, &hkResult)
    }
    guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }
    self.init(owning: hkResult)
  }

  internal func OpenKey(_ lpSubKey: String?, _ ulOptions: DWORD,
                        _ samDesired: REGSAM) throws -> ManagedHandle<HKEY> {
    var hkResult: HKEY?
    let lStatus = lpSubKey.withUTF16CString {
      RegOpenKeyExW(self.value, $0, ulOptions, samDesired, &hkResult)
    }
    guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }
    return ManagedHandle<HKEY>(owning: hkResult)
  }

  internal func QueryValue(_ lpValue: String?) throws -> String {
    try lpValue.withUTF16CString { lpValue in
      var cbData: DWORD = 0
      var lStatus: LSTATUS

      lStatus = RegGetValueW(self.value, nil, lpValue, RRF_RT_REG_SZ, nil, nil,
                             &cbData)
      guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }

      return try withUnsafeTemporaryAllocation(byteCount: Int(cbData),
                                               alignment: MemoryLayout<WCHAR>.alignment) {
        guard let baseAddress = $0.baseAddress else {
          throw WindowsError(ERROR_OUTOFMEMORY)
        }

        lStatus = RegGetValueW(self.value, nil, lpValue, RRF_RT_REG_SZ,
                               nil, baseAddress, &cbData)
        guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }
        return String(decodingCString: baseAddress.assumingMemoryBound(to: WCHAR.self),
                      as: UTF16.self)
      }
    }
  }
}

extension ManagedHandle where Value == HKEY {
  internal struct SubKeyIterator: IteratorProtocol, Sequence {
    public typealias Element = String

    private let key: ManagedHandle<HKEY>
    private let cSubKeys: DWORD
    private let cbMaxSubKeyLen: DWORD

    private var dwIndex: DWORD = 0

    internal init(_ key: ManagedHandle<HKEY>) throws {
      self.key = key

      var cSubKeys: DWORD = 0
      var cbMaxSubKeyLen: DWORD = 0
      let lStatus =
          RegQueryInfoKeyW(key.value, nil, nil, nil, &cSubKeys, &cbMaxSubKeyLen,
                           nil, nil, nil, nil, nil, nil)
      guard lStatus == ERROR_SUCCESS else { throw WindowsError(lStatus) }

      self.cSubKeys = cSubKeys
      self.cbMaxSubKeyLen = cbMaxSubKeyLen
    }

    internal mutating func next() -> String? {
      guard dwIndex < cSubKeys else { return nil }

      return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(cbMaxSubKeyLen + 1)) {
        guard let baseAddress = $0.baseAddress else { return nil }
        var cchName = DWORD($0.count)
        let lStatus = RegEnumKeyExW(key.value, dwIndex, baseAddress, &cchName,
                                    nil, nil, nil, nil)
        defer { dwIndex += 1 }
        guard lStatus == ERROR_SUCCESS else { return nil }
        return String(decoding: UnsafeBufferPointer(start: baseAddress,
                                                    count: Int(cchName)),
                      as: UTF16.self)
      }
    }
  }

  internal var subkeys: SubKeyIterator {
    get throws { try SubKeyIterator(self) }
  }
}
