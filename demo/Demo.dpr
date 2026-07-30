{
  ConcurrentLog demo.

  A short console program that exercises the library the way real code would:
  a few threads logging at once, through more than one sink, with a level
  filter in effect. Run it and watch interleaved output stay intact.

    Free Pascal   fpc -Mdelphi -Fu../src Demo.dpr
    Delphi        add ../src to the search path, build in the IDE
}
program Demo;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
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
  for I := 1 to 5 do
  begin
    FLogger.Info(Format('%s: step %d of 5', [FName, I]));
    Sleep(10);
  end;
  FLogger.Warn(Format('%s: done', [FName]));
end;

var
  Logger: TLogger;
  Workers: array[0..2] of TWorker;
  Names: array[0..2] of string;
  I: Integer;
begin
  Names[0] := 'importer';
  Names[1] := 'mailer';
  Names[2] := 'indexer';

  { Minimum level is Info, so the Debug line below is dropped — proof the
    filter is doing something. Two sinks: the console, and a file. }
  Logger := TLogger.Create(llInfo);
  try
    Logger.AddSink(TConsoleSink.Create);
    Logger.AddSink(TFileSink.Create('demo.log'));

    Logger.Debug('this line is below the minimum level and will not appear');
    Logger.Info('starting three workers');

    for I := 0 to High(Workers) do
      Workers[I] := TWorker.Create(Logger, Names[I]);
    for I := 0 to High(Workers) do
      Workers[I].Start;
    for I := 0 to High(Workers) do
      Workers[I].WaitFor;
    for I := 0 to High(Workers) do
      Workers[I].Free;

    Logger.Info('all workers finished; see demo.log for the same output on disk');
  finally
    Logger.Free;
  end;
end.
