# agy-test-audit ledger

One row per test audit: the review of the committed test suites for coverage, run after the capstone gate and before a branch is declared done. This is a RECORD, not a proof.

Conventions (nothing validates them): the newest row goes at the BOTTOM, and every pipe character inside a cell is escaped as a backslash followed by the pipe.

| Date | Audited range | Rounds | Verdict | Evidence |
|---|---|---|---|---|
| 2026-11-05 | tests and sources in 904ae6f..aa57a4d (rsutils-core unit tests, apps/hello tests, scripts/test-new.sh and the scripts they exercise); range ends on the gap-fold commit 9f98c3511493b8ff933e71ec9b3513dcc3322fb2 | 1 | GAPS FOUND, all gaps dispositioned | Brief: .clavity/seams/scaffold-test-audit.md (local, git-ignored); peer transcript ~/.clavity/agy-replies/a418ac7d-be26-453c-997a-c5c137f33a5a-571.md. Four gaps verified by applying each mutant and running the gate (all survived green), then FOLDED in commit 9f98c3511493b8ff933e71ec9b3513dcc3322fb2 (new scripts/test-policy.sh plus two run() tests; no production line changed; 6 of 6 mutants turn the new tests red, re-verified by the driver; `just check` exit 0). Extra gap from cargo-mutants (Verbosity::init_logging level mapping unobserved) DEFERRED-TO-ANOMALIES (owner scoped it out). Below-floor items listed by the peer (long flags, warn mock, test-new.sh concurrency) agreed below the floor; the peer's doubt about the non-UTF-8 test was REJECTED (the test asserts exit code 2). |
