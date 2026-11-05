#!/usr/bin/env bash
# Exit 0 only if TOML table [<table>] in <file> has a line `<key> = <value>`.
#
# Limitation: a table header is recognised only when written as `[name]`,
# optionally followed by whitespace. A header with a trailing comment
# (`[lints] # c`) or spaces inside the brackets (`[ lints ]`) is not
# recognised, so `just install` treats such a header as "no match".
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: bash scripts/toml-has.sh <file> <table> <key> <value>" >&2
  exit 2
fi

awk -v table="$2" -v key="$3" -v want="$4" '
  function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
  {
    line = trim($0)
    if (line == "" || substr(line, 1, 1) == "#") next
    if (substr(line, 1, 1) == "[") {
      in_table = (line == "[" table "]")
      next
    }
    if (!in_table) next
    eq = index(line, "=")
    if (eq == 0) next
    k = trim(substr(line, 1, eq - 1))
    v = substr(line, eq + 1)
    sub(/[ \t]+#.*$/, "", v)
    v = trim(v)
    if (k == key && v == want) found = 1
  }
  END { exit(found ? 0 : 1) }
' "$1"
