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

extension SDKEnumerator {
  internal struct Iterator: IteratorProtocol {
    private let enumerator: FileManager.DirectoryEnumerator?

    internal init(root: URL) {
      self.enumerator =
          FileManager.default.enumerator(at: root,
                                         includingPropertiesForKeys: [.isDirectoryKey],
                                         options: [.skipsSubdirectoryDescendants])
    }

    internal mutating func next() -> SDK? {
      while let location = enumerator?.nextObject() as? URL {
        guard location.lastPathComponent.hasSuffix(".sdk"),
            (try? location.isDirectory) ?? false else {
          continue
        }
        return SDK(location: location)
      }
      return nil
    }
  }
}

internal struct SDKEnumerator: Sequence {
  private let root: URL

  internal init(in platform: URL) {
    self.root = platform.appending(components: "Developer", "SDKs",
                                   directoryHint: .isDirectory)
  }

  internal func makeIterator() -> Iterator {
    Iterator(root: root)
  }
}
