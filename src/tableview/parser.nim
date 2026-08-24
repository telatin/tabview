## Parsing module for tableview.
##
## Provides CSV/TSV ingestion from files or streams, column-type detection,
## and the core `TableData` structure used throughout the application.
##
## CSV files are parsed with `std/parsecsv` for correct handling of quoted
## fields, embedded delimiters, newlines, and double-quote escaping per
## RFC 4180. TSV files use a fast split-based parser.

import strutils
import unicode
import streams
import std/parsecsv

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
    let stripped = strutils.strip(val)
    if stripped.len == 0:
      continue  # Skip empty values

    try:
      discard parseFloat(stripped)
      if '.' in stripped:
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

proc finalizeTableData(result: var TableData, numColumns: int, maxColWidth: int) =
  ## Shared post-processing: column widths, types, and hidden flags.
  for header in result.headers:
    result.columnWidths.add(min(header.runeLen, maxColWidth))
    result.hiddenColumns.add(false)

  for row in result.rows:
    for j, field in row:
      if j < result.columnWidths.len:
        let fieldLen = field.runeLen
        if fieldLen > result.columnWidths[j]:
          result.columnWidths[j] = min(fieldLen, maxColWidth)

  for colIdx in 0 ..< numColumns:
    var columnValues: seq[string] = @[]
    for row in result.rows:
      if colIdx < row.len:
        columnValues.add(row[colIdx])
    result.columnTypes.add(detectColumnType(columnValues))

proc parseCsvWithParsecsv(content: string, skipLines: int,
                           skipPrefix: string, hasHeader: bool,
                           maxColWidth: int): TableData =
  ## Parse CSV content using std/parsecsv for proper quote handling.
  result = TableData(headers: @[], rows: @[], columnWidths: @[], columnTypes: @[], hiddenColumns: @[])

  let stream = newStringStream(content)
  if stream == nil:
    return

  var p: CsvParser
  # Pass '\0' as quote to disable quote parsing if we wanted plain split,
  # but we always use '"' for proper CSV handling.
  open(p, stream, "<data>", separator = ',', quote = '"', escape = '\0')

  # Read all rows into memory first so we can do skipLines / skipPrefix
  var allRows: seq[seq[string]] = @[]
  while readRow(p):
    allRows.add(p.row)

  close(p)
  stream.close()

  if allRows.len == 0:
    return

  # Apply skipLines
  var startIdx = skipLines
  if startIdx > allRows.len:
    return

  # Apply skipPrefix
  if skipPrefix.len > 0:
    while startIdx < allRows.len:
      let firstField = if allRows[startIdx].len > 0: allRows[startIdx][0] else: ""
      if firstField.startsWith(skipPrefix):
        startIdx += 1
      else:
        break

  if startIdx >= allRows.len:
    return

  # Parse headers
  var numColumns = 0
  if hasHeader:
    result.headers = allRows[startIdx]
    startIdx += 1
    numColumns = result.headers.len
  else:
    # No header - detect number of columns from first data row
    if startIdx < allRows.len:
      numColumns = allRows[startIdx].len
      for i in 1 .. numColumns:
        result.headers.add("Col" & $i)

  # Parse data rows
  for i in startIdx ..< allRows.len:
    let fields = allRows[i]
    # Skip blank rows
    var allBlank = true
    for f in fields:
      if strutils.strip(f).len > 0:
        allBlank = false
        break
    if allBlank:
      continue
    result.rows.add(fields)

  finalizeTableData(result, numColumns, maxColWidth)

proc parseCsvStreamWithParsecsv(stream: Stream, skipLines: int,
                                 skipPrefix: string, hasHeader: bool,
                                 maxColWidth: int): TableData =
  ## Parse CSV from a stream using std/parsecsv for proper quote handling.
  result = TableData(headers: @[], rows: @[], columnWidths: @[], columnTypes: @[], hiddenColumns: @[])

  var p: CsvParser
  open(p, stream, "<stream>", separator = ',', quote = '"', escape = '\0')

  var allRows: seq[seq[string]] = @[]
  while readRow(p):
    allRows.add(p.row)

  close(p)

  if allRows.len == 0:
    return

  # Apply skipLines
  var startIdx = skipLines
  if startIdx > allRows.len:
    return

  # Apply skipPrefix
  if skipPrefix.len > 0:
    while startIdx < allRows.len:
      let firstField = if allRows[startIdx].len > 0: allRows[startIdx][0] else: ""
      if firstField.startsWith(skipPrefix):
        startIdx += 1
      else:
        break

  if startIdx >= allRows.len:
    return

  # Parse headers
  var numColumns = 0
  if hasHeader:
    result.headers = allRows[startIdx]
    startIdx += 1
    numColumns = result.headers.len
  else:
    if startIdx < allRows.len:
      numColumns = allRows[startIdx].len
      for i in 1 .. numColumns:
        result.headers.add("Col" & $i)

  # Parse data rows
  for i in startIdx ..< allRows.len:
    let fields = allRows[i]
    var allBlank = true
    for f in fields:
      if strutils.strip(f).len > 0:
        allBlank = false
        break
    if allBlank:
      continue
    result.rows.add(fields)

  finalizeTableData(result, numColumns, maxColWidth)

proc parseDelimitedFile*(filename: string, delimiter: char = '\t', skipLines: int = 0,
                        skipPrefix: string = "", hasHeader: bool = true, maxColWidth: int = 20): TableData =
  ## Parse a TSV or CSV file and return table data with calculated column widths.
  ## For CSV (delimiter = ','), uses std/parsecsv to handle quoted fields correctly.
  ## For TSV (delimiter = '\t'), uses a fast split-based parser.
  if delimiter == ',':
    let content = readFile(filename)
    return parseCsvWithParsecsv(content, skipLines, skipPrefix, hasHeader, maxColWidth)

  # TSV: fast split-based parser
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
  ## If delimiter is '\0', it will be auto-detected from the first line.
  ## For CSV, uses std/parsecsv to handle quoted fields correctly.
  ## For TSV, uses a fast split-based parser.
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

  # If CSV and the stream was already read into lines, re-parse with parsecsv.
  # We rejoin because parsecsv needs the raw stream for proper newline-in-quotes handling.
  if actualDelimiter == ',':
    let rejoined = lines.join("\n")
    let csvStream = newStringStream(rejoined)
    result = parseCsvStreamWithParsecsv(csvStream, skipLines, skipPrefix, hasHeader, maxColWidth)
    csvStream.close()
    return

  # TSV: fast split-based parser
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