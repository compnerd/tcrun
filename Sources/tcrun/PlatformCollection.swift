// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct PlatformCollection {
  public let root: URL
  public let platforms: [Platform]

  public init(root: URL, platforms: [Platform]) {
    self.root = root
    self.platforms = platforms
  }

  public func containing(sdk: String) -> [Platform] {
    platforms.filter { $0.contains(sdk: sdk) }
  }
}

extension PlatformCollection: Collection {
  public typealias Element = Platform
  public typealias Index = Array<Platform>.Index

  public var startIndex: Index {
    platforms.startIndex
  }

  public var endIndex: Index {
    platforms.endIndex
  }

  public subscript(index: Index) -> Platform {
    return platforms[index]
  }

  public func index(after i: Index) -> Index {
    return platforms.index(after: i)
  }
}
