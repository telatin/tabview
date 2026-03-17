# Package

version       = "0.3.7"
author        = "Andrea Telatin"
description   = "TUI table viewer library with interactive sort, search, filter and graph"
license       = "MIT"
binDir        = "bin"
srcDir        = "src"
installFiles  = @["tableview.nim", "tableview/parser.nim"]
namedBin      = {"tableview_app": "tableview", "wordcount_demo": "wordcount"}.toTable()

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"

task test, "Run unit tests":
  exec "nim c -r --path:src tests/test_parser.nim"

task docs, "Generate HTML documentation into docs/":
  exec "nim doc --project --outdir:docs --index:on src/tableview.nim"
  exec "cp docs/theindex.html docs/index.html"
