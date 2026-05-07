unit Demo.Anthropic.Services;

interface

uses
  System.SysUtils, System.IOUtils, System.JSON, Winapi.Windows,
  WVPythia.Chat.Interfaces, WVPythia.Chat.ManagedFlow, WVPythia.TextFile.Helper,
  WVPythia.Strs, WVPythia.Vendors.Services, WVPythia.Chat.Consts,
  Anthropic, Anthropic.Types, Anthropic.Async.Promise, Anthropic.Helpers,
  Anthropic.API.JsonSafeReader,
  Demo.Anthropic.Helpers, Demo.Anthropic.Context, Demo.Anthropic.FileIds,
  Demo.Anthropic.AsyncUtils, Demo.Anthropic.JsonResponse.Helper,
  Demo.Anthropic.Upload;

const
  ABORTED_INDICATOR = 'aborted';

type
  TMessageContentBuilder = record
    class function Aborted(const Content: string): string; static;
  end;

  TFinalizeData = record
    Model: string;
    Response: string;
    Reasoning: string;
    JsonRequest: string;
    JsonResponse: string;
    FileResults: TArray<string>;
    ImageResults: TArray<string>;
    VideoResults: TArray<string>;
    AudioResult: TArray<string>;
    Error: Boolean;
    ErrorMessage: string;

    class function FromState(
      AState: TStateBuffer): TFinalizeData; overload; static;

    class function FromSuccess(
      const AValue: TEventData;
      const AState: TStateBuffer): TFinalizeData; overload; static;

    class function FromException(
      const E: Exception;
      const AState: TStateBuffer): TFinalizeData; overload; static;

    procedure Emit(const AOnFinalize: TManagedItemFinalizeProc);
  end;

  /// <summary>
  /// Ensures the managed finalize callback is emitted at most once.
  /// </summary>
  IEmitGuard = interface
    ['{F2C0A4D7-3E15-4C9A-9D6E-2A7E4D5B8F11}']
    procedure TryEmit(const Data: TFinalizeData);
  end;

  TEmitGuard = class(TInterfacedObject, IEmitGuard)
  private
    FEmitted: Boolean;
    FOnFinalize: TManagedItemFinalizeProc;
  public
    constructor Create(const AOnFinalize: TManagedItemFinalizeProc);
    procedure TryEmit(const Data: TFinalizeData);
  end;

  TAnthropicServices = class(TInterfacedObject, IVendorServices)
  const
    API_KEY_NAME = 'anthropic';
  private
    FClient: IAnthropic;
    FBrowser: IPythiaBrowser;
    FContext: IContext;
    FClientUtils: IAnthropicClientUtils;

    function IsEventSuitable(const Event: TChatStream): Boolean;
    procedure ChatSessionRename(ID, Value: string);

    function ToolsBuilder(
      const AState: TStateBuffer;
      const Params: TChatParams): TAnthropicServices;

    procedure ThinkingBuilder(
      const AState: TStateBuffer;
      out Effort: string;
      const Params: TChatParams);

    procedure OutputConfigBuilder(
      const AState: TStateBuffer;
      const Effort: string;
      const Params: TChatParams);

    function SkillBuilder(
      const AState: TStateBuffer;
      const Params: TChatParams): TArray<string>;

    function MCPBuilder(
      const AState: TStateBuffer;
      const Params: TChatParams): TArray<string>;

    procedure BetaBuilder(
      const AState: TStateBuffer;
      const BetaSkill, BetaMCP: TArray<string>;
      const Params: TChatParams);

    function HistoricalCodeExecutionRequired: Boolean;

    function BuildPayload(
      State: TStateBuffer): TChatParamProc;

    function BuildSessionCallbacks(State: TStateBuffer): TSessionCallbacksStream;

    function BuildAndCheckPayload(
      State: TStateBuffer;
      out JsonPayloadAsString: string):TChatParamProc;

  protected
    /// <summary>
    /// Resolves fallback file results after the primary file processing path fails.
    /// </summary>
    function LoadFileResult(
      var AState: TStateBuffer;
      const ParamProc: TProc<TArray<string>, TArray<string>>): TArray<string>;

    /// <summary>
    /// Registers the selected skill files used by the Anthropic integration.
    /// </summary>
    procedure LoadSkillsFiles(
      Ids: TArray<string>;
      Filenames: TArray<string>);

    procedure SkillCustomRegister;

    /// <summary>
    /// Best-effort fire-and-forget delete of every non-empty file_id
    /// present in State.Files. Called once when the response arrives
    /// (input files have been consumed) and once on chat-level failure
    /// (a retry will re-upload anyway).
    /// </summary>
    procedure CleanupInputFiles(const State: TStateBuffer);

    /// <summary>
    /// Pure resolution of the local download paths from server-side
    /// filenames: applies skill-derived default extension, ensures media
    /// folder, runs CheckFilename to sanitize each candidate.
    /// </summary>
    function ResolveDownloadFilenames(
      const Names: TArray<string>;
      const State: TStateBuffer): TArray<string>;

    /// <summary>
    /// Dispatches the fire-and-forget download tasks. Wrapped in
    /// try/except so a synchronous setup failure for one ID can't
    /// re-enter the calling Then-body's except branch.
    /// </summary>
    procedure FireDownloads(const IDs, Filenames: TArray<string>);

    /// <summary>
    /// Finalizes the turn with fallback file names after download path resolution fails.
    /// </summary>
    procedure HandleResolveFallback(
      const E: Exception;
      const Value: TEventData;
      var State: TStateBuffer;
      const EmitGuard: IEmitGuard);

    /// <summary>
    /// Finalizes the turn with fallback file results after file retrieval fails.
    /// </summary>
    procedure HandleRetrieveFailure(
      const E: Exception;
      const Value: TEventData;
      var State: TStateBuffer;
      const EmitGuard: IEmitGuard);

    /// <summary>
    /// Finalizes the turn after chat cancellation or chat-level failure.
    /// </summary>
    procedure HandleChatError(
      const E: Exception;
      var State: TStateBuffer;
      const EmitGuard: IEmitGuard);

  public
    constructor Create(const ABrowser: IPythiaBrowser; const AContext: IContext);

    /// <summary>
    /// Refreshes the Anthropic API key used by the demo service.
    /// </summary>
    procedure UpdateApiKey;

    /// <summary>
    /// Starts the asynchronous Anthropic chat stream for the current Pythia turn.
    /// </summary>
    procedure AsyncAwaitStreamChat(
      const AState: TInputPromptState;
      const AOnFinalize: TManagedItemFinalizeProc);
  end;

var
  AnthropicVendor: IVendorServices;

implementation

{ TAnthropicServices }

procedure TAnthropicServices.AsyncAwaitStreamChat(
  const AState: TInputPromptState; const AOnFinalize: TManagedItemFinalizeProc);
var
  JsonPayloadAsString: string;
begin
  {--- AState belongs to the Pythia managed flow; async closures capture only State }
  var State := TStateBuffer.FromState(AState);
  State.Model := State.Models.Items[TEXT_GENERATION_INDEX].Model;

  var Payload := BuildAndCheckPayload(State, JsonPayloadAsString);
  State.JsonRequest := JsonPayloadAsString;

  var SessionCallbacks := BuildSessionCallbacks(State);

  {--- Only one completion path may finalize the turn. }
  var EmitGuard: IEmitGuard := TEmitGuard.Create(AOnFinalize);

  FClient.Chat.AsyncAwaitCreateStream(Payload, SessionCallbacks)
    .&Then(
      procedure (Value: TEventData)
      begin
        State.JsonResponse := TAnthropicJsonResponseHelper.NormalizeJsonResponse(Value.RawJson);
        CleanupInputFiles(State);

        if not TStateChecking.HasFileToDownload(State) then
          begin
            EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State));
            Exit;
          end;

        var IDs := TArrayUtils.ArrayRemoveDuplicates(
          TAnthropicFileIdExtractor.ExtractBashCodeExecutionOutputs(State.JsonResponse));

        FClientUtils.WhenAllRetrieve(IDs)
          .&Then(
            procedure (Names: TArray<string>)
            begin
              try
                State.FileResults := ResolveDownloadFilenames(Names, State);
                EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State));
                FireDownloads(IDs, State.FileResults);
              except
                on E: Exception do
                  HandleResolveFallback(E, Value, State, EmitGuard);
              end;
            end)
          .&Catch(
            procedure (E: Exception)
            begin
              HandleRetrieveFailure(E, Value, State, EmitGuard);
            end);
      end)
    .&Catch(
      procedure (E: Exception)
      begin
        CleanupInputFiles(State);
        HandleChatError(E, State, EmitGuard);
      end);
end;

procedure TAnthropicServices.CleanupInputFiles(const State: TStateBuffer);
var
  FileIds: TArray<string>;
begin
  FileIds := [];
  for var Item in State.Files do
    if not Item.FileId.Trim.IsEmpty then
      FileIds := FileIds + [Item.FileId];

  if Length(FileIds) > 0 then
    FClientUtils.AsyncDeleteAllFire(FileIds);
end;

function TAnthropicServices.ResolveDownloadFilenames(
  const Names: TArray<string>;
  const State: TStateBuffer): TArray<string>;
var
  DefaultExt: string;
begin
  {--- When the server-side filename is missing, use the active skill name as
       the best available default extension for the generated file. }
  if TStateChecking.HasSkills(State) then
    begin
      var Skills := State.Integration.Skills;
      DefaultExt := Skills[High(Skills)].Name;
    end
  else
    DefaultExt := 'unknown';

  var MediaFolder := FBrowser.GetMediaFolder;
  if not TDirectory.Exists(MediaFolder) then
    TDirectory.CreateDirectory(MediaFolder);

  SetLength(Result, Length(Names));
  for var I := Low(Names) to High(Names) do
    begin
      var Candidate := Names[I].Trim;
      if Candidate.IsEmpty then
        Candidate := Format('File_Result.%s', [DefaultExt]);
      Result[I] := TParamsGetter.CheckFilename(Candidate, MediaFolder);
    end;
end;

procedure TAnthropicServices.FireDownloads(const IDs, Filenames: TArray<string>);
begin
  {--- Each download handles its own async failure path. This try/except only
       guards synchronous dispatch errors so they cannot re-enter the parent
       Then-body's exception branch. }
  try
    for var I := Low(IDs) to High(IDs) do
      FClientUtils.AsyncDownloadAs(IDs[I], Filenames[I]);
  except
    on E: Exception do
      FBrowser.DisplayError(Format('Async download dispatch failed: %s (%s)',
        [E.Message, E.ClassName]));
  end;
end;

procedure TAnthropicServices.HandleResolveFallback(
  const E: Exception;
  const Value: TEventData;
  var State: TStateBuffer;
  const EmitGuard: IEmitGuard);
begin
  {--- Filename resolution failed after file retrieval succeeded.
       Fall back to JSON-derived file results so the turn can still finalize. }
  FBrowser.DisplayError(Format('Filename resolution failed: %s (%s)',
    [E.Message, E.ClassName]));

  State.FileResults := LoadFileResult(State, LoadSkillsFiles);
  EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State));
end;

procedure TAnthropicServices.HandleRetrieveFailure(
  const E: Exception;
  const Value: TEventData;
  var State: TStateBuffer;
  const EmitGuard: IEmitGuard);
begin
  FBrowser.DisplayError(Format('Files.Retrieve failed: %s', [E.Message]));
  try
    State.FileResults := LoadFileResult(State, LoadSkillsFiles);
    EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State));
  except
    on EFallback: Exception do
      begin
        FBrowser.DisplayError(Format('Fallback finalize failed: %s (%s)',
          [EFallback.Message, EFallback.ClassName]));
        State.Error := True;
        State.ErrorMessage := EFallback.Message;
        EmitGuard.TryEmit(TFinalizeData.FromException(EFallback, State));
      end;
  end;
end;

procedure TAnthropicServices.HandleChatError(
  const E: Exception;
  var State: TStateBuffer;
  const EmitGuard: IEmitGuard);
begin
  {--- User cancellation is not treated as a failed turn: the partial streamed
       response is promoted to final content so the UI and history stay aligned. }
  if not E.Message.ToLowerInvariant.StartsWith(ABORTED_INDICATOR) then
    begin
      State.Error := True;
      State.ErrorMessage := E.Message;
      EmitGuard.TryEmit(TFinalizeData.FromException(E, State));
      Exit;
    end;

  var MessageContent := TMessageContentBuilder.Aborted(E.Message);
  State.AddStreamedText(MessageContent);
  FBrowser.Display(MessageContent, False);
  EmitGuard.TryEmit(TFinalizeData.FromState(State));
end;

{ TEmitGuard }

constructor TEmitGuard.Create(const AOnFinalize: TManagedItemFinalizeProc);
begin
  inherited Create;
  FOnFinalize := AOnFinalize;
  FEmitted := False;
end;

procedure TEmitGuard.TryEmit(const Data: TFinalizeData);
begin
  if FEmitted then
    Exit;
  FEmitted := True;
  Data.Emit(FOnFinalize);
end;

function TAnthropicServices.BuildPayload(
  State: TStateBuffer): TChatParamProc;
var
  Effort: string;
begin
  var CurrentContent :=
    Demo.Anthropic.Helpers.TMessageContentBuilder.BuildContentBlocks(State);
  var Messages := FContext.BuildMessages(State, CurrentContent);

  Result :=
    procedure (Params: TChatParams)
    begin
      Params
        .Model(State.Model)
        .Messages(Messages)
        .Stream;

      TRequestSettingsBuilder.Apply(State, Params);
      ToolsBuilder(State, Params);
      ThinkingBuilder(State, Effort, Params);
      OutputConfigBuilder(State, Effort, Params);
      var BetaSkill := SkillBuilder(State, Params);
      var BetaMCP := MCPBuilder(State, Params);
      BetaBuilder(State, BetaSkill, BetaMCP, Params);
    end;
end;

function TAnthropicServices.BuildSessionCallbacks(
  State: TStateBuffer): TSessionCallbacksStream;
begin
  Result :=
    function : TPromiseChatStream
    begin
      Result.Sender := nil;

      Result.OnProgress :=
        procedure (Sender: TObject; Event: TChatStream)
        begin
          {--- Ignore events without usable live deltas. }
          if not IsEventSuitable(Event) then
            Exit;

          var Delta := Event.ContentBlockDelta.Delta;

          {--- Accumulate state and render deltas immediately. }
          State.AddStreamedText(Delta.Text);
          State.AddStreamedThinking(Delta.Thinking);
          State.AddJsonResponse(Event.JSONResponse);

          FBrowser.DisplayStream(Delta.Text, Delta.Thinking, False);
         end;

      Result.OnDoCancel :=
        function : Boolean
        begin
          {--- Poll browser escape state for cancellation. }
          Result := FBrowser.Escape;
        end;

      Result.OnCancellation :=
        function (Sender: TObject): string
        begin
          Result := ABORTED_INDICATOR + #10 + State.TextBuffer;
        end;

      Result.OnError :=
        function (Sender: TObject; Text: string): string
        begin
          {--- Surface stream-level errors reported through the callback layer.
               Lower-level transport failures may bypass this callback. }
          Result := Text;
          FBrowser.ReasoningHide;
          FBrowser.DisplayError(Text);
        end;
    end;
end;

procedure TAnthropicServices.BetaBuilder(
  const AState: TStateBuffer;
  const BetaSkill,
  BetaMCP: TArray<string>;
  const Params: TChatParams);
begin
  {--- Reuse beta flags already present in the conversation history, then merge
       the flags required by the current skills, MCP servers, and Files API use. }
  var Beta := FContext.BetaExtract;

  Beta := TArrayUtils.Merge(Beta, BetaSkill);
  Beta := TArrayUtils.Merge(Beta, BetaMCP);

  if TStateChecking.HasAPIFileUsed(AState) then
    Beta := TArrayUtils.Merge(Beta, ['files-api-2025-04-14']);

  if Length(Beta) = 0 then
    Exit;

  Params
    .Beta(Beta);
end;

function TAnthropicServices.BuildAndCheckPayload(
  State: TStateBuffer;
  out JsonPayloadAsString: string): TChatParamProc;
begin
  var Payload := BuildPayload(State);

  var JsonPayload := TChatParams.Create;
  try
    {--- Validate payload generation on a disposable TChatParams instance.
         Return a fresh payload proc so the SDK gets an untouched builder. }
    Payload(JsonPayload);

    JsonPayloadAsString := JsonPayload.ToFormat();

    Result := BuildPayload(State);

  finally
    JsonPayload.Free;
  end;
end;

procedure TAnthropicServices.ChatSessionRename(ID, Value: string);
begin
  FClientUtils.ASyncSessionRename(ID, Value);
end;

constructor TAnthropicServices.Create(const ABrowser: IPythiaBrowser;
  const AContext: IContext);
var
  Anthropic_key: string;
begin
  {--- The service is built around three collaborators: the browser-facing UI
       abstraction, the Anthropic SDK client used for remote execution, and an
       injected IContext that owns the conversation-history projection used to
       seed the messages array sent on each request. }
  FBrowser := ABrowser;
  FContext := AContext;

  {--- Require the user to enter an API key when none is configured. }
  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
      FBrowser.TryHandleAsCommand(Format('/api-key new %s', [API_KEY_NAME]));

  FClient := TAnthropicFactory.CreateInstance(Anthropic_key);

  {---- Set response delay for 2 min and 30 seconds }
  FClient.HttpClient.ResponseTimeout := 150000;

  {--- Set up the Anthropic tools for asynchronous file renaming and downloading. }
  FClientUtils := TAnthropicClientUtils.Create(FClient, FBrowser);

  {--- Set up the automatic session renaming feature. }
  FBrowser.OnChatSessionAutoRename := ChatSessionRename;

  {--- Demo wiring: plug the Anthropic implementation of IFileUploadService
       into the browser. The service uses the browser as the JS callback
       surface for upload status, and FClient as the Anthropic Files API
       entry point. }
  FBrowser.FileUploadService := TDownloadService.Create(FBrowser as IPythiaBrowser, FClient);

  {--- Ensure demo custom skills exist on Anthropic and patch local skill cards
       with the server-side ids when they are created. }
  SkillCustomRegister;
end;

function TAnthropicServices.IsEventSuitable(const Event: TChatStream): Boolean;
begin
  {--- Minimal structural validation for streamed events before reading nested
       delta fields. This isolates protocol-shape checks in one place. }
  Result :=
    Assigned(Event) and
    Assigned(Event.ContentBlockDelta) and
    Assigned(Event.ContentBlockDelta.Delta);
end;

function TAnthropicServices.LoadFileResult(
  var AState: TStateBuffer;
  const ParamProc: TProc<TArray<string>, TArray<string>>): TArray<string>;
{--- Fallback path: invoked only when the Files.Retrieve aggregator fails or
     when the Then body of WhenAllRetrieve raises. Surfaces placeholder
     filenames so the turn can finalize; the actual download still recovers
     the real server-side name on disk via AsyncFetchFile (retrieve+download). }
var
  DefaultExt: string;
begin
  var IDs := TArrayUtils.ArrayRemoveDuplicates(
    TAnthropicFileIdExtractor.ExtractBashCodeExecutionOutputs(AState.JsonResponse));

  if TStateChecking.HasSkills(AState) then
    begin
      var Skills := AState.Integration.Skills;
      DefaultExt := Skills[High(Skills)].Name;
    end
  else
    DefaultExt := 'unknown';

  SetLength(Result, Length(IDs));

  for var I := Low(IDs) to High(IDs) do
    Result[I] := TParamsGetter.CheckFilename(
      Format('File_Result.%s', [DefaultExt]),
      FBrowser.GetMediaFolder);

  AState.FileResults := Result;

  if not TStateChecking.HasFileToDownload(AState) then
    Exit;

  if Assigned(ParamProc) then
    ParamProc(IDs, Result);
end;

procedure TAnthropicServices.LoadSkillsFiles(
  Ids: TArray<string>;
  Filenames: TArray<string>);
begin
  for var I := Low(Ids) to High(Ids) do
    FClientUtils.AsyncDownloadAs(Ids[I], Filenames[I]);
end;

function TAnthropicServices.MCPBuilder(const AState: TStateBuffer;
  const Params: TChatParams): TArray<string>;
var
  Content: string;
  Pat: string;
  Contents: TArray<string>;
  SystemPrompt: string;
begin
  {--- Expose only the MCP capabilities explicitly selected for this turn,
       keeping Anthropic's tool surface aligned with the visible Pythia state. }
  Result := [];

  if not TStateChecking.HasMCP(AState) then
    Exit;

  if not FileExists(FBrowser.GetMcpCardsFileName) then
    Exit;

  Contents := [];

  var MCPJsonAsString := TFileIOHelper.LoadFromFile(FBrowser.GetMcpCardsFileName);
  var Reader := TJsonReader.Parse(MCPJsonAsString);

  for var Item in AState.Integration.Mcp do
    begin
      if not TParamsGetter.TryReadMCPCard(Reader, Item.Name, Content, Pat) then
        Continue;

      if SameText(Item.Name.ToLower, 'github') then
        Content := Format(Content, [Pat]);

      if SameText(Item.Name.ToLower, 'Weather service') then
        begin
          var ToDayInSystemPrompt :=
            'Today is ''' + FormatDateTime('dd"u"mmmm"t"yyyy', Date) + ''' (' + FormatDateTime('yyyy-mm-dd', Date) + ').';
          if AState.CoreParamsState.SystemPrompt.Enabled then
            begin
              SystemPrompt :=
                AState.CoreParamsState.SystemPrompt.Value + slineBreak +
                ToDayInSystemPrompt;
            end
          else
            SystemPrompt := ToDayInSystemPrompt;

          Params.System(SystemPrompt);
        end;

      var CheckContent := TJsonReader.Parse(Content);
      if not CheckContent.IsValid then
        raise Exception.CreateFmt('invalid JSON:#10%s', [Content]);

      Contents := Contents + [Content]
    end;

  if Length(Contents) = 0 then
    Exit;

  Params
    .McpServers(TJSONArrayHelper.ArrayOfStringToJSonArrayAsString(Contents));

  Result := ['mcp-client-2025-11-20'];
end;

procedure TAnthropicServices.OutputConfigBuilder(const AState: TStateBuffer;
  const Effort: string; const Params: TChatParams);
begin
  {--- Keep Anthropic's response shape aligned with the current Pythia state:
       apply structured output and adaptive effort only when they are meaningful
       for this turn. }
  TThinkingBuilder.TryGetThinkingConfigParam(AState, Effort,
    procedure
    begin
      var AResult := TThinkingBuilder.GetTOutputConfig(AState, Effort);

      if Assigned(AResult) then
        Params
          .OutputConfig(AResult);
    end);
end;

function TAnthropicServices.SkillBuilder(
  const AState: TStateBuffer;
  const Params: TChatParams): TArray<string>;
var
  Item: TSkillItem;
begin
  {--- Bind Anthropic skills to the capabilities selected for this turn.
       Skills are part of the visible Pythia state, not ambient model power:
       only enabled document/custom skills are exposed, so the request keeps
       its execution surface explicit and scoped. }
  Result := [];

  if not TStateChecking.HasSkills(AState) then
    Exit;

  var Skills := TParamsGetter.GetSkills(AState);

  for Item in Skills do
    begin
      with Generation do
        Params
          .Container( CreateContainer
              .Skills( SkillParts
                  .Add( Skill.CreateSkill(Item.SkillType)
                      .SkillId(Item.ID)
                      .Version(Item.Version)
                  )
              )
          );
    end;

   Result := ['code-execution-2025-08-25', 'skills-2025-10-02'];
end;

procedure TAnthropicServices.SkillCustomRegister;
begin
  var SkillCardsFileName := FBrowser.GetSkillCardsFileName;
  if not FileExists(SkillCardsFileName) then
    Exit;

  var SkillJsonAsString := TFileIOHelper.LoadFromFile(SkillCardsFileName);

  var Skills := TSkillHelper.ExtractCustomSkills(SkillJsonAsString);

  for var Item in Skills do
    FClientUtils.CustomSkillRegister(Item.ID, Item.Name);
end;

procedure TAnthropicServices.ThinkingBuilder(const AState: TStateBuffer;
  out Effort: string;
  const Params: TChatParams);
var
  MaxTokens: Integer;
begin
  {--- Establish the reasoning contract for this turn.
       Thinking is not just another sampling option: once enabled, it affects
       token budgeting, output effort and compatible request settings. This
       builder centralizes that decision so the rest of the Anthropic request
       stays consistent with the visible Pythia state. }
  TThinkingBuilder.TryGetOutputConfig(AState, Effort,
    procedure
    begin
      if TStateChecking.AdaptiveThinkingCheck(AState) then
        begin
          if TStateChecking.ModelVersion47Check(AState) then
            begin
              Params
              .Thinking( TThinkingConfigParam
                  .New('adaptive')
                  .Display(TStateChecking.SummarizedThinking(AState))
              );
            end
          else
            Params
              .Thinking( TThinkingConfigParam
                  .New('adaptive')
              );
        end
      else
        begin
          Params
            .Thinking( TThinkingConfigParam
                .New('enabled')
                .BudgetTokens(TParamsGetter.GetThinkingBudget(AState, MaxTokens))
            );

          Params.MaxTokens(MaxTokens);
        end;
    end);
end;

function TAnthropicServices.HistoricalCodeExecutionRequired: Boolean;
const
  CODE_EXECUTION_BETA = 'code-execution-2025-08-25';
begin
  {--- If a previous turn used the code-execution beta, Anthropic expects the
       code_execution tool to be registered again on later requests. }
  Result := False;
  if not Assigned(FContext) then
    Exit;

  for var item in FContext.BetaExtract do
    if SameText(item, CODE_EXECUTION_BETA) then
      Exit(True);
end;

function TAnthropicServices.ToolsBuilder(const AState: TStateBuffer;
  const Params: TChatParams): TAnthropicServices;
begin
  Result := Self;

  {--- Tools are enabled from both the current turn and the conversation history:
       historical code execution must remain registered for API continuity. }
  var WebSearchOn := AState.WebSearch;
  var SkillsOn    := TStateChecking.HasSkills(AState);
  var MCPOn       := TStateChecking.HasMCP(AState);
  var CodeExecOn  := MCPOn or SkillsOn or HistoricalCodeExecutionRequired;

  if not (WebSearchOn or CodeExecOn or MCPOn) then
    Exit;

  var Tools: TArray<TToolUnion> := [];

  if WebSearchOn then
    Tools := Tools + [Generation.Tool.CreateWebSearchTool20250305.MaxUses(5)];

  if CodeExecOn then
    Tools := Tools + [Generation.Tool.Beta.CreateCodeExecutionTool20250825];

  if MCPOn then
    for var Item in TParamsGetter.GetMCPNames(AState) do
      Tools := Tools + [Generation.Tool.Beta.CreateMCPToolset.McpServerName(Item)];

  Params
    .Tools(Tools);
end;

procedure TAnthropicServices.UpdateApiKey;
var
  Anthropic_key: string;
begin
  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
    begin
      FClient.API.Token := '';
      Exit;
    end;

  FClient.API.Token := Anthropic_key;
  FBrowser.DisplaySuccess('Anthropic client is up to date.')
end;

{ TFinalizeData }

class function TFinalizeData.FromState(
  AState: TStateBuffer): TFinalizeData;
begin
  {--- Rebuilds the final payload from the local stream buffer.
       This path is used when the request stops before a canonical success
       object is available, such as cancellation. }
  Result.Model := AState.Model;
  Result.Response := AState.TextBuffer;
  Result.Reasoning := AState.ThinkingBuffer;
  Result.JsonRequest := AState.JsonRequest;
  Result.JsonResponse := AState.JsonResponse;
  Result.FileResults := AState.FileResults;
  Result.ImageResults := AState.ImageResults;
  Result.VideoResults := AState.VideoResults;
  Result.AudioResult := AState.AudioResults;
  Result.Error := AState.Error;
  Result.ErrorMessage := AState.ErrorMessage;
end;

class function TFinalizeData.FromSuccess(
  const AValue: TEventData;
  const AState: TStateBuffer): TFinalizeData;
begin
  {--- On success, text and reasoning come from the SDK terminal event, while
       request/response JSON traces remain sourced from the local state buffer
       accumulated during the stream. }
  Result.Model := AState.Model;
  Result.Response := AValue.Text;
  Result.Reasoning := AValue.Thought;
  Result.JsonRequest := AState.JsonRequest;
  Result.JsonResponse := AState.JsonResponse;
  Result.FileResults := AState.FileResults;
  Result.ImageResults := AState.ImageResults;
  Result.VideoResults := AState.VideoResults;
  Result.AudioResult := AState.AudioResults;
  Result.Error := AState.Error;
  Result.ErrorMessage := AState.ErrorMessage;
end;

class function TFinalizeData.FromException(
  const E: Exception;
  const AState: TStateBuffer): TFinalizeData;
begin
  {--- Persist the failure together with any text already streamed.
       The live UI reports the exception through the error channel, but the chat
       history is rebuilt later from Response only; without appending the message
       here, reopening the session would hide why this turn stopped. }
  Result.Model := AState.Model;
  if AState.TextBuffer.Trim.IsEmpty then
    Result.Response := E.Message
  else
    Result.Response := AState.TextBuffer + '<br><br>' + E.Message;
  Result.Reasoning := '';
  Result.JsonRequest := AState.JsonRequest;
  Result.JsonResponse := AState.JsonResponse;
  Result.FileResults := AState.FileResults;
  Result.ImageResults := AState.ImageResults;
  Result.VideoResults := AState.VideoResults;
  Result.AudioResult := AState.AudioResults;
  Result.Error := AState.Error;
  Result.ErrorMessage := AState.ErrorMessage;
end;

procedure TFinalizeData.Emit(const AOnFinalize: TManagedItemFinalizeProc);
begin
  {--- Converts the plain record into the managed result object expected by the
       surrounding flow infrastructure, then dispatches it through the caller's
       finalize callback if one was provided. }
  if not Assigned(AOnFinalize) then
    Exit;

  var ResponseFlow := TManagedItemLLMResult.New;
  try
    ResponseFlow
      .UsedModel(Model)
      .Response(Response)
      .Reasoning(Reasoning)
      .PromptJson(JsonRequest)
      .ResponseJson(JsonResponse)
      .FileResults(FileResults)
      .ImageResults(ImageResults)
      .VideoResults(VideoResults)
      .AudioResults(AudioResult)
      .Error(Error)
      .ErrorMessage(ErrorMessage);

    AOnFinalize(ResponseFlow);
  finally
    ResponseFlow.Free;
  end;
end;

{ TMessageContentBuilder }

class function TMessageContentBuilder.Aborted(const Content: string): string;
var
  Line: string;
begin
  var StringArray := Content.Split([#10]);
  for var I := Low(StringArray) to High(StringArray) do
    if I > 0 then
      Line := Line + #10 + StringArray[I];

  Result := Line + S_ABORTED;
end;

end.

