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

    const CHILD_ENV: &str = "RSUTILS_RUN_CHILD";
    const HELPER: &str = "run::tests::run_child_helper";

    /// Re-runs this test binary with only the helper test selected.
    fn spawn_child(mode: &str) -> std::process::Output {
        std::process::Command::new(std::env::current_exe().expect("current_exe"))
            .args(["--exact", HELPER, "--nocapture", "--test-threads=1"])
            .env(CHILD_ENV, mode)
            .output()
            .expect("spawn child test binary")
    }

    /// Does the real work in a child process; a no-op unless `CHILD_ENV` is set.
    #[test]
    fn run_child_helper() {
        let Ok(mode) = std::env::var(CHILD_ENV) else {
            return;
        };
        let code = if mode == "err" {
            run(|| Err(anyhow::anyhow!("boom").context("ctx")))
        } else {
            run(|| Ok(()))
        };
        let success = format!("{code:?}") == format!("{:?}", ExitCode::SUCCESS);
        std::process::exit(i32::from(!success));
    }

    #[test]
    fn run_error_exits_failure_and_prints_message() {
        let out = spawn_child("err");
        let stdout = String::from_utf8_lossy(&out.stdout);
        let stderr = String::from_utf8_lossy(&out.stderr);
        assert!(
            stdout.contains("running 1 test"),
            "helper not selected: {stdout}"
        );
        assert_eq!(out.status.code(), Some(1), "stderr: {stderr}");
        assert!(stderr.contains("error: ctx: boom"), "stderr: {stderr}");
    }

    #[test]
    fn run_ok_exits_success_silently() {
        let out = spawn_child("ok");
        let stdout = String::from_utf8_lossy(&out.stdout);
        let stderr = String::from_utf8_lossy(&out.stderr);
        assert!(
            stdout.contains("running 1 test"),
            "helper not selected: {stdout}"
        );
        assert_eq!(out.status.code(), Some(0), "stderr: {stderr}");
        assert!(stderr.trim().is_empty(), "stderr not empty: {stderr}");
    }
}
