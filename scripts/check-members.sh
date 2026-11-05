#!/usr/bin/env bash
# Policy: every member crate must have [lints] workspace = true.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

count=0
failed=0
for manifest in apps/*/Cargo.toml libs/*/Cargo.toml; do
  [ -f "$manifest" ] || continue
  count=$((count + 1))
  if ! bash scripts/toml-has.sh "$manifest" lints workspace true; then
    echo "Policy violation: $manifest is missing [lints] workspace = true" >&2
    failed=1
  fi
done

if [ "$count" -eq 0 ]; then
  echo "Error: no member manifests found under apps/ or libs/" >&2
  exit 1
fi
exit "$failed"
