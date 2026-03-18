# numbers-control — Claude Code Plugin for Apple Numbers

A Claude Code plugin that gives Claude full programmatic control over Apple Numbers via AppleScript. Create spreadsheets, manage data, format cells, export to PDF/Excel/CSV, and more — all from natural language.

## Features

### Document Management
- Create new documents (blank or from 37+ built-in templates)
- Open, save, close, and export documents
- Export to **PDF**, **Excel (.xlsx)**, **CSV**, and **Numbers 09**
- Export with options: image quality, password protection, comments
- Password protect/unprotect documents

### Sheet Operations
- List, create, delete, rename sheets
- Switch active sheet

### Table Operations
- Create, delete, list tables with custom dimensions
- Read entire tables as JSON
- Write bulk data from JSON arrays
- Sort by column (ascending/descending)
- Transpose tables
- Get table info (row/column counts, headers, footers, filter status)

### Cell & Range Operations
- Get/set individual cell values, formulas, and formatted values
- Read/write cell ranges
- Set formulas (e.g., `=SUM(A1:B10)`)
- Clear, merge, and unmerge cell ranges
- Extended cell info with row/column address

### Formatting
- Font name and size
- Text color and background color (16-bit RGB)
- Horizontal alignment (left, center, right, justify, auto)
- Vertical alignment (top, center, bottom)
- Text wrap
- Cell format (number, currency, percent, date/time, checkbox, etc.)

### Row & Column Management
- Add rows above/below
- Add columns before/after
- Remove rows and columns
- Set row height and column width

### Headers & Footers
- Set header row/column counts
- Set footer row count
- Freeze/unfreeze header rows and columns

### iWork Item Manipulation
- List and manipulate shapes, images, text items, lines, charts, groups
- Set position, size, rotation, opacity, locked state
- Set reflection properties
- Read/write text content in shapes and text items
- Get image info and set accessibility descriptions
- Get/set line start and end points

### Selection Control
- Get current document selection
- Get/set table cell selection range

## Installation

### As a Claude Code Plugin

1. Copy the `numbers-plugin` directory to your Claude Code plugins location:
   ```bash
   cp -r numbers-plugin ~/.claude/plugins/cache/local/numbers-control/1.0.0
   ```

2. Register in `~/.claude/plugins/installed_plugins.json`:
   ```json
   {
     "numbers-control@local": [{
       "scope": "user",
       "installPath": "~/.claude/plugins/cache/local/numbers-control/1.0.0",
       "version": "1.0.0"
     }]
   }
   ```

3. Enable in `~/.claude/settings.json`:
   ```json
   {
     "enabledPlugins": {
       "numbers-control@local": true
     }
   }
   ```

4. Restart Claude Code.

### Standalone Usage

The script works independently without Claude Code:

```bash
chmod +x numbers-plugin/scripts/numbers.sh
./numbers-plugin/scripts/numbers.sh help
```

## Requirements

- macOS with Apple Numbers installed
- `osascript` (included with macOS)
- Python 3 (for JSON processing)
- Numbers must have Automation permissions in System Settings > Privacy & Security > Automation

## Quick Examples

```bash
SCRIPT="./numbers-plugin/scripts/numbers.sh"

# Launch Numbers and create a document
bash "$SCRIPT" launch
bash "$SCRIPT" new-doc

# Write data
bash "$SCRIPT" write-table "Untitled.numbers" "Sheet 1" "Table 1" \
  '[["Name","Age","City"],["Alice",30,"Berlin"],["Bob",25,"Munich"]]'

# Format header row
bash "$SCRIPT" format-range "Untitled.numbers" "Sheet 1" "Table 1" "A1:C1" \
  font_size=14 alignment=center background_color="0,0,50000" text_color="65535,65535,65535"

# Add a formula
bash "$SCRIPT" set-cell "Untitled.numbers" "Sheet 1" "Table 1" "D1" "Average Age"
bash "$SCRIPT" set-cell "Untitled.numbers" "Sheet 1" "Table 1" "D2" "=AVERAGE(B2:B3)"

# Export
bash "$SCRIPT" export "Untitled.numbers" pdf "$HOME/Desktop/report.pdf"
bash "$SCRIPT" export "Untitled.numbers" excel "$HOME/Desktop/report.xlsx"
```

## All Commands

Run `bash numbers.sh help` for the full command reference. All commands output JSON.

| Category | Commands |
|----------|----------|
| App | `status`, `launch`, `quit` |
| Documents | `list-docs`, `new-doc`, `open`, `close`, `save`, `export`, `export-with-options`, `list-templates` |
| Sheets | `list-sheets`, `new-sheet`, `delete-sheet`, `rename-sheet`, `set-active-sheet` |
| Tables | `list-tables`, `new-table`, `delete-table`, `table-info`, `sort-table`, `transpose-table`, `read-table`, `write-table` |
| Cells | `get-cell`, `set-cell`, `get-range`, `set-range`, `clear-range`, `merge`, `unmerge`, `cell-info` |
| Format | `format-range` (font_name, font_size, text_color, background_color, alignment, vertical_alignment, text_wrap, format) |
| Rows/Cols | `add-row`, `add-column`, `remove-row`, `remove-column`, `set-row-height`, `set-column-width` |
| Headers | `set-header-rows`, `set-header-columns`, `set-footer-rows`, `freeze-header-rows`, `freeze-header-columns` |
| Password | `set-password`, `remove-password`, `is-password-protected` |
| Selection | `get-selection`, `get-table-selection`, `set-table-selection` |
| Items | `list-items`, `get-item-property`, `set-item-property`, `get-image-info`, `set-image-description`, `get-line-points`, `set-line-points`, `get-object-text`, `set-object-text` |

## Security

- User inputs are escaped before embedding in AppleScript to prevent injection
- Python subprocesses receive data via environment variables and stdin, not string interpolation
- All commands output structured JSON for safe parsing

## License

MIT
