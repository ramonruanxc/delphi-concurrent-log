unit ConcurrentLog.Tests;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  ConcurrentLog.Testing;

procedure RunTests(ARunner: TTestRunner);

implementation

uses
  {$IFDEF FPC}SysUtils, Classes, Generics.Collections{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections{$ENDIF},
  ConcurrentLog.Types,
  ConcurrentLog.Sinks,
  ConcurrentLog.Logger;

{ ---- level filtering --------------------------------------------------- }

procedure TestLevelFilter(ARunner: TTestRunner);
var
  Logger: TLogger;
  Sink: TMemorySink;
  SinkRef: ILogSink;
begin
  ARunner.Suite('Level filtering');

  Sink := TMemorySink.Create;
  SinkRef := Sink;
  Logger := TLogger.Create(llWarn);
  try
    Logger.AddSink(SinkRef);

    Logger.Info('dropped, below minimum');
    Logger.Debug('dropped, below minimum');
    ARunner.AreEqual('drops entries below the minimum level', 0, Sink.Count);

    Logger.Warn('kept');
    Logger.Error('kept');
    ARunner.AreEqual('keeps entries at or above the minimum level', 2, Sink.Count);

    Logger.MinLevel := llTrace;
    Logger.Trace('now kept');
    ARunner.AreEqual('lowering the minimum lets quieter entries through',
      3, Sink.Count);
  finally
    Logger.Free;
  end;
end;

{ ---- entry contents ---------------------------------------------------- }

procedure TestEntryContents(ARunner: TTestRunner);
var
  Logger: TLogger;
  Sink: TMemorySink;
  SinkRef: ILogSink;
  Entries: TArray<TLogEntry>;
begin
  ARunner.Suite('Entry contents');

  Sink := TMemorySink.Create;
  SinkRef := Sink;
  Logger := TLogger.Create(llTrace);
  try
    Logger.AddSink(SinkRef);
    Logger.Log(llError, 'code %d: %s', [42, 'boom']);

    Entries := Sink.Snapshot;
    ARunner.AreEqual('records exactly one entry', 1, Length(Entries));
    ARunner.AreEqual('formats the message with its arguments',
      'code 42: boom', Entries[0].Message);
    ARunner.IsTrue('records the level', Entries[0].Level = llError);
    ARunner.IsTrue('stamps the calling thread',
      Entries[0].ThreadId = TThread.CurrentThread.ThreadID);
  finally
    Logger.Free;
  end;
end;

{ ---- fan-out to multiple sinks ----------------------------------------- }

procedure TestMultipleSinks(ARunner: TTestRunner);
var
  Logger: TLogger;
  A, B: TMemorySink;
  ARef, BRef: ILogSink;
begin
  ARunner.Suite('Multiple sinks');

  A := TMemorySink.Create;
  B := TMemorySink.Create;
  ARef := A;
  BRef := B;
  Logger := TLogger.Create(llInfo);
  try
    Logger.AddSink(ARef);
    Logger.AddSink(BRef);
    Logger.Info('one message');
    ARunner.AreEqual('reaches the first sink', 1, A.Count);
    ARunner.AreEqual('reaches the second sink', 1, B.Count);
  finally
    Logger.Free;
  end;
end;

{ ---- the concurrency test ---------------------------------------------- }

type
  TWriterThread = class(TThread)
  strict private
    FLogger: TLogger;
    FCount: Integer;
    FId: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(ALogger: TLogger; AId, ACount: Integer);
  end;

constructor TWriterThread.Create(ALogger: TLogger; AId, ACount: Integer);
begin
  inherited Create(True);
  FLogger := ALogger;
  FId := AId;
  FCount := ACount;
  FreeOnTerminate := False;
end;

procedure TWriterThread.Execute;
var
  I: Integer;
begin
  for I := 1 to FCount do
    FLogger.Log(llInfo, 'w%d:%d', [FId, I]);
end;

{ The point of the whole library: many threads log at once and nothing is lost
  or torn.

  Without the lock this fails two ways — TList.Add reallocating from two
  threads corrupts the backing array or loses entries, so the count comes out
  wrong; and a half-built entry becomes visible, so a message comes out
  garbled. The test checks both: the exact total, and that every message
  matches the "wID:sequence" it was written as. }
procedure TestConcurrency(ARunner: TTestRunner);
const
  ThreadCount = 8;
  PerThread = 5000;
var
  Logger: TLogger;
  Sink: TMemorySink;
  SinkRef: ILogSink;
  Threads: array[0..ThreadCount - 1] of TWriterThread;
  I: Integer;
  Entries: TArray<TLogEntry>;
  Seen: TDictionary<string, Boolean>;
  Expected, Msg: string;
  AllWellFormed: Boolean;
  Uniques: Integer;
begin
  ARunner.Suite('Concurrency');

  Sink := TMemorySink.Create;
  SinkRef := Sink;
  Logger := TLogger.Create(llTrace);
  try
    Logger.AddSink(SinkRef);

    for I := 0 to ThreadCount - 1 do
      Threads[I] := TWriterThread.Create(Logger, I, PerThread);
    for I := 0 to ThreadCount - 1 do
      Threads[I].Start;
    for I := 0 to ThreadCount - 1 do
      Threads[I].WaitFor;

    ARunner.AreEqual('every entry from every thread survives',
      ThreadCount * PerThread, Sink.Count);

    { No entry is torn, and none is duplicated: each "wID:seq" must appear
      exactly once across the whole run. }
    Entries := Sink.Snapshot;
    Seen := TDictionary<string, Boolean>.Create;
    try
      AllWellFormed := True;
      for I := 0 to High(Entries) do
      begin
        Msg := Entries[I].Message;
        if (Length(Msg) < 4) or (Msg[1] <> 'w') or (Pos(':', Msg) = 0) then
          AllWellFormed := False;
        Seen.AddOrSetValue(Msg, True);
      end;
      Uniques := Seen.Count;
    finally
      Seen.Free;
    end;

    ARunner.IsTrue('no entry is torn or garbled', AllWellFormed);

    for I := 0 to ThreadCount - 1 do
      Threads[I].Free;

    { ThreadCount * PerThread distinct "wID:seq" strings were written; if the
      count of distinct messages matches, none was lost to a race and none was
      duplicated. }
    Expected := IntToStr(ThreadCount * PerThread);
    ARunner.AreEqual('every message is present exactly once',
      StrToInt(Expected), Uniques);
  finally
    Logger.Free;
  end;
end;

procedure RunTests(ARunner: TTestRunner);
begin
  TestLevelFilter(ARunner);
  TestEntryContents(ARunner);
  TestMultipleSinks(ARunner);
  TestConcurrency(ARunner);
end;

end.
