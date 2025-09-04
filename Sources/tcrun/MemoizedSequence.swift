// Copyright © 2025 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal struct MemoizedSequence<Element>: Sequence {
  private final class Storage {
    var iterator: AnyIterator<Element>?
    var cache: [Element] = []

    init<SequenceType: Sequence>(_ sequence: SequenceType) where SequenceType.Element == Element {
      self.iterator = AnyIterator(sequence.makeIterator())
    }
  }

  private var storage: Storage

  internal init<SequenceType: Sequence>(_ sequence: SequenceType) where SequenceType.Element == Element {
    self.storage = Storage(sequence)
  }

  internal func makeIterator() -> AnyIterator<Element> {
    var index = 0

    return AnyIterator<Element> {
      if index < storage.cache.count {
        defer { index += 1 }
        return storage.cache[index]
      }

      guard let next = storage.iterator?.next() else {
        storage.iterator = nil
        return nil
      }

      storage.cache.append(next)
      defer { index += 1 }
      return next
    }
  }
}
