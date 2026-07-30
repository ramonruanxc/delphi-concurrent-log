{
  ConcurrentLog — the logger.

  A logger fans one log call out to any number of sinks, under a single lock,
  so many threads can log at once without tearing each other's output.

  The design decision that matters: the lock lives here, and only here. Sinks
  do not lock, callers do not lock. Everything a log entry touches between
  "someone called Log" and "every sink has seen it" happens inside one
  critical section, which is the smallest place that can be correct and the
  only place that has to be.
}
unit ConcurrentLog.Logger;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils, Classes, SyncObjs, Generics.Collections{$ELSE}
  System.SysUtils, System.Classes, System.SyncObjs,
  System.Generics.Collections{$ENDIF},
  ConcurrentLog.Types;

type
  TLogger = class
  strict private
    FLock: TCriticalSection;
    FSinks: TList<ILogSink>;
    FMinLevel: TLogLevel;
    function GetMinLevel: TLogLevel;
    procedure SetMinLevel(AValue: TLogLevel);
  public
    constructor Create(AMinLevel: TLogLevel = llInfo);
    destructor Destroy; override;

    { Sinks may be added at any time, including while other threads are
      logging; the change is made under the lock. }
    procedure AddSink(const ASink: ILogSink);

    procedure Log(ALevel: TLogLevel; const AMessage: string); overload;
    procedure Log(ALevel: TLogLevel; const AFormat: string;
      const AArgs: array of const); overload;

    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);

    { Entries below this level are dropped. Readable and writable from any
      thread. }
    property MinLevel: TLogLevel read GetMinLevel write SetMinLevel;
  end;

{ An optional process-wide logger, for code that does not want to thread a
  logger reference through every call. Created before any user code runs and
  destroyed at shutdown, so there is no lazy-initialisation race to get wrong.
  It starts with no sinks; add the ones you want once at startup. }
function GlobalLog: TLogger;

implementation

var
  _GlobalLog: TLogger;

function GlobalLog: TLogger;
begin
  Result := _GlobalLog;
end;

{ TLogger }

constructor TLogger.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSinks := TList<ILogSink>.Create;
  FMinLevel := AMinLevel;
end;

destructor TLogger.Destroy;
begin
  FSinks.Free;
  FLock.Free;
  inherited Destroy;
end;

function TLogger.GetMinLevel: TLogLevel;
begin
  FLock.Enter;
  try
    Result := FMinLevel;
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.SetMinLevel(AValue: TLogLevel);
begin
  FLock.Enter;
  try
    FMinLevel := AValue;
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.AddSink(const ASink: ILogSink);
begin
  if ASink = nil then
    raise Exception.Create('Sink cannot be nil.');
  FLock.Enter;
  try
    FSinks.Add(ASink);
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.Log(ALevel: TLogLevel; const AMessage: string);
var
  Entry: TLogEntry;
  I: Integer;
begin
  { The PROVE_RACE guard exists so the concurrency test can be run with the
    lock removed — `fpc -dPROVE_RACE` — to confirm the test actually detects
    the race it claims to. A normal build never defines it and always locks.
    See the README, "Proving the lock earns its keep." }
  {$IFNDEF PROVE_RACE}FLock.Enter;{$ENDIF}
  try
    { The level check is inside the lock so a concurrent SetMinLevel cannot be
      read half-applied. The cost is negligible next to the sink writes. }
    if ALevel < FMinLevel then
      Exit;

    Entry.Timestamp := Now;
    Entry.ThreadId := TThread.CurrentThread.ThreadID;
    Entry.Level := ALevel;
    Entry.Message := AMessage;

    for I := 0 to FSinks.Count - 1 do
      FSinks[I].Write(Entry);
  finally
    {$IFNDEF PROVE_RACE}FLock.Leave;{$ENDIF}
  end;
end;

procedure TLogger.Log(ALevel: TLogLevel; const AFormat: string;
  const AArgs: array of const);
begin
  Log(ALevel, Format(AFormat, AArgs));
end;

procedure TLogger.Trace(const AMessage: string);
begin
  Log(llTrace, AMessage);
end;

procedure TLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

initialization
  _GlobalLog := TLogger.Create;

finalization
  _GlobalLog.Free;

end.
