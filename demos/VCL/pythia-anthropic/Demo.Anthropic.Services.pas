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
      const AState: TInputPromptState;
      State: TStateBuffer): TChatParamProc;

    function BuildSessionCallbacks(State: TStateBuffer): TSessionCallbacksStream;

    function BuildAndCheckPayload(
      const AState: TInputPromptState;
      State: TStateBuffer;
      out JsonPayloadAsString: string):TChatParamProc;

  protected
    function LoadFileResult(
      var AState: TStateBuffer;
      const ParamProc: TProc<TArray<string>, TArray<string>>): TArray<string>;

    procedure LoadSkillsFiles(
      Ids: TArray<string>;
      Filenames: TArray<string>);

    procedure SkillCustomRegister;

  public
    constructor Create(const ABrowser: IPythiaBrowser; const AContext: IContext);

    procedure UpdateApiKey;

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
  {--- Main entry point for a streamed chat request. }
  var State := TStateBuffer.FromState(AState);

  {--- Select model for "id":"textGeneration" (index 1) }
  State.Model := State.Models.Items[TEXT_GENERATION_INDEX].Model;

  {--- Build and validate the Payload procedure before starting the stream.
       The returned Payload is the fresh instance used by the SDK. }
  var Payload := BuildAndCheckPayload(AState, State, JsonPayloadAsString);
  State.JsonRequest := JsonPayloadAsString;

  {--- Wire streaming callbacks to the browser/UI layer. }
  var SessionCallbacks := BuildSessionCallbacks(State);

  {--- Normalize promise completion into one finalize contract. }
  var Promise := FClient.Chat.AsyncAwaitCreateStream(Payload, SessionCallbacks);

  Promise
    .&Then(
      procedure (Value: TEventData)
      begin
        {--- Normalize the raw streamed JSON before storing it in the turn state.
             Downstream extractors and context replay rely on one valid JSON
             event per line to recover file/container data and rebuild the
             assistant context on subsequent turns. }
        State.JsonResponse := TAnthropicJsonResponseHelper.NormalizeJsonResponse(Value.RawJson);


        if not TStateChecking.HasFileToDownload(State) then
          begin
            TFinalizeData
              .FromSuccess(Value, State)
              .Emit(AOnFinalize);
            Exit;
          end;

        {--- Resolve real filenames from the Files API before finalization, so the
             UI receives server-issued names instead of JSON-stream heuristics.
             Downloads are then fire-and-forget against those resolved paths. }
        var IDs := TArrayUtils.ArrayRemoveDuplicates(
          TAnthropicFileIdExtractor.ExtractBashCodeExecutionOutputs(State.JsonResponse));

        FClientUtils.WhenAllRetrieve(IDs)
          .&Then(
            procedure (Names: TArray<string>)
            var
              DefaultExt: string;
            begin
              {--- Defensive: any exception thrown inside this body is silently
                   swallowed by the promise framework (TPromise.&Then wraps the
                   call in try/except → Reject), which routes us to &Catch with
                   no traceable stack. Surface the real error explicitly. }
              try
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

                var Resolved: TArray<string>;
                SetLength(Resolved, Length(Names));
                for var I := Low(Names) to High(Names) do
                  begin
                    var Candidate := Names[I].Trim;
                    if Candidate.IsEmpty then
                      Candidate := Format('File_Result.%s', [DefaultExt]);
                    Resolved[I] := TParamsGetter.CheckFilename(Candidate, MediaFolder);
                  end;

                State.FileResults := Resolved;

                TFinalizeData
                  .FromSuccess(Value, State)
                  .Emit(AOnFinalize);

                for var I := Low(IDs) to High(IDs) do
                  FClientUtils.AsyncDownloadAs(IDs[I], Resolved[I]);

              except
                on E: Exception do
                  begin
                    FBrowser.DisplayError(Format('Filename resolution failed: %s (%s)',
                      [E.Message, E.ClassName]));
                    State.FileResults := LoadFileResult(State, LoadSkillsFiles);
                    TFinalizeData
                      .FromSuccess(Value, State)
                      .Emit(AOnFinalize);
                  end;
              end;
            end)
          .&Catch(
            procedure (E: Exception)
            begin
              {--- Reached only if WhenAllRetrieve itself rejects (a Files.Retrieve
                   failed). Surface the cause and fall back to the legacy
                   JSON-derived names so the workflow is never blocked. }
              FBrowser.DisplayError(Format('Files.Retrieve failed: %s', [E.Message]));
              State.FileResults := LoadFileResult(State, LoadSkillsFiles);
              TFinalizeData
                .FromSuccess(Value, State)
                .Emit(AOnFinalize);
            end);
      end)
    .&Catch(
      procedure (E: Exception)
      begin
        if not E.Message.ToLowerInvariant.StartsWith(ABORTED_INDICATOR) then
          begin
            State.Error := True;
            State.ErrorMessage := E.Message;

            TFinalizeData
              .FromException(E, State)
              .Emit(AOnFinalize);
            Exit;
          end;

        {--- Handle cancellation separately. }

        var MessageContent := TMessageContentBuilder.Aborted(E.Message);

        State.AddStreamedText(MessageContent);
        FBrowser.Display(MessageContent, False);

        TFinalizeData
          .FromState(State)
          .Emit(AOnFinalize);
      end);
end;

function TAnthropicServices.BuildPayload(
  const AState: TInputPromptState;
  State: TStateBuffer): TChatParamProc;
var
  Effort: string;
begin
  {--- The request body is composed in two layers:

         1. Conversation timeline. The current user content is materialized
            from the input state, then handed to the injected IContext which
            prepends the prior turns held by IPythiaBrowser.PersistentChat.
            The result is the full TArray<TMessageParam> sent to the API.

         2. Request parameters. Model, sampling, system prompt, tools and
            thinking configuration are applied through the dedicated builders;
            they remain orthogonal to history reconstruction. }
  var CurrentContent :=
    Demo.Anthropic.Helpers.TMessageContentBuilder.BuildContentBlocks(AState);
  var Messages := FContext.BuildMessages(State, CurrentContent);

  {--- Build and snapshot the request payload. }
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
  {--- Find the "beta" data already used in the context }
  var Beta := FContext.BetaExtract;

  {--- Add, if necessary, the "beta" values identified for the construction of this query. }
  Beta := TArrayUtils.Merge(Beta, BetaSkill);

  {--- Add, if necessary, the "beta" values identified for the construction of this query. }
  Beta := TArrayUtils.Merge(Beta, BetaMCP);

  if TStateChecking.AdaptiveThinkingCheck(AState) then
    Beta := TArrayUtils.Merge(Beta, ['files-api-2025-04-14']);

  if Length(Beta) = 0 then
    Exit;

  Params
    .Beta(Beta);
end;

function TAnthropicServices.BuildAndCheckPayload(
  const AState: TInputPromptState;
  State: TStateBuffer;
  out JsonPayloadAsString: string): TChatParamProc;
begin
  var Payload := BuildPayload(AState, State);

  {--- Validate Payload generation using a disposable instance }
  var JsonPayload := TChatParams.Create;
  try
    {--- BuildPayload produces the Payload procedure ultimately used by the SDK.
         Executing such a procedure is required to validate payload generation,
         but it may consume its captured state or resources.

         Therefore this first Payload instance is disposable and used only for
         validation. A fresh instance is built afterwards and returned to the
         caller. }
    Payload(JsonPayload);

    JsonPayloadAsString := JsonPayload.ToFormat();

    Result := BuildPayload(AState, State);

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
  {--- Returns True when any prior turn of the current session opted into
        the code-execution beta. BetaBuilder replays that beta on every
        subsequent request via FContext.BetaExtract; the API requires the
        matching code_execution tool to be re-registered alongside it,
        otherwise it rejects the request with:

          400 Skills beta requires the code_execution tool to be
          included in the request.

        Piggybacking on BetaExtract keeps the tool / beta pair in sync
        through a single source of truth (the JsonPrompt of past turns). }
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

  {--- Tool registration is gated on the union of two signals:

         ● the current AState (user explicitly enabled web search, a skill
           or an MCP server for this turn), and
         ● the conversation history (a prior turn of the same session
           already used the code-execution beta and the API now expects
           the code_execution tool to remain registered for continuity).

       The activation predicate is duplicated inline rather than reusing
       TToolsBuilder.TryToBuild because that helper only consults the
       current state and would short-circuit the historical path. }
  var WebSearchOn := AState.WebSearch;
  var SkillsOn    := TStateChecking.HasSkills(AState);
  var MCPOn       := TStateChecking.HasMCP(AState);
  var CodeExecOn  := SkillsOn or HistoricalCodeExecutionRequired;

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

  Result := Line + Result + S_ABORTED;
end;

end.

