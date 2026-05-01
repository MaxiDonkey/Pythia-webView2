unit Demo.Git.Plugin.Service;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  WVPythia.Chat.Interfaces, WVPythia.Strings.Escape,
  Demo.Shell.Runner, Demo.Git.Plugin.Intf;

type
  TGitService = class(TInterfacedObject, IGitService)
  strict private const
    GIT_EXECUTABLE     = 'git';
    DEFAULT_TIMEOUT_MS = 5000;
    MAX_OUTPUT_CHARS   = 200000;
    DEFAULT_LOG_COUNT  = 10;
    FENCE              = '````';
  strict private
    FBrowser: IPythiaBrowser;
    FRunner: IShellRunner;
    FWorkingDir: string;
    FTimeoutMs: Cardinal;

    function ValidateWorkingDir(out ErrMsg: string): Boolean;
    function ValidateRefArg(const AArg: string;
      out ErrMsg: string): Boolean;
    function ValidateFileArg(const AArg: string;
      out ErrMsg: string): Boolean;
    function ValidateRangeArg(const AArg: string;
      out ErrMsg: string): Boolean;

    function BaseGitArgs: TArray<string>;
    function RunGit(const ASubArgs: TArray<string>;
      out AResult: TShellRunResult): Boolean;

    function TruncateIfNeeded(const AText: string): string;

    function FailFromShell(
      const AResult: TShellRunResult): TGitOperationResult;

    procedure InjectFenced(const AHeader, AInfoString,
      ABody: string);
    function FinishOk(const AHeader, AInfoString, ABody: string;
      const AOkMessage: string): TGitOperationResult;
  private
    function GetBrowser: IPythiaBrowser;
    procedure SetBrowser(const Value: IPythiaBrowser);
  public
    constructor Create(const ARunner: IShellRunner;
      const AWorkingDir: string;
      const ATimeoutMs: Cardinal = DEFAULT_TIMEOUT_MS);

    property Browser: IPythiaBrowser read GetBrowser write SetBrowser;

    // IGitService
    function Status: TGitOperationResult;
    function Diff(const AReference: string): TGitOperationResult;
    function Staged: TGitOperationResult;
    function Log(const ACount: Integer): TGitOperationResult;
    function Branch: TGitOperationResult;
    function Show(const ARef: string): TGitOperationResult;
    function Blame(const AFile, ARange: string): TGitOperationResult;
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Git command service

    Working directory

      The host injects the working directory at construction time. This
      is the cleanest of the three options listed in the design notes:

        - executable directory  : usually meaningless;
        - GetCurrentDir         : depends on shell state, fragile;
        - host-provided         : the application knows the project the
                                  user is reasoning about (typically the
                                  folder of the currently opened workspace).

      An empty working directory is rejected up-front: there is no
      meaningful default for git context.

    Binary location

      The runner uses CreateProcess(nil, "git ..."), which lets Windows
      resolve git through the PATH. If git is not installed, CreateProcess
      fails with ERROR_FILE_NOT_FOUND and the runner returns
      Success = False with that system message. The service forwards it
      verbatim in the Fail() message; the framework's DispatchCommand
      then renders it through DisplayError.

      No upfront "where git" probe: the failure mode is the same and the
      user gets the actual reason from the OS.

    Error display ownership

      Every failure path in the service returns
      TGitOperationResult.Fail(Msg). The service must NOT call
      FBrowser.DisplayError / DisplayWarning itself: the host framework
      (TFMXBrowserCommandLine.DispatchCommand) already calls
      DisplayError(ExecRes.Message) when the command result is not
      successful. Calling it from both sides shows the same error twice.

      Validator messages must also avoid embedded double-quotes.
      ERROR_DISPLAY_TEMPLATE = '{"type":"erreur","text":"%s"}' is
      formatted via Format() with no JSON escaping, so a stray " in the
      message produces invalid JSON and PostWebMessageAsJson silently
      drops it. The validators use single quotes around their hints
      (e.g. "must not start with '-'") for that reason.

    Forced UTF-8

      Every git invocation prepends:

        -c core.quotepath=false
        -c i18n.logoutputencoding=utf-8

      This guarantees that file names and log output are UTF-8 regardless
      of the user's git configuration, so the runner's UTF-8 decoding
      always produces correct text.

    Argument safety

      The plugin builds the git command line itself (subcommand hard-coded);
      only refs, file paths and line ranges come from the user. To avoid
      option injection (e.g. user-supplied ref starting with "--"), the
      service rejects any user arg that starts with "-". This is restrictive
      but covers all real-world refs, paths and ranges.

      Multi-line, NUL or control characters are also rejected.

    Output size

      MAX_OUTPUT_CHARS = 200 000. Past that, the output is truncated and a
      single-line footer is appended. This keeps the bubble manageable on
      large diffs.

    Bubble write deferral

      Identical pattern to the snippet plugin: the runtime issues
      BubbleInputPartialReset on Ok which clears textarea.value. The
      service uses TThread.ForceQueue to land the SetText AFTER the
      runtime's reset.

    Markdown fence

      Outputs are wrapped in a 4-backtick fence (FENCE) so that the
      typical 3-backtick blocks found inside diffs do not break the
      rendering. The info string ('diff' / 'text') hints at the
      highlighter on the rendering side.
*)

{$ENDREGION}

{ TGitService }

constructor TGitService.Create(const ARunner: IShellRunner;
  const AWorkingDir: string; const ATimeoutMs: Cardinal);
begin
  inherited Create;
  FRunner := ARunner;
  FWorkingDir := AWorkingDir;
  FTimeoutMs := ATimeoutMs;
end;

function TGitService.GetBrowser: IPythiaBrowser;
begin
  Result := FBrowser;
end;

procedure TGitService.SetBrowser(const Value: IPythiaBrowser);
begin
  FBrowser := Value;
end;

function TGitService.ValidateWorkingDir(out ErrMsg: string): Boolean;
begin
  ErrMsg := '';

  if FWorkingDir.Trim.IsEmpty then
    begin
      ErrMsg := 'Git working directory is not set';
      Exit(False);
    end;

  if not TDirectory.Exists(FWorkingDir) then
    begin
      ErrMsg := Format('Git working directory does not exist: %s',
        [FWorkingDir]);
      Exit(False);
    end;

  Result := True;
end;

function TGitService.ValidateRefArg(const AArg: string;
  out ErrMsg: string): Boolean;
begin
  ErrMsg := '';

  if AArg.IsEmpty then
    Exit(True);

  if AArg.StartsWith('-') then
    begin
      ErrMsg := Format(
        'Invalid git reference (must not start with ''-''): %s', [AArg]);
      Exit(False);
    end;

  if AArg.IndexOfAny([#0, #10, #13]) >= 0 then
    begin
      ErrMsg := 'Git reference contains invalid characters';
      Exit(False);
    end;

  Result := True;
end;

function TGitService.ValidateFileArg(const AArg: string;
  out ErrMsg: string): Boolean;
begin
  ErrMsg := '';

  if AArg.Trim.IsEmpty then
    begin
      ErrMsg := 'File argument is empty';
      Exit(False);
    end;

  if AArg.StartsWith('-') then
    begin
      ErrMsg := Format(
        'Invalid file path (must not start with ''-''): %s', [AArg]);
      Exit(False);
    end;

  if AArg.IndexOfAny([#0, #10, #13]) >= 0 then
    begin
      ErrMsg := 'File path contains invalid characters';
      Exit(False);
    end;

  Result := True;
end;

function TGitService.ValidateRangeArg(const AArg: string;
  out ErrMsg: string): Boolean;
begin
  ErrMsg := '';

  if AArg.IsEmpty then
    Exit(True);

  if AArg.StartsWith('-') then
    begin
      ErrMsg := Format(
        'Invalid range (must not start with ''-''): %s', [AArg]);
      Exit(False);
    end;

  if AArg.IndexOfAny([#0, #10, #13, ' ', #9]) >= 0 then
    begin
      ErrMsg := 'Range contains invalid characters';
      Exit(False);
    end;

  Result := True;
end;

function TGitService.BaseGitArgs: TArray<string>;
begin
  {--- Force UTF-8 output regardless of the user's git config. }
  Result := ['-c', 'core.quotepath=false',
             '-c', 'i18n.logoutputencoding=utf-8'];
end;

function TGitService.RunGit(const ASubArgs: TArray<string>;
  out AResult: TShellRunResult): Boolean;
var
  Err: string;
  FullArgs: TArray<string>;
begin
  if not ValidateWorkingDir(Err) then
    begin
      AResult := Default(TShellRunResult);
      AResult.Success := False;
      AResult.ErrorMessage := Err;
      Exit(False);
    end;

  FullArgs := BaseGitArgs + ASubArgs;
  AResult := FRunner.Run(GIT_EXECUTABLE, FullArgs, FWorkingDir, FTimeoutMs);
  Result := AResult.Success;
end;

function TGitService.TruncateIfNeeded(const AText: string): string;
begin
  if AText.Length <= MAX_OUTPUT_CHARS then
    Exit(AText);

  Result :=
    AText.Substring(0, MAX_OUTPUT_CHARS) + sLineBreak +
    Format('[output truncated to %d characters]', [MAX_OUTPUT_CHARS]);
end;

function TGitService.FailFromShell(
  const AResult: TShellRunResult): TGitOperationResult;
begin
  if AResult.TimedOut then
    Exit(TGitOperationResult.Fail(AResult.ErrorMessage));

  {--- Process did not run at all. }
  if not AResult.Success and AResult.ErrorMessage.IsEmpty then
    Exit(TGitOperationResult.Fail('Failed to launch git'));

  if not AResult.Success then
    Exit(TGitOperationResult.Fail(AResult.ErrorMessage));

  {--- Process ran but git itself reported an error. }
  var Msg := AResult.StdErr.Trim;
  if Msg.IsEmpty then
    Msg := Format('git exited with code %d', [AResult.ExitCode]);

  Result := TGitOperationResult.Fail(Msg);
end;

procedure TGitService.InjectFenced(const AHeader, AInfoString,
  ABody: string);
var
  Block: string;
begin
  Block :=
    AHeader + sLineBreak +
    sLineBreak +
    FENCE + AInfoString + sLineBreak +
    TruncateIfNeeded(ABody) + sLineBreak +
    FENCE + sLineBreak;

  {--- Defer the bubble write so it lands AFTER the runtime's
       BubbleInputPartialReset that follows a successful command.

       BubbleInputSetText injects the value verbatim into the SET_INPUT_TEXT
       JSON template via Format() without any escaping. Git output always
       contains line breaks (and often tabs, quotes, backslashes), which
       would produce invalid JSON and silently fail (empty bubble, no error).
       We pre-escape the whole block with EscapeJSString(False) so the
       substitution lands inside a valid JSON string literal. }
  var BrowserRef := FBrowser;
  var Captured := TEscapeHelper.EscapeJSString(Block, False);
  TThread.ForceQueue(nil,
    procedure
    begin
      BrowserRef.BubbleInputSetText(Captured);
    end);
end;

function TGitService.FinishOk(const AHeader, AInfoString, ABody: string;
  const AOkMessage: string): TGitOperationResult;
begin
  if ABody.Trim.IsEmpty then
    Exit(TGitOperationResult.Fail(AHeader + ': empty output'));

  InjectFenced(AHeader, AInfoString, ABody);
  Result := TGitOperationResult.Ok(AOkMessage);
end;

function TGitService.Status: TGitOperationResult;
{--- Prompt text: /git status }
var
  Shell: TShellRunResult;
begin
  if not RunGit(['status', '--short'], Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk('git status --short', 'text', Shell.StdOut, 'status');
end;

function TGitService.Diff(const AReference: string): TGitOperationResult;
{--- Prompt text: /git diff [<ref>] }
var
  Err: string;
  Args: TArray<string>;
  Header: string;
  Shell: TShellRunResult;
begin
  if not ValidateRefArg(AReference, Err) then
    Exit(TGitOperationResult.Fail(Err));

  Args := ['diff'];
  Header := 'git diff';

  if not AReference.IsEmpty then
    begin
      Args := Args + [AReference];
      Header := Header + ' ' + AReference;
    end;

  if not RunGit(Args, Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk(Header, 'diff', Shell.StdOut, 'diff');
end;

function TGitService.Staged: TGitOperationResult;
{--- Prompt text: /git staged }
var
  Shell: TShellRunResult;
begin
  if not RunGit(['diff', '--cached'], Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk('git diff --cached', 'diff', Shell.StdOut, 'staged');
end;

function TGitService.Log(const ACount: Integer): TGitOperationResult;
{--- Prompt text: /git log [<n>] }
var
  Effective: Integer;
  Shell: TShellRunResult;
begin
  if ACount <= 0 then
    Effective := DEFAULT_LOG_COUNT
  else
    Effective := ACount;

  if not RunGit(['log', '--oneline', '-n', IntToStr(Effective)], Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk(
    Format('git log --oneline -n %d', [Effective]),
    'text', Shell.StdOut, 'log');
end;

function TGitService.Branch: TGitOperationResult;
{--- Prompt text: /git branch }
var
  Shell: TShellRunResult;
begin
  if not RunGit(['branch', '--show-current'], Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk('git branch --show-current', 'text', Shell.StdOut,
    'branch');
end;

function TGitService.Show(const ARef: string): TGitOperationResult;
{--- Prompt text: /git show <ref> }
var
  Err: string;
  Shell: TShellRunResult;
begin
  if not ValidateRefArg(ARef, Err) then
    Exit(TGitOperationResult.Fail(Err));

  if ARef.IsEmpty then
    Exit(TGitOperationResult.Fail('Reference is empty'));

  if not RunGit(['show', ARef], Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk(Format('git show %s', [ARef]), 'diff', Shell.StdOut,
    'show');
end;

function TGitService.Blame(const AFile,
  ARange: string): TGitOperationResult;
{--- Prompt text: /git blame <file> [<range>] }
var
  Err: string;
  Args: TArray<string>;
  Header: string;
  Shell: TShellRunResult;
begin
  if not ValidateFileArg(AFile, Err) then
    Exit(TGitOperationResult.Fail(Err));

  if not ValidateRangeArg(ARange, Err) then
    Exit(TGitOperationResult.Fail(Err));

  Args := ['blame'];
  Header := Format('git blame %s', [AFile]);

  if not ARange.IsEmpty then
    begin
      Args := Args + ['-L', ARange];
      Header := Format('git blame -L %s %s', [ARange, AFile]);
    end;

  Args := Args + [AFile];

  if not RunGit(Args, Shell) then
    Exit(FailFromShell(Shell));

  if Shell.ExitCode <> 0 then
    Exit(FailFromShell(Shell));

  Result := FinishOk(Header, 'text', Shell.StdOut, 'blame');
end;

end.
