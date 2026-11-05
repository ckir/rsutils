# Roadmap

Items are listed without dates. Open housekeeping items are tracked in
[TODO.md](TODO.md).

- A first release: prebuilt binaries on GitHub Releases (see
  [RELEASING.md](RELEASING.md)).
- The first real file utilities. Today the workspace holds only the template app
  `hello` and the shared library `rsutils-core`.
- Code signing for macOS and Windows binaries, so first runs no longer show a
  Gatekeeper or SmartScreen warning.
- Package managers: Homebrew, winget, apt and Scoop.
- Revisit per-app versioning. The workspace shares one version today. Revisit
  when apps change at very different rates or when others release them
  independently.
