---
description: "Control Apple Numbers spreadsheets — create documents, manage sheets/tables/cells, format, sort, export to PDF/Excel/CSV. Trigger on: 'numbers', 'spreadsheet', 'Tabelle', 'Numbers erstellen', 'export to excel', 'create spreadsheet', 'Numbers öffnen', 'Zellen formatieren'."
---

# Numbers Control Skill

You have full control over Apple Numbers via the `numbers.sh` script at `${CLAUDE_PLUGIN_ROOT}/scripts/numbers.sh`.

## How to Use

Run commands via bash:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/numbers.sh" <command> [args...]
```

All commands return JSON output for easy parsing.

## Quick Reference

### App Control
```bash
# Check if Numbers is running
bash "$SCRIPT" status

# Launch / Quit
bash "$SCRIPT" launch
bash "$SCRIPT" quit
```

### Documents
```bash
# List open documents
bash "$SCRIPT" list-docs

# Create new document (blank or from template)
bash "$SCRIPT" new-doc
bash "$SCRIPT" new-doc "Personal Budget"

# Open existing file
bash "$SCRIPT" open "/path/to/file.numbers"

# Save / Save As
bash "$SCRIPT" save "Untitled"
bash "$SCRIPT" save "Untitled" "/path/to/output.numbers"

# Export to PDF, Excel, CSV, or Numbers 09
bash "$SCRIPT" export "MyDoc" pdf "/path/to/output.pdf"
bash "$SCRIPT" export "MyDoc" excel "/path/to/output.xlsx"
bash "$SCRIPT" export "MyDoc" csv "/path/to/output.csv"

# Close document
bash "$SCRIPT" close "MyDoc" yes

# List available templates
bash "$SCRIPT" list-templates
```

### Sheets
```bash
# List sheets in a document
bash "$SCRIPT" list-sheets "MyDoc"

# Create new sheet
bash "$SCRIPT" new-sheet "MyDoc" "Sales Data"

# Delete sheet
bash "$SCRIPT" delete-sheet "MyDoc" "Sheet 2"

# Set active sheet
bash "$SCRIPT" set-active-sheet "MyDoc" "Sales Data"
```

### Tables
```bash
# List tables in a sheet
bash "$SCRIPT" list-tables "MyDoc" "Sheet 1"

# Create new table (name, rows, columns)
bash "$SCRIPT" new-table "MyDoc" "Sheet 1" "Revenue" 10 5

# Get table info (row/col counts, headers, filtered status)
bash "$SCRIPT" table-info "MyDoc" "Sheet 1" "Table 1"

# Read entire table as JSON array of rows
bash "$SCRIPT" read-table "MyDoc" "Sheet 1" "Table 1"

# Write JSON data to table (array of arrays)
bash "$SCRIPT" write-table "MyDoc" "Sheet 1" "Table 1" '[["Name","Age","City"],["Alice",30,"Berlin"],["Bob",25,"Munich"]]'

# Sort table by column
bash "$SCRIPT" sort-table "MyDoc" "Sheet 1" "Table 1" "B" ascending

# Transpose table
bash "$SCRIPT" transpose-table "MyDoc" "Sheet 1" "Table 1"

# Delete table
bash "$SCRIPT" delete-table "MyDoc" "Sheet 1" "Table 1"
```

### Cells
```bash
# Get cell value, formatted value, and formula
bash "$SCRIPT" get-cell "MyDoc" "Sheet 1" "Table 1" "B2"

# Set cell value (text, number, or formula)
bash "$SCRIPT" set-cell "MyDoc" "Sheet 1" "Table 1" "A1" "Hello"
bash "$SCRIPT" set-cell "MyDoc" "Sheet 1" "Table 1" "B1" 42
bash "$SCRIPT" set-cell "MyDoc" "Sheet 1" "Table 1" "C1" "=SUM(A1:B1)"

# Get range of cells
bash "$SCRIPT" get-range "MyDoc" "Sheet 1" "Table 1" "A1:C3"

# Set multiple cells (semicolon = row separator, comma = column separator)
bash "$SCRIPT" set-range "MyDoc" "Sheet 1" "Table 1" "A1" "Name,Age,City;Alice,30,Berlin;Bob,25,Munich"

# Clear range (content + formatting)
bash "$SCRIPT" clear-range "MyDoc" "Sheet 1" "Table 1" "A1:C3"

# Merge/Unmerge cells
bash "$SCRIPT" merge "MyDoc" "Sheet 1" "Table 1" "A1:C1"
bash "$SCRIPT" unmerge "MyDoc" "Sheet 1" "Table 1" "A1:C1"
```

### Formatting
```bash
# Format cells — supports multiple key=value pairs
bash "$SCRIPT" format-range "MyDoc" "Sheet 1" "Table 1" "A1:C1" \
  font_name=Helvetica font_size=14 \
  text_color="0,0,65535" \
  background_color="65535,65535,0" \
  alignment=center

# Available format keys:
#   font_name    — Font name (e.g., "Helvetica Bold")
#   font_size    — Font size in points
#   text_color   — RGB as "r,g,b" (0-65535 each)
#   background_color — RGB as "r,g,b" (0-65535 each)
#   alignment    — left, center, right, justify, auto align
#   vertical_alignment — top, center, bottom
#   text_wrap    — true/false
#   format       — automatic, number, currency, percent, date and time, fraction, checkbox, pop up menu
```

### Rows & Columns
```bash
# Add row above/below a cell
bash "$SCRIPT" add-row "MyDoc" "Sheet 1" "Table 1" below "A3"
bash "$SCRIPT" add-row "MyDoc" "Sheet 1" "Table 1" above "A1"

# Add column before/after a cell
bash "$SCRIPT" add-column "MyDoc" "Sheet 1" "Table 1" after "C1"

# Remove row or column
bash "$SCRIPT" remove-row "MyDoc" "Sheet 1" "Table 1" 5
bash "$SCRIPT" remove-column "MyDoc" "Sheet 1" "Table 1" "D"

# Set row height / column width
bash "$SCRIPT" set-row-height "MyDoc" "Sheet 1" "Table 1" 1 40
bash "$SCRIPT" set-column-width "MyDoc" "Sheet 1" "Table 1" "A" 200
```

### Headers & Footers
```bash
# Set header/footer counts
bash "$SCRIPT" set-header-rows "MyDoc" "Sheet 1" "Table 1" 1
bash "$SCRIPT" set-header-columns "MyDoc" "Sheet 1" "Table 1" 1
bash "$SCRIPT" set-footer-rows "MyDoc" "Sheet 1" "Table 1" 1

# Freeze/unfreeze headers
bash "$SCRIPT" freeze-header-rows "MyDoc" "Sheet 1" "Table 1" true
bash "$SCRIPT" freeze-header-columns "MyDoc" "Sheet 1" "Table 1" true
```

### Password Protection
```bash
# Set password with optional hint
bash "$SCRIPT" set-password "MyDoc" "s3cret" "See sticky note"

# Remove password
bash "$SCRIPT" remove-password "MyDoc" "s3cret"
```

## Workflow Patterns

### Create a spreadsheet from scratch
```bash
SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/numbers.sh"
bash "$SCRIPT" launch
bash "$SCRIPT" new-doc
bash "$SCRIPT" write-table "Untitled" "Sheet 1" "Table 1" '[["Product","Q1","Q2","Q3","Q4"],["Widget A",1200,1500,1800,2100],["Widget B",800,950,1100,1300]]'
bash "$SCRIPT" format-range "Untitled" "Sheet 1" "Table 1" "A1:E1" font_size=14 alignment=center background_color="40000,40000,65535" text_color="65535,65535,65535"
bash "$SCRIPT" set-header-rows "Untitled" "Sheet 1" "Table 1" 1
bash "$SCRIPT" save "Untitled" "$HOME/Desktop/Sales.numbers"
bash "$SCRIPT" export "Sales" pdf "$HOME/Desktop/Sales.pdf"
```

### Import CSV data
```bash
# Read CSV with python, convert to JSON, write to Numbers
python3 -c "
import csv, json
with open('data.csv') as f:
    data = list(csv.reader(f))
print(json.dumps(data))
" | xargs -0 bash "$SCRIPT" write-table "MyDoc" "Sheet 1" "Table 1"
```

## Notes
- Document names INCLUDE the .numbers extension (e.g., "Untitled.numbers", "Sales.numbers")
- Cell references use standard spreadsheet notation: A1, B2, C3:E10
- Colors use Apple's 16-bit RGB format: 0-65535 per channel (not 0-255)
- Templates must be installed in Numbers to be available
- Numbers must have Automation permissions in System Preferences > Privacy & Security
