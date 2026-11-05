// SPDX-License-Identifier: MIT

//! Command-line flags shared by every app.

use clap::Args;

/// Verbosity chosen on the command line.
#[derive(Args, Debug, Clone, Copy, Default)]
pub struct Verbosity {
    /// Increase verbosity (repeat for more: -v, -vv).
    #[arg(short, long, action = clap::ArgAction::Count, global = true)]
    verbose: u8,

    /// Suppress normal output.
    #[arg(short, long, global = true, conflicts_with = "verbose")]
    quiet: bool,
}

/// Effective output level, from least to most talkative.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Level {
    Quiet,
    Normal,
    Verbose,
    Debug,
}

impl Verbosity {
    /// Maps the parsed flags to a [`Level`]; extra `-v` flags saturate at `Debug`.
    #[must_use]
    pub fn level(&self) -> Level {
        if self.quiet {
            return Level::Quiet;
        }
        match self.verbose {
            0 => Level::Normal,
            1 => Level::Verbose,
            _ => Level::Debug,
        }
    }

    /// Configures `env_logger` from [`Self::level`]; safe to call more than once.
    pub fn init_logging(&self) {
        let filter = match self.level() {
            Level::Quiet => log::LevelFilter::Off,
            Level::Normal => log::LevelFilter::Warn,
            Level::Verbose => log::LevelFilter::Info,
            Level::Debug => log::LevelFilter::Debug,
        };
        // A second call fails because a logger is already set; that is fine.
        let _ = env_logger::Builder::new().filter_level(filter).try_init();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;

    #[derive(Parser, Debug)]
    struct TestCli {
        #[command(flatten)]
        verbosity: Verbosity,
    }

    fn level(args: &[&str]) -> Level {
        let full = std::iter::once("test").chain(args.iter().copied());
        TestCli::try_parse_from(full).unwrap().verbosity.level()
    }

    #[test]
    fn level_maps_flags() {
        assert_eq!(level(&[]), Level::Normal);
        assert_eq!(level(&["-v"]), Level::Verbose);
        assert_eq!(level(&["-vv"]), Level::Debug);
        assert_eq!(level(&["-q"]), Level::Quiet);
    }

    #[test]
    fn excess_verbosity_saturates() {
        assert_eq!(level(&["-vvvvvv"]), Level::Debug);
    }

    #[test]
    fn quiet_conflicts_with_verbose() {
        let err = TestCli::try_parse_from(["test", "-q", "-v"]).unwrap_err();
        assert_eq!(err.kind(), clap::error::ErrorKind::ArgumentConflict);
    }

    #[test]
    fn init_logging_twice_is_safe() {
        let v = Verbosity::default();
        v.init_logging();
        v.init_logging();
    }
}
