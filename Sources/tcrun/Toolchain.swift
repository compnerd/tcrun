// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import Foundation

internal struct Toolchain {
  public let identifier: String
  public let location: URL

  public init(identifier: String, location: URL) {
    self.identifier = identifier
    self.location = location
  }

  public var bindir: URL {
    location.appending(components: "usr", "bin", directoryHint: .isDirectory)
  }
}

extension Toolchain {
  internal func find(_ tool: String) throws -> String? {
    try SearchExecutable(tool, in: self.bindir.path)
  }
}

extension ToolchainEnumerator {
  internal struct Iterator: IteratorProtocol {
    private let enumerator: FileManager.DirectoryEnumerator?

    internal init(root: URL) {
      // FIXME: can we enumerate the toolchains from the installed packages?
      self.enumerator =
          FileManager.default.enumerator(at: root,
                                         includingPropertiesForKeys: [.isDirectoryKey],
                                         options: [.skipsSubdirectoryDescendants])
    }

    // TODO: how should we sort the toolchains?
    internal mutating func next() -> Toolchain? {
      while let location = enumerator?.nextObject() as? URL {
        guard (try? location.isDirectory) ?? false else {
          continue
        }

        let ToolchainInfo = location.appending(component: "ToolchainInfo.plist")

        // FIXME: we should propagate an error if the toolchain image is invalid
        guard let info =
            try? PropertyListSerialization.propertyList(from: Data(contentsOf: ToolchainInfo),
                                                        format: nil) as? Dictionary<String, Any> else {
          return nil
        }

        return Toolchain(identifier: info["Identifier"] as? String ?? "",
                         location: location)
      }
      return nil
    }
  }
}

internal struct ToolchainEnumerator: Sequence {
  private let root: URL

  internal init(in DEVELOPER_DIR: URL) {
    self.root = DEVELOPER_DIR.appending(components: "Toolchains",
                                        directoryHint: .isDirectory)
  }

  internal func makeIterator() -> Iterator {
    Iterator(root: root)
  }
}
