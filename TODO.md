# TODO

Open items. The repository is public, so the `TODO-CONTACT` placeholders are visible until they are replaced.

- [ ] Replace the `TODO-CONTACT` placeholder in `CODE_OF_CONDUCT.md`.
- [ ] Replace the `TODO-CONTACT` placeholder in `SECURITY.md`.
- [ ] Enable GitHub private vulnerability reporting on `ckir/rsutils`.
- [x] Run the CI workflow for real. Done on a push to `main`
      (https://github.com/ckir/rsutils/actions/runs/42094703408): all three
      operating systems pass `just check`. The Windows job runs under Git Bash
      (`uname -o` prints `Msys`), `addlicense` resolves after `go install` on
      all three systems, and the rustup toolchain step works on the runners.
      macOS runs bash 3.2.57. The first macOS attempt never got a hosted runner
      (GitHub capacity notice) and passed on re-run, so a macOS job can need a
      manual re-run when GitHub is short of arm64 runners.
- [ ] Open one pull request to exercise what the push run did not (PR #1
      is in flight): the
      `pull_request` trigger and its concurrency group (superseded PR runs
      should cancel, pushes to `main` should not).
- [x] Confirm `just`'s shell behaviour on Windows. The `justfile` sets
      `windows-shell` explicitly, and that setting works on `windows-latest`
      under Git Bash, so `just`'s own default no longer matters.
- [ ] When the first distributable app lands, generate and commit the release
      configuration (cargo-dist), then update `RELEASING.md` and the install
      section of `README.md`.
- [ ] Enforce that a release tag only ever points at a commit whose CI gate
      passed (a tag protection rule, or a check in the release workflow).
- [ ] Pin the cargo-dist version when its configuration is generated.
- [ ] Bump the `rust-toolchain.toml` pin (and `rust-version`) manually when
      moving to a newer stable.
- [ ] Bump the versions in `.github/tool-versions` by hand on a recurring basis
      (Dependabot cannot update that file).
- [ ] Once releases exist, decide whether to keep GitHub attestations
      (experimental).
- [ ] Add signing for macOS and Windows binaries (also in `ROADMAP.md`).
