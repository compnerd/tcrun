// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import WinSDK

@_transparent
internal var KEY_READ: DWORD {
  DWORD((STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY) & ~SYNCHRONIZE)
}

@_transparent
internal func MAKELANGID(_ p: WORD, _ s: WORD) -> DWORD {
  DWORD((s << 10) | p)
}

@_transparent
internal func HRESULT_FACILITY(_ hr: HRESULT) -> WORD {
  WORD((Int32(hr) >> 16) & 0x1fff)
}

@_transparent
internal func HRESULT_CODE(_ hr: HRESULT) -> WORD {
  WORD(Int32(hr) & 0xffff)
}

@_transparent
internal var RRF_RT_REG_SZ: DWORD {
  DWORD(WinSDK.RRF_RT_REG_SZ)
}

@_transparent
internal var ERROR_INVALID_DATA: DWORD {
  DWORD(WinSDK.ERROR_INVALID_DATA)
}

@_transparent
internal var FORMAT_MESSAGE_ALLOCATE_BUFFER: DWORD {
  DWORD(WinSDK.FORMAT_MESSAGE_ALLOCATE_BUFFER)
}

@_transparent
internal var FORMAT_MESSAGE_FROM_SYSTEM: DWORD {
  DWORD(WinSDK.FORMAT_MESSAGE_FROM_SYSTEM)
}

@_transparent
internal var FORMAT_MESSAGE_IGNORE_INSERTS: DWORD {
  DWORD(WinSDK.FORMAT_MESSAGE_IGNORE_INSERTS)
}

@_transparent
internal var LANG_NEUTRAL: WORD {
  WORD(WinSDK.LANG_NEUTRAL)
}

@_transparent
internal var SUBLANG_DEFAULT: WORD {
  WORD(WinSDK.SUBLANG_DEFAULT)
}

@_transparent
internal var TOKEN_QUERY: DWORD {
  DWORD(WinSDK.TOKEN_QUERY)
}
