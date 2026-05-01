unit Demo.Shell.Runner;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows;

type
  /// <summary>
  /// Outcome of a single Run() call.
  /// <para>
  /// Success = True when the process actually launched and ran to completion
  /// (regardless of its exit code). The exit code, stdout and stderr are valid.
  /// </para>
  /// <para>
  /// Success = False with TimedOut = True means the process was forcefully
  /// terminated by the runner because it exceeded the timeout. StdOut and
  /// StdErr may contain partial output gathered up to that point.
  /// </para>
  /// <para>
  /// Success = False with TimedOut = False means the process could not be
  /// launched at all (executable not found, working directory invalid, ...).
  /// ErrorMessage describes the cause.
  /// </para>
  /// </summary>
  TShellRunResult = record
    Success: Boolean;
    ExitCode: Integer;
    StdOut: string;
    StdErr: string;
    TimedOut: Boolean;
    ErrorMessage: string;
  end;

  /// <summary>
  /// Generic blocking process runner with stdout / stderr capture and a
  /// hard timeout. Reusable by any future command plugin that needs to
  /// shell out to an external binary (/git, /npm, /docker logs, ...).
  /// </summary>
  IShellRunner = interface
    ['{3D4E1A8F-7B2C-4F94-8D5E-A2C9B7D4F6E1}']
    function Run(const AExecutable: string; const AArgs: TArray<string>;
      const AWorkingDir: string; const ATimeoutMs: Cardinal): TShellRunResult;
  end;

  /// <summary>
  /// Default Windows implementation. Uses CreateProcess + anonymous pipes.
  /// Stdout and stderr are captured concurrently by two reader threads to
  /// avoid the well-known pipe-buffer deadlock.
  /// </summary>
  TShellRunner = class(TInterfacedObject, IShellRunner)
  public
    function Run(const AExecutable: string; const AArgs: TArray<string>;
      const AWorkingDir: string; const ATimeoutMs: Cardinal): TShellRunResult;
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Shell runner

    Why a new abstraction

      The project ships TProcessExecute (Windows.Process.Execution.pas), but
      it only calls ShellExecute and discards stdout. Command plugins that
      want the OUTPUT of a process (git, npm, docker, ...) need a different
      primitive: launch, wait, capture both streams, enforce a timeout,
      surface the exit code.

      IShellRunner is that primitive. It deliberately stays generic so that
      future plugins can share it without each one re-implementing pipe
      management.

    Why two reader threads

      Anonymous pipe buffers on Windows are typically 4 KB to 64 KB. If a
      child process writes a lot to stdout while its stderr buffer is full
      (or vice versa), it blocks on WriteFile. The parent must then drain
      both pipes concurrently, otherwise it deadlocks: the parent waits on
      the process, the process waits for the parent to read.

      The runner spawns one TPipeReader per pipe; each reader owns its
      handle and closes it on destruction. ReadFile in the reader exits
      naturally when the write end is closed (child exit or termination).

    Timeout policy

      Run waits on the process handle for ATimeoutMs. On WAIT_TIMEOUT it
      calls TerminateProcess, then waits indefinitely for the child to
      actually be gone (which closes its write ends). Reader threads then
      exit, the runner gathers partial output and returns TimedOut = True.

      The caller decides what timeout is acceptable. A demo /git plugin
      typically uses 5 s; a /docker logs plugin might allow 30 s.

    Command-line quoting

      Args are wrapped in "..." when they contain space, tab or quote.
      Embedded quotes are escaped as \". This is sufficient for typical
      git refs, file paths and line ranges, but NOT a general-purpose
      Win32 quoting routine. Plugin services should additionally validate
      args against option-injection (refusing args that start with '-').

    UTF-8 assumption

      Both pipes are decoded as UTF-8. For git, callers should pass
      "-c core.quotepath=false -c i18n.logoutputencoding=utf-8" through
      AArgs to force UTF-8 output regardless of the user's git config.
      For other tools, this concern moves to the calling service.

      Decoding is non-strict: see DecodeUtf8Lossy. Both TEncoding.UTF8
      and TEncoding.GetEncoding(CP_UTF8) instantiate the same
      TUTF8Encoding class, which runs MultiByteToWideChar with
      MB_ERR_INVALID_CHARS and raises EEncodingError on the first
      malformed byte ("Aucun mappage pour le caractère Unicode..." on
      a French Windows). git diff emits file content byte-for-byte and
      i18n.logoutputencoding has no effect on it, so any tracked file
      saved in CP1252 (or any non-UTF-8 encoding) would otherwise blow
      up the whole call. Calling MultiByteToWideChar directly with
      dwFlags = 0 substitutes U+FFFD and lets the caller surface
      whatever git produced.
*)

{$ENDREGION}

type
  TPipeReader = class(TThread)
  strict private
    FPipe: THandle;
    FBuffer: TBytesStream;
  protected
    procedure Execute; override;
  public
    constructor Create(APipe: THandle);
    destructor Destroy; override;
    function GetBytes: TBytes;
  end;

{ TPipeReader }

constructor TPipeReader.Create(APipe: THandle);
begin
  inherited Create(False);
  FPipe := APipe;
  FBuffer := TBytesStream.Create;
end;

destructor TPipeReader.Destroy;
begin
  if FPipe <> 0 then
    CloseHandle(FPipe);
  FBuffer.Free;
  inherited;
end;

procedure TPipeReader.Execute;
const
  CHUNK = 4096;
var
  Buf: array[0..CHUNK - 1] of Byte;
  NumRead: DWORD;
begin
  while not Terminated do
    begin
      NumRead := 0;
      if not ReadFile(FPipe, Buf, CHUNK, NumRead, nil) then
        Break;
      if NumRead = 0 then
        Break;
      FBuffer.WriteBuffer(Buf, NumRead);
    end;
end;

function TPipeReader.GetBytes: TBytes;
begin
  Result := Copy(FBuffer.Bytes, 0, FBuffer.Size);
end;

{--- NOTE: Lossy UTF-8 decode.

     TEncoding.UTF8 (and TEncoding.GetEncoding(CP_UTF8), which returns the
     same TUTF8Encoding class) is built with MB_ERR_INVALID_CHARS, so any
     invalid byte sequence raises EEncodingError.

     Going through MultiByteToWideChar with dwFlags = 0 lets Windows
     substitute invalid sequences with U+FFFD instead of failing. }
function DecodeUtf8Lossy(const Bytes: TBytes): string;
begin
  if Length(Bytes) = 0 then
    Exit('');

  var WLen := MultiByteToWideChar(CP_UTF8, 0,
    PAnsiChar(@Bytes[0]), Length(Bytes), nil, 0);
  if WLen <= 0 then
    Exit('');

  SetLength(Result, WLen);
  MultiByteToWideChar(CP_UTF8, 0,
    PAnsiChar(@Bytes[0]), Length(Bytes), PChar(Result), WLen);
end;

function QuoteIfNeeded(const S: string): string;
begin
  if S.IsEmpty then
    Exit('""');

  if S.IndexOfAny([' ', #9, '"']) < 0 then
    Exit(S);

  Result := '"' + S.Replace('"', '\"') + '"';
end;

function BuildCommandLine(const Exe: string;
  const Args: TArray<string>): string;
begin
  Result := QuoteIfNeeded(Exe);
  for var A in Args do
    Result := Result + ' ' + QuoteIfNeeded(A);
end;

function MakeFail(const AMessage: string): TShellRunResult;
begin
  Result := Default(TShellRunResult);
  Result.Success := False;
  Result.ErrorMessage := AMessage;
end;

{ TShellRunner }

function TShellRunner.Run(const AExecutable: string;
  const AArgs: TArray<string>; const AWorkingDir: string;
  const ATimeoutMs: Cardinal): TShellRunResult;
var
  SecAttr: TSecurityAttributes;
  OutR, OutW, ErrR, ErrW: THandle;
  SI: TStartupInfo;
  PI: TProcessInformation;
  WorkDirPtr: PChar;
  CmdLine: string;
  CmdLineBuf: array of Char;
  ExitCode: DWORD;
  WaitRes: DWORD;
begin
  Result := Default(TShellRunResult);

  SecAttr.nLength := SizeOf(SecAttr);
  SecAttr.lpSecurityDescriptor := nil;
  SecAttr.bInheritHandle := True;

  OutR := 0; OutW := 0; ErrR := 0; ErrW := 0;

  if not CreatePipe(OutR, OutW, @SecAttr, 0) then
    Exit(MakeFail('CreatePipe (stdout) failed'));

  if not SetHandleInformation(OutR, HANDLE_FLAG_INHERIT, 0) then
    begin
      CloseHandle(OutR);
      CloseHandle(OutW);
      Exit(MakeFail('SetHandleInformation (stdout) failed'));
    end;

  if not CreatePipe(ErrR, ErrW, @SecAttr, 0) then
    begin
      CloseHandle(OutR);
      CloseHandle(OutW);
      Exit(MakeFail('CreatePipe (stderr) failed'));
    end;

  if not SetHandleInformation(ErrR, HANDLE_FLAG_INHERIT, 0) then
    begin
      CloseHandle(OutR); CloseHandle(OutW);
      CloseHandle(ErrR); CloseHandle(ErrW);
      Exit(MakeFail('SetHandleInformation (stderr) failed'));
    end;

  CmdLine := BuildCommandLine(AExecutable, AArgs);

  {--- CreateProcessW requires a writable command-line buffer. }
  SetLength(CmdLineBuf, Length(CmdLine) + 1);
  Move(PChar(CmdLine)^, CmdLineBuf[0],
    (Length(CmdLine) + 1) * SizeOf(Char));

  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  SI.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
  SI.hStdOutput := OutW;
  SI.hStdError := ErrW;

  ZeroMemory(@PI, SizeOf(PI));

  if AWorkingDir = '' then
    WorkDirPtr := nil
  else
    WorkDirPtr := PChar(AWorkingDir);

  if not CreateProcess(nil, PChar(@CmdLineBuf[0]), nil, nil, True,
    CREATE_NO_WINDOW, nil, WorkDirPtr, SI, PI) then
    begin
      var LastErr := GetLastError;
      CloseHandle(OutR); CloseHandle(OutW);
      CloseHandle(ErrR); CloseHandle(ErrW);
      Exit(MakeFail(SysErrorMessage(LastErr)));
    end;

  {--- The parent must close its inheritable copies of the write ends so
       that ReadFile returns EOF once the child terminates. }
  CloseHandle(OutW); OutW := 0;
  CloseHandle(ErrW); ErrW := 0;

  {--- Each reader takes ownership of its read handle and closes it on
       destruction. }
  var OutReader := TPipeReader.Create(OutR); OutR := 0;
  var ErrReader := TPipeReader.Create(ErrR); ErrR := 0;
  try
    WaitRes := WaitForSingleObject(PI.hProcess, ATimeoutMs);
    if WaitRes = WAIT_TIMEOUT then
      begin
        TerminateProcess(PI.hProcess, 1);
        WaitForSingleObject(PI.hProcess, INFINITE);
        Result.TimedOut := True;
      end;

    OutReader.WaitFor;
    ErrReader.WaitFor;

    Result.StdOut := DecodeUtf8Lossy(OutReader.GetBytes);
    Result.StdErr := DecodeUtf8Lossy(ErrReader.GetBytes);
  finally
    OutReader.Free;
    ErrReader.Free;
  end;

  ExitCode := 1;
  GetExitCodeProcess(PI.hProcess, ExitCode);
  CloseHandle(PI.hThread);
  CloseHandle(PI.hProcess);

  if Result.TimedOut then
    begin
      Result.Success := False;
      Result.ExitCode := -1;
      Result.ErrorMessage :=
        Format('Process timed out after %d ms', [ATimeoutMs]);
    end
  else
    begin
      Result.Success := True;
      Result.ExitCode := Integer(ExitCode);
    end;
end;

end.
