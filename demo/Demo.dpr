{
  ConcurrentLog demo.

  A short console program that exercises the library the way real code would:
  a few threads logging at once, through more than one sink, with a level
  filter in effect. Run it and watch interleaved output stay intact; at the end
  it re-reads the log file, checks it, and prints a single SUCCESS or FAILURE
  line (exit code 0 or 1).

    Delphi XE7+   open this file in the IDE and press F9 - nothing to configure
    Free Pascal   fpc demo/Demo.dpr      (from the repository root)
}
program Demo;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  { Free Pascal resolves the `in` paths below from the current directory, not
    from this file. The unit path is resolved from this file, so the demo also
    builds from the repository root with no command line options. }
  {$UNITPATH ../src}
{$ELSE}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  { On Unix, FPC needs a thread driver loaded before any unit that uses
    threads. Guarded so Delphi and Windows are unaffected. }
  {$IF DEFINED(FPC) AND DEFINED(UNIX)}
  cthreads,
  {$IFEND}
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF},
  { Explicit paths so the project builds straight from a clone with no search
    path to configure. Forward slashes on purpose: Delphi accepts them on
    Windows and Free Pascal needs them on Linux. }
  ConcurrentLog.Types in '../src/ConcurrentLog.Types.pas',
  ConcurrentLog.Sinks in '../src/ConcurrentLog.Sinks.pas',
  ConcurrentLog.Logger in '../src/ConcurrentLog.Logger.pas';

const
  WorkerCount = 3;
  StepsPerWorker = 5;
  { One "starting" line, each worker's steps plus its "done" line, and one
    closing line. The filtered Debug line must not be among them. }
  ExpectedLines = 1 + WorkerCount * (StepsPerWorker + 1) + 1;
  FilteredText = 'below the minimum level';

type
  TWorker = class(TThread)
  strict private
    FLogger: TLogger;
    FName: string;
  protected
    procedure Execute; override;
  public
    constructor Create(ALogger: TLogger; const AName: string);
  end;

constructor TWorker.Create(ALogger: TLogger; const AName: string);
begin
  inherited Create(True);
  FLogger := ALogger;
  FName := AName;
  FreeOnTerminate := False;
end;

procedure TWorker.Execute;
var
  I: Integer;
begin
  for I := 1 to StepsPerWorker do
  begin
    FLogger.Info(Format('%s: step %d of %d', [FName, I, StepsPerWorker]));
    Sleep(10);
  end;
  FLogger.Warn(Format('%s: done', [FName]));
end;

{ Re-reads the log file and returns an empty string if it holds exactly the
  expected lines, each one whole, or a description of the first problem. }
function CheckLogFile(const AFileName: string): string;
var
  Lines: TStringList;
  I: Integer;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    if Lines.Count <> ExpectedLines then
      Exit(Format('expected %d lines in the log file, found %d',
        [ExpectedLines, Lines.Count]));
    for I := 0 to Lines.Count - 1 do
    begin
      if Pos(FilteredText, Lines[I]) > 0 then
        Exit('the level filter let the Debug line through');
      if (Pos('[INFO ] (', Lines[I]) = 0) and (Pos('[WARN ] (', Lines[I]) = 0) then
        Exit(Format('line %d is malformed: %s', [I + 1, Lines[I]]));
    end;
  finally
    Lines.Free;
  end;
end;

var
  Logger: TLogger;
  Workers: array[0..WorkerCount - 1] of TWorker;
  Names: array[0..WorkerCount - 1] of string;
  LogFileName: string;
  Problem: string;
  I: Integer;
begin
  Names[0] := 'importer';
  Names[1] := 'mailer';
  Names[2] := 'indexer';

  { Next to the executable, so it is easy to find whichever way the demo was
    started (IDE, Explorer, command line). Recreated on every run. }
  LogFileName := ExtractFilePath(ParamStr(0)) + 'demo.log';

  { Minimum level is Info, so the Debug line below is dropped - proof the
    filter is doing something. Two sinks: the console, and a file. }
  Logger := TLogger.Create(llInfo);
  try
    Logger.AddSink(TConsoleSink.Create);
    Logger.AddSink(TFileSink.Create(LogFileName, False));

    Logger.Debug('this line is ' + FilteredText + ' and will not appear');
    Logger.Info('starting three workers');

    for I := 0 to High(Workers) do
      Workers[I] := TWorker.Create(Logger, Names[I]);
    for I := 0 to High(Workers) do
      Workers[I].Start;
    for I := 0 to High(Workers) do
      Workers[I].WaitFor;
    for I := 0 to High(Workers) do
      Workers[I].Free;

    Logger.Info('all workers finished');
  finally
    { Freeing the logger releases the file sink, which closes the file. }
    Logger.Free;
  end;

  WriteLn;
  WriteLn('Log file: ', LogFileName);
  Problem := CheckLogFile(LogFileName);
  if Problem = '' then
    WriteLn(Format('SUCCESS: %d lines from %d threads, none lost or torn, ' +
      'Debug line filtered out.', [ExpectedLines, WorkerCount]))
  else
  begin
    WriteLn('FAILURE: ', Problem);
    ExitCode := 1;
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
