# Releasing

The release workflow does not exist yet. The release configuration (cargo-dist)
is deliberately deferred and will be generated when the first distributable app
exists, because the release tool errors on a workspace with no distributable
binary. No
release has been published. This file describes the intended process and will be
updated when the workflow is added.

The whole workspace shares one version, set in `Cargo.toml` under
`[workspace.package]`. The initial version is `0.1.0`. The version is now
`0.4.0`, to continue pore's `0.3.0`; `rsutils-core` (never
released) move with it.

## Process

1. Open a release pull request that:
   - bumps `[workspace.package].version` in `Cargo.toml`;
   - runs `cargo update --workspace` (or any cargo command that rewrites the
     lock) and commits the resulting `Cargo.lock` change: the lock records the
     workspace crate versions, so a bump leaves it stale, and `just check`,
     `just install` and the release tool all use `--locked` and fail on a
     stale lock;
   - moves the `Unreleased` entries in `CHANGELOG.md` under the new version.
2. CI runs on the pull request.
3. Once CI is green, merge the pull request.
4. Push the matching tag `vX.Y.Z` on the merge commit. The tag must equal the
   workspace version.

`main` never claims a version that has not passed the gate: the version is bumped
in the pull request, and the tag is pushed only after it is merged.

## Planned release channel

GitHub Releases with prebuilt binaries for Linux (x86_64 and aarch64, static
musl), macOS (Intel and Apple silicon) and Windows (x86_64), with SHA256
checksums. GitHub build attestations are an experimental, best-effort extra.
Binaries are unsigned.

## Recovery

If a platform build fails, no partial release is published.

- Spurious failure: re-run the failed jobs.
- A code fix is needed: delete the unpublished tag, then re-tag the same version
  after the fix.
- A release was already published: the fix gets a new patch version.

## Attestations

If attestations are dropped, remove the attestation-verify instructions from the
README so that checksums are the only documented verification.
