# TableView - Interactive Key Commands

A TUI (Terminal User Interface) application for viewing and manipulating CSV/TSV files.

## Navigation

### Basic Movement
- `↑` / `k` - Move active cell up one row
- `↓` / `j` - Move active cell down one row
- `←` - Move active cell left one column
- `→` - Move active cell right one column

### Quick Navigation
- `Page Up` - Jump up by one screen of rows
- `Page Down` - Jump down by one screen of rows
- `Home` - Go to first row and first column
- `End` - Go to last row

### Mouse Support
- **Scroll wheel up** - Move up
- **Scroll wheel down** - Move down

## Jump to Line

- `:` - Enter command mode to jump to a specific line
  - Type a line number and press `Enter` to jump to that row
  - Press `Escape` to cancel
  - Example: `:42` then `Enter` jumps to row 42

## Search

### Search All Columns
- `/` - Start search across all columns
  - Type your search pattern and press `Enter`
  - Search is case-insensitive
  - Press `Escape` to cancel

### Search Current Column Only
- `|` - Start search in the active column only
  - Type your search pattern and press `Enter`
  - Search is case-insensitive
  - Press `Escape` to cancel

### Navigate Search Results
- `N` - Jump to next occurrence of search pattern
- `B` - Jump to previous occurrence (backward)

Search wraps around - when it reaches the end, it continues from the beginning.

## Column Operations

### Adjust Column Width
- `P` - Increase active column width by 1 character
- `O` - Decrease active column width by 1 character (minimum width: 3)

### Hide/Show Columns
- `H` - Hide the active column
  - The active cell automatically moves to the next visible column
- `U` - Unhide all hidden columns

### Change Column Type
Column types affect how sorting works:
- `I` - Set active column type to Integer
- `F` - Set active column type to Float
- Column type is shown in status bar: `[STR]`, `[INT]`, or `[FLT]`

Note: Column types are auto-detected on load, but you can override them.

## Sorting

Sort the entire table by the active column:
- `[` - Sort **descending** by active column
- `]` - Sort **ascending** by active column

Sorting behavior:
- **Numeric columns** (INT/FLOAT): Sorts numerically
- **String columns**: Sorts alphabetically
- Sorting is **persistent** - original order is not preserved

## Header Management

- `T` - Toggle header mode
  - If header exists: Converts header to first data row and creates artificial headers (Col1, Col2, etc.)
  - If no header: Converts first data row to header

Useful when files don't have headers or when you want to treat the header as data.

## Status Bar

The bottom status bar shows:
- **Cell position**: `Cell: (row, col)` - Current active cell (1-based)
- **Row info**: `Row: current/total` - Current row and total rows
- **Column info**: `Col: current/total` - Current column and total columns
- **Column type**: `[STR]`, `[INT]`, or `[FLT]` - Data type of active column

When in input mode (`:`, `/`, or `|`), the status bar shows your input prompt.

## Highlighting

The table uses three levels of highlighting to show the active cell:
- **Active Cell** (row + column intersection): White background - most prominent
- **Active Row**: All cells in the current row are highlighted
- **Active Column**: All cells in the current column are highlighted with cyan text

This makes it easy to see the entire row and column context of your current position.

## Save

- `s` - Save the table to a file
  - Status bar prompts "Save to: " — type a filename and press `Enter`
  - Press `Escape` to cancel
  - Delimiter is inferred from the filename extension: `.csv` → comma, anything else → tab
  - All rows are written in the current sort order with the header row
  - Hidden columns are excluded from the output
  - If the file already exists, you will be asked "Overwrite? (y/n)" — press `y` to confirm or any other key to cancel

## Exit

- `q` or `Q` - Quit the application

## Command-Line Options

```bash
# View a file
./tableview data.csv
./tableview data.tsv

# Read from stdin (pipe)
cat data.csv | ./tableview
./tableview -

# Force delimiter type
./tableview --csv data.txt
./tableview --tsv data.txt

# File with no header
./tableview --noheader data.csv

# Skip lines at start of file
./tableview --skip 5 data.csv

# Skip lines starting with a character (e.g., comments)
./tableview --skip-prefix "#" data.csv

# Choose color scheme
./tableview --scheme bold data.csv
./tableview --scheme dark data.csv
./tableview --scheme subtle data.csv

# Combine options
cat data.csv | ./tableview --noheader --skip 2
```

## Tips & Tricks

1. **Quick column inspection**: Use `→` and `←` to move between columns while watching the column type change in the status bar

2. **Finding specific values**: Use `/` to search all columns, then use `N` repeatedly to cycle through matches

3. **Column-specific search**: When you need to find values in a specific column, navigate to that column first, then use `|` instead of `/`

4. **Adjusting display**: If column contents are cut off, use `P` multiple times to widen the column

5. **Cleaning up view**: Use `H` to hide columns you don't need, `U` to restore them all later

6. **Sorting workflow**:
   - Navigate to the column you want to sort by
   - Optionally set the correct type with `I` or `F` for proper numeric sorting
   - Press `[` or `]` to sort

7. **Large files from stdin**: The application reads all piped data into memory first, so it works even with large files piped through complex shell pipelines

## Examples

### Example 1: Quick CSV Inspection
```bash
./tableview sales_data.csv
# Use ↓↑→← to explore
# Press / then type "2024" to find all 2024 entries
# Press N to cycle through results
# Press q to quit
```

### Example 2: Sorting and Analysis
```bash
./tableview data.csv
# Navigate to the "price" column with →
# Press I to set it as integer type
# Press ] to sort ascending (lowest to highest)
# Press [ to sort descending (highest to lowest)
```

### Example 3: Pipeline Processing
```bash
# Process and view results
grep "ERROR" app.log | cut -f1,3,5 | ./tableview --noheader
# Use : then type line number to jump to specific errors
# Use H to hide columns you don't need
```

### Example 4: Column Management
```bash
./tableview large_table.csv
# Too many columns? Hide some:
# Navigate to unwanted column with →
# Press H to hide it
# Repeat for other columns
# Press U to restore all when needed
```

## Color Schemes

Four color schemes are available via `--scheme`:

- **default**: Clean, minimal highlighting with cyan accents
- **bold**: High contrast with bright colors (blue, yellow, magenta)
- **subtle**: Very minimal, monochrome highlighting
- **dark**: Dark theme with cyan accents on black

Try different schemes to find what works best for your terminal and preferences!
