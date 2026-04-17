import unittest
import tableview

suite "tableview numeric formatting":
  test "thousands grouping helper":
    check tvAddThousandsSeparator("1", ',') == "1"
    check tvAddThousandsSeparator("1200", ',') == "1,200"
    check tvAddThousandsSeparator("123456789", ',') == "123,456,789"

  test "integer formatting":
    check tvFormatIntegerCell("1200", ',') == "1,200"
    check tvFormatIntegerCell("-129028", ',') == "-129,028"
    check tvFormatIntegerCell("+4500000", ',') == "+4,500,000"
    check tvFormatIntegerCell("not-int", ',') == "not-int"

  test "float fixed precision formatting":
    check tvFormatFloatCell("3.14159", 2, '.') == "3.14"
    check tvFormatFloatCell("12.5", 2, '.') == "12.50"
    check tvFormatFloatCell("0.333333", 2, '.') == "0.33"
    check tvFormatFloatCell("3.14159", 2, ',') == "3,14"
    check tvFormatFloatCell("not-float", 2, '.') == "not-float"

  test "cell text fitting supports right alignment":
    check tvFitCellText("12", 5) == "12   "
    check tvFitCellText("12", 5, true) == "   12"
    check tvFitCellText("abcdef", 5, true) == "...ef"
