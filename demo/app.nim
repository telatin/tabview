## Example: embedding tableview in your own Nim program.
##
## Compile from the repo root:
##   nim c -r demo/app.nim demo/titanic.tsv
##
## Or pipe data in:
##   cat demo/titanic.tsv | nim c -r demo/app.nim -

import os
import strutils
import tableview

proc main() =
  # --- Parse arguments (minimal, just to show the pattern) ---
  var filename  = if paramCount() > 0: paramStr(1) else: "-"
  var delimiter = '\0'   # '\0' means auto-detect
  var maxWidth  = 20
  var scheme    = "default"   # "default" | "bold" | "subtle" | "dark"
  var skipLines = 0
  var skipPfx   = ""
  var hasHeader = true

  if filename in ["-h", "--help"]:
    echo "Usage: app [file|-]"
    echo "  Launches the tableview TUI for a TSV/CSV file or stdin."
    quit(0)

  if filename != "-" and not fileExists(filename):
    stderr.writeLine "Error: file not found: " & filename
    quit(1)

  # --- Option A: let the library handle everything ---
  # viewTabularFile reads the file (or stdin), parses it, and opens the TUI.
  viewTabularFile(
    filename,
    schemeName  = scheme,
    delimiter   = delimiter,
    skipLines   = skipLines,
    skipPrefix  = skipPfx,
    hasHeader   = hasHeader,
    maxColWidth = maxWidth,
  )

  # --- Option B: parse first, then mutate, then view ---
  # Useful when you want to add computed columns or filter rows before display.
  #
  # var data = parseDelimitedFile(filename, delimiter, skipLines, skipPfx, hasHeader)
  # # e.g. keep only rows where column 0 starts with "A"
  # data.rows = data.rows.filterIt(it[0].startsWith("A"))
  # viewTable(data, scheme, filename, hasHeader, maxWidth)

when isMainModule:
  main()
