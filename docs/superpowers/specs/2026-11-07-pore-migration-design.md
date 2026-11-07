# Moving pore into rsutils: design

Date: 2026-11-07. Status: draft for owner approval. Reviewed: builder check, then an adversarial panel (one solo pass plus three agy rounds, the last one clean).

## Intent

The owner wants every binary they maintain in one repository. `pore`, a full-text search CLI
(currently at `https://github.com/ckir/pore`, v0.3.0), moves into this workspace and the old repository
is archived. The owner uses `pore-lua` from Lua, so the Lua module moves too.

## Goals

- All four pore crates live in this workspace and pass `just check` on Linux, macOS and Windows CI.
- pore's commit history (88 commits, including the original author's) is preserved, so `git log` and
  `git blame` on pore code work here after the old repository is archived.
- pore meets this repository's written bar: edition 2024, workspace lints (`unsafe_code = "forbid"`,
  clippy pedantic, `-D warnings`), licence headers, cargo-deny.
- The Lua module's loadable build (`--no-default-features --features lua55,module`) is checked by the gate.
- pore's version keeps moving forward: the workspace becomes 0.4.0.

## Non-goals

- No functional change to pore's CLI, JSON output, config file or Lua API.
- No rewiring of pore onto `libs/rsutils-core`.
- No release in this change. cargo-dist setup waits for the first release PR, as `RELEASING.md` already says.
- No port of pore's GitHub Pages site, release workflow or README-generation workflow.

## Anti-goals (would be a failure even if CI is green)

- Crate-level or workspace-level lint `allow`s, or loosening any rsutils gate to fit pore.
- `unsafe` code anywhere, including tests.
- Losing pore's history by squash-merging the PR.
- Archiving `ckir/pore` before the PR is merged and green on all three systems.
- Dropping the original author's MIT copyright notice.

## Approaches considered

1. **One complete PR, history kept** (chosen). Import history, then adapt everything in the same PR.
2. **Staged**: PR 1 passes the gate with crate-level `#![allow(clippy::pedantic)]`, later PRs pay down
   the debt. agy's first pick; it conceded once the debt was measured at 137 warnings, mostly mechanical.
   Rejected because it leaves pore below the repo's bar with no forcing date.
3. **Fresh copy, no history**: simpler, but blame only survives in an archived repo. Rejected.

Chosen by the owner after an agy consult and one negotiation round that ended ALIGNED.

## Decided

### Layout

| pore path   | rsutils path        | package name  | notes |
|-------------|---------------------|---------------|-------|
| `pore-bin/` | `apps/pore/`        | `pore`        | the binary; distributable (no `dist = false`) |
| `pore-core/`| `libs/pore-core/`   | `pore-core`   | |
| `macros/`   | `libs/pore-macros/` | `pore-macros` | renamed: `macros` is too generic for a shared workspace |
| `pore-lua/` | `libs/pore-lua/`    | `pore-lua`    | cdylib; keeps its Lua-version features |

`pore-bin/pore.example.toml` moves with it (a test reads it via `CARGO_MANIFEST_DIR`).

### History import

- Rewrite a fresh clone of pore with `git filter-repo`. Only the `master` branch is imported:
  `gh-pages` and every other ref stay behind (call: generated HTML has no place here). The filter keeps
  the four crate directories plus `README.md`, `CHANGELOG.md` and `LICENSE`, and renames them per the table
  and the list below, so their blame survives. Root files that would collide with files already in rsutils
  (`typos.toml`, `.config/nextest.toml`, `Cargo.toml`, `.gitignore`) are NOT in the path set. Their
  settings are applied by hand in a later commit (call: avoids conflicts in the unrelated-history merge). Delete all pore tags (`v0.1.0`..`v0.3.0`, `v0.2.1-bump`) from the
  rewritten clone before merging, so they never enter this repository's tag namespace.
- Merge into a feature branch with `--allow-unrelated-histories`.
- Known consequence, accepted: the imported pre-merge commits are for `git log` and `git blame`, not for
  building. Their manifests still use pore's old relative paths (for example `macros = { path = "../macros" }`
  in `pore-core/Cargo.toml:14`), and they carry no rsutils workspace manifest, so `cargo build` fails on
  any of them. Rewriting manifest text across 88 commits is not worth the risk. To build or bisect
  pre-move code, use the archived `ckir/pore`, whose history builds as it always did.
- The PR is merged with a **merge commit** (allowed on `ckir/rsutils`; earlier PRs were squashed, and a
  squash would discard the imported history).

### What comes across from pore's root, and what doesn't

- `README.md` -> `apps/pore/README.md`, with badges and links pointing at `ckir/rsutils`.
- `LICENSE` (MIT, "Copyright (c) 2021 Steven Arcangeli") -> `apps/pore/LICENSE` through filter-repo, then
  copied by hand into `libs/pore-core/`, `libs/pore-macros/` and `libs/pore-lua/`, so the original notice
  travels with each crate (an MIT condition).
- `CHANGELOG.md` -> `apps/pore/CHANGELOG.md`, frozen as pore's history up to 0.3.0, with a note that later
  changes are in the root `CHANGELOG.md`.
- `.config/nextest.toml`: its `[profile.default]` settings (`fail-fast = false`, slow-timeout) move to a
  new root `.config/nextest.toml`. The `ci` profile is dropped because rsutils CI does not use it.
- `typos.toml`: the `ser = "ser"` word moves into the root `typos.toml`.
- Dropped (they stay readable in the archived repository): `.github/` (all three workflows and
  `update_readme.py`), `release.toml`, `pore-bin/release.toml`, `docs/`, `CONTRIBUTING.md`, `ROADMAP.md`,
  `.watch-ci.json`, `.claude/`, `.qwen/`, `.serena/`, pore's `Cargo.toml` and `.gitignore`.

### Adapting to rsutils

- Every pore manifest inherits `version`, `edition`, `license`, `repository` and `rust-version` from
  `[workspace.package]`, and sets `publish = false` and `[lints] workspace = true`.
- `authors` is NOT inherited. The workspace value names only the rsutils owner, and pore's crates
  declare no authors today. Each pore crate sets `authors = ["Steven Arcangeli", "Costas Kirgoussios"]`
  (call: credits the original author in the metadata, as the LICENSE does).
- Each pore crate gets a `description`. For `apps/pore` it must be exactly
  `pore — full-text search powered by Tantivy`. `#[command(about)]` (`pore-bin/src/args.rs:23`) reads the
  crate description, and `pore --help` currently prints that same line. The builder confirms the first
  line of `pore --help` is unchanged.
- Third-party dependencies move into `[workspace.dependencies]` with the features pore uses today, and
  members refer to them with `.workspace = true`. Pore's existing features are kept as they are. A member
  can add features to a workspace dependency but cannot remove them, so the workspace entry for **mlua
  carries no features at all** (call). Each member declares exactly the mlua features it uses today:
  - pore-core: `async`, `macros`;
  - pore-lua: `async`, `macros`, `serialize`, with its Lua-version, `vendored` and `module` feature table
    unchanged;
  - pore: `async`, `macros`, `lua55`, `vendored`.
  Otherwise the Lua-module gate would stop testing a build without `vendored`. Other dependencies whose
  features differ between members follow the same rule.
- Edition 2024: `pore-core/src/location.rs:115` becomes `Some(&Reverse(mut next_pos))` (verified to
  compile).
- Edition 2024 makes `std::env::set_var` / `remove_var` unsafe. They are used only in tests
  (`pore-bin/src/paths.rs:61-103`, `pore-bin/src/config.rs:225`). Refactor so the lookup takes its
  environment as a parameter. For example, `resolve_base_dir` delegates to a function taking a getter
  `impl Fn(&str) -> Option<OsString>`, and `load_config` gets a variant taking the config directory. The
  tests then pass in-memory values. Behaviour (HOME, then USERPROFILE, then the XDG variable; the error
  naming every variable consulted) is unchanged and stays pinned by the existing tests
  (`tests::resolution_order_and_error` and the config tests).
- Lints: all 137 pedantic/debug warnings are fixed in code. The only permitted exceptions are item-level
  `#[allow]`s with a reason comment, on:
  - `clippy::struct_excessive_bools` on the three option/config structs it fires on (measured):
    `pore-bin/src/args.rs:81`, `pore-bin/src/config.rs:38` and `FileIndexOptions` at
    `pore-core/src/file.rs:97`. They mirror CLI flags and config keys, which are naturally booleans;
  - `clippy::too_many_lines` on the two functions it fires on (measured): `macros/src/lib.rs:12`
    (125 lines) and `pore-core/src/file.rs:542` (107 lines).
  (Paths are pore's current paths, measured with clippy pedantic on 2026-11-07.)
  Any other `allow` the builder believes is needed goes back to the owner before it lands.
- cargo-deny: add `"Zlib"` to the licence allowlist (needed for `foldhash` 0.1.5 and 0.2.0, pulled in
  through tantivy and jaq-json; verified rejected today). pore has never committed a `Cargo.lock`
  (its `.gitignore` excludes it), so the first resolve here is fresh. Measured on 2026-11-07 against a
  fresh `cargo generate-lockfile` with Zlib allowed: `advisories ok, licenses ok, sources ok`. Bans failed
  only on wildcard path dependencies, because pore's crates are not `publish = false` yet; the manifest
  change above fixes that. Duplicate-version findings are warnings under `multiple-versions = "warn"`. If a
  new advisory or yanked crate appears by implementation time, a `cargo update -p` within the existing
  version requirement is allowed. An `ignore` entry in `deny.toml` is not: raise it with the owner.
- Licence headers: `bash scripts/license.sh` adds the SPDX header to every pore `.rs` file.
- `Cargo.lock` regenerated and committed.
- The package name stays `pore`. The index cache directory is keyed on `CARGO_PKG_NAME`
  (`pore-bin/src/main.rs:188`), so a rename would orphan users' existing indexes. The crate version is
  stored in index metadata (`pore-core/src/common.rs:68`, `pore-core/src/file.rs:195`), but it is only
  displayed, never compared, so moving to 0.4.0 does not invalidate existing indexes.
- `#[mlua::lua_module]` compiles under `unsafe_code = "forbid"` (verified), so `pore-lua` needs no
  exception.

### Lua module gate

`just lint` gains a step that lints the loadable module build:
`cargo clippy -p pore-lua --no-default-features --features lua55,module --locked -- -D warnings`.
The default workspace build does not compile the `#[mlua::lua_module]` entry point (it sits behind
`#[cfg(feature = "module")]`, `pore-lua/src/lib.rs:49`). Without this step it could break, or collect
lint violations, silently. Using clippy rather than `cargo check` means the module-only code meets the
same lint bar. Measured: pedantic clippy on that feature set reports 80 warnings today, which the
lint work above must also clear.

### Version and docs

- `[workspace.package].version` becomes `0.4.0` in this PR, so pore never goes backwards. `RELEASING.md`
  and the root `CHANGELOG.md` say that 0.4.0 continues pore's numbering, and that `hello` and
  `rsutils-core` (never released) move with it.
- Root `CHANGELOG.md` `[Unreleased]` gets a `**pore:**` entry under `### Added` for the move, following
  the file's conventions.
- `apps/pore/README.md` gets an install-from-source section:
  `cargo install --locked --git https://github.com/ckir/rsutils pore`. The package name is required now
  that the repository holds several packages.
- Root `README.md` lists `apps/pore` and the pore libraries. `ROADMAP.md`'s "first real file utilities"
  item is updated. `CONTRIBUTING.md` documents the Lua module gate.
- The `TODO.md` item "When the first distributable app lands, generate and commit the release
  configuration (cargo-dist)" now applies. It stays open, to be done in the first release PR.

### Retiring `ckir/pore` (after the PR is merged and green)

A separate step, done with the owner's go-ahead:
1. Push a final commit to `ckir/pore` `master` whose README starts with a notice pointing to
   `https://github.com/ckir/rsutils/tree/main/apps/pore`.
2. Archive the repository on GitHub. Existing releases, tags and the Pages site stay readable, but the
   Pages docs are frozen at 0.3.0. The new README section is the current documentation.

## Constraints

- Toolchain pinned at 1.99.1 (`rust-toolchain.toml`). CI runs `just check` on ubuntu, macos and windows
  under bash.
- pore's own CI only ever ran on Linux, so this is pore's first run on macOS and Windows. The vendored Lua
  build needs a C compiler on all three; the hosted runners have one.
- rsutils CI has no build cache (`setup-go` runs with `cache: false`, and there is no Rust cache step) and
  a 30-minute job timeout (`.github/workflows/ci.yml:23`). `scripts/test-new.sh:97` runs `just install`
  for every distributable app, so once pore is distributable `just test` also does a release build of
  pore. That is intended coverage of `just install` and stays; its cost counts toward the durations below. pore adds tantivy and a vendored Lua C build,
  compiled for clippy, nextest, doc tests and the module check. The builder records the job durations of
  the first CI run on each system in the PR. If any job comes within 5 minutes of the timeout, raise it
  with the owner (add a cache or raise the timeout) rather than changing CI unasked.
- `git filter-repo` is not installed on this machine. Installing it is part of the implementation.

## Left to the builder

- Commit breakdown inside the PR (e.g. import, manifests/layout, edition fixes, env refactor, lints,
  headers/deny/lock, docs). Every commit should build where practical; CI gates the tip.
- Exact signatures for the env-injection refactor, within the shape above.
- If pore's tests fail **deterministically** on macOS or Windows (pore's CI only ever ran on Linux): a
  test that is non-portable by itself (e.g. Unix path literals such as `/home` in `paths.rs` and
  `config.rs`) is made portable, keeping what it asserts. A `cfg`-gate that drops coverage is not allowed.
  A genuine product bug on that platform is reported to the owner before it is fixed, because fixing it is
  a functional change. Push the branch to CI early, right after the edition and lint commits, so these
  show up before the docs work.
- How to treat a Windows-only test flake, if one appears (pore's dropped `ci` profile used
  `retries = 2`). Prefer fixing the cause; if a retry is needed, raise it with the owner.
- If the module-build clippy step fails on macOS or Windows for platform reasons (clippy does not link,
  but build scripts such as mlua-sys's still run), report it and propose scoping the step to Linux. Don't drop the step silently.

## Stand-downs

- `REJECTED`: agy panel round 2 re-raised the `test-new.sh:97` release build of pore. It is already in
  Constraints and counted toward the CI-duration check.
- `REJECTED`: agy panel round 2 said a `just install` failure in `test-new.sh` hides which app failed.
  `scripts/test-new.sh:97` does not redirect `just install`'s output, so cargo's error, which names the
  failing package, reaches the CI log before the cleanup trap runs.

- `REJECTED`: agy panel round 1 re-raised "0.4.0 on main contradicts `RELEASING.md:28`". It was already
  settled: the owner chose 0.4.0, and this PR passes the gate before it merges, which is what that line
  requires. The document states the version reasoning in "Version and docs".
- `DISCARDED-BELOW-FLOOR`: agy panel round 3 noted that `build_search_config` (`pore-bin/src/args.rs:237-335`)
  is just under clippy's 100-line limit. Unreachable as a defect, because clippy `-D warnings` in
  `just lint` fails the PR if the function grows past the limit, and the exception list stays closed.
