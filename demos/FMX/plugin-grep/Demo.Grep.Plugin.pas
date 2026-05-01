unit Demo.Grep.Plugin;

interface

uses
  System.SysUtils, System.IOUtils,
  WVPythia.Command.Plugin, WVPythia.Chat.Interfaces, WVPythia.Strings.Escape,
  Demo.Grep.Plugin.Intf;

type
  TGrepPlugin = class(TCommandPlugin)
  strict private
    FService: IGrepService;
  strict protected
    function DoExecute(const Action: string;
      const Args: TArray<string>): TCommandExecResult; override;
  public
    constructor Create(const AService: IGrepService);
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Grep command plugin

    Command surface

        /grep find   <pattern>
        /grep find   <pattern> <subPath>
        /grep dir    <path>
        /grep last
        /grep status

      'find'   runs a literal, case-insensitive substring search under the
               configured root directory (or a sub-path beneath it) and
               opens a picker UI inside the WebView. The user ticks the
               matches that should land in the prompt as context.

      'dir'    updates the root directory used for subsequent 'find' runs.
               The host can also inject the directory at construction time.

      'last'   re-opens the picker for the last search result. Useful if
               the user dismissed the modal and still wants the picks.

      'status' prints the current root directory, last pattern, and last
               result count in the chat.

      The slash-command tokenizer requires that any multi-word value (a
      pattern containing spaces, a path with spaces) be enclosed in double
      quotes. Escape sequences are not interpreted by the tokenizer.

    Plugin role

      TGrepPlugin is intentionally thin. It declares the supported actions
      via AddAction, then delegates execution to IGrepService. Search,
      JSON marshalling, JS injection, and prompt formatting all live inside
      the service.

    Two-way bridge

      Unlike the snippet/git plugins that only push content into the
      bubble, the grep plugin first pushes a picker UI to the WebView, then
      RECEIVES a JSON payload back from the user's selection through the
      custom-event channel. The host adapter must route custom events
      whose name starts with 'grep.' to IGrepService.HandleCustomEvent.

      A minimal wiring inside FMX.WVPythia.Services.pas looks like:

        function TFMXChatManagedItemDialogService.DoActivateCustomEvent(
          const ARawJson: string): Boolean;
        begin
          var Reader := TJsonReader.Parse(ARawJson);
          var EventName := Reader.AsString('name');

          if EventName.StartsWith('grep.') then
            Exit(GrepService.HandleCustomEvent(EventName,
              Reader.AsString('payload', '{}')));

          Result := False;
        end;

    Registration from the host

      The plugin is host-registered through OnRegisterCommandPlugins, the
      same hook used by every custom command plugin:

        procedure TForm1.FormCreate(Sender: TObject);
        begin
          Pythia := TFMXPythia.Create(Layout1);
          Pythia.AttachHost(Self);
          Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;

          Pythia.OnRegisterCommandPlugins :=
            procedure
            begin
              GrepService := TGrepService.Create('C:\path\to\repo');
              GrepService.Browser := Pythia;
              Pythia.CommandLine.RegisterPlugin(
                TGrepPlugin.Create(GrepService));
            end;

          Pythia.Update;
        end;

      Keep a reachable reference to the service (a unit-level variable, a
      form field, or a singleton) so the adapter's DoActivateCustomEvent
      can route incoming events back to it.
*)

{$ENDREGION}

{ TGrepPlugin }

constructor TGrepPlugin.Create(const AService: IGrepService);
begin
  inherited Create('grep');
  FService := AService;
  AddAction('find',   1, 2);
  AddAction('dir',    1, 1);
  AddAction('last',   0, 0);
  AddAction('status', 0, 0);
end;

function TGrepPlugin.DoExecute(const Action: string;
  const Args: TArray<string>): TCommandExecResult;
var
  Op: TGrepOperationResult;
begin
  if Action = 'find' then
    begin
      if Length(Args) = 1 then
        Op := FService.Find(Args[0], '')
      else
        Op := FService.Find(Args[0], Args[1]);
    end
  else
  if Action = 'dir' then
    begin
      var Dir := Args[0].Trim;

      if Dir.IsEmpty then
        Op := TGrepOperationResult.Fail('Grep root directory is empty')
      else
      if not TDirectory.Exists(Dir) then
        Op := TGrepOperationResult.Fail(
          Format('Grep root directory does not exist: %s', [Dir]))
      else
        begin
          FService.RootDir := Dir;

          var Msg := Format('Grep root directory set to "%s"', [Dir]);

          if Assigned(FService.Browser) then
            FService.Browser.DisplaySuccess(
              TEscapeHelper.EscapeJSString(Msg, False));

          {--- Already displayed explicitly. Keep command success semantics,
               but do not rely on the runtime to render the message. }
          Op := TGrepOperationResult.Ok('');
        end;
    end
  else
  if Action = 'last' then
    Op := FService.Last
  else
  if Action = 'status' then
    Op := FService.Status
  else
    Exit(TCommandExecResult.Fail('Unmanaged action'));

  if Op.Success then
    Result := TCommandExecResult.Ok(Op.Message)
  else
    begin
      var Browser := FService.Browser;

      if Assigned(Browser) and not Op.Message.Trim.IsEmpty then
        begin
          Browser.DisplayWarning(
            TEscapeHelper.EscapeJSString(Op.Message, False));

          {--- Error already displayed by the plugin. Keep failure semantics,
               but do not let the command runtime render the same text again. }
          Result := TCommandExecResult.Fail('');
        end
      else
        Result := TCommandExecResult.Fail(Op.Message);
    end;
end;

end.
