{
  ConcurrentLog test runner.

    Delphi XE7+   open this file in the IDE and press F9 - nothing to configure
    Free Pascal   fpc tests/Tests.dpr    (from the repository root)

  Exits non-zero if any assertion fails. CI reads that.
}
program Tests;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  { Free Pascal resolves the `in` paths below from the current directory; the
    unit path is resolved from this file, so a plain `fpc tests/Tests.dpr`
    from the repository root works too. }
  {$UNITPATH ../src}
{$ELSE}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  { On Unix, FPC needs a thread driver pulled in before any unit that touches
    threads, or TThread aborts with runtime error 232. It must come first, and
    only applies to FPC/Unix — Delphi and FPC/Windows load threading directly. }
  {$IF DEFINED(FPC) AND DEFINED(UNIX)}
  cthreads,
  {$IFEND}
  { Every project unit is listed with its path, including the ones only reached
    indirectly, so the project builds from a clone with nothing to configure. }
  ConcurrentLog.Types in '../src/ConcurrentLog.Types.pas',
  ConcurrentLog.Sinks in '../src/ConcurrentLog.Sinks.pas',
  ConcurrentLog.Logger in '../src/ConcurrentLog.Logger.pas',
  ConcurrentLog.Testing in 'ConcurrentLog.Testing.pas',
  ConcurrentLog.Tests in 'ConcurrentLog.Tests.pas';

var
  Runner: TTestRunner;
begin
  WriteLn('ConcurrentLog test suite');
  {$IFDEF FPC}
  WriteLn('compiler: Free Pascal');
  {$ELSE}
  WriteLn('compiler: Delphi');
  {$ENDIF}

  Runner := TTestRunner.Create;
  try
    RunTests(Runner);
    ExitCode := Runner.Finish;
  finally
    Runner.Free;
  end;

  { Keeps the console window open when started from the Delphi IDE (F9).
    DebugHook is only set under the debugger, so command line runs, CI and
    Free Pascal never pause. }
  {$IFNDEF FPC}
  if DebugHook <> 0 then
  begin
    Write('Press Enter to exit...');
    ReadLn;
  end;
  {$ENDIF}
end.
