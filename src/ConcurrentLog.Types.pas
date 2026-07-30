{
  ConcurrentLog — a thread-safe logging library for Delphi.

  Shared types. No platform or UI dependency, so this compiles under both
  Delphi and Free Pascal, which is what lets the test suite run in CI without
  a licensed compiler.
}
unit ConcurrentLog.Types;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  {$IFDEF FPC}SysUtils, Classes{$ELSE}System.SysUtils, System.Classes{$ENDIF};

type
  { Ordered from most to least verbose. A logger with a minimum level drops
    everything below it, so the order matters and is relied on. }
  TLogLevel = (llTrace, llDebug, llInfo, llWarn, llError);

  TLogEntry = record
    Timestamp: TDateTime;
    ThreadId: TThreadID;
    Level: TLogLevel;
    Message: string;
  end;

  { A destination for log entries — a file, the console, a buffer.

    A sink does not lock. The logger holds its own lock for the whole dispatch,
    so every sink is called from one thread at a time. Keeping the lock in one
    place is the point: a sink author cannot forget to be thread-safe, because
    thread-safety is not their responsibility. }
  ILogSink = interface
    ['{2F8A1C64-9E3D-4B77-A1F2-6D50E9C7B384}']
    procedure Write(const AEntry: TLogEntry);
  end;

function LogLevelName(ALevel: TLogLevel): string;

{ Renders an entry as a single line:
    2026-07-29 14:03:11.482 [INFO ] (12345) message text }
function FormatLogLine(const AEntry: TLogEntry): string;

implementation

function LogLevelName(ALevel: TLogLevel): string;
begin
  case ALevel of
    llTrace: Result := 'TRACE';
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO ';
    llWarn:  Result := 'WARN ';
    llError: Result := 'ERROR';
  else
    Result := '?????';
  end;
end;

function FormatLogLine(const AEntry: TLogEntry): string;
begin
  Result := Format('%s [%s] (%u) %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp),
     LogLevelName(AEntry.Level),
     {$IFDEF FPC}PtrUInt(AEntry.ThreadId){$ELSE}NativeUInt(AEntry.ThreadId){$ENDIF},
     AEntry.Message]);
end;

end.
