set shell := ["bash", "-euo", "pipefail", "-c"]
set windows-shell := ["bash", "-euo", "pipefail", "-c"]

# List recipes.
default:
    @just --list

# Run all six gates, then print the tool versions used.
check: fmt lint test deny typos license
    @echo "--- tool versions ---"
    @cargo nextest --version | sed -n 1p
    @cargo deny --version | sed -n 1p
    @typos --version | sed -n 1p
    @just --version
    @echo "addlicense $(sed -n 's/^addlicense=//p' .github/tool-versions)"

fmt:
    cargo fmt --all --check

lint:
    bash scripts/check-members.sh
    cargo clippy --workspace --all-targets -- -D warnings

test:
    cargo nextest run --workspace
    cargo test --doc --workspace

deny:
    cargo deny check

typos:
    typos

license:
    bash scripts/license.sh --check

# Non-blocking unused-dependency scan; not part of `check`.
shear:
    cargo shear

# Install one app (`just install hello`) or every distributable app.
install name="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{name}}" ]; then
      cargo install --locked --path "apps/{{name}}"
    else
      for app in apps/*; do
        if bash scripts/toml-has.sh "$app/Cargo.toml" package.metadata.dist dist false; then
          continue
        fi
        cargo install --locked --path "$app"
      done
    fi

# Scaffold a new app (implemented in Task 6).
new name:
    @echo "just new: not implemented yet (Task 6)" >&2; exit 1
