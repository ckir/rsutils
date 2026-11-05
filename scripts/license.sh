#!/usr/bin/env bash
# Apply (default) or check (--check) the SPDX licence header on all .rs files.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

usage() {
  echo "Usage: bash scripts/license.sh [--check]" >&2
  exit 2
}

# Decide the mode by argument count: none = apply, exactly --check = check.
mode=apply
if [ "$#" -eq 1 ] && [ "$1" = "--check" ]; then
  mode=check
elif [ "$#" -ne 0 ]; then
  usage
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
