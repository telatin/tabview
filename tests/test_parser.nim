## Tests for tableview/parser

import unittest
import streams
import os
import strutils
import tableview/parser

suite "detectColumnType":
  test "all integers":
    let t = parseDelimitedStream(newStringStream("a\n1\n2\n3"))
    check t.columnTypes[0] == ctInt

  test "all floats":
    let t = parseDelimitedStream(newStringStream("a\n1.0\n2.5\n3.14"))
    check t.columnTypes[0] == ctFloat

  test "mixed int and float":
    let t = parseDelimitedStream(newStringStream("a\n1\n2.5\n3"))
    check t.columnTypes[0] == ctFloat

  test "strings":
    let t = parseDelimitedStream(newStringStream("a\nhello\nworld"))
    check t.columnTypes[0] == ctString

  test "empty values treated as missing, rest numeric":
    let t = parseDelimitedStream(newStringStream("a\n1\n\n3"))
    check t.columnTypes[0] == ctInt


suite "parseDelimitedStream - TSV":
  test "basic TSV with header":
    let data = "name\tage\tvalue\nalice\t30\t1.5\nbob\t25\t2.0"
    let t = parseDelimitedStream(newStringStream(data), delimiter = '\t')
    check t.headers == @["name", "age", "value"]
    check t.rows.len == 2
    check t.rows[0] == @["alice", "30", "1.5"]
    check t.columnTypes == @[ctString, ctInt, ctFloat]

  test "no header generates Col1..ColN":
    let data = "alice\t30\nbob\t25"
    let t = parseDelimitedStream(newStringStream(data), delimiter = '\t', hasHeader = false)
    check t.headers == @["Col1", "Col2"]
    check t.rows.len == 2

  test "auto-detect TSV delimiter":
    let data = "name\tage\nalice\t30\nbob\t25"
    let t = parseDelimitedStream(newStringStream(data))
    check t.headers == @["name", "age"]
    check t.rows.len == 2

  test "auto-detect CSV delimiter":
    let data = "name,age\nalice,30\nbob,25"
    let t = parseDelimitedStream(newStringStream(data))
    check t.headers == @["name", "age"]
    check t.rows.len == 2

  test "skip comment lines via skipPrefix":
    let data = "# comment\nname\tage\nalice\t30"
    let t = parseDelimitedStream(newStringStream(data), delimiter = '\t', skipPrefix = "#")
    check t.headers == @["name", "age"]
    check t.rows.len == 1

  test "empty input returns empty TableData":
    let t = parseDelimitedStream(newStringStream(""))
    check t.headers.len == 0
    check t.rows.len == 0

  test "trailing blank lines are ignored":
    let data = "a\tb\n1\t2\n\n"
    let t = parseDelimitedStream(newStringStream(data), delimiter = '\t')
    check t.rows.len == 1

  test "column widths capped at maxColWidth":
    let longVal = "x".repeat(50)
    let data = "col\n" & longVal
    let t = parseDelimitedStream(newStringStream(data), delimiter = '\t', maxColWidth = 20)
    check t.columnWidths[0] == 20

  test "hiddenColumns all false by default":
    let data = "a\tb\n1\t2"
    let t = parseDelimitedStream(newStringStream(data), delimiter = '\t')
    check t.hiddenColumns == @[false, false]


suite "parseDelimitedFile":
  test "TSV file round-trip":
    let path = getTempDir() / "test_tabview.tsv"
    writeFile(path, "x\ty\n10\t20\n30\t40")
    let t = parseDelimitedFile(path, delimiter = '\t')
    check t.headers == @["x", "y"]
    check t.rows.len == 2
    check t.columnTypes == @[ctInt, ctInt]
    removeFile(path)

  test "CSV file round-trip":
    let path = getTempDir() / "test_tabview.csv"
    writeFile(path, "name,score\nalice,95\nbob,87")
    let t = parseDelimitedFile(path, delimiter = ',')
    check t.headers == @["name", "score"]
    check t.rows[1][1] == "87"
    removeFile(path)


suite "detectDelimiter":
  test "detects tab":
    let path = getTempDir() / "test_delim.tsv"
    writeFile(path, "a\tb\tc\n1\t2\t3")
    check detectDelimiter(path) == '\t'
    removeFile(path)

  test "detects comma":
    let path = getTempDir() / "test_delim.csv"
    writeFile(path, "a,b,c\n1,2,3")
    check detectDelimiter(path) == ','
    removeFile(path)
