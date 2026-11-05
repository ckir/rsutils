# rsutils monorepo scaffold: design

Date: 2026-11-05. Status: approved by the owner on 2026-11-05, with placeholder contact addresses for now (tracked in `TODO.md`).

## Intent and why

`rsutils` will hold a growing set of small, independent Rust CLI utilities, mostly file utilities. They are released as prebuilt binaries to end users who do **not** have Rust installed, and developed in the open with community contributors.

The scaffold exists so that adding the Nth CLI costs minutes, not a project setup. Quality gates, release plumbing and community docs are done once, at the workspace level.

Today the repo is empty: one initial commit with a `.gitignore` and a "WIP" README. The target machine has cargo/rustc 1.99, clippy, rustfmt, cargo-nextest, cargo-deny, cargo-shear, cargo-mutants, typos, bacon and `just`. `cargo-dist` and `release-plz` are not installed.

## Goals

- A Cargo workspace: `apps/*` (one binary per crate) and `libs/*` (shared library crates, never published).
- One placeholder app, `apps/hello`, that doubles as the template for new apps. It is always compiled and tested, so it cannot drift from workspace conventions.
- One shared lib on day 1, `libs/rsutils-core`: the common error/`Result` setup, `--verbose`/`--quiet` flag handling with logging setup, and terminal-output helpers. Apps use `clap` (derive).
- A quality gate that runs identically locally (`just check`) and in CI: fmt, clippy (warnings denied), nextest, doc tests, cargo-deny, typos, licence headers (addlicense). Optionally cargo-shear (unused dependencies).
- A release pipeline: pushing a `vX.Y.Z` tag builds and publishes prebuilt binaries to GitHub Releases for the platforms below, with checksums and build attestations.
- The full community docs set (see below).
- `just new <name>` creates an app from the template. `just install [name]` is a developer convenience that wraps `cargo install --locked --path apps/<name>`.

## Non-goals and anti-goals

- No crates.io publishing. Lib crates are `publish = false`.
- No package-manager formulas (Homebrew, winget, apt, Scoop) in this scope.
- No macOS code signing or notarization, and no Windows code signing, in this scope. Known consequence: macOS users will see a Gatekeeper warning on first run. This is documented in the README and tracked in the roadmap.
- Anti-goal: hand-maintained build-matrix YAML. If the release workflow needs hand edits to add a platform or an app, the scaffold has failed.
- Anti-goal: weakening a gate to get green (skipped tests, blanket `allow` lints, loosened deny rules) without an explicit, commented reason.
- No premature abstractions in `rsutils-core`. It holds only what `hello` and every future app genuinely need.

## Constraints

- Platforms:
  - Linux x86_64 and aarch64 (static musl)
  - macOS x86_64 and aarch64
  - Windows x86_64 (msvc)
- Licence: MIT. `license = "MIT"` in `[workspace.package]` and a root `LICENSE` file. The copyright holder line uses the owner's git identity (Costas Kirgoussios).
- Versioning: **one workspace-wide version** in `[workspace.package]`, inherited by every crate. One `vX.Y.Z` tag releases every app (`cargo-dist` announces all packages sharing the version). Switching to per-app tags later is supported by the tool and is a revisit trigger, not a current goal (see Approaches).
- Release tool: `cargo-dist`. Its behaviour (workspace-wide and per-package tag formats, musl targets, `github-attestations` as an experimental option, no macOS signing docs) was verified by reading its source at tag v0.34.0 (`book/src/reference/concepts.md:82-110`, `config.md`). Anything beyond that is unverified until the builder reads the tool's source or docs for the version they install.
- The release tool must be pinned, and once the release workflow is generated (at the first distributable app, see "Decided parts of the how"), it is committed and not hand-edited.
- Source-verified at v0.34.0 (`config.md`): a package can be excluded from distribution with `dist = false` (line 197), and a failed build task for any platform blocks the whole release, so a partial release cannot happen (lines 1416-1418). Dry runs exist: `pr-run-mode` (`plan` is the default, `upload` also builds artifacts on PRs) and a workflow-dispatch "dry-run" tag (lines ~1399, 1421).
- CI runs the quality gate on Linux, macOS and Windows, because file utilities behave differently on Windows paths and symlinks.
- CI invokes the same `just` recipes as local development, so the two cannot drift. `cargo-nextest` does not run doctests, so the gate also runs `cargo test --doc`. (Tool behaviour recalled, not source-checked: the builder confirms it.)
- A release tag must only ever point at a commit whose CI gate passed. The release workflow, or the repo's tag rules, must enforce that.
- Release process (documented in `RELEASING.md`, linked from `CONTRIBUTING.md`): open a **release PR** that bumps `[workspace.package].version` and moves the CHANGELOG `Unreleased` entries under the new version. CI runs on the PR. Once it is green, merge it, then push the matching `vX.Y.Z` tag on the merge commit. `main` therefore never claims a version that has not passed the gate. The tag must equal the workspace version. The initial version is `0.1.0`.
- Unsigned binaries: macOS shows a Gatekeeper warning and Windows shows a SmartScreen warning on first run. Both are documented in the README, and signing is on the roadmap, not in scope.
- Checksums are the baseline integrity guarantee. Attestations (`github-attestations`) are best-effort because the feature is marked experimental. If they prove unstable, drop them rather than hand-writing workflow steps (that would break the anti-goal above). Dropping them is done together with a README update: the attestation-verify instructions are removed and checksums become the only documented verification. `RELEASING.md` lists this as a required step.
- Pinning of third-party Actions applies to hand-written workflows. The generated release workflow is governed by the release tool and regenerated by it, so hand-edits there are overwritten.
- Toolchain pinned via `rust-toolchain.toml`. Dependency and lint settings are inherited via `[workspace.dependencies]` and `[workspace.lints]`.

## Approaches considered

All forks below were put to the owner after consulting the agy peer. Where we differed, both recommendations were presented.

1. **Layout**
   - `apps/` + `libs/` (**chosen**, agy and Claude agreed): installable binaries are visibly separate from libs, and `just install` can loop over `apps/*`.
   - Flat `crates/`: simpler, but bins and libs are indistinguishable without opening each crate.
2. **Day-1 shared libs**
   - agy recommended none (extract only after duplication in two tools).
   - Claude recommended a small `rsutils-core` plus `hello` (**chosen**): the owner asked for shared lib crates, and every CLI needs error handling, logging flags and output helpers from its first line.
3. **Adding a CLI**
   - Template directory + `just new` (**chosen**, both agreed): lighter than cargo-generate or an xtask crate. Drift is mitigated by making `hello` the template.
4. **CI**
   - The first proposal was local-only, because it assumed a personal repo.
   - Replaced by GitHub Actions running the same gate as `just check` on three OSes, once the owner said binaries go to end users.
5. **Release tooling**
   - `cargo-dist` (**chosen**, both agreed, source-verified).
   - A hand-written release matrix was rejected: it is the stated anti-goal.
6. **Versioning**
   - agy first proposed per-app independent versions with `app-vX.Y.Z` tags.
   - Claude proposed workspace-wide versioning.
   - After a negotiation round, agy moved to workspace-wide, and Claude checked its reasoning independently.
   - **Workspace-wide (chosen)**
     - Pro: with one maintainer and no release automation, per-app releases risk an overlooked app when a shared lib changes. They also mean several tags, version bumps and changelogs per release.
     - Con: unchanged tools get a new version number.
     - Mitigation: the root `CHANGELOG.md` has a per-app subsection under each release, listed only when that app changed.
     - Revisit trigger: apps change at very different rates, or others release them independently.
7. **Changelog automation**
   - Hand-kept `CHANGELOG.md` in Keep a Changelog format (**chosen**). `release-plz` or `git-cliff` can be added later.
   - `release-plz` was agy's suggestion. Its fit with `cargo-dist` and workspace-wide tags is unverified, so it is not part of day 1.

## Decided parts of the how

- Workspace root `Cargo.toml` with members `apps/*` and `libs/*`, `[workspace.package]` (version, edition, license, repository, authors), `[workspace.dependencies]`, `[workspace.lints]` (clippy and rustc lints, applied through `[lints] workspace = true`), and the release profile settings the release tool requires.
- `rust-toolchain.toml`, `rustfmt.toml`, `deny.toml`, `_typos.toml` (or `typos.toml`), `justfile`.
- `justfile` recipes: `check` (the full gate), `fmt`, `lint`, `test`, `deny`, `typos`, `license`, `new <name>`, `install [name]`.
- No separate template directory: `just new <name>` copies `apps/hello`, substitutes the crate name, and **removes the `dist = false` line**, so every new app is distributable by default. A test or CI check asserts that `just new` output has no `dist = false`, and that every workspace member carries `[lints] workspace = true`. (Claude's call.)
- `justfile` sets its shell explicitly (including a Windows shell setting), and the Windows CI job runs the same recipes. Contributors on Windows need Git Bash or WSL for `just new`; this is stated in `CONTRIBUTING.md`. The builder confirms `just` 1.58's actual default on Windows, since it is unverified. (Claude's call.)
- `apps/hello` sets `dist = false`, so it is never released. Day-1 consequence: no distributable app exists. Source-verified at v0.34.0 (`announce.rs:798`): `dist` errors when the workspace has no packages with distributable binaries. So **no `dist plan` step, PR-run-mode plan, or release workflow runs in CI until the first real app lands**. The builder generates and commits the release configuration at that point and records the deferral in `TODO.md`/`ROADMAP.md`. (Claude's call.)
- Release recovery (documented in `RELEASING.md`): if a platform build fails, no partial release is published (config.md:1416-1418). For a spurious failure, re-run the failed jobs. If a code fix is needed, delete the unpublished tag and re-tag the same version after the fix. Only if a release was published does the fix get a new patch version.
- CI installs `cargo-nextest`, `cargo-deny`, `typos` and `just` at pinned versions recorded in one file in the repo (for example `.github/tool-versions` or a `just` variable), and `just check` prints the versions it runs. Dependabot cannot bump versions in a custom file, so these tool versions are bumped by hand, with a recurring item in `TODO.md`. (Dependabot still covers Cargo and GitHub Actions dependencies.) This closes the gap between the toolchain pin and the unpinned tool binaries. (Claude's call.)
- Licence headers: `addlicense` (google/addlicense; flags, `.rs` comment style and `-check` mode verified at source, tag v1.2.0, `main.go:57-72,306-318`) adds the header to every `.rs` file. The header text lives in a separate template file in the repo (owner's decision, so it can be changed without touching the recipe), and the recipe passes it with `-f <template>` and **without** `-s`. The default template content is the single line `SPDX-License-Identifier: {{.SPDXID}}` (rendered as `// SPDX-License-Identifier: MIT`); with `-f` the SPDX id and holder come from the template's own text and flags (`-c`, `-y`), so the builder verifies the rendered output. Two source-verified constraints: `-s=only` overrides `-f` (`tmpl.go:55-56`), so `-s=only` must not be used; and header detection (`-check` and idempotent re-runs) only recognises a header containing `copyright`, `mozilla public` or `spdx-license-identifier` in the first 1000 bytes (`main.go:427-435`), so any replacement template must contain one of those strings or `-check` will fail forever. The root `LICENSE` file stays hand-written, because `addlicense` manages source-file headers only. A `just license` recipe runs `addlicense -check`, is part of `just check`, and `hello` carries the header, so `just new` output is compliant from the start. The owner may later switch to the full MIT text by editing the template file only. `addlicense` joins the pinned-tool list. It walks directories with `filepath.Walk` and has no `.gitignore` handling and no built-in skip of `target/` (`main.go:211`, source-verified), and it also rewrites `.toml`, `.yml` and `.sh` files when given a directory (`main.go:336-340`, source-verified). So the recipe never passes directories: it feeds only `.rs` files (listed with `git ls-files`, so `target/` is excluded) to `addlicense`, and fails if it finds none, so the gate cannot pass vacuously. (Corrected after plan review round 2; this replaces the earlier "explicit roots plus `-ignore`" wording.) The README documents installing it only via `go install` or Docker, so `just license` needs a Go toolchain: the pinned install is `go install github.com/google/addlicense@v1.2.0` (GitHub-hosted runners ship Go, which the builder confirms). The Go requirement is stated in `CONTRIBUTING.md` as a prerequisite for this recipe only. If it proves too heavy, the fallback is a small script that checks for the SPDX line. The installed binary's version is unverified against v1.2.0. (Claude's call.)
- `just check` runs fmt, clippy, nextest, doc tests, deny, typos and license (six gates). `cargo-shear` is a separate, non-blocking recipe (`just shear`), not part of `check`, so local and CI results always match.
- Dependabot (or equivalent) for Cargo and GitHub Actions dependencies, so pinned Actions do not go stale. (Claude's call.)
- Toolchain: `rust-toolchain.toml` pins an exact stable version (the current one at scaffold time), and `rust-version` in `[workspace.package]` matches it. Bumps are manual or via Dependabot. (Claude's call.)
- GitHub Actions: a CI workflow (the gate on three OSes) and the release workflow generated and managed by the release tool. Third-party Actions are pinned.
- Community docs at the repo root: `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, `ROADMAP.md`, `TODO.md`, `RELEASING.md`, `LICENSE`.
- `.github/` templates: bug-report and feature-request issue templates, and a pull-request template.
- The README covers install instructions for end users per platform, the macOS Gatekeeper note, how to verify checksums and attestations, and the developer workflow.
- `CONTRIBUTING.md` covers how to add an app (`just new`) and how to run the gate.

## Left to the builder

- Exact lint sets and strictness levels, subject to the anti-goal above.
- Names and signatures inside `rsutils-core` (error type, output helpers, logging crate). Prefer the smallest set that `hello` needs.
- Which of the six gates are blocking in CI (all are expected to be), and the exact `deny.toml` policy (licence allow-list including MIT and common permissive licences, advisories, bans).
- Contact addresses for `SECURITY.md` and `CODE_OF_CONDUCT.md`, and the GitHub owner and repository name. The repository is **`ckir/rsutils`** (`https://github.com/ckir/rsutils`), found via `git remote` and confirmed with `gh` (logged in as `ckir`). It is used for `repository`, README install URLs and `gh attestation verify ckir/rsutils` instructions. The contact addresses for `SECURITY.md` and `CODE_OF_CONDUCT.md` are still open: the builder uses clearly marked placeholders and lists them in `TODO.md`, and nothing is published while placeholders remain. (Preferably use GitHub private vulnerability reporting for `SECURITY.md`.)
- Whether the aarch64 musl Linux target is cross-compiled or built on arm runners: the release tool's defaults decide, and the builder checks them against the pinned version's docs.
- Contributor Covenant version, ROADMAP and TODO structure, and the content of the first CHANGELOG entry.
- Whether `hello` itself is shipped in releases. **Claude's call:** it is excluded from distribution, because it is a template and not a user-facing tool.
- Exact `cargo-dist` configuration file layout and version pin, once the tool is installed and its current docs are read.
- Details of `just install` and `just new` (how names are substituted, whether the workspace manifest or docs are updated automatically).

## Calls made by Claude (owner may override)

- A day-1 `rsutils-core` lib and a `hello` app that is not released.
- Dependencies: `clap` (derive) for argument parsing.
- `anyhow` for application errors and `thiserror` for typed library errors.
- `cargo-shear` as an optional or non-blocking gate.
- The licence copyright line uses the git identity.
- Hand-kept changelog with per-app subsections, no automation on day 1.

## Stand-downs

None. No finding was discarded below the floor, and none was accepted unverified. Two stated mechanisms from the agy round were not adopted: that pushed tags are immutable (GitHub tags can be deleted), and that `just` defaults to `cmd.exe` on Windows (unverified). Both underlying findings were folded on their own merits.
