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
