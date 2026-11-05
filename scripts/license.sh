#!/usr/bin/env bash
# Apply (default) or check (--check) the SPDX licence header on all .rs files.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

mode=apply
case "${1:-}" in
  "") ;;
  --check) mode=check ;;
  *) echo "Usage: bash scripts/license.sh [--check]" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "Usage: bash scripts/license.sh [--check]" >&2
  exit 2
fi

files=()
while IFS= read -r -d '' f; do
  files+=("$f")
done < <(git ls-files -z --cached --others --exclude-standard -- 'apps/*.rs' 'libs/*.rs')

if [ "${#files[@]}" -eq 0 ]; then
  echo "Error: no .rs files found under apps/ or libs/" >&2
  exit 1
fi

if [ "$mode" = check ]; then
  exec addlicense -check -f .license-header.tmpl "${files[@]}"
else
  exec addlicense -f .license-header.tmpl "${files[@]}"
fi
