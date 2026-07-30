{
  ConcurrentLog — built-in sinks.

  None of these lock. The logger serialises every call into a sink, so a sink
  only ever runs on one thread at a time. See ILogSink in ConcurrentLog.Types.
}
unit ConcurrentLog.Sinks;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils, Classes, Generics.Collections{$ELSE}
  System.SysUtils, System.Classes, System.Generics.Collections{$ENDIF},
  ConcurrentLog.Types;

type
  { Appends each entry as a line to a text file, flushing on every write so a
    crash does not lose the tail of the log. }
  TFileSink = class(TInterfacedObject, ILogSink)
  strict private
    FStream: TFileStream;
    procedure WriteRaw(const ALine: string);
  public
    constructor Create(const AFileName: string; AAppend: Boolean = True);
    destructor Destroy; override;
    procedure Write(const AEntry: TLogEntry);
  end;

  { Writes each entry to standard output. }
  TConsoleSink = class(TInterfacedObject, ILogSink)
  public
    procedure Write(const AEntry: TLogEntry);
  end;

  { Keeps entries in memory. Meant for tests and for inspecting recent activity;
    Snapshot hands back a copy so the caller can read it without racing a
    writer. }
  TMemorySink = class(TInterfacedObject, ILogSink)
  strict private
    FEntries: TList<TLogEntry>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const AEntry: TLogEntry);
    function Count: Integer;
    function Snapshot: TArray<TLogEntry>;
  end;

implementation

{ TFileSink }

constructor TFileSink.Create(const AFileName: string; AAppend: Boolean);
begin
  inherited Create;
  if AAppend and FileExists(AFileName) then
    FStream := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyWrite)
  else
    FStream := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);
  FStream.Seek(0, soEnd);
end;

destructor TFileSink.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

procedure TFileSink.WriteRaw(const ALine: string);
var
  Utf8: UTF8String;
begin
  { UTF8Encode is portable across Delphi and FPC and keeps non-ASCII log
    messages correct on disk. }
  Utf8 := UTF8Encode(ALine);
  if Length(Utf8) > 0 then
    FStream.WriteBuffer(Utf8[1], Length(Utf8));
end;

procedure TFileSink.Write(const AEntry: TLogEntry);
begin
  WriteRaw(FormatLogLine(AEntry) + sLineBreak);
end;

{ TConsoleSink }

procedure TConsoleSink.Write(const AEntry: TLogEntry);
begin
  WriteLn(FormatLogLine(AEntry));
end;

{ TMemorySink }

constructor TMemorySink.Create;
begin
  inherited Create;
  FEntries := TList<TLogEntry>.Create;
end;

destructor TMemorySink.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TMemorySink.Write(const AEntry: TLogEntry);
begin
  FEntries.Add(AEntry);
end;

function TMemorySink.Count: Integer;
begin
  Result := FEntries.Count;
end;

function TMemorySink.Snapshot: TArray<TLogEntry>;
begin
  Result := FEntries.ToArray;
end;

end.
