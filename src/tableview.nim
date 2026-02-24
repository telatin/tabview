import os
import terminal
import argparse
import unicode
import tables
import algorithm
import strutils
import streams
import re
when defined(posix):
  import posix
from illwave as iw import `[]`, `[]=`, `==`
from nimwave as nw import nil
import parser

type
  ColorScheme = object
    activeCellBg: iw.BackgroundColor
    activeCellFg: iw.ForegroundColor
    activeRowBg: iw.BackgroundColor
    activeRowFg: iw.ForegroundColor
    activeColBg: iw.BackgroundColor
    activeColFg: iw.ForegroundColor
    evenRowBg: iw.BackgroundColor
    oddRowBg: iw.BackgroundColor
    normalFg: iw.ForegroundColor
    screenBg: iw.BackgroundColor  # Background for non-rendered screen areas

  InputMode = enum
    imNormal, imCommand, imSearch, imSearchColumn, imFilter, imGraph, imSaveFile, imSaveConfirm

  GraphEntry = object
    occurrence: string
    times: int
    percentage: float

  State = object
    tableData: TableData
    filteredRows: seq[int] # Indices of rows that match the filter
    scrollY: int
    scrollX: int
    activeRow: int  # Current/focused row (0-based, relative to data rows)
    activeCol: int  # Current/focused column (0-based)
    statusMessage: string
    colorScheme: ColorScheme
    currentSchemeName: string  # Track current color scheme name for rotation
    inputMode: InputMode
    inputBuffer: string
    searchPattern: string
    searchInColumn: bool
    lastSearchRow: int
    filename: string
    hasHeader: bool
    frozenRows: int
    frozenCols: int
    regexSearch: bool
    graphData: seq[GraphEntry]
    graphColumnName: string
    graphScrollY: int
    pendingSaveFile: string
    statusMessageTTL: int   # ticks remaining to show a transient status message
# Safer, explicit color schemes for an illwill-style TUI table viewer.
# All entries avoid bgNone/fgDefault so they look consistent across terminals.

let ColorSchemesTable = {
  # --- Improved originals (avoid defaults) ---
  "default": ColorScheme(           # classic dark
    activeCellBg: iw.bgYellow,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgBlue,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgCyan,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlack,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "bold": ColorScheme(              # high-saturation dark
    activeCellBg: iw.bgYellow,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgMagenta,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlue,
    activeColFg:  iw.fgWhite,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlue,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "subtle": ColorScheme(            # low-contrast but explicit
    activeCellBg: iw.bgBlack,
    activeCellFg: iw.fgWhite,
    activeRowBg:  iw.bgBlue,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgWhite,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlack,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "dark": ColorScheme(              # cyan accent dark
    activeCellBg: iw.bgCyan,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgBlack,
    activeRowFg:  iw.fgCyan,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgCyan,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlue,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),

  # --- New dark schemes ---
  "highContrastDark": ColorScheme(
    activeCellBg: iw.bgYellow,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgRed,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgYellow,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlack,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "oneDarkish": ColorScheme(        # Atom One Dark-ish via ANSI
    activeCellBg: iw.bgBlue,
    activeCellFg: iw.fgWhite,
    activeRowBg:  iw.bgMagenta,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgCyan,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlue,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "nordish": ColorScheme(           # Nord-ish via ANSI
    activeCellBg: iw.bgCyan,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgBlue,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgCyan,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlack,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "gruvboxDarkish": ColorScheme(    # Gruvbox dark-ish via ANSI
    activeCellBg: iw.bgYellow,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgBlue,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgYellow,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlue,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  ),
  "matrix": ColorScheme(            # green-on-black vibes
    activeCellBg: iw.bgGreen,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgBlack,
    activeRowFg:  iw.fgGreen,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgGreen,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlack,
    normalFg:     iw.fgGreen,
    screenBg:     iw.bgBlack
  ),

  # --- New light schemes ---
  "light": ColorScheme(
    activeCellBg: iw.bgBlue,
    activeCellFg: iw.fgWhite,
    activeRowBg:  iw.bgCyan,
    activeRowFg:  iw.fgBlack,
    activeColBg:  iw.bgWhite,
    activeColFg:  iw.fgBlue,
    evenRowBg:    iw.bgWhite,
    oddRowBg:     iw.bgWhite,
    normalFg:     iw.fgBlack,
    screenBg:     iw.bgWhite
  ),
  "highContrastLight": ColorScheme(
    activeCellBg: iw.bgBlack,
    activeCellFg: iw.fgWhite,
    activeRowBg:  iw.bgYellow,
    activeRowFg:  iw.fgBlack,
    activeColBg:  iw.bgWhite,
    activeColFg:  iw.fgBlack,
    evenRowBg:    iw.bgWhite,
    oddRowBg:     iw.bgWhite,
    normalFg:     iw.fgBlack,
    screenBg:     iw.bgWhite
  ),
  "solarizedLightish": ColorScheme( # approximate via ANSI
    activeCellBg: iw.bgYellow,      # base2-ish
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgCyan,        # cyan accent
    activeRowFg:  iw.fgBlack,
    activeColBg:  iw.bgWhite,
    activeColFg:  iw.fgBlue,
    evenRowBg:    iw.bgWhite,
    oddRowBg:     iw.bgWhite,
    normalFg:     iw.fgBlack,
    screenBg:     iw.bgWhite
  ),
  "gruvboxLightish": ColorScheme(
    activeCellBg: iw.bgYellow,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgMagenta,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgWhite,
    activeColFg:  iw.fgYellow,
    evenRowBg:    iw.bgWhite,
    oddRowBg:     iw.bgWhite,
    normalFg:     iw.fgBlack,
    screenBg:     iw.bgWhite
  ),

  # --- Monochrome / safe fallback ---
  "mono": ColorScheme(              # minimal risk across themes
    activeCellBg: iw.bgWhite,
    activeCellFg: iw.fgBlack,
    activeRowBg:  iw.bgBlack,
    activeRowFg:  iw.fgWhite,
    activeColBg:  iw.bgBlack,
    activeColFg:  iw.fgWhite,
    evenRowBg:    iw.bgBlack,
    oddRowBg:     iw.bgBlack,
    normalFg:     iw.fgWhite,
    screenBg:     iw.bgBlack
  )
}.toTable


# Color scheme names for rotation
const ColorSchemeNames = ["default", "bold", "subtle", "dark", "mono", "highContrastLight"]

include nimwave/prelude

proc init(ctx: var nw.Context[State], filename: string, schemeName: string,
          delimiter: char = '\t', skipLines: int = 0, skipPrefix: string = "",
          hasHeader: bool = true, fromStdin: bool = false, maxColWidth: int = 20) =

  # Select color scheme early, before terminal setup
  if ColorSchemesTable.hasKey(schemeName):
    ctx.data.colorScheme = ColorSchemesTable[schemeName]
    ctx.data.currentSchemeName = schemeName
  else:
    echo "Warning: Color scheme '", schemeName, "' not found. Using 'default'."
    ctx.data.colorScheme = ColorSchemesTable["default"]
    ctx.data.currentSchemeName = "default"

  # Parse the data BEFORE initializing the TUI
  if fromStdin:
    # Read all data from stdin before starting TUI
    # Read everything into memory first
    var allInput = ""
    var line: string
    while stdin.readLine(line):
      allInput.add(line & "\n")

    # Now completely disconnect from the pipe and reopen terminal
    when defined(posix):
      # Close stdin completely
      discard posix.close(0)

      # Reopen stdin from terminal
      let ttyFd = posix.open("/dev/tty", posix.O_RDWR)
      if ttyFd < 0:
        echo "Error: Cannot open /dev/tty for terminal input"
        quit(1)

      # Make sure it's fd 0 (stdin)
      if ttyFd != 0:
        discard posix.dup2(ttyFd, 0)
        discard posix.close(ttyFd)

    # Parse the data we read
    let stringStream = newStringStream(allInput)
    ctx.data.tableData = parseDelimitedStream(stringStream, delimiter, skipLines, skipPrefix, hasHeader, maxColWidth)
    stringStream.close()
    ctx.data.filename = "<stdin>"
  else:
    let detectedDelim = if delimiter == '\0': detectDelimiter(filename) else: delimiter
    ctx.data.tableData = parseDelimitedFile(filename, detectedDelim, skipLines, skipPrefix, hasHeader, maxColWidth)
    ctx.data.filename = filename

  # NOW initialize the TUI after data is loaded and stdin is restored
  terminal.enableTrueColors()
  iw.init()
  setControlCHook(
    proc () {.noconv.} =
      iw.deinit()
      quit(0)
  )
  terminal.hideCursor()

  ctx.data.scrollY = 0
  ctx.data.scrollX = 0
  ctx.data.activeRow = 0
  ctx.data.activeCol = 0
  ctx.data.hasHeader = hasHeader
  ctx.data.inputMode = imNormal
  ctx.data.inputBuffer = ""
  ctx.data.searchPattern = ""
  ctx.data.searchInColumn = false
  ctx.data.lastSearchRow = -1
  ctx.data.frozenRows = 0
  ctx.data.frozenCols = 0
  ctx.data.regexSearch = false
  ctx.data.graphData = @[]
  ctx.data.graphColumnName = ""
  ctx.data.graphScrollY = 0
  ctx.data.statusMessage = "File: " & ctx.data.filename & " | Rows: " & $ctx.data.tableData.rows.len & " | Use arrows to scroll, q to quit"
  ctx.data.filteredRows = @[]

proc deinit() =
  terminal.showCursor()
  iw.deinit()

proc renderTableCell(text: string, width: int, ctx: var nw.Context[State], x, y: int) =
  ## Render a single table cell with padding
  var displayText = text
  if displayText.runeLen > width:
    displayText = displayText.runeSubStr(0, width - 3) & "..."
  else:
    # Pad with spaces
    let padding = width - displayText.runeLen
    displayText = displayText & " ".repeat(padding)

  iw.write(ctx.tb, x, y, displayText)

proc fillScreenBackground(ctx: var nw.Context[State]) =
  ## Fill the entire screen with the screenBg color
  let termWidth = iw.width(ctx.tb)
  let termHeight = iw.height(ctx.tb)
  let scheme = ctx.data.colorScheme

  iw.setBackgroundColor(ctx.tb, scheme.screenBg)
  iw.setForegroundColor(ctx.tb, scheme.normalFg)

  for y in 0 ..< termHeight:
    for x in 0 ..< termWidth:
      iw.write(ctx.tb, x, y, " ")

  iw.resetAttributes(ctx.tb)

proc applyFilter(ctx: var nw.Context[State]) =
  ## Apply the current searchPattern as a filter
  ctx.data.filteredRows = @[]
  if ctx.data.searchPattern.len == 0:
    return

  var regex: Regex
  if ctx.data.regexSearch:
    try:
      regex = re(ctx.data.searchPattern)
    except:
      ctx.data.statusMessage = "Invalid Regex for filter"
      return
  
  for i, row in ctx.data.tableData.rows:
    for cell in row:
      if (ctx.data.regexSearch and cell.find(regex) != -1) or
         (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in cell.toLower()):
        ctx.data.filteredRows.add(i)
        break # next row

proc generateGraphData(ctx: var nw.Context[State]) =
  ## Generate graph data by counting occurrences in the active column
  ctx.data.graphData = @[]
  let colIdx = ctx.data.activeCol

  # Get column name
  if colIdx < ctx.data.tableData.headers.len:
    ctx.data.graphColumnName = ctx.data.tableData.headers[colIdx]
  else:
    ctx.data.graphColumnName = "Column " & $(colIdx + 1)

  # Count occurrences
  var countTable = initTable[string, int]()
  let isFiltered = ctx.data.filteredRows.len > 0
  let dataRows = if isFiltered: ctx.data.filteredRows else: toSeq(0 ..< ctx.data.tableData.rows.len)

  for rowIdx in dataRows:
    if rowIdx < ctx.data.tableData.rows.len:
      let row = ctx.data.tableData.rows[rowIdx]
      if colIdx < row.len:
        let value = row[colIdx]
        if countTable.hasKey(value):
          countTable[value] += 1
        else:
          countTable[value] = 1

  # Calculate total
  var total = 0
  for count in countTable.values:
    total += count

  # Create graph entries with percentages
  for occurrence, times in countTable.pairs:
    let percentage = if total > 0: (times.float / total.float) * 100.0 else: 0.0
    ctx.data.graphData.add(GraphEntry(
      occurrence: occurrence,
      times: times,
      percentage: percentage
    ))

  # Sort by times descending
  ctx.data.graphData.sort(proc(a, b: GraphEntry): int =
    return cmp(b.times, a.times)
  )

  ctx.data.graphScrollY = 0

proc saveTableToFile(ctx: var nw.Context[State], filename: string): string =
  ## Save current table to file. Returns "" on success, error message on failure.
  ## Writes all rows in current sort order with header; hidden columns are excluded.
  ## Delimiter is inferred from the file extension (.csv → comma, anything else → tab).
  let data = ctx.data.tableData
  let (_, _, ext) = splitFile(filename)
  let delimiter = if ext.toLower() == ".csv": ',' else: '\t'

  var visibleCols: seq[int] = @[]
  for i in 0 ..< data.headers.len:
    if not data.hiddenColumns[i]:
      visibleCols.add(i)

  if visibleCols.len == 0:
    return "No visible columns to save"

  try:
    let f = open(filename, fmWrite)
    defer: f.close()

    var headerFields: seq[string] = @[]
    for colIdx in visibleCols:
      headerFields.add(data.headers[colIdx])
    f.writeLine(headerFields.join($delimiter))

    for row in data.rows:
      var fields: seq[string] = @[]
      for colIdx in visibleCols:
        fields.add(if colIdx < row.len: row[colIdx] else: "")
      f.writeLine(fields.join($delimiter))

    return ""
  except IOError as e:
    return "Error: " & e.msg
  except Exception as e:
    return "Error: " & e.msg

proc renderTable(ctx: var nw.Context[State]) =
  # Fill the entire screen with the background color first
  fillScreenBackground(ctx)

  let data = ctx.data.tableData
  let termWidth = iw.width(ctx.tb)
  let termHeight = iw.height(ctx.tb)
  let isFiltered = ctx.data.filteredRows.len > 0

  # Reserve last line for status bar
  let contentHeight = termHeight - 1
  var currentX = 0
  var visibleColumns: seq[int] = @[]
  var columnXPositions: seq[int] = @[]

  # Determine which columns are visible based on scrollX and hidden columns
  var accumulatedWidth = 0

  # Handle frozen columns first - they are always visible
  for i in 0 ..< ctx.data.frozenCols:
    if i < data.hiddenColumns.len and not data.hiddenColumns[i]:
      if currentX < termWidth:
        visibleColumns.add(i)
        columnXPositions.add(currentX)
        currentX += data.columnWidths[i] + 2

  # Then, handle scrolled columns
  accumulatedWidth = 0
  for i, width in data.columnWidths:
    if i < ctx.data.frozenCols: continue # Already handled
    if i < data.hiddenColumns.len and data.hiddenColumns[i]:
      continue  # Skip hidden columns
    if accumulatedWidth >= ctx.data.scrollX:
      if currentX < termWidth:
        visibleColumns.add(i)
        columnXPositions.add(currentX)
        currentX += width + 2  # +2 for separator
    accumulatedWidth += width + 2
  
  let totalRows = if isFiltered: ctx.data.filteredRows.len else: data.rows.len

  # Render headers (always visible at top if not part of frozen rows)
  let headerOffset = if ctx.data.frozenRows > 0: 0 else: 2
  if data.headers.len > 0 and ctx.data.frozenRows == 0:
    for idx, colIdx in visibleColumns:
      let header = if colIdx < data.headers.len: data.headers[colIdx] else: ""
      let width = if colIdx < data.columnWidths.len: data.columnWidths[colIdx] else: 10
      iw.setBackgroundColor(ctx.tb, iw.bgBlue)
      iw.setForegroundColor(ctx.tb, iw.fgWhite)
      renderTableCell(header, width, ctx, columnXPositions[idx], 0)
      iw.resetAttributes(ctx.tb)

    # Header separator line
    if contentHeight > 1:
      for x in 0 ..< termWidth:
        iw.write(ctx.tb, x, 1, "\u2500")  # horizontal line

  # Render frozen rows
  for rowIdx in 0 ..< ctx.data.frozenRows:
    if rowIdx >= data.rows.len: break
    let screenY = rowIdx + headerOffset
    let dataRowIdx = if isFiltered: ctx.data.filteredRows[rowIdx] else: rowIdx
    let row = data.rows[dataRowIdx]
    let isActiveRow = (dataRowIdx == ctx.data.activeRow)

    for idx, colIdx in visibleColumns:
        let cell = if colIdx < row.len: row[colIdx] else: ""
        let width = if colIdx < data.columnWidths.len: data.columnWidths[colIdx] else: 10
        let isActiveCol = (colIdx == ctx.data.activeCol)
        let isActiveCell = isActiveRow and isActiveCol
        let scheme = ctx.data.colorScheme
        # Set colors, same logic as normal rows
        if isActiveCell:
          iw.setBackgroundColor(ctx.tb, scheme.activeCellBg)
          iw.setForegroundColor(ctx.tb, scheme.activeCellFg)
        elif isActiveRow:
          iw.setBackgroundColor(ctx.tb, scheme.activeRowBg)
          iw.setForegroundColor(ctx.tb, scheme.activeRowFg)
        else:
          iw.setBackgroundColor(ctx.tb, iw.bgBlack) # A distinct background for frozen rows
          iw.setForegroundColor(ctx.tb, iw.fgWhite)

        renderTableCell(cell, width, ctx, columnXPositions[idx], screenY)
        iw.resetAttributes(ctx.tb)


  # Render data rows
  let startRow = ctx.data.scrollY + ctx.data.frozenRows
  let rowOffset = headerOffset + ctx.data.frozenRows
  let maxRows = min(contentHeight - rowOffset, totalRows - startRow)

  for rowIdx in 0 ..< maxRows:
    let dataRowIdx = if isFiltered: ctx.data.filteredRows[startRow + rowIdx] else: startRow + rowIdx
    if dataRowIdx >= data.rows.len:
      break

    let row = data.rows[dataRowIdx]
    let screenY = rowIdx + rowOffset
    if screenY >= contentHeight: continue
    let isActiveRow = (dataRowIdx == ctx.data.activeRow)

    for idx, colIdx in visibleColumns:
      let cell = if colIdx < row.len: row[colIdx] else: ""
      let width = if colIdx < data.columnWidths.len: data.columnWidths[colIdx] else: 10
      let isActiveCol = (colIdx == ctx.data.activeCol)
      let isActiveCell = isActiveRow and isActiveCol

      # Set colors based on active state using the color scheme
      let scheme = ctx.data.colorScheme
      var isSearchMatch = false
      if ctx.data.searchPattern.len > 0 and cell.toLower().contains(ctx.data.searchPattern.toLower()):
        if ctx.data.searchInColumn:
          # Only highlight if we're in the active column
          if isActiveCol:
            isSearchMatch = true
        else:
          # Highlight matches in all columns
          isSearchMatch = true

      if isActiveCell:
        # Active cell (intersection of active row and column) - most prominent
        iw.setBackgroundColor(ctx.tb, scheme.activeCellBg)
        iw.setForegroundColor(ctx.tb, scheme.activeCellFg)
      elif isSearchMatch:
        # Search match - should be prominent to see results
        iw.setBackgroundColor(ctx.tb, iw.bgYellow)
        iw.setForegroundColor(ctx.tb, iw.fgBlack)
      elif isActiveRow:
        # Active row - highlighted
        iw.setBackgroundColor(ctx.tb, scheme.activeRowBg)
        iw.setForegroundColor(ctx.tb, scheme.activeRowFg)
      elif isActiveCol:
        # Active column - subtle highlight
        iw.setBackgroundColor(ctx.tb, scheme.activeColBg)
        iw.setForegroundColor(ctx.tb, scheme.activeColFg)
      else:
        # Alternate row colors for better readability
        if rowIdx mod 2 == 0:
          iw.setBackgroundColor(ctx.tb, scheme.evenRowBg)
        else:
          iw.setBackgroundColor(ctx.tb, scheme.oddRowBg)
        iw.setForegroundColor(ctx.tb, scheme.normalFg)

      renderTableCell(cell, width, ctx, columnXPositions[idx], screenY)
      iw.resetAttributes(ctx.tb)

  # Render status bar at bottom
  iw.setBackgroundColor(ctx.tb, iw.bgWhite)
  iw.setForegroundColor(ctx.tb, iw.fgBlack)

  var statusLine = ""
  case ctx.data.inputMode:
  of imCommand:
    statusLine = ":" & ctx.data.inputBuffer
  of imSearch:
    statusLine = "/" & ctx.data.inputBuffer
  of imSearchColumn:
    statusLine = "|" & ctx.data.inputBuffer
  of imFilter:
    statusLine = "&" & ctx.data.inputBuffer
  of imSaveFile:
    statusLine = "Save to: " & ctx.data.inputBuffer
  of imSaveConfirm:
    statusLine = "Overwrite '" & ctx.data.pendingSaveFile & "'? (y/n)"
  of imNormal, imGraph:
    statusLine = ctx.data.statusMessage

  statusLine = statusLine & " ".repeat(max(0, termWidth - statusLine.runeLen))
  iw.write(ctx.tb, 0, termHeight - 1, statusLine.runeSubStr(0, termWidth))
  iw.resetAttributes(ctx.tb)

proc renderGraphView(ctx: var nw.Context[State]) =
  ## Render the graph/statistics view for the active column
  # Fill the entire screen with the background color first
  fillScreenBackground(ctx)

  let termWidth = iw.width(ctx.tb)
  let termHeight = iw.height(ctx.tb)
  let contentHeight = termHeight - 1  # Reserve last line for status

  # Column widths
  let occurrenceWidth = 30
  let timesWidth = 10
  let percentageWidth = 12
  let plotWidth = termWidth - occurrenceWidth - timesWidth - percentageWidth - 6  # -6 for spacing

  var currentY = 0

  # Render title
  iw.setBackgroundColor(ctx.tb, iw.bgCyan)
  iw.setForegroundColor(ctx.tb, iw.fgBlack)
  let title = " Graph View: " & ctx.data.graphColumnName & " "
  iw.write(ctx.tb, 0, currentY, title & " ".repeat(max(0, termWidth - title.runeLen)))
  iw.resetAttributes(ctx.tb)
  currentY += 1

  # Render headers
  if currentY < contentHeight:
    iw.setBackgroundColor(ctx.tb, iw.bgBlue)
    iw.setForegroundColor(ctx.tb, iw.fgWhite)

    var headerLine = ""
    headerLine.add(strutils.alignLeft("Occurrence", occurrenceWidth))
    headerLine.add(" | ")
    headerLine.add(strutils.alignLeft("Times", timesWidth))
    headerLine.add(" | ")
    headerLine.add(strutils.alignLeft("Percentage", percentageWidth))
    headerLine.add(" | ")
    headerLine.add("Plot")

    iw.write(ctx.tb, 0, currentY, headerLine & " ".repeat(max(0, termWidth - headerLine.runeLen)))
    iw.resetAttributes(ctx.tb)
    currentY += 1

  # Render separator
  if currentY < contentHeight:
    for x in 0 ..< termWidth:
      iw.write(ctx.tb, x, currentY, "\u2500")
    currentY += 1

  # Render data rows
  let maxRows = contentHeight - currentY
  let startIdx = ctx.data.graphScrollY
  let endIdx = min(startIdx + maxRows, ctx.data.graphData.len)

  for i in startIdx ..< endIdx:
    if currentY >= contentHeight: break

    let entry = ctx.data.graphData[i]
    var rowLine = ""

    # Occurrence column (truncate if needed)
    var occStr = entry.occurrence
    if occStr.runeLen > occurrenceWidth:
      occStr = occStr.runeSubStr(0, occurrenceWidth - 3) & "..."
    rowLine.add(strutils.alignLeft(occStr, occurrenceWidth))
    rowLine.add(" | ")

    # Times column
    rowLine.add(strutils.alignLeft($entry.times, timesWidth))
    rowLine.add(" | ")

    # Percentage column (2 decimals)
    let percStr = entry.percentage.formatFloat(ffDecimal, 2) & "%"
    rowLine.add(strutils.alignLeft(percStr, percentageWidth))
    rowLine.add(" | ")

    # Plot column (each * = 2.5%)
    let numStars = int(entry.percentage / 2.5)
    let plot = "*".repeat(min(numStars, plotWidth))
    rowLine.add(plot)

    # Alternate row colors
    if i mod 2 == 0:
      iw.setBackgroundColor(ctx.tb, iw.bgNone)
    else:
      iw.setBackgroundColor(ctx.tb, iw.bgBlack)
    iw.setForegroundColor(ctx.tb, iw.fgWhite)

    iw.write(ctx.tb, 0, currentY, rowLine & " ".repeat(max(0, termWidth - rowLine.runeLen)))
    iw.resetAttributes(ctx.tb)
    currentY += 1

  # Render status bar
  iw.setBackgroundColor(ctx.tb, iw.bgWhite)
  iw.setForegroundColor(ctx.tb, iw.fgBlack)
  let statusLine = "Showing " & $ctx.data.graphData.len & " unique values | Press Esc or q to return"
  iw.write(ctx.tb, 0, termHeight - 1, statusLine & " ".repeat(max(0, termWidth - statusLine.runeLen)))
  iw.resetAttributes(ctx.tb)

proc updateStatusMessage(ctx: var nw.Context[State]) =
  ## Update the status message to show current position
  let data = ctx.data.tableData
  let cellInfo = "Cell: (" & $(ctx.data.activeRow + 1) & ", " & $(ctx.data.activeCol + 1) & ")"
  let rowInfo = "Row: " & $(ctx.data.activeRow + 1) & "/" & $data.rows.len
  let colInfo = "Col: " & $(ctx.data.activeCol + 1) & "/" & $data.columnWidths.len

  # Show column type
  var colType = "?"
  if ctx.data.activeCol < data.columnTypes.len:
    case data.columnTypes[ctx.data.activeCol]:
    of ctString: colType = "STR"
    of ctInt: colType = "INT"
    of ctFloat: colType = "FLT"

  ctx.data.statusMessage = cellInfo & " | " & rowInfo & " | " & colInfo & " [" & colType & "]"

proc sortTable(ctx: var nw.Context[State], ascending: bool) =
  ## Sort table by active column
  let colIdx = ctx.data.activeCol
  if colIdx >= ctx.data.tableData.columnTypes.len:
    return

  let colType = ctx.data.tableData.columnTypes[colIdx]

  case colType:
  of ctInt, ctFloat:
    # Numeric sort
    ctx.data.tableData.rows.sort(proc(a, b: seq[string]): int =
      let aVal = if colIdx < a.len and a[colIdx].len > 0: a[colIdx] else: "0"
      let bVal = if colIdx < b.len and b[colIdx].len > 0: b[colIdx] else: "0"
      try:
        let aNum = parseFloat(aVal)
        let bNum = parseFloat(bVal)
        if ascending:
          return cmp(aNum, bNum)
        else:
          return cmp(bNum, aNum)
      except:
        return 0
    )
  of ctString:
    # String sort
    ctx.data.tableData.rows.sort(proc(a, b: seq[string]): int =
      let aVal = if colIdx < a.len: a[colIdx] else: ""
      let bVal = if colIdx < b.len: b[colIdx] else: ""
      if ascending:
        return cmp(aVal, bVal)
      else:
        return cmp(bVal, aVal)
    )

proc searchNext(ctx: var nw.Context[State]): bool =
  ## Search for next occurrence of pattern, returns true if found
  if ctx.data.searchPattern.len == 0:
    return false

  var regex: Regex
  if ctx.data.regexSearch:
    try:
      regex = re(ctx.data.searchPattern)
    except:
      ctx.data.statusMessage = "Invalid Regex"
      return false
  
  let startRow = if ctx.data.lastSearchRow >= 0: ctx.data.lastSearchRow + 1 else: ctx.data.activeRow + 1
  let data = ctx.data.tableData

  for rowIdx in startRow ..< data.rows.len:
    let row = data.rows[rowIdx]

    if ctx.data.searchInColumn:
      # Search in active column only
      if ctx.data.activeCol < row.len:
        if (ctx.data.regexSearch and row[ctx.data.activeCol].find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in row[ctx.data.activeCol].toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true
    else:
      # Search in all columns
      for cell in row:
        if (ctx.data.regexSearch and cell.find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in cell.toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true

  # Wrap around
  for rowIdx in 0 ..< startRow:
    let row = data.rows[rowIdx]

    if ctx.data.searchInColumn:
      if ctx.data.activeCol < row.len:
        if (ctx.data.regexSearch and row[ctx.data.activeCol].find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in row[ctx.data.activeCol].toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true
    else:
      for cell in row:
        if (ctx.data.regexSearch and cell.find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in cell.toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true

  return false

proc searchPrev(ctx: var nw.Context[State]): bool =
  ## Search for previous occurrence of pattern, returns true if found
  if ctx.data.searchPattern.len == 0:
    return false
  
  var regex: Regex
  if ctx.data.regexSearch:
    try:
      regex = re(ctx.data.searchPattern)
    except:
      ctx.data.statusMessage = "Invalid Regex"
      return false

  let startRow = if ctx.data.lastSearchRow >= 0: ctx.data.lastSearchRow - 1 else: ctx.data.activeRow - 1
  let data = ctx.data.tableData

  for rowIdx in countdown(startRow, 0):
    if rowIdx < 0 or rowIdx >= data.rows.len:
      continue
    let row = data.rows[rowIdx]

    if ctx.data.searchInColumn:
      if ctx.data.activeCol < row.len:
        if (ctx.data.regexSearch and row[ctx.data.activeCol].find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in row[ctx.data.activeCol].toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true
    else:
      for cell in row:
        if (ctx.data.regexSearch and cell.find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in cell.toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true

  # Wrap around
  for rowIdx in countdown(data.rows.len - 1, startRow + 1):
    if rowIdx < 0 or rowIdx >= data.rows.len:
      continue
    let row = data.rows[rowIdx]

    if ctx.data.searchInColumn:
      if ctx.data.activeCol < row.len:
        if (ctx.data.regexSearch and row[ctx.data.activeCol].find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in row[ctx.data.activeCol].toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true
    else:
      for cell in row:
        if (ctx.data.regexSearch and cell.find(regex) != -1) or
           (not ctx.data.regexSearch and ctx.data.searchPattern.toLower() in cell.toLower()):
          ctx.data.activeRow = rowIdx
          ctx.data.lastSearchRow = rowIdx
          return true

  return false

proc rotateColorScheme(ctx: var nw.Context[State]) =
  ## Rotate to the next color scheme
  let currentIdx = ColorSchemeNames.find(ctx.data.currentSchemeName)
  let nextIdx = (currentIdx + 1) mod ColorSchemeNames.len
  let nextSchemeName = ColorSchemeNames[nextIdx]

  ctx.data.currentSchemeName = nextSchemeName
  ctx.data.colorScheme = ColorSchemesTable[nextSchemeName]
  ctx.data.statusMessage = "Color scheme: " & nextSchemeName

proc handleInput(ctx: var nw.Context[State], key: iw.Key): bool =
  ## Handle keyboard input. Returns true if should quit.
  let data = ctx.data.tableData
  let termHeight = iw.height(ctx.tb)
  let termWidth = iw.width(ctx.tb)
  let contentHeight = termHeight - 1
  let isFiltered = ctx.data.filteredRows.len > 0
  let totalRows = if isFiltered: ctx.data.filteredRows.len else: data.rows.len
  let maxVisibleRows = contentHeight - 2

  # Handle input modes
  if ctx.data.inputMode in [imCommand, imSearch, imSearchColumn, imFilter]:
    case key:
    of iw.Key.Enter:
      # Execute command or search
      case ctx.data.inputMode:
      of imCommand:
        # Jump to line number
        try:
          let lineNum = parseInt(ctx.data.inputBuffer) - 1
          if lineNum >= 0 and lineNum < totalRows:
            ctx.data.activeRow = if isFiltered: ctx.data.filteredRows[lineNum] else: lineNum
            # Adjust scrolling
            if ctx.data.activeRow < ctx.data.scrollY:
              ctx.data.scrollY = ctx.data.activeRow
            elif ctx.data.activeRow >= ctx.data.scrollY + maxVisibleRows:
              ctx.data.scrollY = max(0, ctx.data.activeRow - maxVisibleRows + 1)
        except:
          discard
      of imSearch, imSearchColumn:
        # Save search pattern and find first match
        ctx.data.searchPattern = ctx.data.inputBuffer
        ctx.data.lastSearchRow = -1
        discard searchNext(ctx)
      of imFilter:
        ctx.data.searchPattern = ctx.data.inputBuffer
        applyFilter(ctx)
        ctx.data.activeRow = if ctx.data.filteredRows.len > 0: ctx.data.filteredRows[0] else: 0

      of imNormal, imGraph, imSaveFile, imSaveConfirm:
        discard

      ctx.data.inputMode = imNormal
      ctx.data.inputBuffer = ""

    of iw.Key.Escape:
      # Cancel input
      ctx.data.inputMode = imNormal
      ctx.data.inputBuffer = ""
      if ctx.data.inputMode == imFilter:
        ctx.data.filteredRows = @[] # Clear filter on escape

    of iw.Key.Backspace:
      # Delete last character
      if ctx.data.inputBuffer.len > 0:
        ctx.data.inputBuffer = ctx.data.inputBuffer[0 ..< ctx.data.inputBuffer.len - 1]

    else:
      # Add character to buffer
      if key.int >= 32 and key.int <= 126:
        ctx.data.inputBuffer.add(chr(key.int))

    return false

  # Handle save-file filename input
  if ctx.data.inputMode == imSaveFile:
    case key:
    of iw.Key.Enter:
      let target = ctx.data.inputBuffer
      ctx.data.inputBuffer = ""
      if target.len == 0:
        ctx.data.statusMessage = "No filename given"
        ctx.data.statusMessageTTL = 100
        ctx.data.inputMode = imNormal
      elif fileExists(target):
        ctx.data.pendingSaveFile = target
        ctx.data.inputMode = imSaveConfirm
      else:
        let err = saveTableToFile(ctx, target)
        if err.len > 0:
          ctx.data.statusMessage = err
        else:
          ctx.data.statusMessage = "Saved: " & target & " (" & $ctx.data.tableData.rows.len & " rows)"
        ctx.data.statusMessageTTL = 200
        ctx.data.inputMode = imNormal
    of iw.Key.Escape:
      ctx.data.inputMode = imNormal
      ctx.data.inputBuffer = ""
    of iw.Key.Backspace:
      if ctx.data.inputBuffer.len > 0:
        ctx.data.inputBuffer = ctx.data.inputBuffer[0 ..< ctx.data.inputBuffer.len - 1]
    else:
      if key.int >= 32 and key.int <= 126:
        ctx.data.inputBuffer.add(chr(key.int))
    return false

  # Handle save overwrite confirmation
  if ctx.data.inputMode == imSaveConfirm:
    case key:
    of iw.Key(ord('y')), iw.Key(ord('Y')):
      let err = saveTableToFile(ctx, ctx.data.pendingSaveFile)
      if err.len > 0:
        ctx.data.statusMessage = err
      else:
        ctx.data.statusMessage = "Saved: " & ctx.data.pendingSaveFile & " (" & $ctx.data.tableData.rows.len & " rows)"
      ctx.data.statusMessageTTL = 200
    else:
      ctx.data.statusMessage = "Save cancelled"
      ctx.data.statusMessageTTL = 100
    ctx.data.pendingSaveFile = ""
    ctx.data.inputMode = imNormal
    return false

  # Handle graph mode
  if ctx.data.inputMode == imGraph:
    case key:
    of iw.Key.Escape, iw.Key(ord('q')), iw.Key(ord('Q')):
      # Exit graph view and return to normal mode
      ctx.data.inputMode = imNormal
      ctx.data.graphData = @[]
      return false

    of iw.Key.Down, iw.Key(ord('j')):
      # Scroll down in graph view
      let maxScroll = max(0, ctx.data.graphData.len - (contentHeight - 4))
      if ctx.data.graphScrollY < maxScroll:
        ctx.data.graphScrollY += 1
      return false

    of iw.Key.Up, iw.Key(ord('k')):
      # Scroll up in graph view
      if ctx.data.graphScrollY > 0:
        ctx.data.graphScrollY -= 1
      return false

    of iw.Key.PageDown:
      # Page down in graph view
      let maxScroll = max(0, ctx.data.graphData.len - (contentHeight - 4))
      ctx.data.graphScrollY = min(ctx.data.graphScrollY + (contentHeight - 4), maxScroll)
      return false

    of iw.Key.PageUp:
      # Page up in graph view
      ctx.data.graphScrollY = max(0, ctx.data.graphScrollY - (contentHeight - 4))
      return false

    of iw.Key.Home:
      # Go to top
      ctx.data.graphScrollY = 0
      return false

    of iw.Key.End:
      # Go to bottom
      let maxScroll = max(0, ctx.data.graphData.len - (contentHeight - 4))
      ctx.data.graphScrollY = maxScroll
      return false

    else:
      discard

    return false

  # Normal mode key bindings
  case key:
  of iw.Key.Down, iw.Key(ord('j')):
    if ctx.data.activeRow < totalRows - 1:
      let currentIdx = if isFiltered: ctx.data.filteredRows.find(ctx.data.activeRow) else: ctx.data.activeRow
      if currentIdx + 1 < totalRows:
        ctx.data.activeRow = if isFiltered: ctx.data.filteredRows[currentIdx+1] else: currentIdx + 1
        if ctx.data.activeRow >= ctx.data.scrollY + maxVisibleRows:
          ctx.data.scrollY = ctx.data.activeRow - maxVisibleRows + 1
  
  of iw.Key.Up, iw.Key(ord('k')):
    if ctx.data.activeRow > 0:
      let currentIdx = if isFiltered: ctx.data.filteredRows.find(ctx.data.activeRow) else: ctx.data.activeRow
      if currentIdx > 0:
        ctx.data.activeRow = if isFiltered: ctx.data.filteredRows[currentIdx-1] else: currentIdx - 1
        if ctx.data.activeRow < ctx.data.scrollY:
          ctx.data.scrollY = ctx.data.activeRow

  of iw.Key.Right:
    if ctx.data.activeCol < data.columnWidths.len - 1:
      ctx.data.activeCol += 1
      var activeColPos = 0
      for i in 0 ..< ctx.data.activeCol:
        activeColPos += data.columnWidths[i] + 2
      let activeColWidth = data.columnWidths[ctx.data.activeCol]
      if activeColPos + activeColWidth > ctx.data.scrollX + termWidth:
        ctx.data.scrollX = activeColPos + activeColWidth - termWidth + 2

  of iw.Key.Left:
    if ctx.data.activeCol > 0:
      ctx.data.activeCol -= 1
      var activeColPos = 0
      for i in 0 ..< ctx.data.activeCol:
        activeColPos += data.columnWidths[i] + 2
      if activeColPos < ctx.data.scrollX:
        ctx.data.scrollX = activeColPos

  of iw.Key.PageDown:
    ctx.data.activeRow = min(ctx.data.activeRow + maxVisibleRows, totalRows - 1)
    if ctx.data.activeRow >= ctx.data.scrollY + maxVisibleRows:
      ctx.data.scrollY = min(ctx.data.activeRow - maxVisibleRows + 1, max(0, totalRows - maxVisibleRows))

  of iw.Key.PageUp:
    ctx.data.activeRow = max(0, ctx.data.activeRow - maxVisibleRows)
    if ctx.data.activeRow < ctx.data.scrollY:
      ctx.data.scrollY = ctx.data.activeRow

  of iw.Key.Home:
    ctx.data.activeRow = 0
    ctx.data.activeCol = 0
    ctx.data.scrollY = 0
    ctx.data.scrollX = 0

  of iw.Key.End:
    ctx.data.activeRow = max(0, totalRows - 1)
    ctx.data.scrollY = max(0, totalRows - maxVisibleRows)

  # New commands
  of iw.Key(ord(':')):
    ctx.data.inputMode = imCommand
    ctx.data.inputBuffer = ""

  of iw.Key(ord('/')):
    ctx.data.inputMode = imSearch
    ctx.data.searchInColumn = false
    ctx.data.inputBuffer = ""
  
  of iw.Key(ord('&')):
    ctx.data.inputMode = imFilter
    ctx.data.inputBuffer = ""

  of iw.Key(ord('|')):
    ctx.data.inputMode = imSearchColumn
    ctx.data.searchInColumn = true
    ctx.data.inputBuffer = ""

  of iw.Key(ord('n')):
    discard searchNext(ctx)
    # Adjust scrolling
    if ctx.data.activeRow < ctx.data.scrollY:
      ctx.data.scrollY = ctx.data.activeRow
    elif ctx.data.activeRow >= ctx.data.scrollY + maxVisibleRows:
      ctx.data.scrollY = max(0, ctx.data.activeRow - maxVisibleRows + 1)

  of iw.Key(ord('b')):
    discard searchPrev(ctx)
    # Adjust scrolling
    if ctx.data.activeRow < ctx.data.scrollY:
      ctx.data.scrollY = ctx.data.activeRow
    elif ctx.data.activeRow >= ctx.data.scrollY + maxVisibleRows:
      ctx.data.scrollY = max(0, ctx.data.activeRow - maxVisibleRows + 1)

  of iw.Key(ord('p')):
    # Increase column width
    if ctx.data.activeCol < ctx.data.tableData.columnWidths.len:
      ctx.data.tableData.columnWidths[ctx.data.activeCol] += 1

  of iw.Key(ord('o')):
    # Decrease column width
    if ctx.data.activeCol < ctx.data.tableData.columnWidths.len:
      if ctx.data.tableData.columnWidths[ctx.data.activeCol] > 3:
        ctx.data.tableData.columnWidths[ctx.data.activeCol] -= 1

  of iw.Key(ord('h')):
    # Hide active column
    if ctx.data.activeCol < ctx.data.tableData.hiddenColumns.len:
      ctx.data.tableData.hiddenColumns[ctx.data.activeCol] = true
      # Move to next visible column
      var nextCol = ctx.data.activeCol + 1
      while nextCol < ctx.data.tableData.hiddenColumns.len and ctx.data.tableData.hiddenColumns[nextCol]:
        nextCol += 1
      if nextCol < ctx.data.tableData.hiddenColumns.len:
        ctx.data.activeCol = nextCol
      else:
        # Try going backwards
        nextCol = ctx.data.activeCol - 1
        while nextCol >= 0 and ctx.data.tableData.hiddenColumns[nextCol]:
          nextCol -= 1
        if nextCol >= 0:
          ctx.data.activeCol = nextCol

  of iw.Key(ord('u')):
    # Unhide all columns
    for i in 0 ..< ctx.data.tableData.hiddenColumns.len:
      ctx.data.tableData.hiddenColumns[i] = false

  of iw.Key(ord('i')):
    # Set column type to Integer
    if ctx.data.activeCol < ctx.data.tableData.columnTypes.len:
      ctx.data.tableData.columnTypes[ctx.data.activeCol] = ctInt

  of iw.Key(ord('F')):
    # Set column type to Float
    if ctx.data.activeCol < ctx.data.tableData.columnTypes.len:
      ctx.data.tableData.columnTypes[ctx.data.activeCol] = ctFloat

  of iw.Key(ord('[')):
    # Sort descending
    sortTable(ctx, false)

  of iw.Key(ord(']')):
    # Sort ascending
    sortTable(ctx, true)

  of iw.Key(ord('r')):
    ctx.data.regexSearch = not ctx.data.regexSearch
    let mode = if ctx.data.regexSearch: "ON" else: "OFF"
    ctx.data.statusMessage = "Regex search " & mode

  of iw.Key(ord('f')):
    # Freeze row/col submenu might be better
    ctx.data.statusMessage = "Freeze: (r)ow, (c)ol, (u)nfreeze"
    # This is a bit of a hack. We need to get another key.
    # A proper implementation would have a state for this.
    var mouseInfo: iw.MouseInfo
    let nextKey = iw.getKey(mouseInfo)
    case nextKey
    of iw.Key(ord('r')):
      ctx.data.frozenRows = ctx.data.activeRow + 1
    of iw.Key(ord('c')):
      ctx.data.frozenCols = ctx.data.activeCol + 1
    of iw.Key(ord('u')):
      ctx.data.frozenRows = 0
      ctx.data.frozenCols = 0
    else:
      discard

  of iw.Key(ord('t')):
    # Toggle header - make current first row the header or add artificial header
    if ctx.data.hasHeader:
      # Move header to first data row
      if data.rows.len > 0:
        ctx.data.tableData.rows.insert(ctx.data.tableData.headers.map(proc(x: string): string = x), 0)
      # Create artificial headers
      ctx.data.tableData.headers = @[]
      for i in 1 .. data.columnWidths.len:
        ctx.data.tableData.headers.add("Col" & $i)
      ctx.data.hasHeader = false
    else:
      # Use first row as header
      if data.rows.len > 0:
        ctx.data.tableData.headers = data.rows[0]
        ctx.data.tableData.rows.delete(0)
      ctx.data.hasHeader = true

  of iw.Key(ord('g')):
    # Enter graph view for active column
    generateGraphData(ctx)
    ctx.data.inputMode = imGraph

  of iw.Key.Tab:
    # Rotate to next color scheme
    rotateColorScheme(ctx)

  of iw.Key(ord('s')):
    ctx.data.inputMode = imSaveFile
    ctx.data.inputBuffer = ""

  of iw.Key(ord('q')), iw.Key(ord('Q')):
    return true

  else:
    discard

  return false

proc tick(ctx: var nw.Context[State], prevTb: var iw.TerminalBuffer): bool =
  ## Returns true if should quit
  var mouseInfo: iw.MouseInfo
  let key = iw.getKey(mouseInfo)

  # Handle mouse scrolling
  case mouseInfo.scrollDir:
  of iw.ScrollDirection.sdUp:
    discard handleInput(ctx, iw.Key.Up)
  of iw.ScrollDirection.sdDown:
    discard handleInput(ctx, iw.Key.Down)
  else:
    discard

  # Handle keyboard input
  if key != iw.Key.None:
    if handleInput(ctx, key):
      return true

  # Update status message to reflect current position (only for normal mode,
  # and only once any transient message TTL has expired)
  if ctx.data.inputMode notin [imGraph, imSaveFile, imSaveConfirm]:
    if ctx.data.statusMessageTTL > 0:
      ctx.data.statusMessageTTL -= 1
    else:
      updateStatusMessage(ctx)

  # Render
  ctx.tb = iw.initTerminalBuffer(terminal.terminalWidth(), terminal.terminalHeight())

  # Choose which view to render based on input mode
  if ctx.data.inputMode == imGraph:
    renderGraphView(ctx)
  else:
    renderTable(ctx)

  iw.display(ctx.tb, prevTb)

  return false

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
    var filename = ""
    if opts.file.len > 0:
      filename = opts.file[0]
    else:
      filename = "-"

    let schemeName = opts.scheme
    let maxColWidth = parseInt(opts.maxwidth)
    let skipLines = parseInt(opts.skip)
    let skipPrefix = opts.skipPrefix
    let hasHeader = not opts.noheader
    let fromStdin = (filename == "-")

    var delimiter: char = '\0'  # Auto-detect
    if opts.tsv:
      delimiter = '\t'
    elif opts.csv:
      delimiter = ','

    if not fromStdin and not fileExists(filename):
      echo "Error: File not found: ", filename
      quit(1)

    var
      ctx: nw.Context[State]
      prevTb: iw.TerminalBuffer

    init(ctx, filename, schemeName, delimiter, skipLines, skipPrefix, hasHeader, fromStdin, maxColWidth)

    try:
      while true:
        if tick(ctx, prevTb):
          break
        prevTb = ctx.tb
        os.sleep(5)
    except Exception as ex:
      deinit()
      raise ex

    deinit()

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
