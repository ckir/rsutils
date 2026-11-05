// SPDX-License-Identifier: MIT

//! `hello`: the template app that `just new` copies.

use std::process::ExitCode;

use clap::Parser;
use rsutils_core::cli::Verbosity;
use rsutils_core::output::info;
use rsutils_core::run::run;

/// Greets the world or a named person.
#[derive(Debug, Parser)]
#[command(version, about)]
struct Cli {
    /// Who to greet; defaults to "world".
    #[arg(value_name = "NAME")]
    name: Option<String>,

    #[command(flatten)]
    verbosity: Verbosity,
}

fn greeting(name: Option<&str>) -> String {
    match name {
        Some(name) if !name.is_empty() => format!("Hello, {name}!"),
        _ => "Hello, world!".to_string(),
    }
}

fn main() -> ExitCode {
    // Parse outside `run` so clap's own usage errors keep their exit code 2.
    let cli = Cli::parse();
    run(|| {
        cli.verbosity.init_logging();
        info(&cli.verbosity, greeting(cli.name.as_deref()));
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::greeting;

    #[test]
    fn greeting_cases() {
        assert_eq!(greeting(None), "Hello, world!");
        assert_eq!(greeting(Some("")), "Hello, world!");
        assert_eq!(greeting(Some("Ada")), "Hello, Ada!");
    }
}
