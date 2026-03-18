# numbers-cli

A [Claude Code](https://claude.com/claude-code) plugin that gives Claude full programmatic control over **Apple Numbers** via AppleScript. Create spreadsheets, manage data, format cells, set formulas, export to PDF/Excel/CSV, manipulate shapes and images — all through natural language or direct CLI commands.

> **60+ commands** covering the most-used Numbers AppleScript API surface. All output is JSON.

## Installation

### Prerequisites

- **macOS** with Apple Numbers installed
- **Python 3** (ships with macOS)
- Numbers must have **Automation permissions**: System Settings > Privacy & Security > Automation

### Step 1 — Clone the repository

```bash
git clone https://github.com/marcelrgberger/numbers-cli.git
cd numbers-cli
```

### Step 2 — Install the plugin into Claude Code

Run the install script, or do it manually:

```bash
# Create plugin directory
mkdir -p ~/.claude/plugins/cache/local/numbers-cli/1.0.0

# Copy plugin files
cp -R numbers-plugin/* ~/.claude/plugins/cache/local/numbers-cli/1.0.0/
```

### Step 3 — Register the plugin

Add the plugin entry to `~/.claude/plugins/installed_plugins.json`. If the file already has a `"plugins"` object, add the `"numbers-cli@local"` key inside it:

```json
{
  "version": 2,
  "plugins": {
    "numbers-cli@local": [
      {
        "scope": "user",
        "installPath": "~/.claude/plugins/cache/local/numbers-cli/1.0.0",
        "version": "1.0.0",
        "installedAt": "2026-01-01T00:00:00.000Z",
        "lastUpdated": "2026-01-01T00:00:00.000Z",
        "gitCommitSha": "local"
      }
    ]
  }
}
```

### Step 4 — Enable the plugin

Add this to `~/.claude/settings.json` inside the `"enabledPlugins"` object:

```json
{
  "enabledPlugins": {
    "numbers-cli@local": true
  }
}
```

### Step 5 — Restart Claude Code

Quit and relaunch Claude Code. The plugin is now active.

### Verify installation

In Claude Code, ask:

> "Check if Numbers is running"

Claude will use the plugin to run `numbers.sh status` and return JSON like:

```json
{"running": false, "document_count": 0}
```

## Usage

### With Claude Code (natural language)

Once the plugin is installed, just talk to Claude:

- *"Create a new Numbers spreadsheet with a sales report"*
- *"Add a table with columns Name, Revenue, Q1, Q2, Q3, Q4"*
- *"Format the header row bold with a blue background"*
- *"Add a SUM formula in the total row"*
- *"Export it as PDF to my Desktop"*
- *"Sort the table by Revenue descending"*

Claude will automatically use the plugin's `numbers.sh` script to execute these operations.

### Standalone CLI (without Claude Code)

The script works independently:

```bash
chmod +x numbers-plugin/scripts/numbers.sh
SCRIPT="./numbers-plugin/scripts/numbers.sh"

# Check status
bash "$SCRIPT" status

# Launch Numbers
bash "$SCRIPT" launch

# Create a document
bash "$SCRIPT" new-doc

# Write data (JSON array of arrays)
bash "$SCRIPT" write-table "Untitled.numbers" "Sheet 1" "Table 1" \
  '[["Product","Q1","Q2","Q3"],["Widget A",1200,1500,1800],["Widget B",800,950,1100]]'

# Set a formula
bash "$SCRIPT" set-cell "Untitled.numbers" "Sheet 1" "Table 1" "E1" "Total"
bash "$SCRIPT" set-cell "Untitled.numbers" "Sheet 1" "Table 1" "E2" "=SUM(B2:D2)"

# Format header row
bash "$SCRIPT" format-range "Untitled.numbers" "Sheet 1" "Table 1" "A1:E1" \
  font_size=14 alignment=center \
  background_color="0,0,50000" text_color="65535,65535,65535"

# Export to PDF and Excel
bash "$SCRIPT" export "Untitled.numbers" pdf "$HOME/Desktop/report.pdf"
bash "$SCRIPT" export "Untitled.numbers" excel "$HOME/Desktop/report.xlsx"

# Close
bash "$SCRIPT" close "Untitled.numbers" yes
bash "$SCRIPT" quit
```

> **Note:** Document names include the `.numbers` extension (e.g., `"Untitled.numbers"`, `"Sales.numbers"`).

## Complete Command Reference

### App Control

| Command | Description |
|---------|-------------|
| `status` | Check if Numbers is running and document count |
| `launch` | Launch Numbers |
| `quit` | Quit Numbers |

### Documents

| Command | Description |
|---------|-------------|
| `list-docs` | List all open documents |
| `new-doc [template]` | Create new document (optionally from a template) |
| `open <path>` | Open a `.numbers` file |
| `close <doc> [yes\|no\|ask]` | Close a document |
| `save <doc> [path]` | Save document (optional Save As) |
| `export <doc> <format> <path>` | Export as `pdf`, `excel`, `csv`, or `numbers09` |
| `export-with-options <doc> <format> <path> [opts...]` | Export with `image_quality=`, `password=`, `include_comments=` |
| `list-templates` | List all available templates (37+) |

### Sheets

| Command | Description |
|---------|-------------|
| `list-sheets <doc>` | List sheets in a document |
| `new-sheet <doc> [name]` | Create a new sheet |
| `delete-sheet <doc> <sheet>` | Delete a sheet |
| `rename-sheet <doc> <old> <new>` | Rename a sheet |
| `set-active-sheet <doc> <sheet>` | Switch active sheet |

### Tables

| Command | Description |
|---------|-------------|
| `list-tables <doc> <sheet>` | List tables with row/column counts |
| `new-table <doc> <sheet> [name] [rows] [cols]` | Create a new table |
| `delete-table <doc> <sheet> <table>` | Delete a table |
| `table-info <doc> <sheet> <table>` | Row/column counts, headers, footers, filter status |
| `sort-table <doc> <sheet> <table> <col> [ascending\|descending]` | Sort by column |
| `transpose-table <doc> <sheet> <table>` | Transpose rows and columns |
| `read-table <doc> <sheet> <table>` | Read entire table as JSON array |
| `write-table <doc> <sheet> <table> <json>` | Write JSON data to table |

### Cells & Ranges

| Command | Description |
|---------|-------------|
| `get-cell <doc> <sheet> <table> <cell>` | Get value, formatted value, and formula |
| `set-cell <doc> <sheet> <table> <cell> <value>` | Set value (text, number, or `=formula`) |
| `cell-info <doc> <sheet> <table> <cell>` | Extended info including row/column address |
| `get-range <doc> <sheet> <table> <range>` | Get all values in a range |
| `set-range <doc> <sheet> <table> <start> <csv>` | Set range (`;` = row sep, `,` = col sep). **Note:** values containing commas or semicolons cannot be represented in CSV format — use `write-table` with JSON for complex data. |
| `clear-range <doc> <sheet> <table> <range>` | Clear content and formatting |
| `merge <doc> <sheet> <table> <range>` | Merge cells |
| `unmerge <doc> <sheet> <table> <range>` | Unmerge cells |

### Formatting

```bash
format-range <doc> <sheet> <table> <range> [key=value ...]
```

| Key | Example | Description |
|-----|---------|-------------|
| `font_name` | `font_name=Helvetica` | Font family |
| `font_size` | `font_size=14` | Font size in points |
| `text_color` | `text_color=65535,0,0` | Text color (16-bit RGB, 0–65535) |
| `background_color` | `background_color=0,0,50000` | Cell background color |
| `alignment` | `alignment=center` | `left`, `center`, `right`, `justify`, `auto align` |
| `vertical_alignment` | `vertical_alignment=top` | `top`, `center`, `bottom` |
| `text_wrap` | `text_wrap=true` | Enable/disable text wrapping |
| `format` | `format=currency` | `automatic`, `number`, `currency`, `percent`, `date and time`, `fraction`, `checkbox`, `pop up menu`, `scientific`, `slider`, `stepper`, `text`, `duration`, `rating`, `numeral system` |

### Rows & Columns

| Command | Description |
|---------|-------------|
| `add-row <doc> <sheet> <table> [above\|below] [cell]` | Add a row |
| `add-column <doc> <sheet> <table> [before\|after] [cell]` | Add a column |
| `remove-row <doc> <sheet> <table> <row_num>` | Remove a row |
| `remove-column <doc> <sheet> <table> <col_letter>` | Remove a column |
| `set-row-height <doc> <sheet> <table> <row> <height>` | Set row height |
| `set-column-width <doc> <sheet> <table> <col> <width>` | Set column width |

### Headers & Footers

| Command | Description |
|---------|-------------|
| `set-header-rows <doc> <sheet> <table> <count>` | Set number of header rows |
| `set-header-columns <doc> <sheet> <table> <count>` | Set number of header columns |
| `set-footer-rows <doc> <sheet> <table> <count>` | Set number of footer rows |
| `freeze-header-rows <doc> <sheet> <table> [true\|false]` | Freeze/unfreeze header rows |
| `freeze-header-columns <doc> <sheet> <table> [true\|false]` | Freeze/unfreeze header columns |

### Password Protection

| Command | Description |
|---------|-------------|
| `set-password <doc> <password> [hint]` | Set document password |
| `remove-password <doc> <password>` | Remove document password |
| `is-password-protected <doc>` | Check if document is protected |

### Selection

| Command | Description |
|---------|-------------|
| `get-selection <doc>` | Get currently selected items |
| `get-table-selection <doc> <sheet> <table>` | Get selected cell range |
| `set-table-selection <doc> <sheet> <table> <range>` | Select a cell range |

### iWork Items (Shapes, Images, Lines, Text Items)

| Command | Description |
|---------|-------------|
| `list-items <doc> <sheet> [type]` | List items (`shape`, `image`, `text item`, `line`, `chart`, `group`) |
| `get-item-property <doc> <sheet> <type> <name>` | Get size, position, rotation, opacity, locked, reflection |
| `set-item-property <doc> <sheet> <type> <name> [key=val ...]` | Set `width=`, `height=`, `position=x,y`, `rotation=`, `opacity=`, `locked=`, `reflection_showing=`, `reflection_value=`, `object_text=` |
| `get-image-info <doc> <sheet> <name>` | Get image file name, accessibility description, size |
| `set-image-description <doc> <sheet> <name> <text>` | Set accessibility description |
| `get-line-points <doc> <sheet> <name>` | Get start/end point coordinates |
| `set-line-points <doc> <sheet> <name> <sx> <sy> <ex> <ey>` | Set start/end point coordinates |
| `get-object-text <doc> <sheet> <type> <name>` | Get text inside a shape or text item |
| `set-object-text <doc> <sheet> <type> <name> <text>` | Set text inside a shape or text item |

## Examples

### Create a budget spreadsheet from a template

```bash
bash "$SCRIPT" launch
bash "$SCRIPT" new-doc "Personal Budget"
bash "$SCRIPT" list-sheets "Personal Budget.numbers"
```

### Build a report from scratch

```bash
bash "$SCRIPT" new-doc
bash "$SCRIPT" rename-sheet "Untitled.numbers" "Sheet 1" "Revenue"

bash "$SCRIPT" write-table "Untitled.numbers" "Revenue" "Table 1" \
  '[["Region","Q1","Q2","Q3","Q4"],["North",45000,52000,48000,61000],["South",38000,41000,44000,47000],["East",29000,33000,37000,42000]]'

bash "$SCRIPT" set-cell "Untitled.numbers" "Revenue" "Table 1" "F1" "Total"
bash "$SCRIPT" set-cell "Untitled.numbers" "Revenue" "Table 1" "F2" "=SUM(B2:E2)"
bash "$SCRIPT" set-cell "Untitled.numbers" "Revenue" "Table 1" "F3" "=SUM(B3:E3)"
bash "$SCRIPT" set-cell "Untitled.numbers" "Revenue" "Table 1" "F4" "=SUM(B4:E4)"

bash "$SCRIPT" format-range "Untitled.numbers" "Revenue" "Table 1" "A1:F1" \
  font_size=13 alignment=center background_color="10000,10000,45000" text_color="65535,65535,65535"

bash "$SCRIPT" format-range "Untitled.numbers" "Revenue" "Table 1" "B2:F4" format=currency
bash "$SCRIPT" set-header-rows "Untitled.numbers" "Revenue" "Table 1" 1
bash "$SCRIPT" freeze-header-rows "Untitled.numbers" "Revenue" "Table 1" true

bash "$SCRIPT" save "Untitled.numbers" "$HOME/Desktop/Revenue.numbers"
bash "$SCRIPT" export "Revenue.numbers" pdf "$HOME/Desktop/Revenue.pdf"
```

### Sort and export existing data

```bash
bash "$SCRIPT" open "$HOME/Documents/data.numbers"
bash "$SCRIPT" sort-table "data.numbers" "Sheet 1" "Table 1" "B" descending
bash "$SCRIPT" export "data.numbers" csv "/tmp/sorted_data.csv"
bash "$SCRIPT" close "data.numbers" yes
```

## Security

- User inputs are escaped before embedding in AppleScript strings to prevent injection attacks
- Python subprocesses receive data via environment variables and stdin (not string interpolation)
- All commands return structured JSON for safe, predictable parsing
- Reviewed by OpenAI Codex for injection vulnerabilities

## License

MIT
