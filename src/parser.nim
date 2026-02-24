## Parsing module for tabview.
##
## Provides CSV/TSV ingestion from files or streams, column-type detection,
## and the core `TableData` structure used throughout the application.

import strutils
import unicode
import streams

type
  ColumnType* = enum
    ## Detected data type for a table column.
    ctString ## Column contains arbitrary text values.
    ctInt    ## All non-empty values parse as integers.
    ctFloat  ## All non-empty values parse as floating-point numbers.

  TableData* = object
    ## Holds the parsed contents of a delimited file.
    headers*: seq[string]      ## Column header names (one per column).
    rows*: seq[seq[string]]    ## Data rows; each inner seq has one field per column.
    columnWidths*: seq[int]    ## Rendering widths (capped at `maxColWidth`) per column.
    columnTypes*: seq[ColumnType] ## Detected type for each column.
    hiddenColumns*: seq[bool]  ## Per-column visibility flag; `true` means hidden.

proc detectColumnType(values: seq[string]): ColumnType =
  ## Detect the type of a column based on its values
  ## If any value is non-numeric, returns ctString
  ## Otherwise returns ctFloat if any has decimal, else ctInt
  var hasFloat = false
  var hasInt = false

  for val in values:
    if strutils.strip(val).len == 0:
      continue  # Skip empty values

    try:
      let f = parseFloat(val)
      if '.' in val:
        hasFloat = true
      else:
        hasInt = true
    except:
      return ctString  # Non-numeric value found

  if hasFloat:
    return ctFloat
  elif hasInt:
    return ctInt
  else:
    return ctString

proc parseDelimitedFile*(filename: string, delimiter: char = '\t', skipLines: int = 0,
                        skipPrefix: string = "", hasHeader: bool = true, maxColWidth: int = 20): TableData =
  ## Parse a TSV or CSV file and return table data with calculated column widths
  result = TableData(headers: @[], rows: @[], columnWidths: @[], columnTypes: @[], hiddenColumns: @[])

  let content = readFile(filename)
  var lines = content.splitLines()

  if lines.len == 0:
    return

  # Skip lines as needed
  var startIdx = skipLines
  if skipPrefix.len > 0:
    while startIdx < lines.len and lines[startIdx].startsWith(skipPrefix):
      startIdx += 1

  if startIdx >= lines.len:
    return

  # Parse headers
  var numColumns = 0
  if hasHeader:
    let headerLine = lines[startIdx]
    result.headers = headerLine.split(delimiter)
    startIdx += 1
    numColumns = result.headers.len
  else:
    # No header - detect number of columns from first data line
    if startIdx < lines.len:
      numColumns = lines[startIdx].split(delimiter).len
      # Create artificial headers
      for i in 1 .. numColumns:
        result.headers.add("Col" & $i)

  # Initialize column widths with header lengths (capped at maxColWidth)
  for header in result.headers:
    result.columnWidths.add(min(header.runeLen, maxColWidth))
    result.hiddenColumns.add(false)

  # Parse data rows
  for i in startIdx ..< lines.len:
    let line = lines[i]
    if strutils.strip(line).len == 0:
      continue

    let fields = line.split(delimiter)
    result.rows.add(fields)

    # Update column widths (capped at maxColWidth)
    for j, field in fields:
      if j < result.columnWidths.len:
        let fieldLen = field.runeLen
        if fieldLen > result.columnWidths[j]:
          result.columnWidths[j] = min(fieldLen, maxColWidth)

  # Detect column types
  for colIdx in 0 ..< numColumns:
    var columnValues: seq[string] = @[]
    for row in result.rows:
      if colIdx < row.len:
        columnValues.add(row[colIdx])
    result.columnTypes.add(detectColumnType(columnValues))

proc parseDelimitedStream*(stream: Stream, delimiter: char = '\0', skipLines: int = 0,
                           skipPrefix: string = "", hasHeader: bool = true, maxColWidth: int = 20): TableData =
  ## Parse a TSV or CSV from a stream (e.g., stdin)
  ## If delimiter is '\0', it will be auto-detected from the first line
  result = TableData(headers: @[], rows: @[], columnWidths: @[], columnTypes: @[], hiddenColumns: @[])

  var lines: seq[string] = @[]
  var line: string
  while stream.readLine(line):
    lines.add(line)

  if lines.len == 0:
    return

  # Skip lines as needed
  var startIdx = skipLines
  if skipPrefix.len > 0:
    while startIdx < lines.len and lines[startIdx].startsWith(skipPrefix):
      startIdx += 1

  if startIdx >= lines.len:
    return

  # Auto-detect delimiter if needed
  var actualDelimiter = delimiter
  if actualDelimiter == '\0' and startIdx < lines.len:
    let firstLine = lines[startIdx]
    let tabCount = firstLine.count('\t')
    let commaCount = firstLine.count(',')
    if tabCount > commaCount:
      actualDelimiter = '\t'
    else:
      actualDelimiter = ','

  # Parse headers
  var numColumns = 0
  if hasHeader:
    let headerLine = lines[startIdx]
    result.headers = headerLine.split(actualDelimiter)
    startIdx += 1
    numColumns = result.headers.len
  else:
    # No header - detect number of columns from first data line
    if startIdx < lines.len:
      numColumns = lines[startIdx].split(actualDelimiter).len
      # Create artificial headers
      for i in 1 .. numColumns:
        result.headers.add("Col" & $i)

  # Initialize column widths with header lengths (capped at maxColWidth)
  for header in result.headers:
    result.columnWidths.add(min(header.runeLen, maxColWidth))
    result.hiddenColumns.add(false)

  # Parse data rows
  for i in startIdx ..< lines.len:
    let line = lines[i]
    if strutils.strip(line).len == 0:
      continue

    let fields = line.split(actualDelimiter)
    result.rows.add(fields)

    # Update column widths (capped at maxColWidth)
    for j, field in fields:
      if j < result.columnWidths.len:
        let fieldLen = field.runeLen
        if fieldLen > result.columnWidths[j]:
          result.columnWidths[j] = min(fieldLen, maxColWidth)

  # Detect column types
  for colIdx in 0 ..< numColumns:
    var columnValues: seq[string] = @[]
    for row in result.rows:
      if colIdx < row.len:
        columnValues.add(row[colIdx])
    result.columnTypes.add(detectColumnType(columnValues))

proc detectDelimiter*(filename: string): char =
  ## Detect whether file is TSV or CSV by checking first line
  let content = readFile(filename)
  let firstLine = content.splitLines()[0]

  let tabCount = firstLine.count('\t')
  let commaCount = firstLine.count(',')

  if tabCount > commaCount:
    result = '\t'
  else:
    result = ','
