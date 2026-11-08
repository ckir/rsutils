set shell := ["bash", "-euo", "pipefail", "-c"]
set windows-shell := ["bash", "-euo", "pipefail", "-c"]

# List recipes.
default:
    @just --list

# Print the tool versions, then run all six gates.
check: versions fmt lint test deny typos license

# Print the tool versions (first, so a failing run still shows them).
versions:
    @echo "--- tool versions ---"
    @cargo nextest --version | sed -n 1p
    @cargo deny --version | sed -n 1p
    @typos --version | sed -n 1p
    @just --version
    @echo "addlicense (pinned) $(sed -n 's/^addlicense=//p' .github/tool-versions)"

fmt:
    cargo fmt --all --check

lint:
    bash scripts/check-members.sh
    cargo clippy --workspace --all-targets --locked -- -D warnings
    cargo clippy -p pore-lua --no-default-features --features lua55,module --locked -- -D warnings
    cargo check -p pore-lua --no-default-features --features lua54,vendored --locked

test:
    cargo nextest run --workspace --locked
    cargo nextest run -p pore-core --locked
    cargo test --doc --workspace --locked
    bash scripts/test-policy.sh

deny:
    cargo deny check

typos:
    typos

license:
    bash scripts/license.sh --check

# Non-blocking unused-dependency scan; not part of `check`.
shear:
    cargo shear

# Install one app (`just install pore`) or every distributable app.
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
