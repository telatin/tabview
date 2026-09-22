## Tests for the regex search/filter backend (nim-regex based).

import unittest
import tableview

suite "regex validation":
  test "valid patterns compile":
    check tvRegexValid("hello")
    check tvRegexValid("^abc$")
    check tvRegexValid("\\d+")
    check tvRegexValid("[a-z]+")
    check tvRegexValid("foo|bar")
    check tvRegexValid("(ab){2,3}")

  test "invalid patterns are rejected without crashing":
    check not tvRegexValid("([")
    check not tvRegexValid("*bad")
    check not tvRegexValid("(unclosed")
    check not tvRegexValid("[z-a]")

suite "regex mode matching (case-sensitive)":
  test "literal pattern":
    check tvCellMatches("hello world", "world", true)
    check not tvCellMatches("hello world", "missing", true)

  test "case sensitivity in regex mode":
    check tvCellMatches("Hello", "Hello", true)
    check not tvCellMatches("Hello", "hello", true)

  test "anchors":
    check tvCellMatches("abc", "^abc$", true)
    check not tvCellMatches("xabcy", "^abc$", true)

  test "character classes and quantifiers":
    check tvCellMatches("id-1234", "id-\\d{4}", true)
    check not tvCellMatches("id-12a4", "id-\\d{4}", true)
    check tvCellMatches("col01", "[a-z]+\\d+", true)

  test "alternation":
    check tvCellMatches("foo", "foo|bar", true)
    check tvCellMatches("bar", "foo|bar", true)
    check not tvCellMatches("baz", "foo|bar", true)

  test "groups":
    check tvCellMatches("abab", "(ab)+", true)
    check tvCellMatches("2026-09-22", "(\\d{4})-(\\d{2})-(\\d{2})", true)

  test "dot matches any character":
    check tvCellMatches("aXc", "a.c", true)

  test "unicode text":
    check tvCellMatches("café", "caf.", true)
    check tvCellMatches("naïve", "\\p{L}+", true)

  test "invalid pattern returns false":
    check not tvCellMatches("anything", "([", true)

suite "plain mode matching (case-insensitive substring)":
  test "substring match ignores case":
    check tvCellMatches("Hello World", "world", false)
    check tvCellMatches("Hello World", "HELLO", false)
    check not tvCellMatches("Hello World", "missing", false)

  test "metacharacters are literal in plain mode":
    check tvCellMatches("a.b", "a.b", false)
    check not tvCellMatches("axb", "a.b", false)
