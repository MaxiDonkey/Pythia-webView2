unit Demo.Anthropic.Services;

interface

uses
  System.SysUtils, System.IOUtils, System.Net.URLClient, System.JSON,
  Winapi.Windows,
  WVPythia.Chat.Interfaces, WVPythia.Chat.ManagedFlow, WVPythia.TextFile.Helper,
  WVPythia.Strs, WVPythia.Vendors.Services,
  Anthropic, Anthropic.Types, Anthropic.Async.Promise, Anthropic.Helpers,
  Anthropic.API.JsonSafeReader, Anthropic.Headers.Beta,
  Demo.Anthropic.Helpers, Demo.Anthropic.Context,
  Demo.Anthropic.AsyncUtils, Demo.Anthropic.JsonResponse.Helper,
  Demo.Anthropic.DisplayBlocks, Demo.Anthropic.Upload;

const
  ABORTED_INDICATOR = 'aborted';

type
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
    Blocks: IDisplayBlockAggregator;

    class function FromState(
      AState: TStateBuffer;
      const ABlocks: IDisplayBlockAggregator): TFinalizeData; overload; static;

    class function FromSuccess(
      const AValue: TEventData;
      const AState: TStateBuffer;
      const ABlocks: IDisplayBlockAggregator): TFinalizeData; overload; static;

    class function FromException(
      const E: Exception;
      const AState: TStateBuffer;
      const ABlocks: IDisplayBlockAggregator): TFinalizeData; overload; static;

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

    procedure SkillBuilder(
      const AState: TStateBuffer;
      const Params: TChatParams);

    procedure MCPBuilder(
      const AState: TStateBuffer;
      const Params: TChatParams);

    procedure BetaBuilder(
      const AState: TStateBuffer;
      const Params: TChatParams);

    function HistoricalCodeExecutionRequired: Boolean;

    function BuildPayload(
      State: TStateBuffer): TChatParamProc;

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
      const Blocks: IDisplayBlockAggregator;
      const EmitGuard: IEmitGuard);

    /// <summary>
    /// Finalizes the turn with fallback file results after file retrieval fails.
    /// </summary>
    procedure HandleRetrieveFailure(
      const E: Exception;
      const Value: TEventData;
      var State: TStateBuffer;
      const Blocks: IDisplayBlockAggregator;
      const EmitGuard: IEmitGuard);

    /// <summary>
    /// Finalizes the turn after chat cancellation or chat-level failure.
    /// </summary>
    procedure HandleChatError(
      const E: Exception;
      var State: TStateBuffer;
      const Blocks: IDisplayBlockAggregator;
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

uses
  System.Classes,
  Anthropic.Chat.StreamCallbacks,
  WVPythia.Chat.Consts,
  WVPythia.ChatSession.Controller;

type
  TAnthropicFileIds = record
  public
    class function IsValid(const Value: string): Boolean; static;
    class function Filter(const IDs: TArray<string>): TArray<string>; static;
  end;

  TAnthropicBetaTokens = record
  public
    class function Extract(const Headers: TNetHeaders): TArray<string>; static;
  end;

  TFileCapturingEventEngineManager = class(TInterfacedObject, IEventEngineManager)
  private
    FInner: IEventEngineManager;
    FOnFileId: TProc<string>;
    FOnToolResultDetails: TProc<string>;
  public
    constructor Create(
      const AInner: IEventEngineManager;
      const AOnFileId: TProc<string>;
      const AOnToolResultDetails: TProc<string> = nil);

    function AggregateStreamEvents(
      const Chunk: TChatStream;
      var Buffer: TEventData): Boolean;

    function GetStreamEventDispatcher: IStreamEventDispatcher;
  end;

{ TAnthropicFileIds }

class function TAnthropicFileIds.IsValid(const Value: string): Boolean;
begin
  Result := Value.Trim.ToLowerInvariant.StartsWith('file_');
end;

class function TAnthropicFileIds.Filter(
  const IDs: TArray<string>): TArray<string>;
begin
  Result := [];
  for var Id in IDs do
    if IsValid(Id) then
      Result := Result + [Id.Trim];
end;

{ TFileCapturingEventEngineManager }

constructor TFileCapturingEventEngineManager.Create(
  const AInner: IEventEngineManager;
  const AOnFileId: TProc<string>;
  const AOnToolResultDetails: TProc<string>);
begin
  inherited Create;
  FInner := AInner;
  FOnFileId := AOnFileId;
  FOnToolResultDetails := AOnToolResultDetails;
end;

function TFileCapturingEventEngineManager.AggregateStreamEvents(
  const Chunk: TChatStream;
  var Buffer: TEventData): Boolean;
var
  ToolResultDetails: string;
begin
  TAnthropicStreamCapture.CaptureCodeExecutionFileIds(Chunk,
    procedure (Id: string)
    begin
      if Assigned(FOnFileId) and TAnthropicFileIds.IsValid(Id) then
        FOnFileId(Id.Trim);
    end);

  if Assigned(FOnToolResultDetails) and
     TToolResultDisplayDetails.TryFromEvent(Chunk, ToolResultDetails) then
    FOnToolResultDetails(ToolResultDetails);

  Result := FInner.AggregateStreamEvents(Chunk, Buffer);
end;

function TFileCapturingEventEngineManager.GetStreamEventDispatcher:
  IStreamEventDispatcher;
begin
  Result := FInner.GetStreamEventDispatcher;
end;

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

  {--- Display-block aggregator captured by all stream closures: it builds the
       ordered TChatDisplayBlock list that Pythia persists on the turn for
       later replay. }
  var Blocks: IDisplayBlockAggregator := TDisplayBlockAggregator.Create;

  {--- Event callbacks are built inline so every streamed delta updates the
       State captured by the finalizers, not a copied record owned by a helper. }
  var TypedEventCallbacks := TEventEngineManagerFactory.CreateInstance(
    function : TStreamEventCallBack
    begin
      Result := Default(TStreamEventCallBack);
      Result.Sender := nil;

      Result.OnAssistantTextDelta :=
        procedure (Sender: TObject; Buffer: TEventData; Delta: string)
        begin
          State.AddStreamedText(Delta);
          Blocks.AppendAssistantDelta(Delta);

          FBrowser.DisplayStream(Delta, '', False);
        end;

      Result.OnReasoningDelta :=
        procedure (Sender: TObject; Buffer: TEventData; Delta: string)
        begin
          State.AddStreamedThinking(Delta);
          Blocks.AppendReasoningDelta(Delta);

          FBrowser.DisplayStream('', Delta, False);
        end;

      Result.OnToolUseStop :=
        procedure (Sender: TObject; Buffer: TEventData; Snapshot: TToolCallSnapshot)
        var
          Title: string;
          Details: string;
          Output: string;
        begin
          {--- The input JSON is fully assembled only at block_stop, so we
               wait until here before emitting any UI for the tool call.
               The title carries the resolved command (e.g. the bash line
               or the text_editor path) rather than the raw block-type
               identifier. }
          Title := TToolDisplayTitle.FromInput(
            Snapshot.BlockType,
            Snapshot.ToolName,
            Snapshot.InputJson);

          Blocks.RegisterToolUseStop(Snapshot, Title);
          FBrowser.DisplayToolStatus(Title, False);

          if TToolUseDisplayDetails.TryFromSnapshot(Snapshot, Details) then
            begin
              Output := Details.Trim;
              if not Output.IsEmpty then
                begin
                  Output := Output + sLineBreak;
                  Blocks.AppendToolResultDelta(Output);
                  FBrowser.DisplayToolOutputStream(Output, False);
                end;
            end;
        end;

      Result.OnToolResultDelta :=
        procedure (Sender: TObject; Buffer: TEventData; Delta: string)
        begin
          if Delta.IsEmpty then
            Exit;

          {--- Stream the output into the entry opened by the matching
               OnToolUseStop. The JS side merges consecutive tool deltas
               under the same tool-call entry inside the collapsible
               group. }
          Blocks.AppendToolResultDelta(Delta);
          FBrowser.DisplayToolOutputStream(Delta, False);
        end;

      Result.OnToolResultStop :=
        procedure (Sender: TObject; Buffer: TEventData; Snapshot: TToolResultSnapshot)
        var
          ErrorTitle: string;
        begin
          Blocks.RegisterToolResultStop(Snapshot);

          {--- Only surface the error transition when the server reports
               it at block_stop. The live UI already streamed the text. }
          if Snapshot.IsError then
            begin
              ErrorTitle := TToolDisplayTitle.FromBlockType(Snapshot.BlockType);
              FBrowser.DisplayToolError(ErrorTitle, Snapshot.Text, False);
            end;
        end;

      Result.OnDoCancel :=
        function : Boolean
        begin
          {--- Poll browser escape state for cancellation. }
          Result := FBrowser.Escape;
        end;

      Result.OnCancellation :=
        procedure (Sender: TObject)
        begin
          {--- State is already updated by the typed delta callbacks. }
          Blocks.CloseCurrent;
        end;

      Result.OnError :=
        procedure (Sender: TObject; Buffer: TEventData)
        begin
          {--- Surface stream-level failures through the promise catch path. }
          FBrowser.ReasoningHide;
        end;
    end);

  var EventCallbacks: IEventEngineManager :=
    TFileCapturingEventEngineManager.Create(TypedEventCallbacks,
      procedure (Id: string)
      begin
        TThread.Synchronize(nil,
          procedure
          begin
            State.AddOutputFileId(Id);
          end);
      end,
      procedure (Details: string)
      begin
        var Output := Details.Trim;
        if Output.IsEmpty then
          Exit;

        Output := Output + sLineBreak;
        TThread.Synchronize(nil,
          procedure
          begin
            Blocks.AppendToolResultDelta(Output);
            FBrowser.DisplayToolOutputStream(Output, False);
          end);
      end);

  {--- Only one completion path may finalize the turn. }
  var EmitGuard: IEmitGuard := TEmitGuard.Create(AOnFinalize);

  FClient.Chat.AsyncAwaitCreateStream(Payload, EventCallbacks)
    .&Then(
      procedure (Value: TEventData)
      begin
        {--- JsonResponse is kept for history/UI tracing only; control
             flow no longer depends on parsing it.
        }
        State.JsonResponse := TAnthropicJsonResponseHelper.NormalizeJsonResponse(Value.RawJson);
        CleanupInputFiles(State);

        if not TStateChecking.HasFileToDownload(State) then
          begin
            EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State, Blocks));
            Exit;
          end;

        {--- IDs were collected live from streamed tool-result blocks. Keep
             only Anthropic Files API ids; tool-use ids start with srvtoolu_
             and must never be sent to Files.Retrieve. }
        var IDs := TAnthropicFileIds.Filter(State.OutputFileIds);
        State.OutputFileIds := IDs;
        if Length(IDs) = 0 then
          begin
            EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State, Blocks));
            Exit;
          end;

        FClientUtils.WhenAllRetrieve(IDs)
          .&Then(
            procedure (Names: TArray<string>)
            begin
              try
                State.FileResults := ResolveDownloadFilenames(Names, State);
                EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State, Blocks));
                FireDownloads(IDs, State.FileResults);
              except
                on E: Exception do
                  HandleResolveFallback(E, Value, State, Blocks, EmitGuard);
              end;
            end)
          .&Catch(
            procedure (E: Exception)
            begin
              HandleRetrieveFailure(E, Value, State, Blocks, EmitGuard);
            end);
      end)
    .&Catch(
      procedure (E: Exception)
      begin
        CleanupInputFiles(State);
        HandleChatError(E, State, Blocks, EmitGuard);
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
       the best available default extension for the generated file.
  }
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
       Then-body's exception branch.
  }
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
  const Blocks: IDisplayBlockAggregator;
  const EmitGuard: IEmitGuard);
begin
  {--- Filename resolution failed after file retrieval succeeded.
       Fall back to JSON-derived file results so the turn can still finalize.
  }
  FBrowser.DisplayError(Format('Filename resolution failed: %s (%s)',
    [E.Message, E.ClassName]));

  State.FileResults := LoadFileResult(State, LoadSkillsFiles);
  EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State, Blocks));
end;

procedure TAnthropicServices.HandleRetrieveFailure(
  const E: Exception;
  const Value: TEventData;
  var State: TStateBuffer;
  const Blocks: IDisplayBlockAggregator;
  const EmitGuard: IEmitGuard);
begin
  FBrowser.DisplayError(Format('Files.Retrieve failed: %s', [E.Message]));
  try
    State.FileResults := LoadFileResult(State, LoadSkillsFiles);
    EmitGuard.TryEmit(TFinalizeData.FromSuccess(Value, State, Blocks));
  except
    on EFallback: Exception do
      begin
        FBrowser.DisplayError(Format('Fallback finalize failed: %s (%s)',
          [EFallback.Message, EFallback.ClassName]));
        State.Error := True;
        State.ErrorMessage := EFallback.Message;
        EmitGuard.TryEmit(TFinalizeData.FromException(EFallback, State, Blocks));
      end;
  end;
end;

procedure TAnthropicServices.HandleChatError(
  const E: Exception;
  var State: TStateBuffer;
  const Blocks: IDisplayBlockAggregator;
  const EmitGuard: IEmitGuard);
begin
  {--- User cancellation is not treated as a failed turn: the partial streamed
       response is promoted to final content so the UI and history stay aligned.
  }
  if not E.Message.ToLowerInvariant.StartsWith(ABORTED_INDICATOR) then
    begin
      State.Error := True;
      State.ErrorMessage := E.Message;
      EmitGuard.TryEmit(TFinalizeData.FromException(E, State, Blocks));

      Exit;
    end;

  var MessageContent := S_ABORTED;
  State.AddStreamedText(MessageContent);

  {--- Mirror the aborted note into the block stream so a later replay shows
       the same termination indicator the live UI did. }
  if Assigned(Blocks) then
    Blocks.AppendAssistantText(MessageContent);
  FBrowser.Display(MessageContent, False);
  EmitGuard.TryEmit(TFinalizeData.FromState(State, Blocks));
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
      SkillBuilder(State, Params);
      MCPBuilder(State, Params);
      BetaBuilder(State, Params);
    end;
end;

{ TAnthropicBetaTokens }

class function TAnthropicBetaTokens.Extract(
  const Headers: TNetHeaders): TArray<string>;
begin
  {--- TBetaHeaderManager.Build returns at most one anthropic-beta header with
        comma-separated tokens. Flatten it to a string array so it can merge with
        hybrid extras and be re-emitted via one Params.Beta() call.
  }
  Result := [];
  for var H in Headers do
    if SameText(H.Name, 'anthropic-beta') then
      for var Token in H.Value.Split([',']) do
        begin
          var Trimmed := Token.Trim;
          if not Trimmed.IsEmpty then
            Result := Result + [Trimmed];
        end;
end;

procedure TAnthropicServices.BetaBuilder(
  const AState: TStateBuffer;
  const Params: TChatParams);
const
  MESSAGES_ENDPOINT = '/v1/messages';
begin
  {--- Hybrid beta strategy.

        Params.Beta() disables SDK auto-detection, so we reproduce it by running
        TBetaHeaderManager.Build on the finalized payload, then merge in tokens
        the detector misses on /v1/messages:

        - skills-2025-10-02: required when container.skills invokes a skill from
        Messages, but auto-detected only on /v1/skills (the /v1/messages branch
        of TBetaHeaderManager adds it via container.skills, but we keep this
        local extra defensively for callers that do not exercise that path).

        - files-api-2025-04-14: defensively added for Files-API file_id sources not
        covered by container_upload detection.

        - code-execution-2025-08-25: starting with SDK 1.3,
        code_execution_20250825 and code_execution_20260120 are GA as tool
        types, so the detector no longer auto-adds the token from the
        registered tool. The container.skills branch still injects it because
        Agent Skills require it. Outside skills, this demo echoes the token
        only when prior code-execution history must be replayed, preserving
        legacy "_20250825" server_tool_use / *_tool_result pairs.

        - mcp-client is still auto-detected; only the three tokens above remain
        local.
  }
  var Extras: TArray<string> := [];

  if TStateChecking.HasSkills(AState) then
    Extras := Extras + ['skills-2025-10-02'];

  if TStateChecking.HasAPIFileUsed(AState) then
    Extras := Extras + ['files-api-2025-04-14'];

  {--- Current code_execution_20260120 is GA as a tool. The residual manual
       token exists for replaying older code-execution history outside a
       skills container, where the original request may have carried
       code-execution-2025-08-25 explicitly. }
  if HistoricalCodeExecutionRequired and not TStateChecking.HasSkills(AState) then
    Extras := Extras + ['code-execution-2025-08-25'];

  if Length(Extras) = 0 then
    Exit;

  {--- Take the payload as it stands right before the beta field is set.
       BetaBuilder is invoked last in BuildPayload, so JSON reflects model,
       messages, tools, container, mcp_servers, output_config, etc.
  }
  var PayloadJson := Params.JSON.ToJSON;

  {--- TBetaHeaderManager.Build may raise on invalid beta combinations
       (e.g., tool_search + input_examples, all-deferred tool sets). Letting
       the exception propagate surfaces those at request build time.
  }
  var AutoTokens := TAnthropicBetaTokens.Extract(
    TBetaHeaderManager.Build(MESSAGES_ENDPOINT, PayloadJson));

  var Merged := TArrayUtils.Merge(AutoTokens, Extras);
  Merged := TArrayUtils.ArrayRemoveDuplicates(Merged);

  if Length(Merged) > 0 then
    Params
      .Beta(Merged);
end;

function TAnthropicServices.BuildAndCheckPayload(
  State: TStateBuffer;
  out JsonPayloadAsString: string): TChatParamProc;
begin
  var Payload := BuildPayload(State);

  var JsonPayload := TChatParams.Create;
  try
    {--- Validate payload generation on a disposable TChatParams instance.
         Return a fresh payload proc so the SDK gets an untouched builder.
    }
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
       seed the messages array sent on each request.
  }
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
       entry point.
  }
  FBrowser.FileUploadService := TDownloadService.Create(FBrowser as IPythiaBrowser, FClient);

  {--- Ensure demo custom skills exist on Anthropic and patch local skill cards
       with the server-side ids when they are created.
  }
  SkillCustomRegister;
end;

function TAnthropicServices.LoadFileResult(
  var AState: TStateBuffer;
  const ParamProc: TProc<TArray<string>, TArray<string>>): TArray<string>;
{--- Fallback path: invoked only when the Files.Retrieve aggregator fails or
     when the Then body of WhenAllRetrieve raises. Surfaces placeholder
     filenames so the turn can finalize; the actual download still recovers
     the real server-side name on disk via AsyncFetchFile (retrieve+download).
}
var
  DefaultExt: string;
begin
  {--- IDs collected live from streamed tool-result blocks.
       Deduplication is handled at insertion. }
  var IDs := TAnthropicFileIds.Filter(AState.OutputFileIds);
  AState.OutputFileIds := IDs;

  if Length(IDs) = 0 then
    begin
      Result := [];
      AState.FileResults := Result;
      Exit;
    end;

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

procedure TAnthropicServices.MCPBuilder(const AState: TStateBuffer;
  const Params: TChatParams);
var
  Content: string;
  Pat: string;
  Contents: TArray<string>;
  SystemPrompt: string;
begin
  {--- Expose only the MCP capabilities explicitly selected for this turn,
       keeping Anthropic's tool surface aligned with the visible Pythia state.
       No beta token is returned: TBetaHeaderManager auto-adds both
       'mcp-client-2025-11-20' and 'advanced-tool-use-2025-11-20' from the
       mcp_servers / mcp_toolset signals injected here.
  }
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
end;

procedure TAnthropicServices.OutputConfigBuilder(const AState: TStateBuffer;
  const Effort: string; const Params: TChatParams);
begin
  {--- Keep Anthropic's response shape aligned with the current Pythia state:
       apply structured output and adaptive effort only when they are meaningful
       for this turn.
  }
  TThinkingBuilder.TryGetThinkingConfigParam(AState, Effort,
    procedure
    begin
      var AResult := TThinkingBuilder.GetTOutputConfig(AState, Effort);

      if Assigned(AResult) then
        Params
          .OutputConfig(AResult);
    end);
end;

procedure TAnthropicServices.SkillBuilder(
  const AState: TStateBuffer;
  const Params: TChatParams);
var
  Item: TSkillItem;
  ContainerId: string;
begin
  {--- Bind Anthropic skills to the capabilities selected for this turn and
       reuse the latest server-side container when history already created one.
       Skills are part of the visible Pythia state, not ambient model power:
       only enabled document/custom skills are exposed, so the request keeps
       its execution surface explicit and scoped. Starting with SDK 1.3,
       TBetaHeaderManager injects "code-execution-2025-08-25",
       "skills-2025-10-02" and "files-api-2025-04-14" when container.skills
       is non-empty (AddBetasFromContainerSkills), and BetaBuilder
       defensively echoes the same tokens as hybrid extras.
  }
  var HasSkills := TStateChecking.HasSkills(AState);

  if Assigned(FContext) then
    ContainerId := FContext.LastContainerId
  else
    ContainerId := '';

  var CodeExecOn :=
    TStateChecking.HasMCP(AState) or
    HasSkills or
    HistoricalCodeExecutionRequired;

  if (not HasSkills) and (ContainerId.IsEmpty or not CodeExecOn) then
    Exit;

  var Container := Generation.CreateContainer;
  if not ContainerId.IsEmpty then
    Container.Id(ContainerId);

  if HasSkills then
    begin
      var Skills := TParamsGetter.GetSkills(AState);
      var SkillList := Generation.SkillParts;

      for Item in Skills do
        SkillList := SkillList.Add(
          Generation.Skill.CreateSkill(Item.SkillType)
            .SkillId(Item.ID)
            .Version(Item.Version));

      Container.Skills(SkillList);
    end;

  Params.Container(Container);
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
       stays consistent with the visible Pythia state.
  }
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
begin
  {--- If a previous turn produced any code_execution server_tool_use,
       Anthropic expects the matching tool to remain registered on later
       requests; otherwise the historical *_tool_use / *_tool_result pair
       triggers a 400 on the next call. Detection walks the replayed
       assistant content blocks (IContext.HasHistoricalCodeExecution) rather
       than the "beta" array of past JsonPrompt. ToolsBuilder re-registers
       the GA code_execution_20260120 variant; older "_20250825" blocks
       carried in historical content remain valid because BetaBuilder can
       echo "code-execution-2025-08-25" as a hybrid extra when history
       requires it outside a skills container.
 }
  Result := Assigned(FContext) and FContext.HasHistoricalCodeExecution;
end;

function TAnthropicServices.ToolsBuilder(const AState: TStateBuffer;
  const Params: TChatParams): TAnthropicServices;
begin
  Result := Self;

  {--- Tools are enabled from both the current turn and the conversation history:
       historical code execution must remain registered for API continuity.
  }
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
    Tools := Tools + [Generation.Tool.Beta.CreateCodeExecutionTool20260120];

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
  AState: TStateBuffer;
  const ABlocks: IDisplayBlockAggregator): TFinalizeData;
begin
  {--- Rebuilds the final payload from the local stream buffer.
       This path is used when the request stops before a canonical success
       object is available, such as cancellation.
  }
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
  Result.Blocks := ABlocks;
end;

class function TFinalizeData.FromSuccess(
  const AValue: TEventData;
  const AState: TStateBuffer;
  const ABlocks: IDisplayBlockAggregator): TFinalizeData;
begin
  {--- On success, text and reasoning come from the SDK terminal event, while
       request/response JSON traces remain sourced from the local state buffer
       accumulated during the stream.
  }
  Result.Model := AState.Model;
  Result.Response := AValue.AssistantText;
  if Result.Response.IsEmpty then
    Result.Response := AState.TextBuffer;
  Result.Reasoning := AValue.Thought;
  Result.JsonRequest := AState.JsonRequest;
  Result.JsonResponse := AState.JsonResponse;
  Result.FileResults := AState.FileResults;
  Result.ImageResults := AState.ImageResults;
  Result.VideoResults := AState.VideoResults;
  Result.AudioResult := AState.AudioResults;
  Result.Error := AState.Error;
  Result.ErrorMessage := AState.ErrorMessage;
  Result.Blocks := ABlocks;
end;

class function TFinalizeData.FromException(
  const E: Exception;
  const AState: TStateBuffer;
  const ABlocks: IDisplayBlockAggregator): TFinalizeData;
begin
  {--- Persist the failure together with any text already streamed.
       The live UI reports the exception through the error channel, but the chat
       history is rebuilt later from Response only; without appending the message
       here, reopening the session would hide why this turn stopped.
  }
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
  Result.Blocks := ABlocks;
end;

procedure TFinalizeData.Emit(const AOnFinalize: TManagedItemFinalizeProc);
var
  BlockClones: TArray<TChatDisplayBlock>;
begin
  {--- Converts the plain record into the managed result object expected by the
       surrounding flow infrastructure, then dispatches it through the caller's
       finalize callback if one was provided.
  }
  if not Assigned(AOnFinalize) then
    Exit;

  {--- Hand a cloned snapshot of the streamed blocks to the result builder;
       TManagedItemLLMResult.SetDisplayBlocks clones again into its own
       storage, so the local copies must be freed before returning. }
  BlockClones := nil;
  if Assigned(Blocks) then
    BlockClones := Blocks.CloneAll;

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
      .DisplayBlockResults(BlockClones)
      .Error(Error)
      .ErrorMessage(ErrorMessage);

    AOnFinalize(ResponseFlow);
  finally
    FreeChatDisplayBlocks(BlockClones);
    ResponseFlow.Free;
  end;
end;

end.

