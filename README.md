# TableView

A full-screen TUI application for viewing TSV and CSV files with nice column formatting.

## Features

- Automatic CSV/TSV format detection
- Column-aligned table rendering with headers
- Vertical and horizontal scrolling
- Keyboard navigation (arrow keys, vim keys, page up/down, home/end)
- Mouse scroll support
- Alternate row coloring for better readability
- Status bar showing file info and navigation hints

## Building

```bash
cd tableview
nimble build
```

## Usage

```bash
./tableview <file.tsv|file.csv>
```

### Keyboard Controls

- `↑`/`k` - Scroll up one row
- `↓`/`j` - Scroll down one row
- `←`/`h` - Scroll left
- `→`/`l` - Scroll right
- `Page Up` - Scroll up one page
- `Page Down` - Scroll down one page
- `Home` - Jump to top
- `End` - Jump to bottom
- `q` - Quit

### Mouse Controls

- Scroll wheel - Navigate up/down

## Example

```bash
# Create a sample TSV file
echo -e "Name\tAge\tCity\tCountry\nAlice\t30\tNew York\tUSA\nBob\t25\tLondon\tUK\nCharlie\t35\tTokyo\tJapan" > sample.tsv

# View it
./tableview sample.tsv
```

## Dependencies

- nimwave - Cross-platform TUI framework
- illwave - Low-level terminal library
- argparse - Command-line argument parser

