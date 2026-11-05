# rsutils Monorepo Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the workspace, shared lib, template app, quality gates, CI, licence headers and community docs described in the spec, so adding the Nth CLI is `just new <name>`.

**Architecture:** Cargo workspace with `apps/*` (binaries) and `libs/*` (never published). One lib, `rsutils-core`, and one template app, `hello`. All gates are `just` recipes; CI runs those same recipes on three OSes. The release workflow is deferred until the first distributable app exists (spec: `dist` errors on a workspace with none).

**Tech Stack:** Rust 1.99.1 (pinned), clap (derive), anyhow, log + env_logger, assert_cmd + predicates (dev), just, cargo-nextest, cargo-deny, typos, addlicense (Go), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-05-monorepo-scaffold-design.md`

## Global Constraints

- Licence: `license = "MIT"`; root `LICENSE` is hand-written MIT, copyright holder `Costas Kirgoussios`, year 2026.
- One workspace-wide version in `[workspace.package]`, initial `0.1.0`; every crate inherits it. Lib crates set `publish = false`.
- Layout: members `apps/*` and `libs/*`. Repository: `https://github.com/ckir/rsutils`.
- `Cargo.lock` is committed (the workspace ships binaries and installs use `--locked`); `.gitignore` must not ignore it.
- Toolchain: `rust-toolchain.toml` pins exactly `1.99.1`; `rust-version = "1.99"` in `[workspace.package]`. Components: rustfmt, clippy.
- Every member has `[lints] workspace = true`; clippy runs with warnings denied.
- `just check` = six gates: fmt, clippy, tests (nextest plus doc tests), deny, typos, license. As recipes: `fmt`, `lint` (policy script plus clippy), `test` (nextest plus doc tests), `deny`, `typos`, `license`. `cargo-shear` is a separate non-blocking `just shear`, not in `check`.
- `apps/hello` has `[package.metadata.dist] dist = false`. No `dist plan`, release workflow, or `dist` config is committed in this plan.
- Licence header: template file passed with `addlicense -f`, never `-s`; the template text must contain `SPDX-License-Identifier` (detection reads the first 1000 bytes). Pinned install: `go install github.com/google/addlicense@v1.2.0`. `addlicense` also rewrites `.toml`, `.yml` and `.sh` files when given a directory (`main.go:336-340`, source-verified), so the recipe never passes directories: `scripts/license.sh [--check]` feeds only `.rs` files listed by `git ls-files` (so `target/` is excluded), fails if it finds none, and runs `addlicense -f .license-header.tmpl` on them.
- Tool versions live in one file, `.github/tool-versions`, bumped by hand. Recorded values: nextest 0.9.146, cargo-deny 0.20.2, typos 1.51.1, just 1.58.0, addlicense v1.2.0.
- justfile sets its shell explicitly (including a Windows shell). Windows contributors need Git Bash or WSL for `just new`.
- Third-party Actions in hand-written workflows are pinned to commit SHAs. Dependabot covers Cargo and GitHub Actions only.
- Nothing is published; contact addresses are placeholders `TODO-CONTACT` listed in `TODO.md`.
- Commits end with: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

Spec-implied inputs no task would otherwise test; each has a test in the owning task.

1. `hello -v -q` (conflicting flags): clap usage error, exit code 2, no panic. (Task 3)
2. `hello -vvvvvv` (excess verbosity): saturates at debug level, no overflow panic. (Task 2)
3. `hello ""` (empty name): falls back to `world`. (Task 3)
4. Output to a closed pipe (`hello | head -0`): no panic, no error message. (Task 2: `emit` ignores `BrokenPipe`)
5. Non-UTF-8 argument on Unix: clap error, exit code 2, no panic. (Task 3, Unix-only test)

## File Structure

- `Cargo.toml`, `rust-toolchain.toml`, `rustfmt.toml`, `deny.toml`, `typos.toml`, `LICENSE`, `.gitattributes`, `.license-header.tmpl`: workspace config.
- `libs/rsutils-core/src/{lib,cli,output,run}.rs`: shared lib, one responsibility per file.
- `apps/hello/src/main.rs`, `apps/hello/tests/cli.rs`: template app.
- `justfile`, `scripts/{license,toml-has,check-members,test-new}.sh`: gates and scaffolding.
- `.github/workflows/ci.yml`, `.github/dependabot.yml`, `.github/tool-versions`, `.github/ISSUE_TEMPLATE/*`, `.github/pull_request_template.md`.
- Root docs: `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, `ROADMAP.md`, `TODO.md`, `RELEASING.md`.

---

### Task 1: Workspace skeleton and toolchain pin

**Files:**
- Create: `Cargo.toml`, `rust-toolchain.toml`, `rustfmt.toml`, `LICENSE`, `.gitattributes`
- Modify: `.gitignore` (already ignores `target`; leave as is)

**Interfaces:**
- Produces: workspace with `members = ["libs/*"]` for now (**measured on Cargo 1.99.1: a member glob that matches no crate, even an existing directory without a `Cargo.toml`, makes every cargo command exit 101**, so `apps/*` is added in Task 3 together with `hello`; the final value is `["apps/*", "libs/*"]`), `resolver = "3"`; `[workspace.package]` (version `0.1.0`, edition `2024`, `license = "MIT"`, `repository`, `rust-version = "1.99"`, `authors = ["Costas Kirgoussios"]`); `[workspace.dependencies]` for clap (features `derive`), anyhow, log, env_logger, assert_cmd, predicates; `[workspace.lints.rust]` (`unsafe_code = "forbid"`, `missing_debug_implementations = "warn"`) and `[workspace.lints.clippy]` (`all = "warn"`, `pedantic = "warn"` with priority -1). No release profile yet (deferred with `dist`).

- [ ] **Step 1: Create the five files** per the Produces block. `.gitattributes` contains `* text=auto eol=lf` so shell scripts, the `justfile` and `.license-header.tmpl` are never checked out with CRLF line endings on Windows runners (a CRLF shell script fails with `\r: command not found`). `LICENSE` is the standard MIT text, `Copyright (c) 2026 Costas Kirgoussios`. `rust-toolchain.toml`: `channel = "1.99.1"`, `components = ["rustfmt", "clippy"]`.
- [ ] **Step 2: Verify the toolchain pin (do not run cargo against the workspace yet; it has no members)**

Run: `rustc --version`
Expected: starts with `rustc 1.99.1` (confirms `rust-toolchain.toml` is honoured). The workspace itself is first verified in Task 2 Step 4.
- [ ] **Step 3: Commit** `chore: add workspace skeleton, toolchain pin and MIT licence`

### Task 2: `rsutils-core` library

**Files:**
- Create: `libs/rsutils-core/Cargo.toml`, `libs/rsutils-core/src/lib.rs`, `src/cli.rs`, `src/output.rs`, `src/run.rs`
- Test: unit tests inside each module (`#[cfg(test)]`)

**Interfaces:**
- Produces (exact):
  - `cli::Verbosity`: `#[derive(clap::Args, Debug, Clone, Copy, Default)]` with `-v/--verbose` (count, global) and `-q/--quiet` (global, `conflicts_with = "verbose"`).
  - `cli::Level`: `enum { Quiet, Normal, Verbose, Debug }`, derives `Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord`.
  - `Verbosity::level(&self) -> Level`: quiet → `Quiet`; 0 → `Normal`; 1 → `Verbose`; 2 or more → `Debug`.
  - `Verbosity::init_logging(&self)`: configures `env_logger` from `level()`; uses `try_init` and ignores the error, so calling it twice never panics.
  - `output::info(v: &Verbosity, msg: impl std::fmt::Display)`: stdout, suppressed when `Quiet`. `output::warn(msg: impl Display)`: stderr, always.
  - `output::emit<W: std::io::Write>(w: &mut W, msg: &dyn std::fmt::Display) -> std::io::Result<()>` (`pub(crate)`): writes `msg` plus newline; maps `ErrorKind::BrokenPipe` to `Ok(())`.
  - `run::format_error(e: &anyhow::Error) -> String` returns `"error: {e:#}"`. `run::run(f: impl FnOnce() -> anyhow::Result<()>) -> std::process::ExitCode`: on `Err` prints `format_error` to stderr and returns `ExitCode::FAILURE`.
  - `lib.rs` re-exports `anyhow::{Context, Result}`.
- `Cargo.toml`: `publish = false`, `[lints] workspace = true`, inherits workspace package fields, depends on clap, anyhow, log, env_logger.

- [ ] **Step 1: Write failing tests** (names and assertions):
  - `cli::tests::level_maps_flags`: parse a test `#[derive(clap::Parser)]` wrapper with args `[]`, `["-v"]`, `["-vv"]`, `["-q"]`; assert `Normal`, `Verbose`, `Debug`, `Quiet`.
  - `cli::tests::excess_verbosity_saturates`: parse `["-vvvvvv"]`; assert `Level::Debug` (Review Focus 2).
  - `cli::tests::quiet_conflicts_with_verbose`: parse `["-q", "-v"]`; assert `Err` with `ErrorKind::ArgumentConflict`.
  - `cli::tests::init_logging_twice_is_safe`: call twice; assert no panic.
  - `output::tests::emit_writes_line`: write to a `Vec<u8>`; assert bytes equal `b"hi\n"`.
  - `output::tests::emit_ignores_broken_pipe`: writer that returns `BrokenPipe`; assert `emit` returns `Ok(())` (Review Focus 4). Another writer returning `PermissionDenied`; assert `Err`.
  - `run::tests::format_error_includes_chain`: `anyhow!("inner").context("outer")`; assert result is `"error: outer: inner"`.
- [ ] **Step 2: Run to verify failure**

Run: `cargo nextest run -p rsutils-core`
Expected: FAIL (items undefined).
- [ ] **Step 3: Implement** the Produces block in the four source files. `Level` derives ordering so `output::info` can test `level() > Quiet`.
- [ ] **Step 4: Run to verify pass**

Run: `cargo metadata --no-deps --format-version 1 >/dev/null && cargo nextest run -p rsutils-core && cargo test --doc -p rsutils-core && cargo clippy -p rsutils-core --all-targets -- -D warnings`
Expected: all tests pass, doc tests ok, clippy clean.
- [ ] **Step 5: Commit** `feat(core): add rsutils-core with verbosity, output and error helpers` (include the generated `Cargo.lock`)

### Task 3: `hello` template app

**Files:**
- Create: `apps/hello/Cargo.toml`, `apps/hello/src/main.rs`
- Modify: root `Cargo.toml`: change `members` from `["libs/*"]` to `["apps/*", "libs/*"]` (first thing in this task, before any cargo command)
- Test: `apps/hello/tests/cli.rs`

**Interfaces:**
- Consumes: `rsutils_core::{cli::Verbosity, output::info, run::run, Result}`.
- Produces: binary `hello`. `fn greeting(name: Option<&str>) -> String`: `None` or empty string → `"Hello, world!"`; otherwise `"Hello, {name}!"`. CLI: `hello [NAME] [-v|-q]`.
- `Cargo.toml`: `publish = false`, `[lints] workspace = true`, inherits package fields, depends on `rsutils-core` (path), clap; dev-depends on assert_cmd and predicates. Contains `[package.metadata.dist]` with `dist = false` as its **last** table (a comment in the file says why: `just new` deletes from that header to end of file).

- [ ] **Step 1: Write failing tests** in `tests/cli.rs` (assert_cmd):
  - `prints_default_greeting`: no args; stdout is exactly `Hello, world!\n`, exit 0.
  - `prints_named_greeting`: `Ada`; stdout `Hello, Ada!\n`.
  - `empty_name_falls_back_to_world`: `""`; stdout `Hello, world!\n` (Review Focus 3).
  - `quiet_suppresses_output`: `-q`; stdout empty, exit 0.
  - `verbose_and_quiet_conflict`: `-v -q`; exit code 2, stderr contains `cannot be used with` (Review Focus 1).
  - `non_utf8_argument_is_a_clean_error` (`#[cfg(unix)]`): pass `OsStr::from_bytes(b"\xff")`; exit code 2, stderr non-empty (Review Focus 5).
  - Unit test `greeting_cases` in `main.rs`: the three branches above.
- [ ] **Step 2: Run to verify failure**

Run: `cargo nextest run -p hello`
Expected: FAIL (binary missing).
- [ ] **Step 3: Implement** `main.rs`: clap `Parser` struct with `name: Option<String>` and `#[command(flatten)] verbosity: Verbosity`. In `main`, call `Cli::parse()` **before** `run(...)` (not inside the closure), so clap's own usage errors exit with code 2; `run` only wraps the work after parsing, which then calls `verbosity.init_logging()` and `info`. Returning clap errors through `run` would give exit code 1 and fail the tests above.
- [ ] **Step 4: Run to verify pass**

Run: `cargo nextest run --workspace && cargo clippy --workspace --all-targets -- -D warnings`
Expected: all pass, clippy clean.
- [ ] **Step 5: Commit** `feat(hello): add hello template app` (include the root `Cargo.toml` change and the updated `Cargo.lock`; `git status --short` must be clean afterwards)

### Task 4: Licence header gate

**Files:**
- Create: `.license-header.tmpl`, `scripts/license.sh`
- Modify: every `.rs` file under `apps/` and `libs/` (headers added by the tool)

**Interfaces:**
- Produces: template text `SPDX-License-Identifier: MIT` (single line, no template variables).
- Produces: `bash scripts/license.sh [--check]`, used verbatim later by `just license` (`--check`). It collects the `.rs` files with `git ls-files -z --cached --others --exclude-standard -- 'apps/*.rs' 'libs/*.rs'` (so `target/` is excluded because it is ignored, and no `find`/`xargs` is needed, which avoids the Windows `find.exe` and BSD-vs-GNU `xargs` differences), reads them into a bash array with a `while IFS= read -r -d ''` loop (works on macOS bash 3.2), **exits 1 with a message if zero files are found** (so the gate can never pass vacuously), then runs `addlicense [-check] -f .license-header.tmpl "${files[@]}"`. Only `.rs` files are ever passed, so `Cargo.toml` and workflow files are never touched. The script first does `cd "$(git rev-parse --show-toplevel)"`, so the relative template path `.license-header.tmpl` and the `apps`/`libs` pathspecs resolve the same way whatever directory it is run from.

- [ ] **Step 1: Check addlicense** (already installed at `~/.local/bin/addlicense`; do not run `go install` locally, the pinned `go install github.com/google/addlicense@v1.2.0` is for CI): confirm `addlicense -h` runs (`go install` writes to `$(go env GOPATH)/bin`, which may not be on `PATH`; if `addlicense` is not found, add that directory to `PATH`). If a different binary is already on `PATH`, note its version in a `.github/tool-versions` comment.
- [ ] **Step 2: Write `scripts/license.sh` and the failing check**

Run: `bash scripts/license.sh --check`
Expected: FAIL, non-zero exit, listing the `.rs` files from Tasks 2-3.
- [ ] **Step 3: Apply headers**

Run: `bash scripts/license.sh`
Then confirm `git status --short` lists only `.rs` files (no `Cargo.toml`), and confirm the first line of `apps/hello/src/main.rs` is `// SPDX-License-Identifier: MIT` (the spec requires the builder to verify the rendered output).
- [ ] **Step 4: Verify pass and idempotence**

Run: `bash scripts/license.sh --check`, then `bash scripts/license.sh` again; then the zero-file guard: `(cd "$(mktemp -d)" && git init -q && bash "$OLDPWD/scripts/license.sh" --check)`.
Expected: check exits 0; the second apply changes no file (`git status --short` unchanged); the zero-file run exits non-zero with a "no .rs files" message.
- [ ] **Step 5: Commit** `chore: add SPDX licence header template and headers`

### Task 5: Gates in the justfile, policy scripts and tool config

**Files:**
- Create: `justfile`, `deny.toml`, `typos.toml`, `scripts/toml-has.sh`, `scripts/check-members.sh`, `.github/tool-versions`
- Test: `scripts/check-members.sh` is itself the check; its negative case is Step 1.

**Interfaces:**
- Produces: recipes `check`, `fmt`, `lint`, `test`, `deny`, `typos`, `license`, `shear`, `new <name>`, `install [name]`.
  - `check` runs, in order: `fmt`, `lint`, `test`, `deny`, `typos`, `license`, and prints the tool versions it ran: from `--version` for nextest, deny, typos and just, and for addlicense (which has no version flag) the pinned value read from `.github/tool-versions`.
  - `fmt` = `cargo fmt --all --check`. `lint` = `scripts/check-members.sh` then `cargo clippy --workspace --all-targets -- -D warnings`. `test` = `cargo nextest run --workspace` then `cargo test --doc --workspace`. `deny` = `cargo deny check`. `typos` = `typos`. `license` = `bash scripts/license.sh --check`. `shear` = `cargo shear` (not in `check`).
  - `install [name]`: with a name, `cargo install --locked --path apps/<name>`; with none, loops over `apps/*` skipping crates where `scripts/toml-has.sh "$app/Cargo.toml" package.metadata.dist dist false` succeeds, with `$app` being each directory matched by `apps/*` (already `apps/<name>`, so `"$app/Cargo.toml"` is the manifest path).
- `scripts/toml-has.sh <file> <table> <key> <value>`: exit 0 only if the TOML table `[<table>]` in `<file>` contains the line `<key> = <value>` (awk, section-aware: it only matches inside that table, so `version.workspace = true` under `[package]` never satisfies `lints workspace true`). Exit 1 otherwise. Shared by `check-members.sh`, `install` and `test-new.sh`.
- `scripts/check-members.sh`: for every `apps/*/Cargo.toml` and `libs/*/Cargo.toml`, exit 1 and name the file unless `scripts/toml-has.sh <file> lints workspace true` succeeds.
- `deny.toml`: licence allow-list `MIT`, `Apache-2.0`, `Unicode-3.0`, `BSD-3-Clause`, `ISC` (extend only for a real dependency that needs it); advisories deny; wildcards deny with `allow-wildcard-paths = true` under `[bans]` so workspace path dependencies pass (reported by a scratch run; run `cargo deny init` to see the current 0.20 schema and adapt key names).
- `typos.toml`: `[files]` with `extend-exclude = ["docs/superpowers/**", ".superpowers/**", "target/**"]` (the plan and spec quote the deliberate misspelling `recieve` and would otherwise fail `just typos`).
- `.github/tool-versions`: five `key=value` lines with **hyphen-free keys** `nextest`, `deny`, `typos`, `just`, `addlicense` and the versions from Global Constraints. The workflow's first step exports them as `NEXTEST_VERSION`, `DENY_VERSION`, `TYPOS_VERSION`, `JUST_VERSION`, `ADDLICENSE_VERSION` (names without hyphens, so `${{ env.X }}` expressions are valid).
- justfile first lines: `set shell := ["bash", "-euo", "pipefail", "-c"]` and `set windows-shell := ["bash", "-euo", "pipefail", "-c"]`. The builder confirms just 1.58 accepts both (just 1.58 is installed).

- [ ] **Step 1: Write the failing policy checks** (all three must exit 1 naming the file; delete the throwaway crate after each): (a) `libs/zz-bad/Cargo.toml` with no `[lints]` table; (b) `libs/zz-bad/Cargo.toml` with `version.workspace = true` under `[package]` and no `[lints]` (a grep for `workspace = true` would wrongly pass this one); (c) `libs/zz-bad/Cargo.toml` with `[lints]` present but no `workspace = true`. Run `bash scripts/check-members.sh` each time.
- [ ] **Step 2: Implement** the files in the Produces block.
- [ ] **Step 3: Run the full gate**

Run: `just check`
Expected: exit 0; output lists all six gates and the tool versions. If `cargo deny` reports a licence not in the allow-list, add it with a comment naming the crate.
- [ ] **Step 4: Verify `deny` and `typos` can fail.** (a) Temporarily add a misspelling (`recieve`) to `README.md`; `just typos` must exit non-zero. (b) Temporarily add `[bans]` with `deny = [{ name = "anyhow" }]` to `deny.toml`; `just deny` must exit non-zero. Revert both and rerun `just check` to confirm it passes again.
- [ ] **Step 5: Commit** `build: add justfile gates, deny/typos config and policy check`

### Task 6: `just new` scaffolding

**Files:**
- Modify: `justfile` (the `new` recipe body)
- Create: `scripts/test-new.sh`

**Interfaces:**
- Produces: `just new <name>` copies `apps/hello` to `apps/<name>`, replaces the crate and binary name `hello` with `<name>`, removes the `[package.metadata.dist]` table, and refuses (non-zero) if `apps/<name>` exists or `<name>` is not `^[a-z][a-z0-9-]*$`.
- `scripts/test-new.sh`: runs `just new zz-probe`, asserts `apps/zz-probe/Cargo.toml` contains `workspace = true` under `[lints]`, does not contain `dist = false`, that the generated `Cargo.toml` has no line containing `template app`, and that `apps/zz-probe/src/main.rs` starts with the SPDX line; runs `cargo build -p zz-probe` and then `cargo nextest run -p zz-probe` (the probe's own copied tests must compile and pass, which proves the identifier rename for a hyphenated name); then verifies `just install`: with `CARGO_INSTALL_ROOT` set to a temp dir, `just install zz-probe` must leave a `zz-probe` binary (`bin/zz-probe*`) in it, and with a second temp dir `just install` (no name) must install `zz-probe` but **not** `hello` (it is `dist = false`); always (trap) removes `apps/zz-probe` **and restores `Cargo.lock`** from a copy taken before the run, because building the probe adds it to `Cargo.lock` and a stale entry breaks later `--locked` commands. After the trap, `git status --short` must show no change to `Cargo.lock`.

- [ ] **Step 1: Write `scripts/test-new.sh`** per the Produces block, plus negative cases: `just new Bad_Name` exits non-zero; `just new hello` exits non-zero.
- [ ] **Step 2: Run to verify failure**

Run: `bash scripts/test-new.sh`
Expected: FAIL (recipe not implemented).
- [ ] **Step 3: Implement the `new` recipe** (POSIX shell). Portability rules: never use `sed -i` (differs between GNU and macOS); write `sed ... file > file.tmp && mv file.tmp file` instead. Name substitution (two steps, in this order, on `Cargo.toml`, `src/main.rs` and `tests/cli.rs`): first `s/hello(/<ident>(/g` where `<ident>` is `<name>` with `-` replaced by `_` (the test helper `fn hello()` and its call sites are Rust identifiers, and `fn zz-probe()` would not compile), then `s/hello/<name>/g` for everything else (package name, `cargo_bin("...")`, doc text). Removing the dist table: `apps/hello/Cargo.toml` keeps `[package.metadata.dist]` as its **last** table (a comment in the file says so), and the recipe deletes from the first comment line above it (`# The template app is never released`) to end of file with `sed '/^# The template app is never released/,$d'`, so the template-only comment does not leak into the new app. `test-new.sh` asserts the output has no `dist` key with `! scripts/toml-has.sh ... package.metadata.dist dist false`, and that the table header is gone.
- [ ] **Step 4: Run to verify pass**

Run: `bash scripts/test-new.sh && just check`
Expected: script ends `ok`; `git status --short` shows no leftover `apps/zz-probe`; check passes.
- [ ] **Step 5: Add `scripts/test-new.sh` to the `test` recipe** (not `lint`, so `just lint` and file watchers stay fast, and `just check` still has six gates) so CI exercises it, rerun `just check`, commit `feat: add just new app scaffolding`.

### Task 7: CI workflow and Dependabot

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/dependabot.yml`

**Interfaces:**
- Produces: workflow `ci` with a top-level `permissions: contents: read` (least privilege for `GITHUB_TOKEN`), on `push` to `main` and `pull_request` (never `pull_request_target`), plus `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }} }` so superseded PR runs are cancelled while every commit on `main` still runs to completion (a release tag needs a finished green run on its commit); matrix `ubuntu-latest`, `macos-latest`, `windows-latest` with `strategy.fail-fast: false` (a failing Linux job must not cancel the Windows run whose diagnostics are needed); steps: checkout, install the pinned toolchain (from `rust-toolchain.toml`), install nextest, deny, typos, just, addlicense at the versions in `.github/tool-versions`, run `just check` with `shell: bash`. After `go install` for addlicense, the workflow appends `$(go env GOPATH)/bin` to `$GITHUB_PATH` so `just license` finds it (whether runners already have it on `PATH` is unverified; the step is harmless either way). Third-party Actions are pinned to full commit SHAs, each with a `# vX.Y.Z` comment. Dependabot: two `updates` entries, `package-ecosystem: cargo` and `package-ecosystem: github-actions`, each with the required `directory: "/"` and `schedule.interval: weekly`.
- Release tags are only created from merged release PRs (documented in Task 8); the CI workflow does not run on tags.

- [ ] **Step 1: Resolve action SHAs.** The Actions used are exactly `actions/checkout`, `actions/setup-go` (for addlicense) and `taiki-e/install-action` (installs `cargo-nextest`, `cargo-deny`, `typos`, `just` at the pinned versions; its manifests for all four were confirmed with `gh api`). The Rust toolchain needs no Action: runners ship rustup and `rust-toolchain.toml` triggers the pinned install. Resolve each with `gh api repos/<owner>/<action>/commits/<tag> --jq .sha` for each Action used; record them in the workflow.
- [ ] **Step 2: Write the workflow and Dependabot file** per Produces. Read versions from `.github/tool-versions` in a first step (do not hard-code them twice). That step first validates every line that is not blank and not a `#` comment against `^(nextest|deny|typos|just|addlicense)=[A-Za-z0-9._-]+$` and fails the job on any other line (blank and comment lines are skipped and never exported), then appends the `*_VERSION` variables to `$GITHUB_ENV`, so a malformed or hostile line can never inject other variables.
- [ ] **Step 3: Validate locally**

Run: `gh workflow list` after push, or `actionlint .github/workflows/ci.yml` if available; otherwise `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"`.
Expected: parses with no errors. Also assert the Dependabot file locally: `python3 -c "import yaml; d=yaml.safe_load(open('.github/dependabot.yml')); assert d['updates'] and all(u.get('directory')=='/' and u.get('schedule',{}).get('interval')=='weekly' for u in d['updates']), d; print([u['package-ecosystem'] for u in d['updates']])"`; expected output `['cargo', 'github-actions']`.
- [ ] **Step 4: Push a branch and open a PR** (only with the owner's go-ahead for pushing; **skipped during automated execution: record it as pending for the owner and do not push**); expect all three matrix jobs green. Also have the Windows job print `uname -o` and `bash --version | head -1` before `just check`: `uname -o` must be `Msys` (Git Bash). A different `bash` (for example the WSL launcher in System32) would be visible there, and the fix is to put Git's `bash` first on `PATH`. Report per-OS results; fix Windows-specific failures (shell, paths) at the root, not by skipping a gate.
- [ ] **Step 5: Commit** `ci: add three-OS gate workflow and dependabot`

### Task 8: Community docs and templates

**Files:**
- Create: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, `ROADMAP.md`, `TODO.md`, `RELEASING.md`, `.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/feature_request.md`, `.github/pull_request_template.md`
- Modify: `README.md`

**Interfaces:**
- Content requirements:
  - `README.md`: what rsutils is; install per platform from GitHub Releases (marked "no releases yet" until the first one); checksum verification; `gh attestation verify <downloaded-file> --repo ckir/rsutils`, inside a block headed "When attestations are enabled (not yet)"; macOS Gatekeeper and Windows SmartScreen notes; developer workflow (`just check`, `just new <name>`).
  - `CONTRIBUTING.md`: prerequisites (Rust via `rust-toolchain.toml`, just, nextest, deny, typos, Go for `just license`); Git Bash/WSL for `just new <name>`; how to add an app; how to run the gate.
  - `CODE_OF_CONDUCT.md`: Contributor Covenant, contact `TODO-CONTACT`. `SECURITY.md`: prefers GitHub private vulnerability reporting; fallback contact `TODO-CONTACT`.
  - `CHANGELOG.md`: Keep a Changelog; `## [Unreleased]`; under each version, `###` headings are Added/Changed/Fixed, and a per-app line is written as a bold prefix such as `**hello:** ...`; changes to `libs/*` are listed under the apps they affect, or under `**core:**` when no app is affected; no released version yet.
  - `RELEASING.md`: the release-PR process, tag-after-CI-green, tag must equal the workspace version, recovery procedure, "if attestations are dropped, update the README", and a note that the release workflow is generated at the first distributable app.
  - `TODO.md`: `TODO-CONTACT` placeholders; generate the release configuration at the first distributable app; recurring hand-bump of `.github/tool-versions`; confirm `just` default shell on Windows; confirm GitHub runners ship Go.
  - `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md`: YAML front matter with `name`, `about`, `title` (`"[bug] "` / `"[feature] "`) and `labels` (`bug` / `enhancement`); bug template asks for OS, `just`/tool version, command, expected and actual output.
  - `ROADMAP.md`: macOS and Windows signing; package managers; first real utilities; revisit per-app versioning.

- [ ] **Step 1: Write the files** per Produces.
- [ ] **Step 2: Verify**

Run: `just typos && just check && grep -rl "TODO-CONTACT" --include=*.md --exclude-dir=docs --exclude-dir=.superpowers --exclude-dir=target . | grep -v '^./TODO.md$' | sort`
Expected: gates pass; the printed files are exactly the files `TODO.md` lists as holding a contact placeholder (`CODE_OF_CONDUCT.md`, `SECURITY.md`), no more and no fewer.
Template checks: `for f in .github/ISSUE_TEMPLATE/*.md; do head -1 "$f" | grep -qx -- '---' && grep -q '^name:' "$f" && grep -q '^about:' "$f" || echo "bad front matter: $f"; done` must print nothing, and `grep -q 'just check' .github/pull_request_template.md` must succeed (the PR template carries a "just check passes" checklist item).
- [ ] **Step 3: Verify links**

Run: `mlc --offline --ignore-path target,.superpowers .` (`mlc` takes a single directory argument, not a file glob; `--offline` skips web links).
Expected: exit 0, no broken relative links.
- [ ] **Step 4: Commit** `docs: add community docs, release runbook and GitHub templates`

---

## Self-Review

- **Spec coverage:** layout (T1,2,3); shared lib and template app (T2,3); gates incl. doc tests and shear split (T5); `just new` strips `dist = false`, enforces lints opt-in (T5,6); licence + `addlicense -f` constraints (T1,4,5); CI on three OSes with pinned tools and Dependabot scope (T7); docs list incl. `RELEASING.md` (T8); release PR order, recovery, attestation README rule (T8). **Deliberately deferred per spec:** release workflow, `dist plan`, `dist` config, attestations, signing (TODO/ROADMAP, T8).
- **Deviation from the spec's "calls" list:** `thiserror` is not added on day 1 (no typed error exists to justify it). Add it with the first typed library error.
- **Unverified, to confirm during execution (each is a named step):** just 1.58 on Windows shell settings (T5); rendered `addlicense -f` output (T4); GitHub runners ship Go (T7); cargo-deny licence allow-list against real dependencies (T5).
- **Types:** `Verbosity`, `Level`, `info`, `warn`, `emit`, `format_error`, `run` have one definition (T2) and the same names in T3.
- **Proportion:** the plan is about 1.5x the spec, with no function bodies beyond signatures.
- **Exhaustiveness audit:** open items are listed above with where each resolves (task and step). Contact addresses are placeholders by owner decision. Nothing else is left as TBD.

## Stand-downs

- `just install` (no name) rebuilds shared dependencies once per app (round 4, Resource Vampire). Discarded below the floor: `just install` is a developer convenience (spec, Goals), not on the CI or release path; releases are built by the release tool, and the cost grows linearly with a handful of small apps. Revisit if install time becomes a complaint.
