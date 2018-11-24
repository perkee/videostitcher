//
//  DraggableView.swift
//  FileViewer
//
//  Created by perkee on 10/14/18.
//  Copyright © 2018 razeware. All rights reserved.
//

import Cocoa

let dragType = NSPasteboard.PasteboardType(kUTTypeFileURL as String)

class DropzoneView: NSView {
  var filesReceiver: NSViewController?

  required init?(coder decoder: NSCoder) {
    super.init(coder: decoder)
    registerForDraggedTypes([ dragType ])
  }

  override func draggingEnded(_ sender: NSDraggingInfo) {
    let type = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    if let urls = sender.draggingPasteboard.propertyList(forType: type) {
      Swift.print("urls", urls)
      if let urlStrings = (urls as? [String]) {
        Swift.print("url strings", urlStrings)
        self.filesReceiver?.representedObject = urlStrings.map { URL(fileURLWithPath: $0) }
      }
    }
  }
}
