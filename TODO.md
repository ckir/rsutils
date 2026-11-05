# TODO

Open items. Nothing is published while the contact placeholders remain.

- [ ] Replace the `TODO-CONTACT` placeholder in `CODE_OF_CONDUCT.md`.
- [ ] Replace the `TODO-CONTACT` placeholder in `SECURITY.md`.
- [ ] Enable GitHub private vulnerability reporting on `ckir/rsutils`.
- [ ] Run the CI workflow for real: push a branch, open a pull request and check
      that all three operating systems pass. Not done yet because it needs a
      push to the remote. Check in particular that:
  - the Windows job's diagnostics step prints `Msys` for `uname -o`;
  - `addlicense` resolves after `go install`;
  - the rustup toolchain step works on the runners.
- [ ] Confirm `just`'s default shell behaviour on Windows (the `justfile` sets
      `windows-shell` explicitly).
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
