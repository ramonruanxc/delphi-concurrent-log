{
  ConcurrentLog test runner.

    Free Pascal   fpc -Mdelphi -Fu../src -Fu. Tests.dpr
    Delphi        (add src and tests to the search path, build in the IDE)

  Exits non-zero if any assertion fails. CI reads that.
}
program Tests;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
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
  ConcurrentLog.Testing,
  ConcurrentLog.Tests;

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
end.
