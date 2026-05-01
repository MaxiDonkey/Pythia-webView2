unit Demo.Snippet.Plugin;

interface

uses
  System.SysUtils,
  WVPythia.Command.Plugin, WVPythia.Chat.Interfaces,
  Demo.Snippet.Plugin.Intf;

type
  TSnippetPlugin = class(TCommandPlugin)
  strict private
    FService: ISnippetService;
  strict protected
    function DoExecute(const Action: string;
      const Args: TArray<string>): TCommandExecResult; override;
  public
    constructor Create(const AService: ISnippetService);
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Snippet command plugin

    Command surface

        /snippet save   <name> "<content>"
        /snippet use    <name>
        /snippet show   <name>
        /snippet list
        /snippet rename <oldName> <newName>
        /snippet delete <name>
        /snippet import <jsonFile>
        /snippet export <jsonFile>

      Snippet names are normalized to Trim + ToLowerInvariant. The content
      is stored verbatim, but the slash-command tokenizer requires that any
      multi-word content be enclosed in double quotes. Escape sequences
      are NOT interpreted by the tokenizer, so a literal double-quote
      inside the content cannot be passed in a single command.

    Plugin role

      TSnippetPlugin is intentionally thin. It declares the supported
      actions through AddAction, then delegates execution to ISnippetService.
      Storage, normalization, JSON shape and bubble-write timing all live
      inside the service.

    Note about the original 'append' design

      The initial design listed an 'append' action meant to concatenate a
      stored snippet to whatever the user had already typed in the bubble.
      Implementing it cleanly requires reading the current input contents,
      which IBrowser does not expose today (only SetText / Clear / Welcome
      are public). Two integrator paths exist:

        - extend IBrowser with a BubbleInputAppendText primitive backed by
          a JS function that appends to the textarea, and add the action
          here, or

        - have the service inject a small JS fragment via ExecuteScript
          that targets the textarea element directly.

      Both options go beyond the scope of this demo, which is why 'append'
      is not part of the surface above.

    Registration from the host

      The plugin is host-registered through the OnRegisterCommandPlugins
      hook, identical to any other custom command plugin:

        procedure TForm1.FormCreate(Sender: TObject);
        begin
          Pythia := TFMXPythia.Create(Layout1);
          Pythia.AttachHost(Self);
          Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;

          Pythia.OnRegisterCommandPlugins :=
            procedure
            begin
              FSnippetService := TSnippetService.Create;
              FSnippetService.Browser := Pythia;
              Pythia.CommandLine.RegisterPlugin(
                TSnippetPlugin.Create(FSnippetService));
            end;

          Pythia.Update;
        end;

      The hook fires AFTER the built-in TApiKeyPlugin registration, so
      this plugin co-exists with the built-in /api-key command without
      conflict.
*)

{$ENDREGION}

{ TSnippetPlugin }

constructor TSnippetPlugin.Create(const AService: ISnippetService);
begin
  inherited Create('snippet');
  FService := AService;
  AddAction('save',   2, 2);
  AddAction('use',    1, 1);
  AddAction('show',   1, 1);
  AddAction('list',   0, 0);
  AddAction('rename', 2, 2);
  AddAction('delete', 1, 1);
  AddAction('import', 1, 1);
  AddAction('export', 1, 1);
end;

function TSnippetPlugin.DoExecute(const Action: string;
  const Args: TArray<string>): TCommandExecResult;
var
  Op: TSnippetOperationResult;
begin
  if Action = 'save' then
    Op := FService.Save(Args[0], Args[1])
  else
  if Action = 'use' then
    Op := FService.Use(Args[0])
  else
  if Action = 'show' then
    Op := FService.Show(Args[0])
  else
  if Action = 'list' then
    Op := FService.List
  else
  if Action = 'rename' then
    Op := FService.Rename(Args[0], Args[1])
  else
  if Action = 'delete' then
    Op := FService.Delete(Args[0])
  else
  if Action = 'import' then
    Op := FService.ImportFromFile(Args[0])
  else
  if Action = 'export' then
    Op := FService.ExportToFile(Args[0])
  else
    Exit(TCommandExecResult.Fail('Unmanaged action'));

  if Op.Success then
    Result := TCommandExecResult.Ok(Op.Message)
  else
    Result := TCommandExecResult.Fail(Op.Message);
end;

end.
