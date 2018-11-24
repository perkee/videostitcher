//
//  opener.swift
//  Stitchee
//
//  Created by perkee on 11/20/18.
//  Copyright © 2018 razeware. All rights reserved.
//

import Cocoa

infix operator --> :AdditionPrecedence
infix operator ---> :AdditionPrecedence

func --> <A, B, C> (
  aToB: @escaping (A) -> B,
  bToC: @escaping (B) -> C
) -> (A) -> C {
  return { a in
    let b = aToB(a)
    let c = bToC(b)
    return c
  }
}

func ---> <A, B, C, D> (
  abToC: @escaping (A, B) -> C,
  cToD: @escaping (C) -> D
) -> (A, B) -> D {
  return { a, b in
    let c = abToC(a, b)
    let d = cToD(c)
    return d
  }
}

//func applyToSelected(indices: IndexSet, movies: Array<Metadata>) -> ((Array<Metadata>) -> String) -> String {
//  let selectedMovies = getSelectedMovies(indices: indices, movies: movies)
//  return { $0(selectedMovies) }
//}

func compose2<A, X, B, C>(f: @escaping (B) -> C, g: @escaping (A, X) -> B) -> (A, X) -> C {
  return { f(g($0, $1)) }
}

func makeApplyToMovies(movies: [Metadata]) -> (([Metadata]) -> String) -> String {
  return { $0(movies) }
}

let makeApplyToSelected = compose2(f: makeApplyToMovies, g: getSelectedMovies)

func compose3<A, X, Y, B, C>(f: @escaping (B) -> C, g: @escaping (A, X, Y) -> B) -> (A, X, Y) -> C {
  return { f(g($0, $1, $2)) }
}

func openPanel() -> NSOpenPanel {
  let dialog = NSOpenPanel()

  dialog.title                   = "Choose movie files"
  dialog.showsResizeIndicator    = true
  dialog.showsHiddenFiles        = false
  dialog.canChooseDirectories    = false
  dialog.canCreateDirectories    = true
  dialog.allowsMultipleSelection = true
  dialog.allowedFileTypes        = ["public.movie"]

  return dialog
}

func getSelectedMovies(indices: IndexSet, movies: [Metadata]) -> [Metadata] {
  return indices.compactMap { index in movies[index] }
}

func getTotalDurationSeconds(movies: [Metadata]) -> Double {
  return movies.reduce(0) {sum, movie in sum + movie.duration}
}

func getTotalSizeBytes(movies: [Metadata]) -> Int64 {
  return movies.reduce(0) {sum, movie in sum + movie.size}
}

func concatMovies(movies: [Metadata], path: String) {
  let paths = movies.map { $0.url.path }.joined(separator: "' '")
  let dest = "\(path).\(movies[0].url.pathExtension)"
  let bashFileRedirect = "<(for f in '\( paths )'; do echo \\\"file '$f'\\\"; done)"
  let command = "/usr/local/bin/ffmpeg -f concat -i \(bashFileRedirect) -c copy '\( dest )';"
  let script = "tell application \"Terminal\"\n\tactivate\n\tdo script with command \"\( command )\"\n\tend tell"

  var error: NSDictionary?
  if let scriptObject = NSAppleScript(source: script) {
    let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
    print("output: \(output.stringValue ?? "none")")
    print("error: \(String(describing: error ?? nil))")
  }
  print(script)
}
