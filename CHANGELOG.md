# Changelog

This project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] — unreleased

First release. A thread-safe logging library extracted from a personal systems
project and rebuilt as a standalone, testable, portable component.

### Added

- `TLogger`: a thread-safe logger that fans one log call out to any number of
  sinks under a single critical section. Sinks and callers never lock.
- Log levels `llTrace`, `llDebug`, `llInfo`, `llWarn`, `llError`, with a
  runtime-adjustable `MinLevel`.
- `ILogSink` with three built-in sinks: `TConsoleSink`, `TFileSink`
  (UTF-8, flushed per write), and `TMemorySink` (buffered, with `Snapshot`).
- `GlobalLog`, an optional process-wide logger initialised before user code
  and destroyed at shutdown, with no lazy-initialisation race.
- A portable test suite — 12 assertions including a 40,000-entry, 8-thread
  concurrency test — run in CI on every push by GitHub Actions under Free
  Pascal.
- A `PROVE_RACE` build that compiles the lock out, so the concurrency test can
  be shown to fail without it. CI runs this variant and goes red if the suite
  passes without the lock.
- `boss.json` for installation through Boss.

### Changed

- Clone-and-run: `demo/Demo.dpr` and `tests/Tests.dpr` open and run with F9 in
  Delphi XE7+ (intended; not compiler-verified) and build with a plain
  `fpc demo/Demo.dpr` / `fpc tests/Tests.dpr` from the repository root. The
  demo writes `demo.log` next to its executable, checks it, and prints a
  `SUCCESS`/`FAILURE` line; under the Delphi debugger it waits for Enter.
- The documented Delphi minimum is now XE7 (was 10.1 Berlin).
  `TMemorySink.Snapshot` copies with a plain loop on Delphi instead of
  `TList<T>.ToArray`.
