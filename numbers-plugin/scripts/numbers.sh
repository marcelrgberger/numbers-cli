#!/bin/bash
# numbers.sh — AppleScript executor for Apple Numbers
# Usage: numbers.sh <command> [args...]
# All commands output JSON for easy parsing.

set -euo pipefail

APP="Numbers"

run_applescript() {
  osascript -e "$1" 2>/dev/null
}

run_applescript_file() {
  osascript "$1" 2>/dev/null
}

run_applescript_safe() {
  # Runs AppleScript, captures stderr separately, returns JSON error on failure
  local script="$1"
  local output
  local err
  err=$(mktemp)
  output=$(osascript -e "$script" 2>"$err") || {
    local errmsg
    errmsg=$(cat "$err")
    rm -f "$err"
    echo "{\"error\": $(echo "$errmsg" | json_escape)}"
    return 1
  }
  rm -f "$err"
  echo "$output"
}

json_escape() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read().rstrip('\n')))"
}

# Escape a string for safe embedding in AppleScript double-quoted literals
# Replaces \ with \\ and " with \"
as_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  echo "$s"
}

json_array_from_lines() {
  python3 -c "
import json, sys
lines = [l.strip() for l in sys.stdin if l.strip()]
print(json.dumps(lines))
"
}

# ── Document Commands ──

cmd_app_status() {
  local running
  running=$(run_applescript 'tell application "System Events" to (name of processes) contains "Numbers"')
  local doc_count="0"
  if [ "$running" = "true" ]; then
    doc_count=$(run_applescript "tell application \"$APP\" to count of documents" 2>/dev/null || echo "0")
  fi
  echo "{\"running\": $running, \"document_count\": $doc_count}"
}

cmd_launch() {
  run_applescript "tell application \"$APP\" to activate" >/dev/null
  echo '{"status": "launched"}'
}

cmd_quit() {
  run_applescript "tell application \"$APP\" to quit" >/dev/null 2>&1 || true
  echo '{"status": "quit"}'
}

cmd_list_documents() {
  run_applescript "
    tell application \"$APP\"
      set output to \"\"
      repeat with d in documents
        set output to output & name of d & \"|\" & (id of d) & linefeed
      end repeat
      return output
    end tell
  " | python3 -c "
import json, sys
docs = []
for line in sys.stdin:
    line = line.strip()
    if '|' in line:
        name, did = line.rsplit('|', 1)
        docs.append({'name': name, 'id': did})
print(json.dumps({'documents': docs}))
"
}

cmd_new_document() {
  local template="${1:-}"
  if [ -n "$template" ]; then
    run_applescript "
      tell application \"$APP\"
        activate
        set newDoc to make new document with properties {document template: template \"$template\"}
        return name of newDoc & \"|\" & id of newDoc
      end tell
    " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
name, did = line.rsplit('|', 1)
print(json.dumps({'name': name, 'id': did}))
"
  else
    run_applescript "
      tell application \"$APP\"
        activate
        set newDoc to make new document
        return name of newDoc & \"|\" & id of newDoc
      end tell
    " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
name, did = line.rsplit('|', 1)
print(json.dumps({'name': name, 'id': did}))
"
  fi
}

cmd_open_document() {
  local filepath="$1"
  run_applescript "
    tell application \"$APP\"
      activate
      open POSIX file \"$filepath\"
      delay 1
      set d to front document
      return name of d & \"|\" & id of d
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
name, did = line.rsplit('|', 1)
print(json.dumps({'name': name, 'id': did}))
"
}

cmd_close_document() {
  local doc_name="$1"
  local saving="${2:-yes}"
  run_applescript "
    tell application \"$APP\"
      close document \"$doc_name\" saving $saving
    end tell
  " >/dev/null
  echo "{\"status\": \"closed\", \"document\": $(echo "$doc_name" | json_escape)}"
}

cmd_save_document() {
  local doc_name="$1"
  local save_path="${2:-}"
  if [ -n "$save_path" ]; then
    run_applescript "
      tell application \"$APP\"
        save document \"$doc_name\" in POSIX file \"$save_path\"
      end tell
    " >/dev/null
  else
    run_applescript "
      tell application \"$APP\"
        save document \"$doc_name\"
      end tell
    " >/dev/null
  fi
  echo "{\"status\": \"saved\", \"document\": $(echo "$doc_name" | json_escape)}"
}

cmd_export_document() {
  local doc_name="$1"
  local format="$2"
  local dest_path="$3"
  local as_format
  case "$format" in
    pdf|PDF) as_format="PDF" ;;
    excel|xlsx|Excel) as_format="Microsoft Excel" ;;
    csv|CSV) as_format="CSV" ;;
    numbers09) as_format="Numbers 09" ;;
    *) echo "{\"error\": \"Unknown format: $format. Use: pdf, excel, csv, numbers09\"}"; return 1 ;;
  esac
  run_applescript "
    tell application \"$APP\"
      export document \"$doc_name\" to POSIX file \"$dest_path\" as $as_format
    end tell
  " >/dev/null
  echo "{\"status\": \"exported\", \"document\": $(echo "$doc_name" | json_escape), \"format\": \"$format\", \"path\": $(echo "$dest_path" | json_escape)}"
}

cmd_list_templates() {
  run_applescript "
    tell application \"$APP\"
      set tNames to {}
      repeat with t in templates
        set end of tNames to name of t
      end repeat
      set AppleScript's text item delimiters to linefeed
      return tNames as text
    end tell
  " | json_array_from_lines | python3 -c "
import json, sys
templates = json.load(sys.stdin)
print(json.dumps({'templates': templates}))
"
}

# ── Sheet Commands ──

cmd_list_sheets() {
  local doc_name="$1"
  run_applescript "
    tell application \"$APP\"
      tell document \"$doc_name\"
        set output to \"\"
        repeat with s in sheets
          set output to output & name of s & linefeed
        end repeat
        return output
      end tell
    end tell
  " | json_array_from_lines | python3 -c "
import json, sys
sheets = json.load(sys.stdin)
print(json.dumps({'sheets': sheets}))
"
}

cmd_new_sheet() {
  local doc_name="$1"
  local sheet_name="${2:-}"
  if [ -n "$sheet_name" ]; then
    run_applescript "
      tell application \"$APP\"
        tell document \"$doc_name\"
          set newSheet to make new sheet
          set name of newSheet to \"$sheet_name\"
          return name of newSheet
        end tell
      end tell
    " | python3 -c "
import json, sys
print(json.dumps({'name': sys.stdin.read().strip()}))
"
  else
    run_applescript "
      tell application \"$APP\"
        tell document \"$doc_name\"
          set newSheet to make new sheet
          return name of newSheet
        end tell
      end tell
    " | python3 -c "
import json, sys
print(json.dumps({'name': sys.stdin.read().strip()}))
"
  fi
}

cmd_delete_sheet() {
  local doc_name="$1"
  local sheet_name="$2"
  run_applescript "
    tell application \"$APP\"
      tell document \"$doc_name\"
        delete sheet \"$sheet_name\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"deleted\", \"sheet\": $(echo "$sheet_name" | json_escape)}"
}

cmd_set_active_sheet() {
  local doc_name="$1"
  local sheet_name="$2"
  run_applescript "
    tell application \"$APP\"
      tell document \"$doc_name\"
        set active sheet to sheet \"$sheet_name\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"active\", \"sheet\": $(echo "$sheet_name" | json_escape)}"
}

# ── Table Commands ──

cmd_list_tables() {
  local doc_name="$1"
  local sheet_name="$2"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set output to \"\"
        repeat with t in tables
          set output to output & name of t & \"|\" & row count of t & \"|\" & column count of t & linefeed
        end repeat
        return output
      end tell
    end tell
  " | python3 -c "
import json, sys
tables = []
for line in sys.stdin:
    line = line.strip()
    if '|' in line:
        parts = line.split('|')
        tables.append({'name': parts[0], 'rows': int(parts[1]), 'columns': int(parts[2])})
print(json.dumps({'tables': tables}))
"
}

cmd_new_table() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="${3:-}"
  local rows="${4:-5}"
  local cols="${5:-5}"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set newTable to make new table with properties {row count: $rows, column count: $cols}
        $([ -n "$table_name" ] && echo "set name of newTable to \"$table_name\"")
        return name of newTable & \"|\" & row count of newTable & \"|\" & column count of newTable
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
parts = line.split('|')
print(json.dumps({'name': parts[0], 'rows': int(parts[1]), 'columns': int(parts[2])}))
"
}

cmd_delete_table() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        delete table \"$table_name\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"deleted\", \"table\": $(echo "$table_name" | json_escape)}"
}

cmd_table_info() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set rc to row count
        set cc to column count
        set hrc to header row count
        set hcc to header column count
        set frc to footer row count
        set flt to filtered
        set n to name
        return n & \"|\" & rc & \"|\" & cc & \"|\" & hrc & \"|\" & hcc & \"|\" & frc & \"|\" & flt
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
p = line.split('|')
print(json.dumps({
    'name': p[0], 'row_count': int(p[1]), 'column_count': int(p[2]),
    'header_rows': int(p[3]), 'header_columns': int(p[4]),
    'footer_rows': int(p[5]), 'filtered': p[6].strip() == 'true'
}))
"
}

cmd_sort_table() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local column_name="$4"
  local direction="${5:-ascending}"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        sort table \"$table_name\" by column \"$column_name\" direction $direction
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"sorted\", \"table\": $(echo "$table_name" | json_escape), \"by\": $(echo "$column_name" | json_escape), \"direction\": \"$direction\"}"
}

cmd_transpose_table() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        transpose table \"$table_name\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"transposed\", \"table\": $(echo "$table_name" | json_escape)}"
}

# ── Cell Commands ──

cmd_get_cell() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local cell_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set c to cell \"$cell_ref\"
        set v to value of c
        set fv to formatted value of c
        set f to formula of c
        set n to name of c
        if v is missing value then
          set vStr to \"null\"
        else
          set vStr to v as text
        end if
        if f is missing value then
          set fStr to \"\"
        else
          set fStr to f
        end if
        if fv is missing value then
          set fvStr to \"\"
        else
          set fvStr to fv
        end if
        return n & \"|||\" & vStr & \"|||\" & fvStr & \"|||\" & fStr
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
parts = line.split('|||')
val = parts[1]
if val == 'null':
    val = None
print(json.dumps({'cell': parts[0], 'value': val, 'formatted_value': parts[2], 'formula': parts[3] if parts[3] else None}))
"
}

cmd_set_cell() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local cell_ref="$4"
  local value="$5"
  # Check if value starts with = (formula)
  if [[ "$value" == =* ]]; then
    run_applescript "
      tell application \"$APP\"
        tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
          set value of cell \"$cell_ref\" to \"$value\"
        end tell
      end tell
    " >/dev/null
  else
    # Try number first, fallback to string
    run_applescript "
      tell application \"$APP\"
        tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
          try
            set value of cell \"$cell_ref\" to ($value as number)
          on error
            set value of cell \"$cell_ref\" to \"$value\"
          end try
        end tell
      end tell
    " >/dev/null
  fi
  echo "{\"status\": \"set\", \"cell\": \"$cell_ref\", \"value\": $(echo "$value" | json_escape)}"
}

cmd_get_range() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local range_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set r to range \"$range_ref\"
        set output to \"\"
        repeat with c in cells of r
          set v to value of c
          set n to name of c
          if v is missing value then
            set vStr to \"__NULL__\"
          else
            set vStr to v as text
          end if
          set output to output & n & \"|||\" & vStr & linefeed
        end repeat
        return output
      end tell
    end tell
  " | python3 -c "
import json, sys
cells = []
for line in sys.stdin:
    line = line.strip()
    if '|||' in line:
        name, val = line.split('|||', 1)
        if val == '__NULL__':
            val = None
        cells.append({'cell': name, 'value': val})
print(json.dumps({'range': '$range_ref', 'cells': cells}))
"
}

cmd_set_range() {
  # Sets multiple cells. Values provided as: row1col1,row1col2;row2col1,row2col2
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local start_cell="$4"
  local values_csv="$5"  # semicolon-separated rows, comma-separated columns

  NUMBERS_DOC="$doc_name" NUMBERS_SHEET="$sheet_name" NUMBERS_TABLE="$table_name" \
  NUMBERS_START="$start_cell" NUMBERS_CSV="$values_csv" \
  python3 -c '
import subprocess, json, sys, os, re

doc = os.environ["NUMBERS_DOC"]
sheet = os.environ["NUMBERS_SHEET"]
table = os.environ["NUMBERS_TABLE"]
start = os.environ["NUMBERS_START"]
values_csv = os.environ["NUMBERS_CSV"]

m = re.match(r"([A-Z]+)(\d+)", start)
col_str, row_num = m.group(1), int(m.group(2))

def col_to_num(c):
    n = 0
    for ch in c:
        n = n * 26 + (ord(ch) - ord("A") + 1)
    return n

def num_to_col(n):
    s = ""
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(r + ord("A")) + s
    return s

def as_escape(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"")

start_col = col_to_num(col_str)
rows = values_csv.split(";")
commands = []
for ri, row in enumerate(rows):
    cols = row.split(",")
    for ci, val in enumerate(cols):
        cell = num_to_col(start_col + ci) + str(row_num + ri)
        val = val.strip()
        if val.startswith("="):
            commands.append(f"set value of cell \"{cell}\" to \"{as_escape(val)}\"")
        else:
            try:
                float(val)
                commands.append(f"set value of cell \"{cell}\" to {val}")
            except ValueError:
                commands.append(f"set value of cell \"{cell}\" to \"{as_escape(val)}\"")

esc_doc = as_escape(doc)
esc_sheet = as_escape(sheet)
esc_table = as_escape(table)
script = f"""tell application "Numbers"
  tell table "{esc_table}" of sheet "{esc_sheet}" of document "{esc_doc}"
    {chr(10).join("    " + c for c in commands)}
  end tell
end tell"""

result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
if result.returncode != 0:
    print(json.dumps({"error": result.stderr.strip()}))
else:
    print(json.dumps({"status": "set", "cells_updated": len(commands)}))
'
}

cmd_clear_range() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local range_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        clear range \"$range_ref\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"cleared\", \"range\": \"$range_ref\"}"
}

cmd_merge_cells() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local range_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        merge range \"$range_ref\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"merged\", \"range\": \"$range_ref\"}"
}

cmd_unmerge_cells() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local range_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        unmerge range \"$range_ref\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"unmerged\", \"range\": \"$range_ref\"}"
}

# ── Format Commands ──

cmd_format_range() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local range_ref="$4"
  shift 4
  # Remaining args are key=value pairs: font_name=Helvetica font_size=14 bold=true ...
  local commands=""
  while [ $# -gt 0 ]; do
    local kv="$1"
    local key="${kv%%=*}"
    local val="${kv#*=}"
    case "$key" in
      font_name) commands="$commands
        set font name of range \"$range_ref\" to \"$val\"" ;;
      font_size) commands="$commands
        set font size of range \"$range_ref\" to $val" ;;
      text_color) commands="$commands
        set text color of range \"$range_ref\" to {$val}" ;;
      background_color) commands="$commands
        set background color of range \"$range_ref\" to {$val}" ;;
      alignment) commands="$commands
        set alignment of range \"$range_ref\" to $val" ;;
      vertical_alignment) commands="$commands
        set vertical alignment of range \"$range_ref\" to $val" ;;
      text_wrap) commands="$commands
        set text wrap of range \"$range_ref\" to $val" ;;
      format) commands="$commands
        set format of range \"$range_ref\" to $val" ;;
    esac
    shift
  done
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        $commands
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"formatted\", \"range\": \"$range_ref\"}"
}

# ── Row/Column Commands ──

cmd_add_row() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local position="${4:-below}"  # above or below
  local ref_cell="${5:-A1}"
  local cmd
  if [ "$position" = "above" ]; then
    cmd="add row above"
  else
    cmd="add row below"
  fi
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        $cmd range \"$ref_cell\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"row_added\", \"position\": \"$position\"}"
}

cmd_add_column() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local position="${4:-after}"  # before or after
  local ref_cell="${5:-A1}"
  local cmd
  if [ "$position" = "before" ]; then
    cmd="add column before"
  else
    cmd="add column after"
  fi
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        $cmd range \"$ref_cell\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"column_added\", \"position\": \"$position\"}"
}

cmd_remove_row() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local row_num="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        remove row $row_num
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"row_removed\", \"row\": $row_num}"
}

cmd_remove_column() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local col_name="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        remove column \"$col_name\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"column_removed\", \"column\": $(echo "$col_name" | json_escape)}"
}

cmd_set_row_height() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local row_num="$4"
  local height="$5"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set height of row $row_num to $height
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"row\": $row_num, \"height\": $height}"
}

cmd_set_column_width() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local col_name="$4"
  local width="$5"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set width of column \"$col_name\" to $width
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"column\": $(echo "$col_name" | json_escape), \"width\": $width}"
}

# ── Table Header/Footer Commands ──

cmd_set_header_rows() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local count="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set header row count to $count
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"header_rows\": $count}"
}

cmd_set_header_columns() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local count="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set header column count to $count
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"header_columns\": $count}"
}

cmd_set_footer_rows() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local count="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set footer row count to $count
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"footer_rows\": $count}"
}

# ── Password Commands ──

cmd_set_password() {
  local doc_name="$1"
  local password="$2"
  local hint="${3:-}"
  if [ -n "$hint" ]; then
    run_applescript "
      tell application \"$APP\"
        set password \"$password\" to document \"$doc_name\" hint \"$hint\"
      end tell
    " >/dev/null
  else
    run_applescript "
      tell application \"$APP\"
        set password \"$password\" to document \"$doc_name\"
      end tell
    " >/dev/null
  fi
  echo "{\"status\": \"password_set\"}"
}

cmd_remove_password() {
  local doc_name="$1"
  local password="$2"
  run_applescript "
    tell application \"$APP\"
      tell document \"$doc_name\" to remove password \"$password\"
    end tell
  " >/dev/null
  echo "{\"status\": \"password_removed\"}"
}

# ── Rename Sheet ──

cmd_rename_sheet() {
  local doc_name="$1"
  local old_name="$2"
  local new_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell document \"$doc_name\"
        set name of sheet \"$old_name\" to \"$new_name\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"renamed\", \"old_name\": $(echo "$old_name" | json_escape), \"new_name\": $(echo "$new_name" | json_escape)}"
}

# ── Export with Options ──

cmd_export_with_options() {
  local doc_name="$1"
  local format="$2"
  local dest_path="$3"
  shift 3
  local as_format
  case "$format" in
    pdf|PDF) as_format="PDF" ;;
    excel|xlsx|Excel) as_format="Microsoft Excel" ;;
    csv|CSV) as_format="CSV" ;;
    numbers09) as_format="Numbers 09" ;;
    *) echo "{\"error\": \"Unknown format: $format\"}"; return 1 ;;
  esac
  local props=""
  while [ $# -gt 0 ]; do
    local kv="$1"
    local key="${kv%%=*}"
    local val="${kv#*=}"
    case "$key" in
      image_quality)
        case "$val" in
          good|Good) props="$props, image quality:Good" ;;
          better|Better) props="$props, image quality:Better" ;;
          best|Best) props="$props, image quality:Best" ;;
        esac ;;
      password) props="$props, password:\"$val\"" ;;
      password_hint) props="$props, password hint:\"$val\"" ;;
      exclude_summary) props="$props, exclude summary worksheet:$val" ;;
      include_comments) props="$props, include comments:$val" ;;
    esac
    shift
  done
  if [ -n "$props" ]; then
    props="${props#, }"  # remove leading comma+space
    run_applescript "
      tell application \"$APP\"
        export document \"$doc_name\" to POSIX file \"$dest_path\" as $as_format with properties {$props}
      end tell
    " >/dev/null
  else
    run_applescript "
      tell application \"$APP\"
        export document \"$doc_name\" to POSIX file \"$dest_path\" as $as_format
      end tell
    " >/dev/null
  fi
  echo "{\"status\": \"exported\", \"format\": \"$format\", \"path\": $(echo "$dest_path" | json_escape)}"
}

# ── Selection Commands ──

cmd_get_selection() {
  local doc_name="$1"
  run_applescript "
    tell application \"$APP\"
      tell document \"$doc_name\"
        set sel to selection
        set output to \"\"
        repeat with s in sel
          set output to output & class of s & \"|\" & name of s & linefeed
        end repeat
        return output
      end tell
    end tell
  " | python3 -c "
import json, sys
items = []
for line in sys.stdin:
    line = line.strip()
    if '|' in line:
        cls, name = line.split('|', 1)
        items.append({'class': cls, 'name': name})
print(json.dumps({'selection': items}))
"
}

cmd_get_table_selection() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set sr to selection range
        return name of sr
      end tell
    end tell
  " | python3 -c "
import json, sys
print(json.dumps({'selection_range': sys.stdin.read().strip()}))
"
}

cmd_set_table_selection() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local range_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set selection range to range \"$range_ref\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"selected\", \"range\": \"$range_ref\"}"
}

# ── Cell Info Commands ──

cmd_cell_info() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local cell_ref="$4"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set c to cell \"$cell_ref\"
        set v to value of c
        set fv to formatted value of c
        set f to formula of c
        set n to name of c
        set r to address of row of c
        set co to address of column of c
        if v is missing value then
          set vStr to \"null\"
        else
          set vStr to v as text
        end if
        if f is missing value then
          set fStr to \"\"
        else
          set fStr to f
        end if
        if fv is missing value then
          set fvStr to \"\"
        else
          set fvStr to fv
        end if
        return n & \"|||\" & vStr & \"|||\" & fvStr & \"|||\" & fStr & \"|||\" & r & \"|||\" & co
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
parts = line.split('|||')
val = parts[1]
if val == 'null':
    val = None
print(json.dumps({
    'cell': parts[0], 'value': val, 'formatted_value': parts[2],
    'formula': parts[3] if parts[3] else None,
    'row_address': int(parts[4]), 'column_address': int(parts[5])
}))
"
}

# ── iWork Item Commands (Shapes, Images, Text Items, Lines) ──

cmd_list_items() {
  local doc_name="$1"
  local sheet_name="$2"
  local item_type="${3:-iWork item}"  # shape, image, text item, line, chart, group
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set output to \"\"
        repeat with i in every $item_type
          try
            set n to name of i
          on error
            set n to \"(unnamed)\"
          end try
          set w to width of i
          set h to height of i
          set p to position of i
          set px to item 1 of p
          set py to item 2 of p
          set output to output & n & \"|\" & w & \"|\" & h & \"|\" & px & \"|\" & py & linefeed
        end repeat
        return output
      end tell
    end tell
  " | python3 -c "
import json, sys
items = []
for line in sys.stdin:
    line = line.strip()
    if '|' in line:
        parts = line.split('|')
        items.append({
            'name': parts[0],
            'width': int(float(parts[1])),
            'height': int(float(parts[2])),
            'x': int(float(parts[3])),
            'y': int(float(parts[4]))
        })
print(json.dumps({'items': items, 'type': '$item_type'}))
"
}

cmd_set_item_property() {
  local doc_name="$1"
  local sheet_name="$2"
  local item_type="$3"  # shape, image, text item, line
  local item_name="$4"
  shift 4
  local commands=""
  while [ $# -gt 0 ]; do
    local kv="$1"
    local key="${kv%%=*}"
    local val="${kv#*=}"
    case "$key" in
      width) commands="$commands
        set width of $item_type \"$item_name\" to $val" ;;
      height) commands="$commands
        set height of $item_type \"$item_name\" to $val" ;;
      position) commands="$commands
        set position of $item_type \"$item_name\" to {$val}" ;;
      rotation) commands="$commands
        set rotation of $item_type \"$item_name\" to $val" ;;
      opacity) commands="$commands
        set opacity of $item_type \"$item_name\" to $val" ;;
      locked) commands="$commands
        set locked of $item_type \"$item_name\" to $val" ;;
      reflection_showing) commands="$commands
        set reflection showing of $item_type \"$item_name\" to $val" ;;
      reflection_value) commands="$commands
        set reflection value of $item_type \"$item_name\" to $val" ;;
      object_text) commands="$commands
        set object text of $item_type \"$item_name\" to \"$val\"" ;;
    esac
    shift
  done
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        $commands
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"updated\", \"item_type\": $(echo "$item_type" | json_escape), \"item_name\": $(echo "$item_name" | json_escape)}"
}

cmd_get_item_property() {
  local doc_name="$1"
  local sheet_name="$2"
  local item_type="$3"
  local item_name="$4"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set i to $item_type \"$item_name\"
        set w to width of i
        set h to height of i
        set p to position of i
        set px to item 1 of p
        set py to item 2 of p
        set l to locked of i
        try
          set r to rotation of i
        on error
          set r to 0
        end try
        try
          set o to opacity of i
        on error
          set o to 100
        end try
        try
          set rs to reflection showing of i
          set rv to reflection value of i
        on error
          set rs to false
          set rv to 0
        end try
        return w & \"|\" & h & \"|\" & px & \"|\" & py & \"|\" & l & \"|\" & r & \"|\" & o & \"|\" & rs & \"|\" & rv
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
p = line.split('|')
print(json.dumps({
    'width': int(float(p[0])), 'height': int(float(p[1])),
    'x': int(float(p[2])), 'y': int(float(p[3])),
    'locked': p[4].strip() == 'true',
    'rotation': int(float(p[5])), 'opacity': int(float(p[6])),
    'reflection_showing': p[7].strip() == 'true',
    'reflection_value': int(float(p[8]))
}))
"
}

# ── Image Commands ──

cmd_get_image_info() {
  local doc_name="$1"
  local sheet_name="$2"
  local image_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set i to image \"$image_name\"
        set fn to file name of i
        set d to description of i
        set w to width of i
        set h to height of i
        return fn & \"|||\" & d & \"|||\" & w & \"|||\" & h
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
p = line.split('|||')
print(json.dumps({'file_name': p[0], 'description': p[1], 'width': int(float(p[2])), 'height': int(float(p[3]))}))
"
}

cmd_set_image_description() {
  local doc_name="$1"
  local sheet_name="$2"
  local image_name="$3"
  local desc="$4"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set description of image \"$image_name\" to \"$desc\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"description\": $(echo "$desc" | json_escape)}"
}

# ── Line Commands ──

cmd_get_line_points() {
  local doc_name="$1"
  local sheet_name="$2"
  local line_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set l to line \"$line_name\"
        set sp to start point of l
        set ep to end point of l
        return (item 1 of sp) & \"|\" & (item 2 of sp) & \"|\" & (item 1 of ep) & \"|\" & (item 2 of ep)
      end tell
    end tell
  " | python3 -c "
import json, sys
line = sys.stdin.read().strip()
p = line.split('|')
print(json.dumps({
    'start_point': {'x': int(float(p[0])), 'y': int(float(p[1]))},
    'end_point': {'x': int(float(p[2])), 'y': int(float(p[3]))}
}))
"
}

cmd_set_line_points() {
  local doc_name="$1"
  local sheet_name="$2"
  local line_name="$3"
  local start_x="$4"
  local start_y="$5"
  local end_x="$6"
  local end_y="$7"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set start point of line \"$line_name\" to {$start_x, $start_y}
        set end point of line \"$line_name\" to {$end_x, $end_y}
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\"}"
}

# ── Shape/Text Item Text ──

cmd_get_object_text() {
  local doc_name="$1"
  local sheet_name="$2"
  local item_type="$3"  # shape or text item
  local item_name="$4"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        return object text of $item_type \"$item_name\" as text
      end tell
    end tell
  " | python3 -c "
import json, sys
print(json.dumps({'text': sys.stdin.read().rstrip('\n')}))
"
}

cmd_set_object_text() {
  local doc_name="$1"
  local sheet_name="$2"
  local item_type="$3"  # shape or text item
  local item_name="$4"
  local text="$5"
  run_applescript "
    tell application \"$APP\"
      tell sheet \"$sheet_name\" of document \"$doc_name\"
        set object text of $item_type \"$item_name\" to \"$text\"
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\"}"
}

# ── Password Protected Check ──

cmd_is_password_protected() {
  local doc_name="$1"
  run_applescript "
    tell application \"$APP\"
      return password protected of document \"$doc_name\"
    end tell
  " | python3 -c "
import json, sys
val = sys.stdin.read().strip()
print(json.dumps({'password_protected': val == 'true'}))
"
}

# ── Read entire table as CSV-like JSON ──

cmd_read_table() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set rc to row count
        set cc to column count
        set output to \"\"
        repeat with r from 1 to rc
          repeat with c from 1 to cc
            set v to value of cell r of column c
            if v is missing value then
              set vStr to \"__NULL__\"
            else
              set vStr to v as text
            end if
            if c < cc then
              set output to output & vStr & \"|||\"
            else
              set output to output & vStr
            end if
          end repeat
          set output to output & linefeed
        end repeat
        return output
      end tell
    end tell
  " | python3 -c "
import json, sys
rows = []
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    cells = line.split('|||')
    row = []
    for c in cells:
        if c == '__NULL__':
            row.append(None)
        else:
            row.append(c)
    rows.append(row)
print(json.dumps({'rows': rows, 'row_count': len(rows), 'column_count': len(rows[0]) if rows else 0}))
"
}

# ── Bulk write table from JSON ──

cmd_write_table() {
  # Writes data to a table starting at A1. Input: JSON array of arrays via arg
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local json_data="$4"

  # Pass all user data via environment variables to avoid injection
  NUMBERS_DOC="$doc_name" NUMBERS_SHEET="$sheet_name" NUMBERS_TABLE="$table_name" \
  python3 -c '
import subprocess, json, sys, os

doc = os.environ["NUMBERS_DOC"]
sheet = os.environ["NUMBERS_SHEET"]
table = os.environ["NUMBERS_TABLE"]
data = json.load(sys.stdin)

def num_to_col(n):
    s = ""
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(r + ord("A")) + s
    return s

def as_escape(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"")

commands = []
for ri, row in enumerate(data):
    for ci, val in enumerate(row):
        cell = num_to_col(ci + 1) + str(ri + 1)
        if val is None:
            continue
        elif isinstance(val, bool):
            commands.append(f"set value of cell \"{cell}\" to {str(val).lower()}")
        elif isinstance(val, str) and val.startswith("="):
            commands.append(f"set value of cell \"{cell}\" to \"{as_escape(val)}\"")
        elif isinstance(val, (int, float)):
            commands.append(f"set value of cell \"{cell}\" to {val}")
        else:
            commands.append(f"set value of cell \"{cell}\" to \"{as_escape(str(val))}\"")

batch_size = 50
total = 0
esc_doc = as_escape(doc)
esc_sheet = as_escape(sheet)
esc_table = as_escape(table)
for i in range(0, len(commands), batch_size):
    batch = commands[i:i+batch_size]
    script = f"""tell application "Numbers"
  tell table "{esc_table}" of sheet "{esc_sheet}" of document "{esc_doc}"
    {chr(10).join("    " + c for c in batch)}
  end tell
end tell"""
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    if result.returncode != 0:
        print(json.dumps({"error": result.stderr.strip(), "cells_written": total}))
        sys.exit(1)
    total += len(batch)

print(json.dumps({"status": "written", "cells_written": total}))
' <<< "$json_data"
}

# ── Freeze header Commands ──

cmd_freeze_header_rows() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local frozen="${4:-true}"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set header rows frozen to $frozen
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"header_rows_frozen\": $frozen}"
}

cmd_freeze_header_columns() {
  local doc_name="$1"
  local sheet_name="$2"
  local table_name="$3"
  local frozen="${4:-true}"
  run_applescript "
    tell application \"$APP\"
      tell table \"$table_name\" of sheet \"$sheet_name\" of document \"$doc_name\"
        set header columns frozen to $frozen
      end tell
    end tell
  " >/dev/null
  echo "{\"status\": \"set\", \"header_columns_frozen\": $frozen}"
}

# ── Main dispatcher ──

case "${1:-help}" in
  # App
  status) cmd_app_status ;;
  launch) cmd_launch ;;
  quit) cmd_quit ;;

  # Documents
  list-documents|list-docs) cmd_list_documents ;;
  new-document|new-doc) cmd_new_document "${2:-}" ;;
  open) cmd_open_document "$2" ;;
  close) cmd_close_document "$2" "${3:-yes}" ;;
  save) cmd_save_document "$2" "${3:-}" ;;
  export) cmd_export_document "$2" "$3" "$4" ;;
  list-templates) cmd_list_templates ;;

  # Sheets
  list-sheets) cmd_list_sheets "$2" ;;
  new-sheet) cmd_new_sheet "$2" "${3:-}" ;;
  delete-sheet) cmd_delete_sheet "$2" "$3" ;;
  set-active-sheet) cmd_set_active_sheet "$2" "$3" ;;

  # Tables
  list-tables) cmd_list_tables "$2" "$3" ;;
  new-table) cmd_new_table "$2" "$3" "${4:-}" "${5:-5}" "${6:-5}" ;;
  delete-table) cmd_delete_table "$2" "$3" "$4" ;;
  table-info) cmd_table_info "$2" "$3" "$4" ;;
  sort-table) cmd_sort_table "$2" "$3" "$4" "$5" "${6:-ascending}" ;;
  transpose-table) cmd_transpose_table "$2" "$3" "$4" ;;
  read-table) cmd_read_table "$2" "$3" "$4" ;;
  write-table) cmd_write_table "$2" "$3" "$4" "$5" ;;

  # Cells
  get-cell) cmd_get_cell "$2" "$3" "$4" "$5" ;;
  set-cell) cmd_set_cell "$2" "$3" "$4" "$5" "$6" ;;
  get-range) cmd_get_range "$2" "$3" "$4" "$5" ;;
  set-range) cmd_set_range "$2" "$3" "$4" "$5" "$6" ;;
  clear-range) cmd_clear_range "$2" "$3" "$4" "$5" ;;
  merge) cmd_merge_cells "$2" "$3" "$4" "$5" ;;
  unmerge) cmd_unmerge_cells "$2" "$3" "$4" "$5" ;;

  # Format
  format-range) cmd_format_range "$2" "$3" "$4" "$5" "${@:6}" ;;

  # Rows/Columns
  add-row) cmd_add_row "$2" "$3" "$4" "${5:-below}" "${6:-A1}" ;;
  add-column) cmd_add_column "$2" "$3" "$4" "${5:-after}" "${6:-A1}" ;;
  remove-row) cmd_remove_row "$2" "$3" "$4" "$5" ;;
  remove-column) cmd_remove_column "$2" "$3" "$4" "$5" ;;
  set-row-height) cmd_set_row_height "$2" "$3" "$4" "$5" "$6" ;;
  set-column-width) cmd_set_column_width "$2" "$3" "$4" "$5" "$6" ;;

  # Headers/Footers
  set-header-rows) cmd_set_header_rows "$2" "$3" "$4" "$5" ;;
  set-header-columns) cmd_set_header_columns "$2" "$3" "$4" "$5" ;;
  set-footer-rows) cmd_set_footer_rows "$2" "$3" "$4" "$5" ;;
  freeze-header-rows) cmd_freeze_header_rows "$2" "$3" "$4" "${5:-true}" ;;
  freeze-header-columns) cmd_freeze_header_columns "$2" "$3" "$4" "${5:-true}" ;;

  # Password
  set-password) cmd_set_password "$2" "$3" "${4:-}" ;;
  remove-password) cmd_remove_password "$2" "$3" ;;
  is-password-protected) cmd_is_password_protected "$2" ;;

  # Sheet rename
  rename-sheet) cmd_rename_sheet "$2" "$3" "$4" ;;

  # Export with options
  export-with-options) cmd_export_with_options "$2" "$3" "$4" "${@:5}" ;;

  # Selection
  get-selection) cmd_get_selection "$2" ;;
  get-table-selection) cmd_get_table_selection "$2" "$3" "$4" ;;
  set-table-selection) cmd_set_table_selection "$2" "$3" "$4" "$5" ;;

  # Cell info (extended)
  cell-info) cmd_cell_info "$2" "$3" "$4" "$5" ;;

  # iWork items
  list-items) cmd_list_items "$2" "$3" "${4:-iWork item}" ;;
  get-item-property) cmd_get_item_property "$2" "$3" "$4" "$5" ;;
  set-item-property) cmd_set_item_property "$2" "$3" "$4" "$5" "${@:6}" ;;

  # Images
  get-image-info) cmd_get_image_info "$2" "$3" "$4" ;;
  set-image-description) cmd_set_image_description "$2" "$3" "$4" "$5" ;;

  # Lines
  get-line-points) cmd_get_line_points "$2" "$3" "$4" ;;
  set-line-points) cmd_set_line_points "$2" "$3" "$4" "$5" "$6" "$7" "$8" ;;

  # Shape/Text item text
  get-object-text) cmd_get_object_text "$2" "$3" "$4" "$5" ;;
  set-object-text) cmd_set_object_text "$2" "$3" "$4" "$5" "$6" ;;

  help|*)
    cat <<'HELP'
numbers.sh — Apple Numbers CLI Controller

USAGE: numbers.sh <command> [args...]

APP COMMANDS:
  status                                    App status (running, doc count)
  launch                                    Launch Numbers
  quit                                      Quit Numbers

DOCUMENT COMMANDS:
  list-docs                                 List open documents
  new-doc [template]                        Create new document (optional template)
  open <path>                               Open a .numbers file
  close <doc> [yes|no|ask]                  Close document
  save <doc> [path]                         Save document (optional Save As)
  export <doc> <pdf|excel|csv|numbers09> <path>  Export document
  list-templates                            List available templates

SHEET COMMANDS:
  list-sheets <doc>                         List sheets in document
  new-sheet <doc> [name]                    Create new sheet
  delete-sheet <doc> <sheet>                Delete sheet
  set-active-sheet <doc> <sheet>            Switch active sheet

TABLE COMMANDS:
  list-tables <doc> <sheet>                 List tables in sheet
  new-table <doc> <sheet> [name] [rows] [cols]  Create new table
  delete-table <doc> <sheet> <table>        Delete table
  table-info <doc> <sheet> <table>          Get table info
  sort-table <doc> <sheet> <table> <col> [asc|desc]  Sort table
  transpose-table <doc> <sheet> <table>     Transpose table
  read-table <doc> <sheet> <table>          Read entire table as JSON
  write-table <doc> <sheet> <table> <json>  Write JSON data to table

CELL COMMANDS:
  get-cell <doc> <sheet> <table> <cell>     Get cell value/formula
  set-cell <doc> <sheet> <table> <cell> <value>  Set cell value or formula
  get-range <doc> <sheet> <table> <range>   Get range values
  set-range <doc> <sheet> <table> <start> <csv>  Set range (;=rows ,=cols)
  clear-range <doc> <sheet> <table> <range> Clear range
  merge <doc> <sheet> <table> <range>       Merge cells
  unmerge <doc> <sheet> <table> <range>     Unmerge cells

FORMAT COMMANDS:
  format-range <doc> <sheet> <table> <range> [key=val...]
    Keys: font_name, font_size, text_color, background_color,
          alignment, vertical_alignment, text_wrap, format

ROW/COLUMN COMMANDS:
  add-row <doc> <sheet> <table> [above|below] [cell]
  add-column <doc> <sheet> <table> [before|after] [cell]
  remove-row <doc> <sheet> <table> <row_num>
  remove-column <doc> <sheet> <table> <col_letter>
  set-row-height <doc> <sheet> <table> <row> <height>
  set-column-width <doc> <sheet> <table> <col> <width>

HEADER/FOOTER COMMANDS:
  set-header-rows <doc> <sheet> <table> <count>
  set-header-columns <doc> <sheet> <table> <count>
  set-footer-rows <doc> <sheet> <table> <count>
  freeze-header-rows <doc> <sheet> <table> [true|false]
  freeze-header-columns <doc> <sheet> <table> [true|false]

PASSWORD COMMANDS:
  set-password <doc> <password> [hint]
  remove-password <doc> <password>
  is-password-protected <doc>               Check if doc is protected

SHEET RENAME:
  rename-sheet <doc> <old_name> <new_name>

EXPORT WITH OPTIONS:
  export-with-options <doc> <fmt> <path> [key=val...]
    Keys: image_quality (good|better|best), password, password_hint,
          exclude_summary (true|false), include_comments (true|false)

SELECTION COMMANDS:
  get-selection <doc>                       Get selected items
  get-table-selection <doc> <sheet> <table> Get selected cell range
  set-table-selection <doc> <sheet> <table> <range>  Select cells

CELL INFO (EXTENDED):
  cell-info <doc> <sheet> <table> <cell>    Cell value + row/column address

iWORK ITEM COMMANDS:
  list-items <doc> <sheet> [type]           List items (shape|image|text item|line|chart|group)
  get-item-property <doc> <sheet> <type> <name>     Get item properties
  set-item-property <doc> <sheet> <type> <name> [key=val...]
    Keys: width, height, position (x,y), rotation, opacity, locked,
          reflection_showing, reflection_value, object_text

IMAGE COMMANDS:
  get-image-info <doc> <sheet> <name>       Get image file/description/size
  set-image-description <doc> <sheet> <name> <desc>  Set accessibility text

LINE COMMANDS:
  get-line-points <doc> <sheet> <name>      Get start/end points
  set-line-points <doc> <sheet> <name> <sx> <sy> <ex> <ey>

SHAPE/TEXT ITEM TEXT:
  get-object-text <doc> <sheet> <type> <name>  Get text in shape/text item
  set-object-text <doc> <sheet> <type> <name> <text>  Set text

All commands output JSON.
HELP
    ;;
esac
