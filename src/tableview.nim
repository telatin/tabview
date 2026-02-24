import os
import strutils
import argparse
import tabview

export tabview.TableData
export tabview.ColumnType
export tabview.viewTable
export tabview.viewTabularFile

proc main() =
  var p = newParser("tableview"):
    help("TUI application for viewing TSV/CSV files")
    arg("file", nargs = -1, help="Path to the TSV or CSV file to view (or '-' for stdin)")
    flag("-t", "--tsv", help="Force TSV format (tab-separated)")
    flag("-c", "--csv", help="Force CSV format (comma-separated)")
    flag("--noheader", help="File has no header row, create artificial headers")
    option("-w", "--maxwidth", default=some("20"), help="Maximum column width (default: 20)")
    option("-s", "--scheme", default=some("default"), help="Color scheme: default, bold, subtle, dark")
    option("--skip", default=some("0"), help="Skip first N lines before parsing")
    option("--skip-prefix", default=some(""), help="Skip lines starting with this prefix")

  try:
    let opts = p.parse()
    var filename = if opts.file.len > 0: opts.file[0] else: "-"

    let schemeName = opts.scheme
    let maxColWidth = parseInt(opts.maxwidth)
    let skipLines = parseInt(opts.skip)
    let skipPrefix = opts.skipPrefix
    let hasHeader = not opts.noheader

    var delimiter: char = '\0'  # Auto-detect
    if opts.tsv:
      delimiter = '\t'
    elif opts.csv:
      delimiter = ','

    if filename != "-" and not fileExists(filename):
      echo "Error: File not found: ", filename
      quit(1)

    viewTabularFile(filename, schemeName, delimiter, skipLines, skipPrefix, hasHeader, maxColWidth)

  except ShortCircuit as e:
    if e.flag == "argparse_help":
      echo p.help
      quit(0)
  except UsageError:
    stderr.writeLine getCurrentExceptionMsg()
    echo p.help
    quit(1)

when isMainModule:
  main()
