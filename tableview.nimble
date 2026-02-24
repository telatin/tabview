# Package

version       = "0.2.0"
author        = "Andrea Telatin"
description   = "TUI application for viewing TSV/CSV files"
license       = "MIT"
srcDir        = "src"
bin           = @["tableview"]
binDir        = "bin"

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"
