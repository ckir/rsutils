// SPDX-License-Identifier: MIT

//! Terminal output helpers.

use std::fmt::Display;
use std::io::{self, Write};

use crate::cli::{Level, Verbosity};

/// Prints `msg` to stdout unless the level is `Quiet`.
pub fn info(v: &Verbosity, msg: impl Display) {
    if v.level() > Level::Quiet {
        // A failed stdout write (other than a closed pipe) is not worth aborting for.
        let _ = emit(&mut io::stdout().lock(), &msg);
    }
}

/// Prints `msg` to stderr, always.
pub fn warn(msg: impl Display) {
    let _ = emit(&mut io::stderr().lock(), &msg);
}

/// Writes `msg` and a newline to `w`; a closed pipe counts as success.
pub(crate) fn emit<W: Write>(w: &mut W, msg: &dyn Display) -> io::Result<()> {
    match writeln!(w, "{msg}") {
        Err(e) if e.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        other => other,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{self, Write};

    struct FailWith(io::ErrorKind);

    impl Write for FailWith {
        fn write(&mut self, _: &[u8]) -> io::Result<usize> {
            Err(io::Error::from(self.0))
        }
        fn flush(&mut self) -> io::Result<()> {
            Err(io::Error::from(self.0))
        }
    }

    #[test]
    fn emit_writes_line() {
        let mut buf = Vec::new();
        emit(&mut buf, &"hi").unwrap();
        assert_eq!(buf, b"hi\n");
    }

    #[test]
    fn emit_ignores_broken_pipe() {
        assert!(emit(&mut FailWith(io::ErrorKind::BrokenPipe), &"hi").is_ok());
        assert!(emit(&mut FailWith(io::ErrorKind::PermissionDenied), &"hi").is_err());
    }
}
