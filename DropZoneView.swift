//
//  DraggableView.swift
//  FileViewer
//
//  Created by perkee on 10/14/18.
//  Copyright © 2018 razeware. All rights reserved.
//

import Cocoa

class DropzoneView: NSView {
  var filesReceiver: NSViewController?
  
  required init?(coder decoder: NSCoder) {
    super.init(coder: decoder)
    self.register(forDraggedTypes: ["public.data"])
  }
  
  override func draggingEnded(_ sender: NSDraggingInfo?) {
    if let urls = sender!.draggingPasteboard().propertyList(forType: NSFilenamesPboardType) {
      self.filesReceiver?.representedObject = (urls as! [String]).map { URL(fileURLWithPath: $0) }
    }
  }
}
