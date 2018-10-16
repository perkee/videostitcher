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

import Cocoa
import Quartz.QuickLookUI

class ViewController: NSViewController {

  @IBOutlet weak var statusLabel: NSTextField!
  @IBOutlet var dropzone: DropzoneView!
  
  @IBOutlet var tableView: NSTableView!
  let sizeFormatter = ByteCountFormatter()
  var movies = [Metadata]()

  override func viewDidLoad() {
    super.viewDidLoad()
    statusLabel.stringValue = ""
    tableView.delegate = self
    tableView.dataSource = self
    // tableView.register(forDraggedTypes: ["public.data"])
    dropzone.filesReceiver = self
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
    print("selected \(tableView.selectedRowIndexes)");
    movies = movies.enumerated()
      .filter { !tableView.selectedRowIndexes.contains($0.offset) }
      .map { $0.element }
    reloadFileList()
  }
  
  @IBAction func concatenate(_ sender: Any) {
    if movies.isEmpty {
      return
    }

    let dialog = NSSavePanel();
    dialog.title = "Choose output video file location"
    dialog.showsResizeIndicator    = true
    dialog.showsHiddenFiles        = false
    dialog.canCreateDirectories    = true
    dialog.isExtensionHidden = true

    if dialog.runModal() == NSModalResponseOK {
      let paths = movies.map { $0.url.path }.joined(separator: "\" \"")
      let dest = "\(dialog.url!.path).\(movies[0].url.pathExtension)"
      print("/usr/local/bin/ffmpeg -copytb 1 -f concat -i <(for f in \"\( paths )\"; do echo \"file '$f'\"; done) -c copy \"\( dest )\";")
    } else {
      // User clicked on "Cancel"
      return
    }
  }
  
  @IBAction func addFile(_ sender: Any) {
    let dialog = NSOpenPanel();
    dialog.title                   = "Choose movie files";
    dialog.showsResizeIndicator    = true;
    dialog.showsHiddenFiles        = false;
    dialog.canChooseDirectories    = false;
    dialog.canCreateDirectories    = true;
    dialog.allowsMultipleSelection = true;
    //dialog.allowedFileTypes        = ["txt"];

    if (dialog.runModal() == NSModalResponseOK) {
      movies += dialog.urls.map { urlToMetaData(url: $0)! }
      reloadFileList();
    } else {
      // User clicked on "Cancel"
      return
    }
  }
  
  override func keyDown(with event: NSEvent) {
    print("key down \(event.keyCode) \(event.isARepeat)");
    if !event.isARepeat && event.keyCode == 49 {
      previewFile(sender: self)
    }
  }

  func reloadFileList() {
    //directoryItems = directory?.contentsOrderedBy(sortOrder, ascending: sortAscending)
    tableView.reloadData()
  }
  
  func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
    let item = NSPasteboardItem()
    item.setString(String(row), forType: "private.table-row")
    return item
  }
  
  func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
    if dropOperation == .above {
      return .move
    }
    return []
  }
  
  func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
    var oldIndexes = [Int]()
    info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) {
      if let str = ($0.0.item as! NSPasteboardItem).string(forType: "private.table-row"), let index = Int(str) {
        oldIndexes.append(index)
      }
    }
    
    var oldIndexOffset = 0
    var newIndexOffset = 0
    
    // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
    // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
    tableView.beginUpdates()
    for oldIndex in oldIndexes {
      if oldIndex < row {
        tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
        oldIndexOffset -= 1
      } else {
        tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
        newIndexOffset += 1
      }
    }
    tableView.endUpdates()
    
    return true
  }
}

extension ViewController: QLPreviewPanelDataSource {
  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    return movies[tableView.selectedRowIndexes.sorted()[index]].url as QLPreviewItem
  }
  
  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    return tableView.numberOfSelectedRows
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
  }
  
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
    var image: NSImage?
    var text: String = ""
    var cellIdentifier: String = ""
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .long
    
    // 1
    let item = movies[row]
    
    // 2
    if tableColumn == tableView.tableColumns[0] {
      image = item.icon
      text = item.name
      cellIdentifier = CellIdentifiers.NameCell
    } else if tableColumn == tableView.tableColumns[1] {
      text = dateFormatter.string(from: item.date)
      cellIdentifier = CellIdentifiers.DateCell
    } else if tableColumn == tableView.tableColumns[2] {
      text = item.isFolder ? "--" : sizeFormatter.string(fromByteCount: item.size)
      cellIdentifier = CellIdentifiers.SizeCell
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
