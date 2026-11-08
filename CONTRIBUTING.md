# Contributing

## Prerequisites

- Rust: installed through `rustup`; `rust-toolchain.toml` pins the toolchain
  and the right version is selected automatically.
- [`just`](https://github.com/casey/just)
- [`cargo-nextest`](https://nexte.st)
- [`cargo-deny`](https://github.com/EmbarkStudios/cargo-deny)
- [`typos`](https://github.com/crate-ci/typos)
- Go, only to install `addlicense`:
  `go install github.com/google/addlicense@v1.2.0`. The binary must be on
  `PATH` (`$(go env GOPATH)/bin`) for `just license`.
- [`cargo-shear`](https://github.com/Boshen/cargo-shear), optional: only for
  `just shear`, not part of `just check`.

CI uses the versions pinned in `.github/tool-versions`: nextest 0.9.146,
cargo-deny 0.20.2, typos 1.51.1, just 1.58.0, addlicense v1.2.0. Use the same
versions locally to get the same results.

On Windows the recipes assume a POSIX shell. Use Git Bash or WSL.

## Installing apps

`just install [name]` installs one app, or every app except those marked
`dist = false`.

## Running the gate

```
just check
```

This prints the tool versions used, then runs six gates in order:

1. `fmt`: `cargo fmt --all --check`.
2. `lint`: the policy script `scripts/check-members.sh`, then clippy with
   `-D warnings`, then a third step that lints the Lua module build, which no
   default build compiles:
   `cargo clippy -p pore-lua --no-default-features --features lua55,module --locked -- -D warnings`.
3. `test`: `cargo nextest` and doc tests, and `scripts/test-policy.sh`.
4. `deny`: `cargo deny check`. It fetches the RustSec advisory database, so it
   needs network access; on an offline machine this gate fails.
5. `typos`: spell check.
6. `license`: every `.rs` file under `apps/` and `libs/` must carry the
   licence header.

CI runs `just check` on Linux, macOS and Windows for pushes to `main` and for
pull requests. `just shear` (cargo-shear, unused dependencies) is separate and is
not part of `check`.

## Licence headers

Every `.rs` file under `apps/` and `libs/` (the only files
`scripts/license.sh` covers) starts with `// SPDX-License-Identifier: MIT`. The header text
is in `.license-header.tmpl`. Run `bash scripts/license.sh` to add missing
headers, and `bash scripts/license.sh --check` (what `just license` runs) to only
check.

## Releases

See [RELEASING.md](RELEASING.md).
