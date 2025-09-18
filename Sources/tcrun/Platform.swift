// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct Platform {
  public let identifier: String
  public let location: URL
  public let SDKs: MemoizedSequence<SDK>

  internal init(location: URL, SDKs: SDKEnumerator) {
    self.identifier = location.lastPathComponent
    self.location = location
    self.SDKs = MemoizedSequence(SDKs)
  }
}

extension Platform {
  public func contains(sdk identifier: String) -> Bool {
    return SDKs.contains { $0.identifier == identifier }
  }

  public func sdk(named identifier: String) -> SDK? {
    return SDKs.first { $0.identifier == identifier }
  }
}

extension PlatformEnumerator {
  internal struct Iterator: IteratorProtocol {
    private let enumerator: FileManager.DirectoryEnumerator?

    internal init(root: URL) {
      self.enumerator =
          FileManager.default.enumerator(at: root,
                                         includingPropertiesForKeys: [.isDirectoryKey],
                                         options: [.skipsSubdirectoryDescendants])
    }

    internal mutating func next() -> Platform? {
      while let location = enumerator?.nextObject() as? URL {
        guard location.lastPathComponent.hasSuffix(".platform"),
            (try? location.isDirectory) ?? false else {
          continue
        }
        return Platform(location: location, SDKs: SDKEnumerator(in: location))
      }
      return nil
    }
  }
}

internal struct PlatformEnumerator: Sequence {
  private let root: URL

  internal init(in DEVELOPER_DIR: URL, version: Version) {
    self.root = DEVELOPER_DIR.appending(components: "Platforms", version.description,
                                        directoryHint: .isDirectory)
  }

  internal func makeIterator() -> Iterator {
    Iterator(root: root)
  }
}
