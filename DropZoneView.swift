//
//  DraggableView.swift
//  FileViewer
//
//  Created by perkee on 10/14/18.
//  Copyright © 2018 razeware. All rights reserved.
//

import Cocoa

let dragType = kUTTypeFileURL as String

class DropzoneView: NSView {
  var filesReceiver: NSViewController?

  required init?(coder decoder: NSCoder) {
    super.init(coder: decoder)
    register(forDraggedTypes: [dragType])
  }

  override func draggingEnded(_ sender: NSDraggingInfo?) {
    if let urls = sender!.draggingPasteboard().propertyList(forType: "NSFilenamesPboardType") {
      Swift.print("urls", urls)
      if let urlStrings = (urls as? [String]) {
        Swift.print("url strings", urlStrings)
        self.filesReceiver?.representedObject = urlStrings.map { URL(fileURLWithPath: $0) }
      }
    }
  }
}
