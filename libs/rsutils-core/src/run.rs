// SPDX-License-Identifier: MIT

//! Entry-point helper that turns errors into an exit code.

use std::process::ExitCode;

/// Formats an error with its full cause chain.
#[must_use]
pub fn format_error(e: &anyhow::Error) -> String {
    format!("error: {e:#}")
}

/// Runs `f`; on error prints it to stderr and returns `ExitCode::FAILURE`.
pub fn run(f: impl FnOnce() -> anyhow::Result<()>) -> ExitCode {
    match f() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            crate::output::warn(format_error(&e));
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_error_includes_chain() {
        let e = anyhow::anyhow!("inner").context("outer");
        assert_eq!(format_error(&e), "error: outer: inner");
    }
}
