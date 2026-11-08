# Moving pore into rsutils Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import pore's four crates, with their history, into the rsutils workspace so that `just check` passes on all three systems, then retire `ckir/pore`.

**Architecture:** A `git filter-repo` rewrite of pore's `master` places the crates at `apps/pore`, `libs/pore-core`, `libs/pore-macros` and `libs/pore-lua`, and is merged into `feat/pore-migration` with `--allow-unrelated-histories`. Follow-up commits on the same branch adapt pore to rsutils' manifests, edition, lints and gates. It all lands as one PR, merged with a merge commit.

**Tech Stack:** Rust 1.99.1 (edition 2024), Cargo workspace, git-filter-repo, just, cargo-nextest, cargo-deny, typos, addlicense, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-07-pore-migration-design.md` (approved 2026-11-07). Executors read both. Where this plan and the spec disagree, the spec wins: stop and report the conflict.

## Global Constraints

- No functional change to pore's CLI, JSON output, config file or Lua API.
- No crate-level or workspace-level lint `allow`s. No `unsafe` anywhere, including tests. No loosening of any rsutils gate.
- Item-level `#[allow]`, each with a reason comment, ONLY at these places (pore's current paths -> new paths):
  - `clippy::struct_excessive_bools`: `pore-bin/src/args.rs:81` -> `apps/pore/src/args.rs`, `pore-bin/src/config.rs:38` -> `apps/pore/src/config.rs`, `FileIndexOptions` at `pore-core/src/file.rs:97` -> `libs/pore-core/src/file.rs`.
  - `clippy::too_many_lines`: `macros/src/lib.rs:12` -> `libs/pore-macros/src/lib.rs` (125 lines), and `pore-core/src/file.rs:542` -> `libs/pore-core/src/file.rs` (107 lines).
  - Any other `allow` you think is needed: STOP and report `ALLOW_NEEDED: <file:line> <lint> <why>`.
- The package name stays `pore` (the index cache dir is keyed on `CARGO_PKG_NAME`, `pore-bin/src/main.rs:188`).
- `apps/pore` description: exactly `pore — full-text search powered by Tantivy`.
- Each pore crate: `authors = ["Steven Arcangeli", "Costas Kirgoussios"]` (not inherited); `publish = false`; `[lints] workspace = true`; `version`/`edition`/`license`/`repository`/`rust-version` `.workspace = true`.
- `[workspace.package].version = "0.4.0"`.
- The workspace `mlua` entry carries NO features. Each member declares its own mlua features, unchanged from today.
- Old pore tags never enter this repository. Only pore's `master` is imported.
- The repo gate is `just check` (see `justfile`). Don't add stricter flags; don't skip gates.

## Review Focus

1. **Windows user with only `USERPROFILE` set:** config and cache still resolve. Pinned by `resolution_order_and_error` (Task 2), which must keep every existing assertion.
2. **Existing users' index caches are reused after the upgrade:** the package name must stay `pore`. Pinned by `package_name_is_pore` (Task 1).
3. **`pore --help` first line unchanged after `description` is added:** pinned by `help_first_line_is_unchanged` (Task 1).
4. **The config file is still read from `$XDG_CONFIG_HOME/pore.toml` by the real binary** after the env refactor (a refactor could leave only the test seam working). Pinned by `config_file_in_xdg_config_home_is_used` (Task 2), which sets the child process env via `assert_cmd`.
5. **The Lua module build, which no default build compiles:** pinned by the `just lint` module clippy step (Task 3).

---

### Task 1: Import pore with history and make the workspace build

**Files:**
- Create (by merge): `apps/pore/**`, `libs/pore-core/**`, `libs/pore-macros/**`, `libs/pore-lua/**`
- Modify: `Cargo.toml` (root), `apps/pore/Cargo.toml`, `libs/pore-core/Cargo.toml`, `libs/pore-macros/Cargo.toml`, `libs/pore-lua/Cargo.toml`, `libs/pore-core/src/location.rs:115`, `Cargo.lock`
- Test: `apps/pore/tests/cli_integration.rs` (two new tests)

**Interfaces:**
- Produces: the workspace with pore's crates at their new paths. `pore-macros` is consumed under its old extern name: `macros = { package = "pore-macros", path = "../pore-macros" }` (and `../../libs/pore-macros` from `apps/pore`), so `use macros::create_option_copy;` (`pore-core/src/file.rs:30`, `pore-core/src/generic.rs:16`, `pore-bin/src/config.rs:20`) stays unchanged.

- [ ] **Step 0: Verify state.** On branch `feat/pore-migration`, `git status --short` is empty, `git log --oneline -1` shows `docs: implementation plan for moving pore into the workspace`, and `git log --oneline -2` shows `docs: design for moving pore into the workspace` beneath it. `/home/user/Development/Rust/pore` is at `5c3960e` on `master`. If any of this differs, STOP: `STATE_MISMATCH: <what>`.

- [ ] **Step 1: Install git-filter-repo** (`sudo apt-get install -y git-filter-repo`, candidate 2.47.0). Verify with `git filter-repo --version`. Add it to `.claude/recommended-tools.json` (create the file) as `{"name":"git-filter-repo","why":"history-preserving import of external repos","install":"sudo apt-get install -y git-filter-repo","in_path":"git-filter-repo"}`, in a JSON array.

- [ ] **Step 2: Rewrite a fresh clone** in the session scratchpad (never in either repo):

```bash
git clone --single-branch --branch master --no-tags /home/user/Development/Rust/pore "$SCRATCH/pore-filtered"
cd "$SCRATCH/pore-filtered"
git filter-repo \
  --path pore-bin/ --path pore-core/ --path pore-lua/ --path macros/ \
  --path README.md --path CHANGELOG.md --path LICENSE \
  --path-rename pore-bin/:apps/pore/ --path-rename pore-core/:libs/pore-core/ \
  --path-rename pore-lua/:libs/pore-lua/ --path-rename macros/:libs/pore-macros/ \
  --path-rename README.md:apps/pore/README.md --path-rename CHANGELOG.md:apps/pore/CHANGELOG.md \
  --path-rename LICENSE:apps/pore/LICENSE
git tag -l | xargs -r git tag -d
```

Expected: `git tag -l` is empty. `git branch -a` shows only `master`. `git rev-list --count master` is 61 (measured: 61 of pore's 88 commits touch the kept paths; the rest are pruned as empty). `git ls-files | cut -d/ -f1-2 | sort -u` lists only `apps/pore`, `libs/pore-core`, `libs/pore-lua` and `libs/pore-macros`.

- [ ] **Step 3: Merge into rsutils.** In rsutils: `git remote add pore-import "$SCRATCH/pore-filtered"`, then `git fetch --no-tags pore-import master`, then `git merge --allow-unrelated-histories --no-ff pore-import/master -m "chore: import pore's history into apps/pore and libs/pore-*"` (plus the attribution trailer), then `git remote remove pore-import`. Expected: no conflicts (no path overlaps), and `git tag -l | grep -c '^v'` is 0.

- [ ] **Step 4: Copy the MIT licence** from `apps/pore/LICENSE` to `libs/pore-core/LICENSE`, `libs/pore-macros/LICENSE` and `libs/pore-lua/LICENSE`, byte-identical.

- [ ] **Step 5: Root `Cargo.toml`:** set `version = "0.4.0"`. Add to `[workspace.dependencies]` every third-party dependency pore uses, with today's version floors and NO features (members add features):
  - `chrono = "0.4.45"`, `ignore = "0.4.33"`, `mlua = "0.12.0"`, `serde = "1.0.229"`, `serde_json = "1.0.151"`, `tantivy = "0.26.1"`, `jaq-core = "3.1.0"`, `jaq-std = "3.0.1"`, `jaq-json = "2.0.2"`, `termcolor = "1.4.1"`, `toml = "1.1.4"`, `tempfile = "3.27.0"`, `syn = "1"`, `quote = "1"`, `proc-macro2 = "1"`.
  - `anyhow`, `clap`, `assert_cmd` and `predicates` already exist and are reused.

- [ ] **Step 6: Member manifests.** Rewrite each manifest from the pore originals (pore commit `5c3960e`, e.g. `git show 5c3960e:pore-core/Cargo.toml` in the pore repo):
  - Apply the Global Constraints package keys. Package names: `pore`, `pore-core`, `pore-macros`, `pore-lua`.
  - Descriptions:
    - `pore`: the exact string above;
    - `pore-core`: `Indexing and search engine behind pore`;
    - `pore-macros`: `Proc macros for pore's option types`;
    - `pore-lua`: `Lua module exposing pore's search engine`.
  - Dependencies use `.workspace = true` plus the member's own features, exactly as today:
    - `anyhow` features `["backtrace"]` (pore-core, pore);
    - `chrono` `["serde"]`;
    - `clap` (workspace already has `derive`);
    - mlua: pore-core `["async", "macros"]`, pore-lua `["async", "macros", "serialize"]`, pore `["async", "macros", "lua55", "vendored"]`;
    - `jaq-json` `["serde"]`.
  - Keep `[lib] proc-macro = true` (pore-macros), `[lib] crate-type = ["cdylib"]` and the whole `[features]` table (pore-lua), `[features] vendored` (pore-core), and `[[bin]] name = "pore", path = "src/main.rs"`.
  - Path deps: `pore-core = { path = "../../libs/pore-core" }` from `apps/pore`, `{ path = "../pore-core" }` from `libs/pore-lua`. `macros` is renamed per Interfaces.
  - Drop `apps/pore/release.toml` (`git rm`).
  - A shape change to any feature list is a STOP: `[original] -> [yours] because <reason>`.

- [ ] **Step 7: Edition-2024 fix:** in `libs/pore-core/src/location.rs:115`, `if let Some(Reverse(mut next_pos)) = positions.peek()` becomes `if let Some(&Reverse(mut next_pos)) = positions.peek()`.

- [ ] **Step 8: Write the two Review Focus tests** in `apps/pore/tests/cli_integration.rs`, reusing its `pore()` helper (line 5):

```rust
#[test]
fn help_first_line_is_unchanged() {
    let out = pore().arg("--help").output().unwrap();
    let stdout = String::from_utf8(out.stdout).unwrap();
    assert_eq!(stdout.lines().next(), Some("pore — full-text search powered by Tantivy"));
}

#[test]
fn package_name_is_pore() {
    // The index cache directory is keyed on the package name (src/main.rs), so renaming
    // the package would orphan every existing user's indexes.
    assert_eq!(env!("CARGO_PKG_NAME"), "pore");
}
```

- [ ] **Step 9: Lock and build.** Run `cargo generate-lockfile`, then `cargo build --workspace --locked`. Expected: `Finished`. Then run `cargo nextest run -p pore --test cli_integration --locked`. Expected: all pass, including the two new tests. (`--all-targets` still fails on `set_var` in unit tests; Task 2 fixes that. That is the only expected failure, and it is not a STOP.)

- [ ] **Step 10: Commit** `build: adapt pore's manifests to the workspace and move to 0.4.0`, with the manifests, `Cargo.toml`, `Cargo.lock`, the LICENSE copies, `location.rs`, the tests, the `release.toml` removal and `.claude/recommended-tools.json`.

### Task 2: Inject the environment into base-dir and config lookup

**Files:**
- Modify: `apps/pore/src/paths.rs` (whole file is 107 lines; tests at 48-107), `apps/pore/src/config.rs:123-140` (`load_config`) and its tests at `177-255`
- Test: same files, plus `apps/pore/tests/cli_integration.rs`

**Interfaces:**
- Produces:
  - `pub fn resolve_base_dir(xdg_var: &str, suffix: &str) -> Result<PathBuf, anyhow::Error>`: signature unchanged. It delegates to the new function below, passing `|v| std::env::var_os(v)`.
  - `pub(crate) fn resolve_base_dir_with(xdg_var: &str, suffix: &str, get: impl Fn(&str) -> Option<OsString>) -> Result<PathBuf, anyhow::Error>`: the current body, with `non_empty_var` applied to `get`'s result. The error text is unchanged.
  - `pub fn load_config(path: &Path, index_name: Option<&str>) -> Result<(FileIndexOptionsShape, SearchConfigOpt), anyhow::Error>`: signature unchanged. It resolves the config file as today, then delegates to the new function below.
  - `pub(crate) fn load_config_from(config_file: &Path, path: &Path, index_name: Option<&str>) -> Result<(FileIndexOptionsShape, SearchConfigOpt), anyhow::Error>`: the current body, from `if config_file.exists()` on.
- Callers unchanged: `main.rs:63`, `main.rs:187`.

- [ ] **Step 0: Verify state.** `paths.rs` matches pore `5c3960e`'s `pore-bin/src/paths.rs`, and `config.rs:129` reads `crate::paths::resolve_base_dir("XDG_CONFIG_HOME", ".config")?.join(CONFIG_FILE);`. Otherwise STOP: `STATE_MISMATCH`.

- [ ] **Step 1: Rewrite `tests::resolution_order_and_error`** to call `resolve_base_dir_with` with a getter over a local `HashMap<&str, &str>` that the test mutates between asserts. Keep every existing assertion and expected value (the 2 error-text `contains`, then `/up`, `/home`, `/xdg`, and empty-XDG -> `/home`). Remove the save/restore block and the comment about process-wide state. This is the oracle: an existing expected value that looks wrong means STOP and report it, not edit it.

- [ ] **Step 2: Rewrite `tests::can_load_and_merge_defaults`** to call `load_config_from(&conf_file, …)` with the same four calls and the same expected `threads` (10, 20, 30, 40). Remove `env` from the test imports.

- [ ] **Step 3: Add `config_file_in_xdg_config_home_is_used`** to `apps/pore/tests/cli_integration.rs`. It creates a tempdir holding a `pore.toml` with `limit = 1`, and a project dir with two files both containing `wolf`. It runs `pore search wolf --json` there with `.env("XDG_CONFIG_HOME", cfg.path())`, `.env("HOME", home.path())` and `.env("XDG_CACHE_HOME", cache.path())`. `--json` prints one JSON object per result, one per line (`pore-bin/src/output.rs:57,78`). So it asserts that stdout has exactly 1 non-empty line, and that the line parses with `serde_json::from_str::<serde_json::Value>`. (Read `search_command_finds_matches` and `json_output_flag` first, for the existing invocation. If `limit` is not honoured from the config file today, STOP and report it: that would be existing behaviour to discuss, not to change.)

- [ ] **Step 4: Run, expect a compile failure** (`resolve_base_dir_with` / `load_config_from` undefined): `cargo nextest run -p pore --locked`.

- [ ] **Step 5: Implement** the two functions per Interfaces.

- [ ] **Step 6: Verify.** Run `cargo nextest run --workspace --locked` and `cargo test --doc --workspace --locked`. Expected: all pass. `git grep -n "set_var\|remove_var" -- apps libs` returns nothing.

- [ ] **Step 7: Commit** `refactor(pore): inject the environment into base-dir and config lookup`.

### Task 3: Bring pore to the workspace lint bar, and lint the Lua module build

Split for execution into 3a (`libs/pore-macros` + `libs/pore-core`), 3b (`apps/pore`) and 3c (`libs/pore-lua` + the `justfile` step). Do them in that order, one commit each. Each has the same steps.

**Files:**
- Modify: the `.rs` files of the crate(s) in scope; `justfile:23-25` (3c only)

**Interfaces:**
- No public signature may change, except adding `#[must_use]`, `#[derive(Debug)]` and doc sections. A change to a `pub` item's parameters (e.g. pass-by-value -> reference, flagged by `needless_pass_by_value`) is allowed only on items not re-exported to another crate. Otherwise STOP and report.

- [ ] **Step 0: Verify state.** Task 2's commit is HEAD~0 (3a), or the previous sub-task's commit is (3b, 3c).
- [ ] **Step 1: Measure.** 3a/3b: `cargo clippy -p <crate> --all-targets --locked -- -D warnings`. 3c: also `cargo clippy -p pore-lua --no-default-features --features lua55,module --locked -- -D warnings`. Note the warning count.
- [ ] **Step 2: Fix every warning in code.** Add only the Global Constraints `#[allow]`s, each on the item, with a `// reason:` comment above it. The `# Errors` and `# Panics` sections state the real conditions, read from the body.
- [ ] **Step 3 (3c only): Add to the `lint` recipe in `justfile`**, after the clippy line: `cargo clippy -p pore-lua --no-default-features --features lua55,module --locked -- -D warnings`
- [ ] **Step 4: Verify.** The Step 1 command(s) now print no warnings and end `Finished`. Then run `cargo nextest run --workspace --locked` and `cargo test --doc --workspace --locked` (all pass), and `cargo fmt --all --check` (clean).
- [ ] **Step 5: Commit** `style(<crate>): meet the workspace lint bar` (3c: `…, and lint the Lua module build`).

### Task 4: Licence headers, cargo-deny, typos and nextest config

**Files:**
- Modify: every `.rs` under `apps/pore` and `libs/pore-*` (header only), `deny.toml`, `typos.toml`
- Create: `.config/nextest.toml`

- [ ] **Step 1:** Run `bash scripts/license.sh`. Expected: headers added. `bash scripts/license.sh --check` exits 0.
- [ ] **Step 2:** Add `"Zlib"` to `[licenses].allow` in `deny.toml`. Run `cargo deny check`. Expected: `advisories ok, bans ok, licenses ok, sources ok`. Duplicate-version warnings are fine. If an advisory or yanked crate fails: `cargo update -p <crate>` within its requirement is allowed. A `deny.toml` ignore is not: STOP and report.
- [ ] **Step 3:** In `typos.toml`, add `[default.extend-words]` with `ser = "ser"`. Run `typos`. Fix real typos in pore prose and code. A domain word that isn't a typo: STOP and report it with the file:line.
- [ ] **Step 4:** Create `.config/nextest.toml` containing only pore's `[profile.default]` (pore `5c3960e:.config/nextest.toml`: `fail-fast = false`, `slow-timeout = { period = "30s", terminate-after = 4 }`, and its comments).
- [ ] **Step 5: Verify.** `just check` passes all six gates locally (needs network for deny).
- [ ] **Step 6: Commit** `chore: licence headers, cargo-deny, typos and nextest config for pore`.

### Task 5: Documentation

**Files:**
- Modify: `apps/pore/README.md`, `apps/pore/CHANGELOG.md`, `CHANGELOG.md`, `RELEASING.md`, `README.md`, `ROADMAP.md`, `CONTRIBUTING.md`

- [ ] **Step 1:** In `apps/pore/README.md`:
  - Point the badge and links at `ckir/rsutils`.
  - Add an "Install from source" section with `cargo install --locked --git https://github.com/ckir/rsutils pore`.
  - Fix any build instructions that name old paths, e.g. `cd pore-lua` -> `libs/pore-lua`, `-p pore-lua`.
- [ ] **Step 2:** At the top of `apps/pore/CHANGELOG.md`, add: history up to 0.3.0 is frozen here, and later changes are in the root `CHANGELOG.md`.
- [ ] **Step 3:** In the root `CHANGELOG.md` `[Unreleased]`, replace "No release has been published yet." with an `### Added` entry, `**pore:** moved into this workspace from ckir/pore (history preserved); the workspace version moves to 0.4.0 to continue pore's numbering.`, keeping the conventions section.
- [ ] **Step 4:** In `RELEASING.md`, after the "initial version" sentence, say that the version is 0.4.0 to continue pore's 0.3.0, and that `hello` and `rsutils-core` (never released) move with it.
- [ ] **Step 5:** In the root `README.md`, list `apps/pore` and `libs/pore-*`. In `ROADMAP.md`, update the "first real file utilities" item (pore has landed). In `CONTRIBUTING.md`, document the module clippy step under gate 2 (`lint`).
- [ ] **Step 6: Verify.** `typos` is clean, and `just check` passes.
- [ ] **Step 7: Commit** `docs: document pore's move into the workspace`.

### Task 6: PR and three-system CI (orchestrator, not delegated)

- [ ] **Step 1:** Push `feat/pore-migration` right after Task 3 (early CI, per spec). Open the PR as a draft. Fix portable-test failures in place. A product bug on macOS or Windows: STOP and ask the owner.
- [ ] **Step 2:** After Task 5, mark the PR ready. In the PR description, include:
  - the CI job durations for each OS;
  - the output of `git grep -n 'allow(' -- apps/pore libs/pore-*`;
  - a note that it must be merged with a merge commit.
  If any job is within 5 minutes of the 30-minute timeout, ask the owner (cache vs timeout).
- [ ] **Step 3:** Run the agy capstone and test audit (CLAUDE.md AGY-CAPSTONE / AGY-TEST-AUDIT) on the committed range, until GREEN.
- [ ] **Step 4:** With the owner's go-ahead, merge with a merge commit (`gh pr merge --merge`). Confirm `git log --oneline main | wc -l` grew by the imported commits.

### Task 7: Retire ckir/pore (owner go-ahead required)

- [ ] **Step 1:** In `/home/user/Development/Rust/pore` on `master`, prepend to `README.md` a notice: `> **pore has moved** to https://github.com/ckir/rsutils/tree/main/apps/pore. This repository is archived; its releases and docs (frozen at 0.3.0) stay readable.` Commit, then push.
- [ ] **Step 2:** `gh repo archive ckir/pore --yes`. Verify: `gh repo view ckir/pore --json isArchived` prints `true`.
