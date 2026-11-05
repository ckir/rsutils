use assert_cmd::Command;
use predicates::prelude::*;

fn hello() -> Command {
    Command::cargo_bin("hello").expect("hello binary builds")
}

#[test]
fn prints_default_greeting() {
    hello().assert().success().stdout("Hello, world!\n");
}

#[test]
fn prints_named_greeting() {
    hello()
        .arg("Ada")
        .assert()
        .success()
        .stdout("Hello, Ada!\n");
}

#[test]
fn empty_name_falls_back_to_world() {
    hello().arg("").assert().success().stdout("Hello, world!\n");
}

#[test]
fn quiet_suppresses_output() {
    hello().arg("-q").assert().success().stdout("");
}

#[test]
fn verbose_and_quiet_conflict() {
    hello()
        .args(["-v", "-q"])
        .assert()
        .code(2)
        .stderr(predicate::str::contains("cannot be used with"));
}

#[cfg(unix)]
#[test]
fn non_utf8_argument_is_a_clean_error() {
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;

    hello()
        .arg(OsStr::from_bytes(b"\xff"))
        .assert()
        .code(2)
        .stderr(predicate::str::is_empty().not());
}
