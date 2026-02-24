# Package

version       = "0.3.0"
author        = "Andrea Telatin"
description   = "TUI table viewer library with interactive sort, search, filter and graph"
license       = "MIT"
srcDir        = "src"
namedBin      = {"tableview": "tableview", "wordcount_demo": "wordcount"}.toTable()
binDir        = "bin"

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"

task docs, "Generate HTML documentation into docs/":
  exec "nim doc --project --outdir:docs --index:on src/tabview.nim"
  exec "cp docs/tabview.html docs/index.html"
