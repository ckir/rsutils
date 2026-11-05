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
    @echo "addlicense (pinned) $(sed -n 's/^addlicense=//p' .github/tool-versions)"

fmt:
    cargo fmt --all --check

lint:
    bash scripts/check-members.sh
    cargo clippy --workspace --all-targets --locked -- -D warnings

test:
    cargo nextest run --workspace --locked
    cargo test --doc --workspace --locked
    bash scripts/test-new.sh

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

# Scaffold a new app from apps/hello (`just new my-tool`).
new $name:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! printf '%s\n' "$name" | grep -Eq '^[a-z][a-z0-9-]*$'; then
      echo "just new: name must match ^[a-z][a-z0-9-]*\$: $name" >&2
      exit 1
    fi
    if [ -e "apps/$name" ]; then
      echo "just new: apps/$name already exists" >&2
      exit 1
    fi
    if [ -e "libs/$name" ]; then
      echo "just new: libs/$name already exists" >&2
      exit 1
    fi
    ident=$(printf '%s' "$name" | tr '-' '_')
    case "$ident" in
      as|break|const|continue|crate|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|static|struct|super|trait|true|type|unsafe|use|where|while|async|await|dyn|abstract|become|box|do|final|macro|override|priv|typeof|unsized|virtual|yield|try|gen)
        echo "just new: $ident is a Rust keyword and cannot be a crate name" >&2
        exit 1
        ;;
      build|deps|examples|incremental|test)
        echo "just new: $name is rejected by cargo as a package name" >&2
        exit 1
        ;;
    esac
    case "$name" in
      con|prn|aux|nul|com[1-9]|lpt[1-9])
        echo "just new: $name is a reserved Windows device name" >&2
        exit 1
        ;;
    esac
    cp -R apps/hello "apps/$name"
    for f in Cargo.toml src/main.rs tests/cli.rs; do
      p="apps/$name/$f"
      sed "s/hello(/__RSUTILS_IDENT__(/g" "$p" > "$p.tmp" && mv "$p.tmp" "$p"
      sed "s/hello/$name/g" "$p" > "$p.tmp" && mv "$p.tmp" "$p"
      sed "s/__RSUTILS_IDENT__/$ident/g" "$p" > "$p.tmp" && mv "$p.tmp" "$p"
    done
    p="apps/$name/Cargo.toml"
    sed '/^# The template app is never released/,$d' "$p" > "$p.tmp" && mv "$p.tmp" "$p"
    # drop trailing blank lines (buffer blanks, print them only if a non-blank line follows)
    awk '/^[ \t\r]*$/ { blank = blank $0 "\n"; next } { printf "%s", blank; blank = ""; print }' "$p" > "$p.tmp" && mv "$p.tmp" "$p"
    echo "created apps/$name"
