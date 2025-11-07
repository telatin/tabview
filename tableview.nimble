# Package

version       = "0.1.0"
author        = "Your Name"
description   = "TUI application for viewing TSV/CSV files"
license       = "MIT"
srcDir        = "src"
bin           = @["tableview"]

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"
