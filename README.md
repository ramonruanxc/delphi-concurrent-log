# ConcurrentLog

[![CI](https://github.com/ramonruanxc/delphi-concurrent-log/actions/workflows/ci.yml/badge.svg)](https://github.com/ramonruanxc/delphi-concurrent-log/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A small thread-safe logging library for Delphi.

Many threads can log at once without tearing each other's output. One lock,
in one place; sinks and callers never lock. The core is plain Object Pascal
with no platform or UI dependency, so it compiles under both Delphi and Free
Pascal — which is what lets the test suite, including the concurrency test,
run in CI.

```pascal
uses
  ConcurrentLog.Types, ConcurrentLog.Sinks, ConcurrentLog.Logger;

var
  Logger: TLogger;
begin
  Logger := TLogger.Create(llInfo);
  try
    Logger.AddSink(TConsoleSink.Create);
    Logger.AddSink(TFileSink.Create('app.log'));

    Logger.Info('service started');
    Logger.Log(llError, 'request %d failed: %s', [id, reason]);
  finally
    Logger.Free;
  end;
end;
```

---

## Install

With [Boss](https://github.com/HashLoad/boss):

```
boss install github.com/ramonruanxc/delphi-concurrent-log
```

Or add `src` to your project's search path. Requires Delphi 10.1 Berlin or
later; the core also builds on Free Pascal 3.2 with `-Mdelphi`.

## Concepts

**Logger.** Holds the lock, the sink list, and the minimum level. Create one,
add sinks, log to it from any thread.

**Level.** `llTrace < llDebug < llInfo < llWarn < llError`. Entries below the
logger's `MinLevel` are dropped. `MinLevel` is readable and writable at runtime
from any thread.

**Sink.** A destination — `TConsoleSink`, `TFileSink`, `TMemorySink`. Implement
`ILogSink` for your own. A sink never has to lock: the logger calls it from one
thread at a time.

```pascal
type
  ILogSink = interface
    procedure Write(const AEntry: TLogEntry);
  end;
```

`TMemorySink` keeps entries in memory and hands back a copy through `Snapshot`
— useful in tests and for showing recent activity in a UI.

## The design decision

The lock lives in the logger and nowhere else. Everything a log entry touches
between "someone called `Log`" and "every sink has seen it" — the level check,
building the entry, dispatching to each sink — happens inside one critical
section.

That is deliberate. It is the smallest region that can be correct, and the only
one that has to be. A sink author cannot introduce a data race, because they
never touch shared state without the logger's lock held. The alternative —
each sink locking itself — is more code, more locks, and more ways to get it
wrong, for no benefit.

The cost is that sinks run serially while the lock is held, so a slow sink slows
every logging thread. If you need to log across a slow sink without blocking
callers, put a queue in front of it — a sink that hands entries to a background
writer thread. That is a natural extension and intentionally left out of the
core.

## A note on lifetimes

Sinks are reference-counted interfaces (`ILogSink`). The logger holds them, so
you do not free them yourself — construct and hand them straight to `AddSink`:

```pascal
Logger.AddSink(TFileSink.Create('app.log'));
```

The logger itself is a plain object; free it when you are done, and it releases
its sinks.

## The global logger

For code that does not want to pass a logger around, `GlobalLog` returns a
process-wide instance:

```pascal
uses ConcurrentLog.Logger;

GlobalLog.AddSink(TConsoleSink.Create);   // once, at startup
GlobalLog.Info('ready');
```

It is created before any user code runs and destroyed at shutdown, so there is
no lazy-initialisation race. It starts with no sinks and the default `llInfo`
minimum.

---

## Building from a clone

Every `.dpr` lists its units with explicit `in '...'` paths, so **opening one in
the Delphi IDE and pressing build works with nothing to configure** — no search
path, no library path.

Free Pascal resolves units from `-Fu` rather than from the `in` clause, so a
manual FPC build needs the paths on the command line. Every example below
includes them.

## Demo

`demo/Demo.dpr` is a short console program: three threads logging at once
through a console sink and a file sink, with a level filter dropping the
quietest line. Run it and the interleaved output stays intact.

```
fpc -Mdelphi -Fusrc -FUbuild demo/Demo.dpr -obuild/Demo && ./build/Demo
```

---

## Running the tests

Free Pascal, which is what CI uses:

```
mkdir build
fpc -Mdelphi -Fusrc -Futests -FUbuild -obuild/Tests tests/Tests.dpr
./build/Tests
```

The runner exits non-zero if any assertion fails. It uses a small assertion
runner rather than DUnitX, because the suite has to run under both compilers
and DUnitX does not run under Free Pascal. The assertions hold no framework
state, so they can be wrapped in DUnitX for IDE use without changes.

### Proving the lock earns its keep

A concurrency test that always passes proves nothing — it has to fail when the
thing it tests is removed. This one does. Build it with the lock compiled out:

```
fpc -Mdelphi -dPROVE_RACE -Fusrc -Futests -FUbuild -obuild/TestsRace tests/Tests.dpr
./build/TestsRace
```

Without the lock, eight threads calling `TList.Add` at once corrupt the backing
array, and the run dies in a storm of access violations instead of reporting
`40000 entries`. That failure is the evidence that the passing run means
something. `PROVE_RACE` is never defined by a normal build.

---

## Licence

MIT. See [LICENSE](LICENSE).
