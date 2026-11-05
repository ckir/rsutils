#!/usr/bin/env bash
# Negative/edge tests for the policy scripts (check-members.sh, toml-has.sh,
# license.sh), run against COPIES in a throwaway git repository.
set -euo pipefail

src="$(git rev-parse --show-toplevel)/scripts"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "test-policy: FAIL: $*" >&2
  exit 1
}

mkdir -p "$tmp/repo/scripts"
cp "$src/toml-has.sh" "$src/check-members.sh" "$src/license.sh" "$tmp/repo/scripts/"
repo="$tmp/repo"
(cd "$repo" && git init -q)

err="$tmp/stderr"
out="$tmp/stdout"

# expect_rc <name> <expected-rc> <cmd...>: run in $repo, capture stdout/stderr.
expect_rc() {
  local name="$1" want="$2" rc=0
  shift 2
  (cd "$repo" && "$@") >"$out" 2>"$err" || rc=$?
  [ "$rc" -eq "$want" ] || fail "$name: expected exit $want, got $rc (stderr: $(cat "$err"))"
}

# expect_err <name> <fragment>: stderr must contain the fragment.
expect_err() {
  grep -F -q -- "$2" "$err" || fail "$1: stderr lacks '$2' (stderr: $(cat "$err"))"
}

# expect_no_err <name>: stderr must be empty.
expect_no_err() {
  [ ! -s "$err" ] || fail "$1: stderr not empty: $(cat "$err")"
}

# reset_members: remove all member manifests.
reset_members() {
  rm -rf "$repo/apps" "$repo/libs"
  mkdir -p "$repo/apps" "$repo/libs"
}

# write_manifest <relpath> <content>
write_manifest() {
  mkdir -p "$(dirname "$repo/$1")"
  printf '%s\n' "$2" >"$repo/$1"
}

# --- check-members.sh ---
cm="bash scripts/check-members.sh"

reset_members
expect_rc "check-members (a) no manifests" 1 $cm
expect_err "check-members (a)" "no member manifests"

reset_members
write_manifest libs/a/Cargo.toml $'[package]\nname = "a"'
expect_rc "check-members (b) no [lints]" 1 $cm
expect_err "check-members (b)" "libs/a/Cargo.toml"

reset_members
write_manifest libs/a/Cargo.toml $'[package]\nname = "a"\nversion.workspace = true\nworkspace = true'
expect_rc "check-members (c) grep trap" 1 $cm

reset_members
write_manifest libs/a/Cargo.toml $'[package]\nname = "a"\n\n[lints]\nunsafe_code = "forbid"'
expect_rc "check-members (d) [lints] without workspace" 1 $cm

reset_members
write_manifest libs/a/Cargo.toml $'[package]\nname = "a"\n\n[lints]\nworkspace = true'
expect_rc "check-members (e) valid" 0 $cm
expect_no_err "check-members (e)"

reset_members
write_manifest libs/good/Cargo.toml $'[package]\nname = "good"\n\n[lints]\nworkspace = true'
write_manifest libs/bad/Cargo.toml $'[package]\nname = "bad"'
expect_rc "check-members (f) mixed" 1 $cm
expect_err "check-members (f)" "libs/bad/Cargo.toml"
if grep -F -q "libs/good/Cargo.toml" "$err"; then
  fail "check-members (f): stderr names the valid member: $(cat "$err")"
fi

reset_members
write_manifest "libs/my lib/Cargo.toml" $'[package]\nname = "my-lib"\n\n[lints]\nworkspace = true'
expect_rc "check-members (g) path with space" 0 $cm

# --- toml-has.sh ---
th="bash scripts/toml-has.sh"
f="$tmp/t.toml"

printf '%s\n' '[package]' 'name = "x"' 'workspace = true' '' '[lints]' 'unsafe_code = "forbid"' >"$f"
expect_rc "toml-has (h1) cross-table, wrong table" 1 $th "$f" lints workspace true
expect_rc "toml-has (h2) cross-table, right table" 0 $th "$f" package workspace true

printf '%s\n' '[lints]' 'workspace = true' >"$f"
expect_rc "toml-has (i) key in right table" 0 $th "$f" lints workspace true

printf '%s\n' '[lints.clippy]' 'workspace = true' >"$f"
expect_rc "toml-has (j) sub-table header" 1 $th "$f" lints workspace true

printf '%s\n' '[package.metadata.dist]' 'dist = false # note' >"$f"
expect_rc "toml-has (k) trailing comment" 0 $th "$f" package.metadata.dist dist false

expect_rc "toml-has (l) wrong arg count" 2 $th "$f" lints workspace

# --- license.sh ---
reset_members
printf '%s\n' 'placeholder' >"$repo/.license-header.tmpl"
expect_rc "license (m) zero-file guard" 1 bash scripts/license.sh --check
expect_err "license (m)" "no .rs files found"

echo ok
