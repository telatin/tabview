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


suite "parseDelimitedStream - CSV with parsecsv":
  test "basic CSV with header":
    let data = "name,age,value\nalice,30,1.5\nbob,25,2.0"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
    check t.headers == @["name", "age", "value"]
    check t.rows.len == 2
    check t.rows[0] == @["alice", "30", "1.5"]
    check t.columnTypes == @[ctString, ctInt, ctFloat]

  test "quoted field with embedded comma":
    let data = "name,description,value\nItem1,\"hello, world\",10\nItem2,\"foo, bar, baz\",20"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
    check t.headers == @["name", "description", "value"]
    check t.rows.len == 2
    check t.rows[0][1] == "hello, world"
    check t.rows[1][1] == "foo, bar, baz"

  test "quoted field with embedded newline":
    let data = "name,note,value\nItem1,\"line1\nline2\",10\nItem2,simple,20"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
    check t.headers == @["name", "note", "value"]
    check t.rows.len == 2
    check t.rows[0][1] == "line1\nline2"
    check t.rows[1][1] == "simple"

  test "double-quote escaping inside quoted field":
    let data = "name,quote\nAlice,\"he said \"\"hello\"\" to me\"\nBob,\"no quotes\""
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
    check t.headers == @["name", "quote"]
    check t.rows.len == 2
    check t.rows[0][1] == "he said \"hello\" to me"
    check t.rows[1][1] == "no quotes"

  test "mixed quoted and unquoted fields":
    let data = "col1,col2,col3\nplain,\"quoted, value\",42\nanother,plain,99"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
    check t.headers == @["col1", "col2", "col3"]
    check t.rows.len == 2
    check t.rows[0] == @["plain", "quoted, value", "42"]
    check t.rows[1] == @["another", "plain", "99"]

  test "no header CSV with parsecsv":
    let data = "alice,30\nbob,25"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',', hasHeader = false)
    check t.headers == @["Col1", "Col2"]
    check t.rows.len == 2

  test "skip comment lines via skipPrefix in CSV":
    let data = "# comment\nname,age\nalice,30"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',', skipPrefix = "#")
    check t.headers == @["name", "age"]
    check t.rows.len == 1

  test "blank lines ignored in CSV":
    let data = "a,b\n1,2\n\n3,4\n\n"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
    check t.rows.len == 2
    check t.rows[0] == @["1", "2"]
    check t.rows[1] == @["3", "4"]

  test "column widths capped in CSV":
    let longVal = "\"" & "x".repeat(50) & "\""
    let data = "col\n" & longVal
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',', maxColWidth = 20)
    check t.columnWidths[0] == 20

  test "hiddenColumns all false by default in CSV":
    let data = "a,b\n1,2"
    let t = parseDelimitedStream(newStringStream(data), delimiter = ',')
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

  test "CSV file with quoted fields":
    let path = getTempDir() / "test_quoted.csv"
    writeFile(path, "name,desc,val\nAlpha,\"hello, world\",10\nBeta,\"foo \"\"bar\"\" baz\",20")
    let t = parseDelimitedFile(path, delimiter = ',')
    check t.headers == @["name", "desc", "val"]
    check t.rows[0][1] == "hello, world"
    check t.rows[1][1] == "foo \"bar\" baz"
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