// SPDX-License-Identifier: MIT

//! `init_logging` must install the logger at the level the flags ask for.
//! This file holds one test on purpose: the logger is process-global, and an
//! integration test binary gets a process of its own under `cargo test` and
//! under `cargo nextest`.

use clap::Parser;
use rsutils_core::cli::Verbosity;

#[derive(Parser, Debug)]
struct Cli {
    #[command(flatten)]
    verbosity: Verbosity,
}

#[test]
fn init_logging_installs_the_requested_level_and_first_call_wins() {
    let verbose = Cli::try_parse_from(["test", "-v"]).unwrap().verbosity;
    verbose.init_logging();
    assert_eq!(log::max_level(), log::LevelFilter::Info);

    // A later call must not change the level (the logger is already set).
    let debug = Cli::try_parse_from(["test", "-vv"]).unwrap().verbosity;
    debug.init_logging();
    assert_eq!(log::max_level(), log::LevelFilter::Info);
}
