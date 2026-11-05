#!/usr/bin/env bash
# Test `just new` and `just install` end to end with a throwaway app, zz-probe.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

lock_copy="$(mktemp)"
install_a=""
install_b=""
cp Cargo.lock "$lock_copy"

cleanup() {
  rm -rf apps/zz-probe apps/hello-zz-probe
  [ -z "$install_a" ] || rm -rf "$install_a"
  [ -z "$install_b" ] || rm -rf "$install_b"
  cp "$lock_copy" Cargo.lock
  rm -f "$lock_copy"
}
trap cleanup EXIT

fail() {
  echo "test-new: FAIL: $*" >&2
  exit 1
}

probe=apps/zz-probe
toml="$probe/Cargo.toml"

# (a) negative cases
if just new Bad_Name; then fail "just new Bad_Name should have failed"; fi
[ ! -e apps/Bad_Name ] || fail "just new Bad_Name created apps/Bad_Name"
if just new hello; then fail "just new hello should have failed"; fi
[ -z "$(git status --short apps/hello)" ] || fail "just new hello changed apps/hello"

for kw in type fn; do
  if just new "$kw"; then fail "just new $kw should have failed"; fi
  [ ! -e "apps/$kw" ] || fail "just new $kw created apps/$kw"
done

# names cargo or Windows reject, and names already used by a lib: nothing may be created
for bad in con test rsutils-core; do
  if just new "$bad"; then fail "just new $bad should have failed"; fi
  [ "$bad" = rsutils-core ] || [ ! -e "apps/$bad" ] || fail "just new $bad created apps/$bad"
done
[ ! -e apps/rsutils-core ] || fail "just new rsutils-core created apps/rsutils-core"

# license.sh: an empty-string argument is a usage error, not apply mode
rc=0
bash scripts/license.sh "" 2>/dev/null || rc=$?
[ "$rc" -eq 2 ] || fail "license.sh \"\" should exit 2, got $rc"

# (b) scaffold
just new zz-probe || fail "just new zz-probe failed"

# (c) generated files
bash scripts/toml-has.sh "$toml" lints workspace true || fail "[lints] workspace = true missing"
if bash scripts/toml-has.sh "$toml" package.metadata.dist dist false; then
  fail "dist = false leaked into the new app"
fi
if grep -F '[package.metadata.dist]' "$toml"; then fail "dist table header leaked"; fi
if grep -F 'template app' "$toml"; then fail "template comment leaked"; fi
grep -F 'name = "zz-probe"' "$toml" >/dev/null || fail 'name = "zz-probe" missing'
[ "$(sed -n 1p "$probe/src/main.rs")" = "// SPDX-License-Identifier: MIT" ] \
  || fail "main.rs lacks the SPDX header on line 1"

check_no_residue() {
  d="$1"
  for f in Cargo.toml src/main.rs tests/cli.rs; do
    if grep -qi template "$d/$f"; then fail "$d/$f mentions template"; fi
  done
  [ -n "$(tail -n 1 "$d/Cargo.toml" | tr -d ' \t\r')" ] || fail "$d/Cargo.toml ends with a blank line"
}
check_no_residue "$probe"

# (d) build and test the copy
cargo build -p zz-probe || fail "cargo build -p zz-probe failed"
cargo nextest run -p zz-probe || fail "cargo nextest run -p zz-probe failed"

# (e) install
install_a="$(mktemp -d)"
CARGO_INSTALL_ROOT="$install_a" just install zz-probe || fail "just install zz-probe failed"
ls "$install_a"/bin/zz-probe* >/dev/null 2>&1 || fail "install zz-probe left no bin/zz-probe*"

install_b="$(mktemp -d)"
CARGO_INSTALL_ROOT="$install_b" just install || fail "just install (all) failed"
ls "$install_b"/bin/zz-probe* >/dev/null 2>&1 || fail "install (all) left no bin/zz-probe*"
if ls "$install_b"/bin/hello* >/dev/null 2>&1; then fail "install (all) installed hello"; fi

# (e2) a name that starts with hello must not be mangled by the rename
hz=apps/hello-zz-probe
just new hello-zz-probe || fail "just new hello-zz-probe failed"
grep -q '^fn hello_zz_probe()' "$hz/tests/cli.rs" || fail "hello-zz-probe: identifier not renamed"
grep -q 'cargo_bin("hello-zz-probe")' "$hz/tests/cli.rs" || fail "hello-zz-probe: cargo_bin not renamed"
grep -q 'name = "hello-zz-probe"' "$hz/Cargo.toml" || fail "hello-zz-probe: package name not renamed"
check_no_residue "$hz"
cargo nextest run -p hello-zz-probe || fail "cargo nextest run -p hello-zz-probe failed"

# (f)
echo ok
