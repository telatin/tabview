# Package

version       = "0.3.0"
author        = "Andrea Telatin"
description   = "TUI table viewer library with interactive sort, search, filter and graph"
license       = "MIT"
srcDir        = "src"
namedBin      = {"tableview_app": "tableview", "wordcount_demo": "wordcount"}.toTable()
binDir        = "bin"

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"

task docs, "Generate HTML documentation into docs/":
  exec "nim doc --project --outdir:docs --index:on src/tableview.nim"
  exec "cp docs/theindex.html docs/index.html"
