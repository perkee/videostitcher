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

// Table Row Dragging info is courtesy sooop https://gist.github.com/sooop/3c964900d429516ba48bd75050d0de0a

import Cocoa
import Quartz.QuickLookUI

func formatDuration (duration: Double) -> String {
  let durationFormatter = DateComponentsFormatter()
  durationFormatter.unitsStyle = .positional
  durationFormatter.allowsFractionalUnits = true
  durationFormatter.zeroFormattingBehavior = .pad
  durationFormatter.includesApproximationPhrase = false
  durationFormatter.includesTimeRemainingPhrase = false
  durationFormatter.allowedUnits = [ .hour, .minute, .second ]

  return durationFormatter.string(from: duration) ?? ""
}

func formatSize (size: Int64) -> String {
  let bcf = ByteCountFormatter()
  return bcf.string(fromByteCount: size)
}

let formatTotalDuration = getTotalDurationSeconds(movies:) --> formatDuration(duration:)
let formatTotalSize = getTotalSizeBytes(movies:) --> formatSize(size:)

class ViewController: NSViewController {
  @IBOutlet var dropzone: DropzoneView!

  var movies = [Metadata]()

  @IBOutlet var tableView: NSTableView!
  @IBOutlet var minusButton: NSButton!
  @IBOutlet var previewButton: NSButton!
  @IBOutlet var statusBar: NSTextField!
  @IBOutlet weak var statusLabel: NSTextField!

  override func viewDidLoad() {
    super.viewDidLoad()
    statusLabel.stringValue = ""
    tableView.delegate = self
    tableView.dataSource = self
    // tableView.register(forDraggedTypes: ["public.data"])
    dropzone.filesReceiver = self

    tableView.register(forDraggedTypes: ["public.data"])
    tableView.allowsMultipleSelection = true

    reloadFileList()
  }

  override var representedObject: Any? {
    didSet {
      if let urls = representedObject as? [URL] {
        movies += urls.map { urlToMetaData(url: $0)! }
        reloadFileList()
      }
    }
  }

  @IBAction func previewFile(_ sender: Any) {
    if let panel = QLPreviewPanel.shared() {
      panel.delegate = self
      panel.dataSource = self
      panel.makeKeyAndOrderFront(self)
    }
  }

  @IBAction func removeFiles(_ sender: Any) {
    print("selected \(tableView.selectedRowIndexes)")
    movies = movies.enumerated()
      .filter { !tableView.selectedRowIndexes.contains($0.offset) }
      .map { $0.element }
    reloadFileList()
  }

  @IBAction func concatenate(_ sender: Any) {
    if movies.isEmpty {
      return
    }

    let dialog = NSSavePanel()
    dialog.title = "Choose output video file location"
    dialog.showsResizeIndicator    = true
    dialog.showsHiddenFiles        = false
    dialog.canCreateDirectories    = true
    dialog.isExtensionHidden = false
    dialog.canSelectHiddenExtension = true

    if dialog.runModal() == NSModalResponseOK {
      concatMovies(movies: movies, path: dialog.url!.path)
    } else {
      print("bad save? \(dialog.url!)")
      return
    }
  }

  @IBAction func addFile(_ sender: Any) {
    let dialog = openPanel()

    if dialog.runModal() == NSModalResponseOK {
      movies += dialog.urls.map { urlToMetaData(url: $0)! }
      reloadFileList()
    } else {
      // User clicked on "Cancel"
      return
    }
  }

  override func keyDown(with event: NSEvent) {
    print("key down \(event.keyCode) \(event.isARepeat)")
    if !event.isARepeat && event.keyCode == 49 {
      previewFile(sender: self)
    }
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let numSelected: Int
    if let table = notification.object as? NSTableView {
      numSelected = table.numberOfSelectedRows

      let anySelected = numSelected > 0
      let anyMovies = movies.count > 0

      previewButton.isEnabled = anyMovies
      minusButton.isEnabled = anySelected

      if anyMovies {
        let apply = makeApplyToMovies(movies: movies)

        let moviesWord = "movie\(movies.count > 1 ? "s" : "")"
        let totalText = "\(movies.count) \(moviesWord), \(apply(formatTotalDuration)), \(apply(formatTotalSize))"

        if numSelected > 1 {
          let selectedText: String
          if numSelected == movies.count {
            selectedText = "all \(numSelected) selected"

            setPreviewButtonTitle("Preview all \(movies.count) movies")
          } else {
            let applyToSelected = makeApplyToSelected(table.selectedRowIndexes, movies)
            let selectedDetails = "\(applyToSelected(formatTotalDuration)), \(applyToSelected(formatTotalSize))"
            selectedText = "\(numSelected) selected: \(selectedDetails)"

            setPreviewButtonTitle("Preview \(numSelected) movies")
          }
          statusBar.stringValue = "\(totalText) (\(selectedText))"

        } else {
          statusBar.stringValue = totalText
          if numSelected == 1 {
            setPreviewButtonTitle("Preview 1 movie")
          } else {
            setPreviewButtonTitle("Preview all \(movies.count) movies")
          }
        }
      } else {
        // now preview button disabled
        statusBar.stringValue = "No movies"
        setPreviewButtonTitle("Preview")
      }
    }
  }

  func setPreviewButtonTitle(_ string: String) {
    previewButton.title = string
    previewButton.sizeToFit()
  }

  func reloadFileList() {
    tableView.reloadData()
    let notification = Notification(name: NSNotification.Name.NSTableViewSelectionDidChange, object: tableView)
    tableViewSelectionDidChange(notification)
  }

  override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
    return true
  }

  override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.delegate = self
    panel.dataSource = self
  }

  // MARK: Allow Drag Operation
  func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
    // let data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
    do {
      let data = try NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false)
      let item = NSPasteboardItem()
      item.setData(data, forType: "public.data")
      pboard.writeObjects([item])
      return true
    } catch {
      return false
    }
  }

  // MARK: Drag Destination Actions
  func tableView(
    _ tableView: NSTableView,
    validateDrop info: NSDraggingInfo,
    proposedRow row: Int,
    proposedDropOperation dropOperation: NSTableViewDropOperation
  ) -> NSDragOperation {
    guard let source = info.draggingSource() as? NSTableView,
      source === tableView
      else {
        // invalid drop
        return []
    }

    if dropOperation == .above {
      return .move
    }
    return []
  }

  func tableView(
    _ tableView: NSTableView,
    acceptDrop info: NSDraggingInfo,
    row: Int,
    dropOperation: NSTableViewDropOperation
  ) -> Bool {
    if
      let itemData = info.draggingPasteboard().pasteboardItems?.first?.data(forType: "public.data"),
      let indexes = NSKeyedUnarchiver.unarchiveObject(with: itemData) as? IndexSet {
      movies.move(with: indexes, to: row)
      let targetIndex = row - (indexes.filter { $0 < row }.count)
      tableView.selectRowIndexes(IndexSet(targetIndex..<targetIndex+indexes.count), byExtendingSelection: false)
      reloadFileList()
      return true
    }
    return false
  }
}

extension ViewController: QLPreviewPanelDataSource {
  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    if tableView.numberOfSelectedRows > 1 {
      return movies[tableView.selectedRowIndexes.sorted()[index]].url as QLPreviewItem
    } else if tableView.numberOfSelectedRows == 1 {
      return movies[((tableView.selectedRowIndexes.first ?? 0) + index) % movies.count].url as QLPreviewItem
    } else {
      return movies[index].url as QLPreviewItem
    }
  }

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    return tableView.numberOfSelectedRows > 1 ? tableView.numberOfSelectedRows : movies.count
  }

}

extension ViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return movies.count
  }
}

extension ViewController: NSTableViewDelegate {
  fileprivate enum CellIdentifiers {
    static let NameCell = "NameCellID"
    static let DateCell = "DateCellID"
    static let SizeCell = "SizeCellID"
    static let DurationCell = "DurationCellID"
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    var image: NSImage?
    var text: String = ""
    var cellIdentifier: String = ""

    // 1
    let item = movies[row]

    // 2
    if tableColumn == tableView.tableColumns[0] {
      image = item.icon
      text = item.name
      cellIdentifier = CellIdentifiers.NameCell
    } else if tableColumn == tableView.tableColumns[1] {
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .short
      dateFormatter.timeStyle = .short

      text = dateFormatter.string(from: item.date)
      cellIdentifier = CellIdentifiers.DateCell
    } else if tableColumn == tableView.tableColumns[2] {
      let sizeFormatter = ByteCountFormatter()

      text = item.isFolder ? "--" : sizeFormatter.string(fromByteCount: item.size)
      cellIdentifier = CellIdentifiers.SizeCell
    } else if tableColumn == tableView.tableColumns[3] {
      text = formatDuration(duration: item.duration)
      cellIdentifier = CellIdentifiers.DurationCell
    }

    // 3
    if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
      cell.textField?.stringValue = text
      cell.imageView?.image = image ?? nil
      return cell
    }
    return nil
  }
}

extension Array {
  mutating func move(from start: Index, to end: Index) {
    print("moving from", start, "to", end)
    guard (0..<count) ~= start, (0...count) ~= end else { return }
    if start == end { return }
    let targetIndex = start < end ? end - 1 : end
    insert(remove(at: start), at: targetIndex)
  }

  mutating func move(with indexes: IndexSet, to toIndex: Index) {
    let movingData = indexes.map { self[$0] }
    let targetIndex = toIndex - indexes.filter { $0 < toIndex }.count
    for (i, e) in indexes.enumerated() {
      remove(at: e - i)
    }
    insert(contentsOf: movingData, at: targetIndex)
  }
}
