/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import AppKit
import CoreData

public struct Metadata: CustomDebugStringConvertible, Equatable {

  let name: String
  let date: Date
  let size: Int64
  let icon: NSImage
  let color: NSColor
  let isFolder: Bool
  let url: URL
  let duration: Double

  init(
    fileURL: URL,
    name: String,
    date: Date,
    size: Int64,
    icon: NSImage,
    isFolder: Bool,
    color: NSColor,
    duration: Double
  ) {
    self.name = name
    self.date = date
    self.size = size
    self.icon = icon
    self.color = color
    self.isFolder = isFolder
    self.url = fileURL
    self.duration = duration
  }

  public var debugDescription: String {
    return name + " " + "Folder: \(isFolder)" + " Size: \(size)"
  }

}

// MARK: Metadata Equatable

public func == (lhs: Metadata, rhs: Metadata) -> Bool {
  return (lhs.url == rhs.url)
}

public func urlToMetaData(url: URL) -> Metadata? {
  let requiredAttributes = [
    URLResourceKey.localizedNameKey, URLResourceKey.effectiveIconKey,
    URLResourceKey.typeIdentifierKey, URLResourceKey.contentModificationDateKey,
    URLResourceKey.fileSizeKey, URLResourceKey.isDirectoryKey,
    URLResourceKey.isPackageKey
  ]
  do {
    let properties = try  (url as NSURL).resourceValues(forKeys: requiredAttributes)
    let md = MDItemCreateWithURL(nil, (url as CFURL))
    let dur = MDItemCopyAttribute(md, kMDItemDurationSeconds)
    return Metadata(fileURL: url,
                        name: properties[URLResourceKey.localizedNameKey] as? String ?? "",
                        date: properties[URLResourceKey.contentModificationDateKey] as? Date ?? Date.distantPast,
                        size: (properties[URLResourceKey.fileSizeKey] as? NSNumber)?.int64Value ?? 0,
                        icon: properties[URLResourceKey.effectiveIconKey] as? NSImage  ?? NSImage(),
                        isFolder: (properties[URLResourceKey.isDirectoryKey] as? NSNumber)?.boolValue ?? false,
                        color: NSColor(),
                        duration: dur?.doubleValue ?? -1
    )
  } catch {
    print("Error reading file attributes")
    return nil
  }
}

public struct Directory {

  fileprivate var files: [Metadata] = []
  let url: URL

  public enum FileOrder: String {
    case Name
    case Date
    case Size
  }

  public init(folderURL: URL) {
    url = folderURL
    let requiredAttributes = [URLResourceKey.localizedNameKey, URLResourceKey.effectiveIconKey,
                              URLResourceKey.typeIdentifierKey, URLResourceKey.contentModificationDateKey,
                              URLResourceKey.fileSizeKey, URLResourceKey.isDirectoryKey,
                              URLResourceKey.isPackageKey]
    if let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: requiredAttributes,
      options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants],
      errorHandler: nil
    ) {
      while let url = enumerator.nextObject() as? URL {
        print( "Adding File: \(url)")

        if let meta = urlToMetaData(url: url) {
          files.append(meta)
        }
      }
    }
  }

  func contentsOrderedBy(_ orderedBy: FileOrder, ascending: Bool) -> [Metadata] {
    let sortedFiles: [Metadata]
    switch orderedBy {
    case .Name:
      sortedFiles = files.sorted {
        return sortMetadata(
          lhsIsFolder: true,
          rhsIsFolder: true,
          ascending: ascending,
          attributeComparation: itemComparator(lhs: $0.name, rhs: $1.name, ascending: ascending)
        )
      }
    case .Size:
      sortedFiles = files.sorted {
        return sortMetadata(
          lhsIsFolder: true,
          rhsIsFolder: true,
          ascending: ascending,
          attributeComparation: itemComparator(lhs: $0.size, rhs: $1.size, ascending: ascending)
        )
      }
    case .Date:
      sortedFiles = files.sorted {
        return sortMetadata(
          lhsIsFolder: true,
          rhsIsFolder: true,
          ascending: ascending,
          attributeComparation: itemComparator(lhs: $0.date, rhs: $1.date, ascending: ascending)
        )
      }
    }
    return sortedFiles
  }

}

// MARK: - Sorting

func sortMetadata(
  lhsIsFolder: Bool,
  rhsIsFolder: Bool,
  ascending: Bool,
  attributeComparation: Bool
) -> Bool {
  if lhsIsFolder && !rhsIsFolder {
    return ascending
  } else if !lhsIsFolder && rhsIsFolder {
    return !ascending
  }
  return attributeComparation
}

func itemComparator<T: Comparable> (lhs: T, rhs: T, ascending: Bool) -> Bool {
  return ascending ? (lhs < rhs) : (lhs > rhs)
}

public func == (lhs: Date, rhs: Date) -> Bool {
  if lhs.compare(rhs) == .orderedSame {
    return true
  }
  return false
}

public func < (lhs: Date, rhs: Date) -> Bool {
  if lhs.compare(rhs) == .orderedAscending {
    return true
  }
  return false
}
