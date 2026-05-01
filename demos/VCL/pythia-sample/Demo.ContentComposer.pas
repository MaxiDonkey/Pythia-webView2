unit Demo.ContentComposer;

interface

uses
  System.SysUtils, System.IOUtils,
  WVPythia.Types, WVPythia.Types.EnumWire, WVPythia.Strs, WVPythia.Net.MediaCodec,
  WVPythia.TextFile.Helper, WVPythia.Chat.Interfaces, WVPythia.ChatSession.Controller;

type
  TContentComposer = class
  private
    FBrowser: IPythiaBrowser;
    FLightMode: string;
    FPythiaLogo: string;
    FCathedral: string;
    FMaxidonkeyMp3: string;
    FDialogMp4: string;
    FPDFDocument: string;
    FXlsDocument: string;
    FHtmlDocument: string;
    procedure TurnDisplay(const Turn: TChatTurn);
    procedure DoEdition(const Filename: string;
      const Prompt: string); overload;
    procedure DoEdition(const Filenames: TArray<string>;
      const Prompt: string); overload;
  public
    constructor Create(const ABrowser: IPythiaBrowser);
    procedure DisplayImageGenerated;
    procedure DisplayAudioGenerated;
    procedure DisplayVideoGenerated;
    procedure DisplayFilesGenerated;

    procedure ImageAttachedToThePrompt;
    procedure FilesAttachedToThePrompt;
    procedure ImagesAndFilesAttached;
    procedure PromptsVeryLong;

    procedure LaTeXUsing;
    procedure CodeAndArrayUsing;

    procedure CreateSessionByCode;
    procedure CreateSessionAboutReadme;

    procedure ModelListJsonEdition;
    procedure ModelGetReplaceVersion;
    procedure CapabilitiesEdition;
    procedure CustomTemplateEdition;

    procedure FunctionCardEdition;
    procedure McpCardEdition;
    procedure SkillsCardEdition;
    procedure AgentsCardEdition;
    procedure CustomCardEdition;

    procedure DialogServiceError;
    procedure DefaultModelError;
    procedure HowToStart;
  end;

implementation

uses
  VCL.Dialogs, WVPythia.JSON.SafeReader, WVPythia.Strings.Escape,
  Demo.Support;

{ TContentComposer }

procedure TContentComposer.AgentsCardEdition;
begin
  var Prompt :=
    'When editing the application''s Agent card file, each entry must define at least an id and a name.' + sLineBreak +
    sLineBreak +
    'The id field is the technical identifier of the agent entry. It allows the application to recognize which agent was selected by the user in the Cards panel. Once the selections have been collected and passed to the vendor service when the prompt is submitted, the developer can use this identifier to map the selected card to the corresponding internal agent implementation or configuration.' + sLineBreak +
    sLineBreak +
    'This id therefore acts as the anchor point between the card declared in the JSON file and the actual application-side agent. It allows the associated agent definition, orchestration logic, system instructions, configuration, or processing rule to be retrieved and added to the request or processing flow currently being built.' + sLineBreak +
    sLineBreak +
    'The name field, on the other hand, is the label displayed to the user in the Cards panel. It should be explicit enough to help the user identify the purpose of the agent. Unlike the name, which may evolve to improve readability, the id must remain stable over time to ensure reliable resolution of the selected agent entry.' + sLineBreak +
    sLineBreak +
    'Note: The user may also add custom keys to each card object in the JSON file, but existing keys must not be removed. Added keys will not be deserialized into the standard card structure, but they will remain available through TJsonReader for application-specific processing.';

  DoEdition(FBrowser.GetAgentCardsFileName, Prompt);
end;

procedure TContentComposer.CapabilitiesEdition;
begin
  var Prompt := 'This file contains a flat dictionary of booleans — one per capability — preceded by a type field that serves as the signature for the JS channel';
  DoEdition(FBrowser.GetCapabilitiesFileName, Prompt);
end;

procedure TContentComposer.CodeAndArrayUsing;
begin
  FBrowser.Clear;
  var Response := TFileIOHelper.LoadFromFile(FBrowser.GetMediaFolder + '\DelphiLoops.txt');
  FBrowser.Prompt('Can you show me how to write loops in Delphi? I would like to have code snippets covering the different types of loops possible, with clear examples for each.');
  FBrowser.Display(Response, False);
  FBrowser.DisplayFooter('the_model_name');
  FBrowser.DisplaySpacer();
end;

constructor TContentComposer.Create(const ABrowser: IPythiaBrowser);
begin
  inherited Create;
  FBrowser := ABrowser;
  FLightMode := TMediaCodec.ToDataURI('..\docs\images\screenshots\pythia-workspace-dark.png');
  FPythiaLogo := TMediaCodec.ToDataURI(FBrowser.GetMediaFolder + '\Pythia.png');
  FCathedral := TMediaCodec.ToDataURI(FBrowser.GetMediaFolder + '\Cathedral.png');
  FMaxidonkeyMp3 := TMediaCodec.ToDataURI(FBrowser.GetMediaFolder + '\Maxidonkey.mp3');
  FDialogMp4 := 'https://app.local/media/dialogue.mp4';
  FPDFDocument := FBrowser.GetMediaFolder + '\File_Search_file.pdf';
  FXlsDocument := FBrowser.GetMediaFolder + '\budget.xlsx';
  FHtmlDocument := FBrowser.GetMediaFolder + '\Cinema.htm';
end;

procedure TContentComposer.CreateSessionAboutReadme;
begin
  FBrowser.ChatSessionDrawerOpen;
  FBrowser.Clear;

  FBrowser.BeginUpdate;
  try
    {--- New chat session }
    var Item := FBrowser.PersistentChat.AddChat;
    Item.ApplyTitle('Session Pythia-webview2 README');

    {******************** New turn into the chat }
    var Turn := FBrowser.PersistentChat.AddPrompt;
    Turn.Index := FBrowser.PromptCount + 1;
    Turn.Prompt := 'Show me Pythia-webview2 README';
    Turn.Response := TFileIOHelper.LoadFromFile('..\README.md');
    Turn.Reasoning := '';

    {--- Save and display the turn to the browser }
    FBrowser.PersistentChat.SaveToFile();
    TurnDisplay(Turn);

    {--- Update the UI - the session is added to the file drawer }
    FBrowser.ChatSessionAdd(Item.Id, Item.Title);

  finally
    FBrowser.EndUpdate;
  end;
end;

procedure TContentComposer.CreateSessionByCode;
begin
  FBrowser.ChatSessionDrawerOpen;
  FBrowser.Clear;

  FBrowser.BeginUpdate;
  try
    {--- New chat session }
    var Item := FBrowser.PersistentChat.AddChat;
    Item.ApplyTitle('Session created by code');

    {******************** New turn into the chat }
    var Turn := FBrowser.PersistentChat.AddPrompt;
    Turn.Index := FBrowser.PromptCount + 1;
    Turn.Prompt := 'Show the Pythia-webview2 Markdown documentation.';
    Turn.Response := TFileIOHelper.LoadFromFile('..\docs\pythia-documentation.md');
    Turn.Reasoning := '';

    {--- Save and display the turn to the browser }
    FBrowser.PersistentChat.SaveToFile();
    TurnDisplay(Turn);

    {******************** New turn into the chat }
    Turn := FBrowser.PersistentChat.AddPrompt;
    Turn.Index := FBrowser.PromptCount + 1;
    Turn.Prompt := 'Hwo to build a first application based on Pythia-Webview2.';
    Turn.Response := TFileIOHelper.LoadFromFile('..\docs\integrator\index.md');
    Turn.Reasoning := '';

    {--- Save and display the turn to the browser }
    FBrowser.PersistentChat.SaveToFile();
    TurnDisplay(Turn);

    {--- Update the UI - the session is added to the file drawer }
    FBrowser.ChatSessionAdd(Item.Id, Item.Title);

  finally
    FBrowser.EndUpdate;
  end;
end;

procedure TContentComposer.CustomCardEdition;
begin
  var Prompt :=
    'When editing the application''s Custom card file, each entry must define at least an id and a name.' + sLineBreak +
    sLineBreak +
    'The id field is the technical identifier of the custom entry. It allows the application to recognize which custom integration was selected by the user in the Cards panel. Once the selections have been collected and passed to the vendor service when the prompt is submitted, the developer can use this identifier to map the selected card to the corresponding internal application-specific integration, feature, or business process.' + sLineBreak +
    sLineBreak +
    'This id therefore acts as the anchor point between the card declared in the JSON file and the actual application-side custom implementation. It allows the associated business integration, internal command, configuration, workflow, or processing rule to be retrieved and added to the request or processing flow currently being built.' + sLineBreak +
    sLineBreak +
    'The name field, on the other hand, is the label displayed to the user in the Cards panel. It should be explicit enough to help the user identify the purpose of the custom entry. Unlike the name, which may evolve to improve readability, the id must remain stable over time to ensure reliable resolution of the selected custom entry.' + sLineBreak +
    sLineBreak +
    'Note: The user may also add custom keys to each card object in the JSON file, but existing keys must not be removed. Added keys will not be deserialized into the standard card structure, but they will remain available through TJsonReader for application-specific processing.';

  DoEdition(FBrowser.GetCustomCardsFileName, Prompt);
end;

procedure TContentComposer.CustomTemplateEdition;
begin
  var Prompt := 'This file allows you to define custom JavaScript templates, along with their file paths, so they are taken into account during bridge initialization and injected alongside the default JavaScript scripts.';
  DoEdition(FBrowser.GetCustomJSFileName, Prompt);
end;

procedure TContentComposer.DefaultModelError;
begin
  var ContentAsMd := TFileIOHelper.LoadFromFile(
    TPath.combine(FBrowser.GetMediaFolder, 'DialogModelError.txt')
  );
  var Image := TMediaCodec.ToDataURI(FBrowser.GetMediaFolder + '\ModelsByCategoriesPanel.png');

  FBrowser.Clear;

  FBrowser.DisplayWarning('No default model configured: Image creation aborted');
  FBrowser.Prompt(
    'What to do when you receive the warning:'#10 +
      #10'- "No default model: text generation cannot be processed" or' +
      #10'- "No default model configured: Image creation aborted" or' +
      #10'- "No default model configured: Video creation aborted" or' +
      #10'- "No default model configured: Audio creation aborted" or' +
      #10'- "No default model configured: TTS operation aborted" or' +
      #10'- "No default model configured: Deep Reasearch operation aborted"'
  );
  FBrowser.Display(ContentAsMd, False);
  FBrowser.DisplayMedia(dkImages, [Image]);
  FBrowser.DisplayMedia(dkFile, [FBrowser.GetModelCategoriesFileName, FBrowser.GetModelListFileName]);
  FBrowser.DisplaySpacer();
  FBrowser.ScrollToTop();
end;

procedure TContentComposer.DialogServiceError;
begin
  var ContentAsMd := TFileIOHelper.LoadFromFile(
    TPath.combine(FBrowser.GetMediaFolder, 'DialogSeviceWarning.txt')
  );

  FBrowser.Clear;

  FBrowser.DisplayWarning('DialogService not assigned');
  FBrowser.Prompt('What to do when you receive the warning:'#10#10#9#9#9'"DialogService not assigned"');
  FBrowser.Display(ContentAsMd, False);
  FBrowser.DisplaySpacer();
  FBrowser.ScrollToTop();
end;

procedure TContentComposer.DisplayAudioGenerated;
begin
  FBrowser.Clear;
  FBrowser.Prompt('Displaying an audio generated by an LLM');
  FBrowser.Display('This audio has been generated.');
  FBrowser.DisplayMedia(dkAudio, [FMaxidonkeyMp3], False);
  FBrowser.DisplayFooter('the_model_name');
end;

procedure TContentComposer.DisplayFilesGenerated;
begin
  FBrowser.Clear;
  FBrowser.Prompt('Displaying files generated by an LLM');
  FBrowser.Display('This files was been generated.');
  FBrowser.DisplayMedia(dkFile, [FPDFDocument, FXlsDocument, FHtmlDocument]);
  FBrowser.DisplayFooter('the_model_name');
end;

procedure TContentComposer.DisplayImageGenerated;
begin
  FBrowser.Clear;
  FBrowser.Prompt('Displaying an image generated by an LLM');
  FBrowser.Display('This image has been generated.');
  FBrowser.DisplayMedia(dkimages, [FCathedral], False);
  FBrowser.DisplayFooter('the_model_name');
end;

procedure TContentComposer.DisplayVideoGenerated;
begin
  FBrowser.Clear;
  FBrowser.Prompt('Displaying a video generated by an LLM');
  FBrowser.Display('This video has been generated.');
  FBrowser.DisplayMedia(dkVideo, [FDialogMp4], False);
  FBrowser.DisplayFooter('the_model_name');
end;

procedure TContentComposer.DoEdition(const Filenames: TArray<string>;
  const Prompt: string);
var
  FilenameArray: TArray<string>;
begin
  if Length(Filenames) = 0 then
    Exit;

  var JsonAsString1 := TFileIOHelper.LoadFromFile(Filenames[0]);
  var Reader1 := TJsonReader.Parse(JsonAsString1);

  SetLength(FilenameArray,Length(Filenames));
  for var i := Low(FileNames) to High(FileNames) do
    FilenameArray[i] := FileNames[i];

  FBrowser.Clear;
  FBrowser.Prompt(Prompt);
  FBrowser.Display(TEscapeHelper.ToPreformattedHTML(Reader1.Format()));
  FBrowser.DisplayMedia(dkFile, FilenameArray);
  FBrowser.DisplaySpacer();
  FBrowser.ScrollToTop(True);

  var CurrentFilename := Format('%s', [ExtractFileName(Filenames[0])]);

  FBrowser.DisplaySuccess(CurrentFilename); //Format('%s edit', [Filenames[0]]));
end;

procedure TContentComposer.DoEdition(const Filename, Prompt: string);
begin
  DoEdition([FileName], Prompt);
end;

procedure TContentComposer.FilesAttachedToThePrompt;
begin
  FBrowser.Clear;
  FBrowser.PromptMedia(dkFile, [FPDFDocument, FHtmlDocument], False);
  FBrowser.Prompt('Files are attached to the prompt');
  FBrowser.ReasoningHide;
  FBrowser.ScrollToTop(True);
end;

procedure TContentComposer.FunctionCardEdition;
begin
  var Prompt :=
    'When editing the application''s Function card file, each entry must define at least an id and a name.' + sLineBreak +
    sLineBreak +
    'The id field is the technical identifier of the function. It allows the application to recognize which function was selected by the user in the Cards panel. Once the selections have been collected and passed to the vendor service when the prompt is submitted, the developer can use this identifier to map the selected card to the corresponding internal function.' + sLineBreak +
    sLineBreak +
    'This id therefore acts as the anchor point between the card declared in the JSON file and the actual application-side implementation. It allows the associated business function to be retrieved and its definition, schema, or parameters to be added to the request currently being built.' + sLineBreak +
    sLineBreak +
    'The name field, on the other hand, is the label displayed to the user in the Cards panel. It should be explicit enough to help the user identify the purpose of the function. Unlike the name, which may evolve to improve readability, the id must remain stable over time to ensure reliable resolution of the selected function.' + sLineBreak +
    sLineBreak +
    'Note: the key named "content" can be used to store the JSON payload that defines how to access the function schema. The user may also add custom keys to each card object in the JSON file, but existing keys must not be removed. Added keys will not be deserialized into the standard card structure, but they will remain available through TJsonReader for application-specific processing.';

  DoEdition(FBrowser.GetFunctionCardsFileName, Prompt);
end;

procedure TContentComposer.HowToStart;
begin
  var ContentAsMd := TFileIOHelper.LoadFromFile(
    TPath.combine(FBrowser.GetMediaFolder, 'HowToStart.txt')
  );

  FBrowser.Clear;
  FBrowser.Prompt('How to start a project with Pythia-Webview2 in the simplest way possible?');
  FBrowser.Display(ContentAsMd, False);
  FBrowser.DisplaySpacer();
  FBrowser.ScrollToTop();
end;

procedure TContentComposer.ImageAttachedToThePrompt;
begin
  FBrowser.Clear;
  FBrowser.PromptMedia(dkImages, [FLightMode], False);
  FBrowser.Prompt('An image is attached to the prompt');
  FBrowser.ReasoningHide;
  FBrowser.ScrollToTop(True);
end;

procedure TContentComposer.ImagesAndFilesAttached;
begin
  FBrowser.Clear;
  FBrowser.PromptMedia(dkImages, [FLightMode, FPythiaLogo], False);
  FBrowser.PromptMedia(dkFile, [FPDFDocument, FHtmlDocument], False);
  FBrowser.Prompt('Images and Files are attached to the prompt');
  FBrowser.ReasoningHide;
  FBrowser.ScrollToTop(True);
end;

procedure TContentComposer.LaTeXUsing;
begin
  FBrowser.Clear;
  var Response := TFileIOHelper.LoadFromFile(FBrowser.GetMediaFolder + '\LaTeX-using.txt');
  var Reasoning := TFileIOHelper.LoadFromFile(FBrowser.GetMediaFolder + '\Reasoning-using.txt');
  FBrowser.Prompt('Can you tell me about presheaves and the Yoneda lemma?');
  FBrowser.Display(Response, Reasoning, False);
  FBrowser.DisplayFooter('the_reasoning_model_name');
  FBrowser.DisplaySpacer();
end;

procedure TContentComposer.McpCardEdition;
begin
  var Prompt :=
    'When editing the application''s MCP card file, each entry must define at least an id and a name.' + sLineBreak +
    sLineBreak +
    'The id field is the technical identifier of the MCP entry. It allows the application to recognize which MCP server or integration was selected by the user in the Cards panel. Once the selections have been collected and passed to the vendor service when the prompt is submitted, the developer can use this identifier to map the selected card to the corresponding internal MCP configuration.' + sLineBreak +
    sLineBreak +
    'This id therefore acts as the anchor point between the card declared in the JSON file and the actual application-side MCP implementation or configuration. It allows the associated MCP server, manifest, endpoint, or business integration to be retrieved and added to the request or processing flow currently being built.' + sLineBreak +
    sLineBreak +
    'The name field, on the other hand, is the label displayed to the user in the Cards panel. It should be explicit enough to help the user identify the purpose of the MCP entry. Unlike the name, which may evolve to improve readability, the id must remain stable over time to ensure reliable resolution of the selected MCP entry.' + sLineBreak +
    sLineBreak +
    'Note: the key named "content" can be used to store the JSON payload that defines how to access the MCP server. The user may also add custom keys to each card object in the JSON file, but existing keys must not be removed. Added keys will not be deserialized into the standard card structure, but they will remain available through TJsonReader for application-specific processing.';

  DoEdition(FBrowser.GetMcpCardsFileName, Prompt);
end;

procedure TContentComposer.ModelGetReplaceVersion;
begin
  var Prompt :=
    'This JSON defines the available model categories and the default models associated with them.' + sLineBreak +
    sLineBreak +
    'A category can only be used if a default model is configured for it. During prompt validation, the system checks this association; if no default model is found, processing is stopped and the following error is returned: "No default model: operation cannot be processed".' + sLineBreak +
    sLineBreak +
    'To configure these associations, first add the models you want to expose in <exeName>-model-list.json.' + sLineBreak +
    sLineBreak +
    'Then edit <exeName>-model-get-replace-version.json to associate default models with categories and define whether each model category is visible or not.';

  DoEdition([FBrowser.GetModelCategoriesFileName, FBrowser.GetModelListFileName], Prompt);
end;

procedure TContentComposer.ModelListJsonEdition;
begin
  var Prompt := 'JSON schema of the model list.';
  DoEdition(FBrowser.GetModelListFileName, Prompt);
end;

procedure TContentComposer.PromptsVeryLong;
begin
  FBrowser.Clear;
  var LongPrompt := TFileIOHelper.LoadFromFile(FBrowser.GetMediaFolder + '\LongPrompt.txt');
  FBrowser.Prompt(LongPrompt);
  FBrowser.ReasoningHide;
end;

procedure TContentComposer.SkillsCardEdition;
begin
  var Prompt :=
    'When editing the application''s Skill card file, each entry must define at least an id and a name.' + sLineBreak +
    sLineBreak +
    'The id field is the technical identifier of the skill entry. It allows the application to recognize which skill was selected by the user in the Cards panel. Once the selections have been collected and passed to the vendor service when the prompt is submitted, the developer can use this identifier to map the selected card to the corresponding internal skill implementation or configuration.' + sLineBreak +
    sLineBreak +
    'This id therefore acts as the anchor point between the card declared in the JSON file and the actual application-side skill. It allows the associated business skill, execution logic, prompt fragment, configuration, or processing rule to be retrieved and added to the request or processing flow currently being built.' + sLineBreak +
    sLineBreak +
    'The name field, on the other hand, is the label displayed to the user in the Cards panel. It should be explicit enough to help the user identify the purpose of the skill. Unlike the name, which may evolve to improve readability, the id must remain stable over time to ensure reliable resolution of the selected skill entry.' + sLineBreak +
    sLineBreak +
    'Note: The user may also add custom keys to each card object in the JSON file, but existing keys must not be removed. Added keys will not be deserialized into the standard card structure, but they will remain available through TJsonReader for application-specific processing.';

  DoEdition(FBrowser.GetSkillCardsFileName, Prompt);
end;

procedure TContentComposer.TurnDisplay(const Turn: TChatTurn);
begin
  FBrowser.Prompt(Turn.Prompt);
  FBrowser.Display(Turn.Response, Turn.Reasoning, False);
  FBrowser.DisplayMedia(dkimages, Turn.ReponseImages, False);
  FBrowser.DisplayMedia(dkAudio, Turn.ReponseAudio, False);
  FBrowser.DisplayMedia(dkVideo, Turn.ReponseVideo, False);
  FBrowser.DisplayMedia(dkFile, Turn.ReponseFiles, False);
  FBrowser.DisplaySpacer;
end;

end.
