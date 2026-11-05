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

## Adding an app

```
just new <name>
```

This copies the template app `apps/hello` to `apps/<name>`, renames it, and
removes the `dist = false` setting so the new app is distributable. The name
must match `^[a-z][a-z0-9-]*$`, `apps/<name>` must not already exist, and the
name (with `-` read as `_`) must not be a Rust keyword. `libs/<name>` must not
exist either, and names that cargo or Windows reject (`test`, `build`, `deps`,
`examples`, `incremental`, `con`, `prn`, `aux`, `nul`, `com1`..`com9`,
`lpt1`..`lpt9`) are refused.

After `just new <name>`:

- edit `description` in the new `Cargo.toml`, and the doc comment and the
  greeting in `src/main.rs`;
- commit the resulting `Cargo.lock` change (the new crate is added to the
  lock, and `just check` runs with `--locked`).

`just install [name]` installs one app, or every app except those marked
`dist = false`.

## Running the gate

```
just check
```

This runs six gates in order, then prints the tool versions used:

1. `fmt`: `cargo fmt --all --check`.
2. `lint`: the policy script `scripts/check-members.sh`, then clippy with
   `-D warnings`.
3. `test`: `cargo nextest`, doc tests, and `scripts/test-new.sh` (which tests
   `just new`).
4. `deny`: `cargo deny check`.
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
