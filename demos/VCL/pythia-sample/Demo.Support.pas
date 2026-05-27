unit Demo.Support;

interface

uses
  System.SysUtils, System.Classes, System.Threading,
  Vcl.ControlList, Vcl.ExtCtrls,
  VCL.WVPythia.Chat, WVPythia.Types, WVPythia.Chat.Interfaces,
  Demo.ContentComposer;

const
  MaxSubMenuIndex = 3;
  MaxDiscoveryIndex = 5;

type
  TDelayedSupport = record
    class procedure Run(const ParamProc: TProc; const WaitingPeriod: Cardinal = 700); static;
  end;

  TCheckComponent = class
  private
    FBrowser: TVCLPythia;
    FContentComposer: TContentComposer;
    FSubMenuPages: array[0..MaxSubMenuIndex] of TPanel;
    FCurrentSubMenu: Integer;
    FDiscoveryPages: array[0..MaxDiscoveryIndex] of TPanel;
    FCurrentDiscovery: Integer;
    procedure CustomPanelApply(Sender: TObject; CustomPanel: TCustomPanel);
    procedure ButtonVisibilityApply(Sender: TObject; Button: TEnabledButton);
    procedure CapabilitiesApply(Sender: TObject; ParamProc: TProc<Boolean>);
    procedure SubMenuCapabilitiesApply(Sender: TObject; ParamProc: TProc<Boolean>);
    procedure NextSubMenu(Sender: TObject);
    procedure PreviousSubMenu(Sender: TObject);
    procedure NextDiscovery(Sender: TObject);
    procedure PreviousDiscovery(Sender: TObject);
    procedure ShowSubMenu(const Index: Integer);
    procedure ShowDiscovery(const Index: Integer);
    procedure UpdateSubMenuLabel;
    procedure UpdateDiscoveryLabel;
  public
    procedure CustomParameters(Sender: TObject);
    procedure CustomModels(Sender: TObject);
    procedure CustomCards(Sender: TObject);
    procedure FunctionButtonVisible(Sender: TObject);
    procedure MicrophoneButtonVisible(Sender: TObject);
    procedure ParametersButtonVisible(Sender: TObject);
    procedure ModelsButtonVisible(Sender: TObject);
    procedure ProjectButtonVisible(Sender: TObject);
    procedure EndpointVisible(Sender: TObject);
    procedure WebReseachVisible(Sender: TObject);
    procedure ReasoningVisible(Sender: TObject);
    procedure AttachFileVisible(Sender: TObject);
    procedure KnowledgeSearchVisible(Sender: TObject);
    procedure VisionVisible(Sender: TObject);
    procedure DeepResearchVisible(Sender: TObject);
    procedure IntegrationVisible(Sender: TObject);
    procedure MediaVisible(Sender: TObject);
    procedure CustomVisible(Sender: TObject);
    procedure EndpointChatCompletionVisible(Sender: TObject);
    procedure EndpointChatResponseVisible(Sender: TObject);
    procedure EndpointMessageVisible(Sender: TObject);
    procedure EndpointGenerateContentVisible(Sender: TObject);
    procedure EndpointInteractionsVisible(Sender: TObject);
    procedure EndpointConversationVisible(Sender: TObject);
    procedure ThinkingLowVisible(Sender: TObject);
    procedure ThinkingMediumVisible(Sender: TObject);
    procedure ThinkingHighVisible(Sender: TObject);
    procedure IntegrationFunctionVisible(Sender: TObject);
    procedure IntegrationMcpVisible(Sender: TObject);
    procedure IntegrationSkillsVisible(Sender: TObject);
    procedure IntegrationAgentsVisible(Sender: TObject);
    procedure MediaCreateImageVisible(Sender: TObject);
    procedure MediaCreateVideoVisible(Sender: TObject);
    procedure MediaCreateAudioVisible(Sender: TObject);
    procedure MediaSpeechToTextVisible(Sender: TObject);
    procedure MediaTextToSpeechVisible(Sender: TObject);

    procedure DisplayImageGenerated(Sender: TObject);
    procedure DisplayAudioGenerated(Sender: TObject);
    procedure DisplayVideoGenerated(Sender: TObject);
    procedure DisplayFilesGenerated(Sender: TObject);
    procedure ImageAttachedToThePrompt(Sender: TObject);
    procedure FilesAttachedToThePrompt(Sender: TObject);
    procedure ImagesAndFilesAttached(Sender: TObject);
    procedure PromptsVeryLong(Sender: TObject);
    procedure LaTeXUsing(Sender: TObject);
    procedure CodeAndArrayUsing(Sender: TObject);
    procedure CreateSessionByCode(Sender: TObject);
    procedure CreateSessionAboutReadme(Sender: TObject);

    procedure ModelListJsonEdition(Sender: TObject);
    procedure ModelGetReplaceVersion(Sender: TObject);
    procedure CapabilitiesEdition(Sender: TObject);
    procedure CustomTemplateEdition(Sender: TObject);

    procedure FunctionCardEdition(Sender: TObject);
    procedure McpCardEdition(Sender: TObject);
    procedure SkillsCardEdition(Sender: TObject);
    procedure AgentsCardEdition(Sender: TObject);
    procedure CustomCardEdition(Sender: TObject);

    procedure DialogServiceError(Sender: TObject);
    procedure DefaultModelError(Sender: TObject);
    procedure HowToStart(Sender: TObject);

    constructor Create;
    destructor Destroy; override;
  end;

  TDidacticCustomProc = record
    class function MyChatContentBuilder: Boolean; static;
  end;

var
  CheckComponent: TCheckComponent;

implementation

uses
  Main, VCL.Dialogs, WVPythia.Strings.Escape;

{ TCheckComponent }

procedure TCheckComponent.AgentsCardEdition(Sender: TObject);
begin
  FContentComposer.AgentsCardEdition;
end;

procedure TCheckComponent.AttachFileVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Files(Value)
        .Update;
    end);
end;

procedure TCheckComponent.ButtonVisibilityApply(Sender: TObject;
  Button: TEnabledButton);
begin
  var Component := (Sender as TControlListCheckBox);

  if Component.Checked then
    FBrowser.EnabledButtons := FBrowser.EnabledButtons + [Button]
  else
    FBrowser.EnabledButtons := FBrowser.EnabledButtons - [Button];
end;

procedure TCheckComponent.CapabilitiesApply(Sender: TObject; ParamProc: TProc<Boolean>);
begin
  if not Assigned(ParamProc) then
    Exit;

  var Component := (Sender as TControlListCheckBox);

  ParamProc(Component.Checked);
  FBrowser.BubbleInputMenuOpen;
end;

procedure TCheckComponent.CapabilitiesEdition(Sender: TObject);
begin
  FContentComposer.CapabilitiesEdition;
end;

procedure TCheckComponent.CodeAndArrayUsing(Sender: TObject);
begin
  FContentComposer.CodeAndArrayUsing;
end;

procedure TCheckComponent.EndpointChatCompletionVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .EndpointChatCompletion(Value)
        .Update;
    end);
end;

procedure TCheckComponent.EndpointChatResponseVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .EndpointChatResponse(Value)
        .Update;
    end);
end;

procedure TCheckComponent.EndpointConversationVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .EndpointConversation(Value)
        .Update;
    end);
end;

procedure TCheckComponent.EndpointGenerateContentVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .EndpointGenerateContent(Value)
        .Update;
    end);
end;

procedure TCheckComponent.EndpointInteractionsVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .EndpointInteractions(Value)
        .Update;
    end);
end;

procedure TCheckComponent.EndpointMessageVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .EndpointMessage(Value)
        .Update;
    end);
end;

constructor TCheckComponent.Create;
begin
  inherited Create;
  FBrowser := Form1.Pythia;
  FContentComposer := TContentComposer.Create(FBrowser);
  FSubMenuPages[0] := Form1.Panel3;
  FSubMenuPages[1] := Form1.Panel4;
  FSubMenuPages[2] := Form1.Panel5;
  FSubMenuPages[3] := Form1.Panel6;
  FCurrentSubMenu := 0;
  UpdateSubMenuLabel;

  Form1.SpeedButton1.OnClick := PreviousSubMenu;
  Form1.SpeedButton2.OnClick := NextSubMenu;

  FDiscoveryPages[0] := Form1.Panel7;
  FDiscoveryPages[1] := Form1.Panel8;
  FDiscoveryPages[2] := Form1.Panel9;
  FDiscoveryPages[3] := Form1.Panel10;
  FDiscoveryPages[4] := Form1.Panel11;
  FDiscoveryPages[5] := Form1.Panel12;
  FCurrentDiscovery := 0;
  UpdateDiscoveryLabel;

  Form1.SpeedButton3.OnClick := PreviousDiscovery;
  Form1.SpeedButton4.OnClick := NextDiscovery;

  Form1.ControlListCheckBox1.OnClick := CustomParameters;
  Form1.ControlListCheckBox2.OnClick := CustomModels;
  Form1.ControlListCheckBox3.OnClick := CustomCards;
  Form1.ControlListCheckBox4.OnClick := FunctionButtonVisible;
  Form1.ControlListCheckBox5.OnClick := MicrophoneButtonVisible;
  Form1.ControlListCheckBox6.OnClick := ParametersButtonVisible;
  Form1.ControlListCheckBox7.OnClick := ModelsButtonVisible;
  Form1.ControlListCheckBox36.OnClick := ProjectButtonVisible;

  Form1.ControlListCheckBox8.OnClick := EndpointVisible;
  Form1.ControlListCheckBox9.OnClick := WebReseachVisible;
  Form1.ControlListCheckBox10.OnClick := ReasoningVisible;
  Form1.ControlListCheckBox11.OnClick := AttachFileVisible;
  Form1.ControlListCheckBox12.OnClick := KnowledgeSearchVisible;
  Form1.ControlListCheckBox13.OnClick := VisionVisible;
  Form1.ControlListCheckBox14.OnClick := DeepResearchVisible;
  Form1.ControlListCheckBox15.OnClick := IntegrationVisible;
  Form1.ControlListCheckBox16.OnClick := MediaVisible;
  Form1.ControlListCheckBox17.OnClick := CustomVisible;

  // Sub menus
  Form1.ControlListCheckBox18.OnClick := EndpointChatCompletionVisible;
  Form1.ControlListCheckBox19.OnClick := EndpointChatResponseVisible;
  Form1.ControlListCheckBox20.OnClick := EndpointMessageVisible;
  Form1.ControlListCheckBox21.OnClick := EndpointGenerateContentVisible;
  Form1.ControlListCheckBox22.OnClick := EndpointInteractionsVisible;
  Form1.ControlListCheckBox23.OnClick := EndpointConversationVisible;

  Form1.ControlListCheckBox24.OnClick := ThinkingLowVisible;
  Form1.ControlListCheckBox25.OnClick := ThinkingMediumVisible;
  Form1.ControlListCheckBox26.OnClick := ThinkingHighVisible;

  Form1.ControlListCheckBox27.OnClick := IntegrationFunctionVisible;
  Form1.ControlListCheckBox28.OnClick := IntegrationMcpVisible;
  Form1.ControlListCheckBox29.OnClick := IntegrationSkillsVisible;
  Form1.ControlListCheckBox30.OnClick := IntegrationAgentsVisible;

  Form1.ControlListCheckBox31.OnClick := MediaCreateImageVisible;
  Form1.ControlListCheckBox32.OnClick := MediaCreateVideoVisible;
  Form1.ControlListCheckBox33.OnClick := MediaCreateAudioVisible;
  Form1.ControlListCheckBox34.OnClick := MediaSpeechToTextVisible;
  Form1.ControlListCheckBox35.OnClick := MediaTextToSpeechVisible;

  // Display tests
  Form1.Label38.OnClick := DisplayImageGenerated;
  Form1.Label40.OnClick := DisplayAudioGenerated;
  Form1.Label41.OnClick := DisplayVideoGenerated;
  Form1.Label42.OnClick := DisplayFilesGenerated;
  Form1.Label44.OnClick := ImageAttachedToThePrompt;
  Form1.Label45.OnClick := FilesAttachedToThePrompt;
  Form1.Label46.OnClick := ImagesAndFilesAttached;
  Form1.Label47.OnClick := PromptsVeryLong;
  Form1.Label49.OnClick := LaTeXUsing;
  Form1.Label50.OnClick := CodeAndArrayUsing;
  Form1.Label52.OnClick := CreateSessionByCode;
  Form1.Label53.OnClick := CreateSessionAboutReadme;
  Form1.Label55.OnClick := ModelListJsonEdition;
  Form1.Label56.OnClick := CapabilitiesEdition;
  Form1.Label57.OnClick := CustomTemplateEdition;
  Form1.Label59.OnClick := FunctionCardEdition;
  Form1.Label60.OnClick := McpCardEdition;
  Form1.Label61.OnClick := SkillsCardEdition;
  Form1.Label62.OnClick := AgentsCardEdition;
  Form1.Label63.OnClick := CustomCardEdition;
  Form1.Label64.OnClick := ModelGetReplaceVersion;

  Form1.SpeedButton5.OnClick := DialogServiceError;
  Form1.SpeedButton6.OnClick := DefaultModelError;
  Form1.SpeedButton7.OnClick := HowToStart;
end;

procedure TCheckComponent.CreateSessionAboutReadme(Sender: TObject);
begin
  FContentComposer.CreateSessionAboutReadme;
end;

procedure TCheckComponent.CreateSessionByCode(Sender: TObject);
begin
  FContentComposer.CreateSessionByCode;
end;

procedure TCheckComponent.CustomCardEdition(Sender: TObject);
begin
  FContentComposer.CustomCardEdition;
end;

procedure TCheckComponent.CustomCards(Sender: TObject);
begin
  CustomPanelApply(Sender, cpCards);

  var WarningMessage := TEscapeHelper.EscapeJSString(
    'Now click on "custom" or "Integration" and choosing a function: '#10'Function, MCP, Skills or Agents',
    False
  );
  FBrowser.DisplayWarning(WarningMessage);
end;

procedure TCheckComponent.CustomModels(Sender: TObject);
begin
  CustomPanelApply(Sender, cpModels);

  var WarningMessage := TEscapeHelper.EscapeJSString('Now click on the "Model" button', False);
  FBrowser.DisplayWarning(WarningMessage);
end;

procedure TCheckComponent.CustomPanelApply(Sender: TObject; CustomPanel: TCustomPanel);
begin
  var Component := (Sender as TControlListCheckBox);

  if Component.Checked then
    FBrowser.CustomPanels := FBrowser.CustomPanels + [CustomPanel]
  else
    FBrowser.CustomPanels := FBrowser.CustomPanels - [CustomPanel];

  FBrowser.BubbleInputMenuOpen;
end;

procedure TCheckComponent.CustomParameters(Sender: TObject);
begin
  CustomPanelApply(Sender, cpSettings);

  var WarningMessage := TEscapeHelper.EscapeJSString('Now click on the "Settings" button', False);
  FBrowser.DisplayWarning(WarningMessage);
end;

procedure TCheckComponent.CustomTemplateEdition(Sender: TObject);
begin
  FContentComposer.CustomTemplateEdition;
end;

procedure TCheckComponent.CustomVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Custom(Value)
        .Update;
    end);
end;

procedure TCheckComponent.DeepResearchVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .DeepResearch(Value)
        .Update;
    end);
end;

procedure TCheckComponent.DefaultModelError(Sender: TObject);
begin
  FContentComposer.DefaultModelError;
end;

destructor TCheckComponent.Destroy;
begin
  FContentComposer.Free;
  inherited;
end;

procedure TCheckComponent.DialogServiceError(Sender: TObject);
begin
  FContentComposer.DialogServiceError;
end;

procedure TCheckComponent.DisplayAudioGenerated(Sender: TObject);
begin
  FContentComposer.DisplayAudioGenerated;
end;

procedure TCheckComponent.DisplayFilesGenerated(Sender: TObject);
begin
  FContentComposer.DisplayFilesGenerated;
end;

procedure TCheckComponent.DisplayImageGenerated(Sender: TObject);
begin
  FContentComposer.DisplayImageGenerated;
end;

procedure TCheckComponent.DisplayVideoGenerated(Sender: TObject);
begin
  FContentComposer.DisplayVideoGenerated;
end;

procedure TCheckComponent.EndpointVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Endpoint(Value)
        .Update;
    end);
end;

procedure TCheckComponent.FilesAttachedToThePrompt(Sender: TObject);
begin
  FContentComposer.FilesAttachedToThePrompt;
end;

procedure TCheckComponent.FunctionButtonVisible(Sender: TObject);
begin
  ButtonVisibilityApply(Sender, ebSettings);
end;

procedure TCheckComponent.FunctionCardEdition(Sender: TObject);
begin
  FContentComposer.FunctionCardEdition;
end;

procedure TCheckComponent.HowToStart(Sender: TObject);
begin
  FContentComposer.HowToStart;
end;

procedure TCheckComponent.ImageAttachedToThePrompt(Sender: TObject);
begin
  FContentComposer.ImageAttachedToThePrompt;
end;

procedure TCheckComponent.ImagesAndFilesAttached(Sender: TObject);
begin
  FContentComposer.ImagesAndFilesAttached;
end;

procedure TCheckComponent.IntegrationAgentsVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .IntegrationAgents(Value)
        .Update;
    end);
end;

procedure TCheckComponent.IntegrationFunctionVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .IntegrationFunction(Value)
        .Update;
    end);
end;

procedure TCheckComponent.IntegrationMcpVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .IntegrationMcp(Value)
        .Update;
    end);
end;

procedure TCheckComponent.IntegrationSkillsVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .IntegrationSkills(Value)
        .Update;
    end);
end;

procedure TCheckComponent.IntegrationVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Integration(Value)
        .Update;
    end);
end;

procedure TCheckComponent.KnowledgeSearchVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .KnowledgeSearch(Value)
        .Update;
    end);
end;

procedure TCheckComponent.LaTeXUsing(Sender: TObject);
begin
  FContentComposer.LaTeXUsing;
end;

procedure TCheckComponent.McpCardEdition(Sender: TObject);
begin
  FContentComposer.McpCardEdition;
end;

procedure TCheckComponent.MediaCreateAudioVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .MediaCreateAudio(Value)
        .Update;
    end);
end;

procedure TCheckComponent.MediaCreateImageVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .MediaCreateImage(Value)
        .Update;
    end);
end;

procedure TCheckComponent.MediaCreateVideoVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .MediaCreateVideo(Value)
        .Update;
    end);
end;

procedure TCheckComponent.MediaSpeechToTextVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .MediaSpeechToText(Value)
        .Update;
    end);
end;

procedure TCheckComponent.MediaTextToSpeechVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .MediaTextToSpeech(Value)
        .Update;
    end);
end;

procedure TCheckComponent.MediaVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Media(Value)
        .Update;
    end);
end;

procedure TCheckComponent.MicrophoneButtonVisible(Sender: TObject);
begin
  ButtonVisibilityApply(Sender, ebMicrophone);
end;

procedure TCheckComponent.ModelGetReplaceVersion(Sender: TObject);
begin
  FContentComposer.ModelGetReplaceVersion;
end;

procedure TCheckComponent.ModelListJsonEdition(Sender: TObject);
begin
  FContentComposer.ModelListJsonEdition;
end;

procedure TCheckComponent.ModelsButtonVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Model(Value)
        .Update;
    end);
end;

procedure TCheckComponent.NextDiscovery(Sender: TObject);
begin
  if FCurrentDiscovery = High(FDiscoveryPages) then
    Exit;

  FCurrentDiscovery := FCurrentDiscovery + 1;
  ShowDiscovery(FCurrentDiscovery);
end;

procedure TCheckComponent.NextSubMenu(Sender: TObject);
begin
  if FCurrentSubMenu = High(FSubMenuPages) then
    Exit;

  FCurrentSubMenu := FCurrentSubMenu + 1;
  ShowSubMenu(FCurrentSubMenu);
end;

procedure TCheckComponent.ParametersButtonVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .SystemPrompt(Value)
        .Update;
    end);
end;

procedure TCheckComponent.PreviousDiscovery(Sender: TObject);
begin
  if FCurrentDiscovery = 0 then
  Exit;

  FCurrentDiscovery := FCurrentDiscovery - 1;
  ShowDiscovery(FCurrentDiscovery);
end;

procedure TCheckComponent.PreviousSubMenu(Sender: TObject);
begin
  if FCurrentSubMenu = 0 then
  Exit;

  FCurrentSubMenu := FCurrentSubMenu - 1;
  ShowSubMenu(FCurrentSubMenu);
end;

procedure TCheckComponent.ProjectButtonVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Project(Value)
        .Update;
    end);
end;

procedure TCheckComponent.PromptsVeryLong(Sender: TObject);
begin
  FContentComposer.PromptsVeryLong;
end;

procedure TCheckComponent.ReasoningVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Thinking(Value)
        .Update;
    end);
end;

procedure TCheckComponent.ShowDiscovery(const Index: Integer);
begin
  FDiscoveryPages[FCurrentDiscovery].BringToFront;
  UpdateDiscoveryLabel;
end;

procedure TCheckComponent.ShowSubMenu(const Index: Integer);
begin
  FSubMenuPages[FCurrentSubMenu].BringToFront;
  UpdateSubMenuLabel;
end;

procedure TCheckComponent.SkillsCardEdition(Sender: TObject);
begin
  FContentComposer.SkillsCardEdition;
end;

procedure TCheckComponent.SubMenuCapabilitiesApply(Sender: TObject;
  ParamProc: TProc<Boolean>);
begin
  if not Assigned(ParamProc) then
    Exit;

  var Component := (Sender as TControlListCheckBox);

  ParamProc(Component.Checked);
end;

procedure TCheckComponent.ThinkingHighVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .ThinkingHigh(Value)
        .Update;
    end);
end;

procedure TCheckComponent.ThinkingLowVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .ThinkingLow(Value)
        .Update;
    end);
end;

procedure TCheckComponent.ThinkingMediumVisible(Sender: TObject);
begin
  SubMenuCapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .ThinkingMedium(Value)
        .Update;
    end);
end;

procedure TCheckComponent.UpdateDiscoveryLabel;
begin
  Form1.label37.Caption := Format('Discovery %d/%d', [FCurrentDiscovery + 1, MaxDiscoveryIndex + 1]);
end;

procedure TCheckComponent.UpdateSubMenuLabel;
begin
  Form1.label24.Caption := Format('sub menus %d/%d', [FCurrentSubMenu + 1, MaxSubMenuIndex + 1]);
end;

procedure TCheckComponent.VisionVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .Vision(Value)
        .Update;
    end);
end;

procedure TCheckComponent.WebReseachVisible(Sender: TObject);
begin
  CapabilitiesApply(Sender,
    procedure (Value: Boolean)
    begin
      FBrowser.Capabilities
        .WebSearch(Value)
        .Update;
    end);
end;

{ TDidacticCustomProc }

class function TDidacticCustomProc.MyChatContentBuilder: Boolean;
begin
  with Form1 do
    begin
      Pythia.BeginUpdate;
      try
        var First := True;
        {--- Rebuild the full conversation by replaying each persisted turn
             in the same order as originally rendered. }
        for var Turn in Pythia.PersistentChat.CurrentChat.Data do
          begin
            if not First then
              Pythia.DisplaySpacer(60);
            Pythia.PromptMedia(dkimages, Turn.PromptImages, False);
            Pythia.PromptMedia(dkFile, Turn.PromptFiles, False);
            Pythia.PromptMedia(dkFile, Turn.PromptKnowledgeSearch, False);
            Pythia.Prompt(Turn.Prompt);

            Pythia.Display(Turn.Response, Turn.Reasoning, False);
            Pythia.DisplayMedia(dkimages, Turn.ReponseImages, False);
            Pythia.DisplayMedia(dkAudio, Turn.ReponseAudio, False);
            Pythia.DisplayMedia(dkVideo, Turn.ReponseVideo, False);
            Pythia.DisplayMedia(dkFile, Turn.ReponseFiles, False);
            Pythia.DisplayFooter(Turn.Model);
            First := False;
          end;
          Pythia.DisplaySpacer;
          Result := True;
      finally
        Pythia.EndUpdate;
        Pythia.ScrollToTop(False);
        Pythia.SetFocus;
      end;
    end;
end;

{ TDelayedSupport }

class procedure TDelayedSupport.Run(const ParamProc: TProc;
  const WaitingPeriod: Cardinal);
begin
  if not Assigned(ParamProc) then
    Exit;

  TTask.Run(
    procedure()
    begin
      Sleep(WaitingPeriod);
      TThread.Queue(nil,
        procedure
        begin
          ParamProc();
        end);
    end);
end;

end.
