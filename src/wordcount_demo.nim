import os
import strutils
import unicode
import argparse
import tableview

when defined(posix):
  import posix

proc countContent(content: string): tuple[lines, words, chars: int] =
  result.lines = content.count('\n')
  result.words = strutils.splitWhitespace(content).len
  result.chars = content.runeLen

proc buildTableData(rows: seq[seq[string]]): TableData =
  result = TableData(
    headers: @["File", "Lines", "Words", "Characters"],
    rows: rows,
    columnWidths: @[4, 5, 5, 10],
    columnTypes: @[ctString, ctInt, ctInt, ctInt],
    hiddenColumns: @[false, false, false, false]
  )
  for row in rows:
    for i, cell in row:
      if i < result.columnWidths.len:
        let w = cell.runeLen
        if w > result.columnWidths[i]:
          result.columnWidths[i] = w

proc printTable(data: TableData) =
  for i, h in data.headers:
    stdout.write(strutils.alignLeft(h, data.columnWidths[i] + 2))
  stdout.writeLine("")
  for w in data.columnWidths:
    stdout.write("-".repeat(w + 2))
  stdout.writeLine("")
  for row in data.rows:
    for i, cell in row:
      if i < data.columnWidths.len:
        stdout.write(strutils.alignLeft(cell, data.columnWidths[i] + 2))
    stdout.writeLine("")

proc main() =
  var p = newParser("wordcount"):
    help("Count lines, words and characters in files")
    arg("paths", nargs = -1, help = "Files to process (use '-' for stdin)")
    flag("-t", "--table", help = "Show results interactively with tableview")
    flag("-s", "--summary-row", help = "Add a totals row when multiple files are given")

  try:
    let opts = p.parse()

    if opts.paths.len == 0:
      echo p.help
      quit(0)

    var rows: seq[seq[string]] = @[]
    var totalLines, totalWords, totalChars = 0
    var stdinConsumed = false

    for path in opts.paths:
      var content: string
      var label: string

      if path == "-":
        content = stdin.readAll()
        label = "<stdin>"
        stdinConsumed = true
      else:
        if not fileExists(path):
          stderr.writeLine("Error: file not found: " & path)
          continue
        content = readFile(path)
        label = path

      let (lines, words, chars) = countContent(content)
      totalLines += lines
      totalWords += words
      totalChars += chars
      rows.add(@[label, $lines, $words, $chars])

    if rows.len == 0:
      quit(0)

    if opts.summaryRow and rows.len > 1:
      rows.add(@["TOTAL", $totalLines, $totalWords, $totalChars])

    let data = buildTableData(rows)

    if opts.table:
      if stdinConsumed:
        when defined(posix):
          discard posix.close(0)
          let ttyFd = posix.open("/dev/tty", posix.O_RDWR)
          if ttyFd < 0:
            stderr.writeLine("Error: cannot open /dev/tty for terminal input")
            quit(1)
          if ttyFd != 0:
            discard posix.dup2(ttyFd, 0)
            discard posix.close(ttyFd)
      viewTable(data, filename = "wordcount")
    else:
      printTable(data)

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
