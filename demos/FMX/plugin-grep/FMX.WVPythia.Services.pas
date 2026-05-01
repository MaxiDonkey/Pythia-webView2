unit FMX.WVPythia.Services;

interface

uses
  Fmx.Dialogs,
  System.SysUtils, System.JSON,

  WVPythia.Adapter, WVPythia.Chat.ManagedFlow, WVPythia.ManagedItemService,
  WVPythia.JSON.SafeReader,
  Demo.Grep.Plugin.Intf;

type
  TFMXChatManagedItemDialogService = class(TCustomChatManagedItemDialogService)
  protected
    function DoSelectFunctionItem(
      out AItem: TChatManagedItemRef): Boolean; override;

    function DoSelectMCPItem(
      out AItem: TChatManagedItemRef): Boolean; override;

    function DoSelectSkillItem(
      out AItem: TChatManagedItemRef): Boolean; override;

    function DoSelectAgentItem(
      out AItem: TChatManagedItemRef): Boolean; override;

    function DoSelectCustomItem(
      out AItem: TChatManagedItemRef): Boolean; override;

    function DoActivateSystemSettings: Boolean; override;
    function DoActivateModelSelection: Boolean; override;

    function DoActivateInputState(
      const AState: TInputPromptState;
      const AOnFinalize: TManagedItemFinalizeProc): Boolean; override;

    function DoActivateCopyItemEvent(
      const APairId, AKind, AContent: string): Boolean; override;

    function DoActivateCodeCopyItemEvent(
      const ALang, AText: string): Boolean; override;

    function DoActivateNewChatEvent: Boolean; override;

    function DoActivateCardSettingsEvent: Boolean; override;

    function DoActivateAudioInputEvent: Boolean; override;

    {--- Two-way bridge entry point. The framework forwards every JSON
         message whose 'event' field equals 'custom-event' here. We parse
         the payload once and dispatch by 'name' prefix. }
    function DoActivateCustomEvent(const ARawJson: string): Boolean; override;
  end;

  TToolContainer = record
    class function SelectFunctionItem(out AItem: TChatManagedItemRef): Boolean; static;
    class function SelectMCPItem(out AItem: TChatManagedItemRef): Boolean; static;
    class function SelectSkillItem(out AItem: TChatManagedItemRef): Boolean; static;
    class function SelectAgentItem(out AItem: TChatManagedItemRef): Boolean; static;
    class function SelectCustomItem(out AItem: TChatManagedItemRef): Boolean; static;

    class function ActivateSystemPrompt: Boolean; static;
    class function ActivateModelSelection: Boolean; static;
    class function ActivateInputState(
      const AState: TInputPromptState;
      const AOnFinalize: TManagedItemFinalizeProc): Boolean; static;
    class function ActivateCopyItemEvent(
      const APairId, AKind, AContent: string): Boolean; static;
    class function ActivateCodeCopyItemEvent(
      const ALang, AText: string): Boolean; static;
    class function ActivateNewChatEvent: Boolean; static;
    class function ActivateCardSettingsEvent: Boolean; static;
    class function ActivateAudioInputEvent: Boolean; static;
  end;

var
  {--- Set this to the IGrepService instance from the host (Form unit)
       before /grep find runs. The custom-event router below uses it to
       deliver 'grep.*' events back to the plugin service. }
  GrepService: IGrepService = nil;

implementation

uses
  Main; // Form unit; provides Form1.Pythia.

{ TFMXChatManagedItemDialogService }

function TFMXChatManagedItemDialogService.DoActivateCodeCopyItemEvent(
  const ALang, AText: string): Boolean;
begin
  Result := TToolContainer.ActivateCodeCopyItemEvent(ALang, AText);
end;

function TFMXChatManagedItemDialogService.DoActivateCopyItemEvent(const APairId,
  AKind, AContent: string): Boolean;
begin
  Result := TToolContainer.ActivateCopyItemEvent(APairId, AKind, AContent);
end;

function TFMXChatManagedItemDialogService.DoActivateInputState(
  const AState: TInputPromptState;
  const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
  Result := TToolContainer.ActivateInputState(AState, AOnFinalize);
end;

function TFMXChatManagedItemDialogService.DoActivateModelSelection: Boolean;
begin
  Result := TToolContainer.ActivateModelSelection;
end;

function TFMXChatManagedItemDialogService.DoActivateSystemSettings: Boolean;
begin
  Result := TToolContainer.ActivateSystemPrompt;
end;

function TFMXChatManagedItemDialogService.DoActivateAudioInputEvent: Boolean;
begin
  Result := TToolContainer.ActivateAudioInputEvent;
end;

function TFMXChatManagedItemDialogService.DoActivateCardSettingsEvent: Boolean;
begin
  Result := TToolContainer.ActivateCardSettingsEvent;
end;

function TFMXChatManagedItemDialogService.DoActivateNewChatEvent: Boolean;
begin
  Result := TToolContainer.ActivateNewChatEvent;
end;

function TFMXChatManagedItemDialogService.DoActivateCustomEvent(
  const ARawJson: string): Boolean;
{--- Custom-event router.

     ARawJson is the FULL message that arrived from the WebView through
     postMessage, including the 'event', 'name' and 'payload' fields. The
     framework only reads 'event' to decide that this is a custom event;
     it leaves the rest untouched.

     We parse once here, look at 'name' and forward the inner 'payload'
     object as a JSON sub-document to the matching plugin handler. The
     plugin re-parses the payload because the framework does not know its
     schema.

     Returning False signals "not consumed by the host", which lets the
     framework treat the event as unhandled. Plugins should return True
     for events they own. }
var
  Reader: TJsonReader;
  EventName: string;
  PayloadJson: string;
begin
  Reader := TJsonReader.Parse(ARawJson);
  if not Reader.IsValid then
    Exit(False);

  EventName := Reader.AsString('name');
  if EventName.Trim.IsEmpty then
    Exit(False);

  PayloadJson := Reader.ExtractSubJson('payload', '{}');

  if EventName.StartsWith('grep.') and Assigned(GrepService) then
    Exit(GrepService.HandleCustomEvent(EventName, PayloadJson));

  {--- Add other 'name' prefixes here as plugins grow:
       if EventName.StartsWith('myplugin.') then
         Exit(MyService.HandleCustomEvent(EventName, PayloadJson)); }

  Result := False;
end;

function TFMXChatManagedItemDialogService.DoSelectAgentItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := TToolContainer.SelectAgentItem(AItem);
end;

function TFMXChatManagedItemDialogService.DoSelectCustomItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := TToolContainer.SelectCustomItem(AItem);
end;

function TFMXChatManagedItemDialogService.DoSelectFunctionItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := TToolContainer.SelectFunctionItem(AItem);
end;

function TFMXChatManagedItemDialogService.DoSelectMCPItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := TToolContainer.SelectMCPItem(AItem);
end;

function TFMXChatManagedItemDialogService.DoSelectSkillItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := TToolContainer.SelectSkillItem(AItem);
end;

{ TToolContainer }

class function TToolContainer.ActivateCodeCopyItemEvent(const ALang,
  AText: string): Boolean;
begin
  Result := True;
end;

class function TToolContainer.ActivateCopyItemEvent(const APairId, AKind,
  AContent: string): Boolean;
begin
  Result := True;
end;

class function TToolContainer.ActivateInputState(
  const AState: TInputPromptState;
  const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
(*
   NOTE:
   ----

   - In this method, we recommend asynchronous processing to avoid UI blockage.
   - This asynchronous processing must include the `var Returns...` section
     shown below at the end of the process.
*)

  Result := True;
  Form1.Pythia.Display('test...');

  var Returns := TManagedItemLLMResult.Create;
  try
    Returns
      .UsedModel('my_model')
      .Response('test...')
      .Error(False);

    if Assigned(AOnFinalize) then
      AOnFinalize(Returns);

  finally
    Returns.Free;
  end;
end;

class function TToolContainer.ActivateModelSelection: Boolean;
begin
  Result := True;
  ShowMessage('Todo Model selection');
end;

class function TToolContainer.ActivateSystemPrompt: Boolean;
begin
  Result := True;
  ShowMessage('Todo custom settings');
end;

class function TToolContainer.ActivateAudioInputEvent: Boolean;
begin
  Result := True;
  ShowMessage('Todo audio input');
end;

class function TToolContainer.ActivateCardSettingsEvent: Boolean;
begin
  Result := True;
  ShowMessage('Todo settings card');
end;

class function TToolContainer.ActivateNewChatEvent: Boolean;
begin
  Result := True;
end;

class function TToolContainer.SelectAgentItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := True;
  ShowMessage('Todo custom selection: Agent Item');

  {--- Simulated return value here to maintain UI consistency }
  AItem := TChatManagedItemRef.Create(Trunc(Random(20000) + 1).ToString, 'Agent name');
end;

class function TToolContainer.SelectCustomItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := True;
  ShowMessage('Todo custom selection: custom Item');

  {--- Simulated return value here to maintain UI consistency }
  AItem := TChatManagedItemRef.Create(Trunc(Random(20000) + 1).ToString, 'custom service');
end;

class function TToolContainer.SelectFunctionItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := True;
  ShowMessage('Todo custom selection: function Item');

  {--- Simulated return value here to maintain UI consistency }
  AItem := TChatManagedItemRef.Create(Trunc(Random(20000) + 1).ToString, 'Function name');
end;

class function TToolContainer.SelectMCPItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := True;
  ShowMessage('Todo custom selection: MCP Item');

  {--- Simulated return value here to maintain UI consistency }
  AItem := TChatManagedItemRef.Create(Trunc(Random(20000) + 1).ToString, 'MCP-Title');
end;

class function TToolContainer.SelectSkillItem(
  out AItem: TChatManagedItemRef): Boolean;
begin
  Result := True;
  ShowMessage('Todo custom selection: skill Item');

  {--- Simulated return value here to maintain UI consistency }
  AItem := TChatManagedItemRef.Create(Trunc(Random(20000) + 1).ToString, 'custom-skill');
end;

end.
