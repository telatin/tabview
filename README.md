# tableview

A Nim library for interactive TUI table viewing, with two demo binaries bundled.
Other tools can embed the viewer by importing `tableview` and calling `viewTable` or `viewTabularFile`.

## Library API

```nim
import tableview

# View an in-memory table (e.g. output of your own tool)
viewTable(data: TableData, schemeName = "default", filename = "", hasHeader = true)

# View a file or stdin ("-")
viewTabularFile(path: string, schemeName = "default", delimiter = '\0',
                skipLines = 0, skipPrefix = "", hasHeader = true, maxColWidth = 20)
```

### Building a `TableData` yourself

```nim
import tableview

var data = TableData(
  headers:      @["Name", "Score", "Grade"],
  rows:         @[@["Alice", "95", "A"], @["Bob", "82", "B"]],
  columnWidths: @[5, 5, 5],          # will be expanded as needed
  columnTypes:  @[ctString, ctInt, ctString],
  hiddenColumns: @[false, false, false]
)

viewTable(data, filename = "my tool output")
```

### Example: tool with optional `--view-table` flag

```nim
import tableview

# ... build `data: TableData` from your tool's output ...

if opts.viewTable:
  viewTable(data, filename = "my-tool")
else:
  for row in data.rows:
    echo row.join("\t")
```

## Binaries

### `tableview` — view TSV/CSV files

```bash
nimble build
./bin/tableview <file.tsv|file.csv>
./bin/tableview -                      # read from stdin
cat data.csv | ./bin/tableview -
```

Options:

| Flag | Description |
|------|-------------|
| `-t`, `--tsv` | Force tab-separated parsing |
| `-c`, `--csv` | Force comma-separated parsing |
| `--noheader` | Treat first row as data, generate Col1/Col2… headers |
| `-w N`, `--maxwidth N` | Maximum column display width (default: 20) |
| `-s NAME`, `--scheme NAME` | Color scheme (default, bold, subtle, dark, mono, …) |
| `--skip N` | Skip first N lines before parsing |
| `--skip-prefix STR` | Skip lines starting with STR |

### `wordcount` — count lines, words and characters (library demo)

```bash
./bin/wordcount file1.txt file2.txt    # print table to stdout
./bin/wordcount -s file1.txt file2.txt # include TOTAL row
./bin/wordcount -t file1.txt file2.txt # open interactive viewer
./bin/wordcount - < file.txt           # read from stdin
```

Options:

| Flag | Description |
|------|-------------|
| `-t`, `--table` | Open results interactively with `viewTable` |
| `-s`, `--summary-row` | Add a TOTAL row when multiple files are given |

## Keyboard Controls

| Key | Action |
|-----|--------|
| `↑`/`k`, `↓`/`j` | Move up / down one row |
| `←`, `→` | Move left / right one column |
| `Page Up`/`Page Down` | Scroll one page |
| `Home` / `End` | Jump to first / last row |
| `/` | Search across all columns |
| `\|` | Search within active column |
| `&` | Filter rows (keep matches) |
| `n` / `b` | Next / previous search match |
| `r` | Toggle regex search mode |
| `:N` + Enter | Jump to row N |
| `[` / `]` | Sort active column descending / ascending |
| `g` | Graph view: value frequencies for active column |
| `h` / `u` | Hide active column / unhide all columns |
| `p` / `o` | Widen / narrow active column |
| `f` then `r`/`c`/`u` | Freeze rows / cols / unfreeze |
| `t` | Toggle header row |
| `s` | Save visible table to file (TSV or CSV by extension) |
| Tab | Cycle color schemes |
| `q` / `Q` | Quit |

## Building

```bash
nimble build        # produces bin/tableview and bin/wordcount
```

## Dependencies

- [nimwave](https://github.com/nicowillis/nimwave) — TUI rendering framework
- [illwave](https://github.com/nicowillis/illwave) — low-level terminal library
- [argparse](https://github.com/iffy/nim-argparse) — command-line argument parsing
