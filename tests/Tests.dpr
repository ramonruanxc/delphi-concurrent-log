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
end.
