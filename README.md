# rsutils

Small file utilities written in Rust, kept in one Cargo workspace.

- `apps/*`: the command-line tools. Today there is `apps/pore`, a full-text
  search tool moved here from ckir/pore.
- `libs/*`: shared libraries, used inside the workspace and never published.
  Today there are `libs/rsutils-core` and the pore libraries `libs/pore-core`,
  `libs/pore-macros` and `libs/pore-lua` (a Lua module).

## Install

**No releases yet.** Nothing has been published. pore can be installed from source today:
see [apps/pore/README.md](apps/pore/README.md#install-from-source). The plan is to publish prebuilt
binaries on [GitHub Releases](https://github.com/ckir/rsutils/releases) for:

- Linux: x86_64 and aarch64 (static musl)
- macOS: Intel and Apple silicon
- Windows: x86_64

Each release will include SHA256 checksums. Download the archive for your
platform and verify it before use.

### Verify the checksum

Linux:

```
sha256sum -c <checksum-file>
```

macOS:

```
shasum -a 256 -c <checksum-file>
```

Windows (PowerShell), then compare the output with the published checksum:

```
Get-FileHash <downloaded-file> -Algorithm SHA256
```

### When attestations are enabled (not yet)

GitHub build attestations are planned as an experimental extra. Once enabled,
you will be able to verify a download with:

```
gh attestation verify <downloaded-file> --repo ckir/rsutils
```

### First run on macOS and Windows

The binaries are unsigned. macOS shows a Gatekeeper warning and Windows shows a
SmartScreen warning the first time you run one. Signing is on the
[roadmap](ROADMAP.md).

## Development

You need the tools listed in [CONTRIBUTING.md](CONTRIBUTING.md).

```
just check        # run all six gates
just install      # install every distributable app
```

More information:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [RELEASING.md](RELEASING.md)
- [ROADMAP.md](ROADMAP.md)
- [CHANGELOG.md](CHANGELOG.md)

## Licence

MIT. See [LICENSE](LICENSE).
