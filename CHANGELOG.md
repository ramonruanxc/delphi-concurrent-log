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
