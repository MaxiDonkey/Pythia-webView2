unit Demo.Git.Plugin;

interface

uses
  System.SysUtils,
  WVPythia.Command.Plugin, WVPythia.Chat.Interfaces,
  Demo.Git.Plugin.Intf;

type
  TGitPlugin = class(TCommandPlugin)
  strict private
    FService: IGitService;
    function ParseLogCount(const AArgs: TArray<string>;
      out ACount: Integer): Boolean;
  strict protected
    function DoExecute(const Action: string;
      const Args: TArray<string>): TCommandExecResult; override;
  public
    constructor Create(const AService: IGitService);
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Git command plugin

    Command surface

        /git status
        /git diff   [<ref>]
        /git staged
        /git log    [<n>]
        /git branch
        /git show   <ref>
        /git blame  <file> [<range>]

      The plugin is intentionally thin: it declares actions through
      AddAction and delegates execution to IGitService. Argument parsing
      is limited to "did the user pass a positive integer to /git log".
      Everything else (refs, file paths, ranges) flows through the service
      validators.

    What this plugin does NOT do

      - Arbitrary git commands. There is no "/git raw <cmdline>". Each
        action maps to a fixed git subcommand, with user-supplied refs /
        files / ranges only. This is the security boundary. If you need
        free-form shell access, write a separate /shell plugin and
        document its threat model explicitly.

      - Auto-submission. The output is injected into the bubble; the user
        adds their question and submits when ready.

      - Async work. DoExecute remains synchronous. Long git operations
        are bounded by the service's timeout (default 5 s), enforced by
        the underlying shell runner. If your repo legitimately needs
        more (e.g. /git log on a million-commit history), raise the
        timeout at construction.

    Registration from the host

      The plugin is host-registered through OnRegisterCommandPlugins,
      together with its dependencies:

        procedure TForm1.FormCreate(Sender: TObject);
        begin
          Pythia := TFMXBrowser.Create(Layout1);
          Pythia.AttachHost(Self);
          Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;

          Pythia.OnRegisterCommandPlugins :=
            procedure
            begin
              FRunner := TShellRunner.Create;
              FGitService := TGitService.Create(FRunner, 'C:\path\to\repo');
              FGitService.Browser := Pythia;
              Pythia.CommandLine.RegisterPlugin(
                TGitPlugin.Create(FGitService));
            end;

          Pythia.Update;
        end;

      The working directory is the repository root that "git" should
      operate against. The host application owns this choice (the user
      may have a project picker, a recent-folder list, etc.) and passes
      it explicitly. There is no implicit fallback.
*)

{$ENDREGION}

{ TGitPlugin }

constructor TGitPlugin.Create(const AService: IGitService);
begin
  inherited Create('git');
  FService := AService;
  AddAction('status', 0, 0);
  AddAction('diff',   0, 1);
  AddAction('staged', 0, 0);
  AddAction('log',    0, 1);
  AddAction('branch', 0, 0);
  AddAction('show',   1, 1);
  AddAction('blame',  1, 2);
end;

function TGitPlugin.ParseLogCount(const AArgs: TArray<string>;
  out ACount: Integer): Boolean;
begin
  ACount := 0;

  if Length(AArgs) = 0 then
    Exit(True);

  if not TryStrToInt(AArgs[0], ACount) then
    Exit(False);

  Result := ACount > 0;
end;

function TGitPlugin.DoExecute(const Action: string;
  const Args: TArray<string>): TCommandExecResult;
var
  Op: TGitOperationResult;
  RefArg: string;
  RangeArg: string;
  LogCount: Integer;
begin
  if Action = 'status' then
    Op := FService.Status
  else
  if Action = 'diff' then
    begin
      if Length(Args) >= 1 then RefArg := Args[0] else RefArg := '';
      Op := FService.Diff(RefArg);
    end
  else
  if Action = 'staged' then
    Op := FService.Staged
  else
  if Action = 'log' then
    begin
      if not ParseLogCount(Args, LogCount) then
        Exit(TCommandExecResult.Fail(
          'Argument must be a positive integer'));
      Op := FService.Log(LogCount);
    end
  else
  if Action = 'branch' then
    Op := FService.Branch
  else
  if Action = 'show' then
    Op := FService.Show(Args[0])
  else
  if Action = 'blame' then
    begin
      if Length(Args) >= 2 then RangeArg := Args[1] else RangeArg := '';
      Op := FService.Blame(Args[0], RangeArg);
    end
  else
    Exit(TCommandExecResult.Fail('Unmanaged action'));

  if Op.Success then
    Result := TCommandExecResult.Ok(Op.Message)
  else
    Result := TCommandExecResult.Fail(Op.Message);
end;

end.
