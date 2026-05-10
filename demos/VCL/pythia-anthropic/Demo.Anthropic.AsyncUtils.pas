unit Demo.Anthropic.AsyncUtils;

interface

uses
  System.SysUtils, System.IOUtils, System.Classes, System.Threading, System.JSON,
  Winapi.Windows,
  Anthropic, Anthropic.Types, Anthropic.Helpers, Anthropic.Async.Promise,
  WVPythia.Chat.Interfaces, WVPythia.Vendors.Services, WVPythia.TextFile.Helper,
  WVPythia.JSON.SafeWriter,
  Demo.Anthropic.Helpers;

type
  IAnthropicClientUtils = interface
    ['{7A5E70A4-251C-47B0-BBBA-185DA65A2A76}']
    procedure ASyncSessionRename(const ChatID: string; const ContentToSummarize: string);
    procedure CustomSkillRegister(const SkillID: string; const AName: string);
    function WhenAllRetrieve(const IDs: TArray<string>): TPromise<TArray<string>>;
    procedure AsyncDownloadAs(const ID, LocalPath: string);
    procedure AsyncDeleteFire(const ID: string);
    procedure AsyncDeleteAllFire(const IDs: TArray<string>);
  end;

  TAnthropicClientUtils = class(TInterfacedObject, IAnthropicClientUtils)
  const
    MODEL_FOR_RENAMING = 'claude-haiku-4-5';
  private
    FClient: IAnthropic;
    FPythia: IPythiaBrowser;
  protected
    /// <summary>
    /// Searches Anthropic custom skills by display title, following all
    /// result pages until a case-insensitive match for AName is found.
    /// Returns the matching skill ID, or an empty string when no match exists.
    /// </summary>
    function FindCustomSkillIDByDisplayTitle(const AName: string): string;

    /// <summary>
    /// Registers a custom skill by creating it from the files in Folder and
    /// assigning AName as its display title. The Skills API creates the skill
    /// and its first immutable version in a single upload. Returns the new
    /// skill ID.
    /// </summary>
    function SkillRegister(const AName: string; const Folder: string): string;
  public
    constructor Create(const AClient: IAnthropic; const ABrowser: IPythiaBrowser);

    /// <summary>
    /// Fire-and-forget chat-title generation for ChatID. The model summarizes
    /// ContentToSummarize into a short title, which is then saved to the
    /// persistent chat store and reflected in the active chat session. Empty
    /// results and failures are ignored.
    /// </summary>
    procedure ASyncSessionRename(const ChatID: string; const ContentToSummarize: string);

    /// <summary>
    /// Registers or resolves the Anthropic custom skill identified by AName.
    /// If the registered skill ID differs from SkillID, the local skill-card
    /// file is updated accordingly. Missing folders, registration failures,
    /// and update results are reported through the Pythia UI.
    /// </summary>
    procedure CustomSkillRegister(const SkillID: string; const AName: string);

    /// <summary>
    /// Resolves all retrieve promises in parallel and yields the server-side
    /// filenames in the same order as the input IDs. The returned promise
    /// rejects on first failure.
    /// </summary>
    function WhenAllRetrieve(const IDs: TArray<string>): TPromise<TArray<string>>;

    /// <summary>
    /// Fire-and-forget download that saves the payload at LocalPath, then
    /// best-effort deletes the server-side file once the local copy is
    /// persisted (or once the download has definitively failed). The delete
    /// is itself fire-and-forget; failures are silent.
    /// </summary>
    procedure AsyncDownloadAs(const ID, LocalPath: string);

    /// <summary>
    /// Fire-and-forget best-effort delete of one server-side file. Empty
    /// IDs are ignored. Errors are silent (404/already-deleted is normal
    /// after AsyncDownloadAs has already cleaned up).
    /// </summary>
    procedure AsyncDeleteFire(const ID: string);

    /// <summary>
    /// Bulk variant. Used to clean up prompt-attached file_ids
    /// (State.Files[i].FileId) once the assistant turn has consumed them.
    /// </summary>
    procedure AsyncDeleteAllFire(const IDs: TArray<string>);
  end;

implementation

var
  GSkillCardsJsonLock: TObject;

function TryUpdateSkillIDInSkillCardsFile(
  const SkillCardsFileName: string;
  const AName: string;
  const NewId: string): Boolean;
begin
  Result := False;
  var UpdatedSkillJsonAsString := '';

  if SkillCardsFileName.IsEmpty then
    Exit;

  TMonitor.Enter(GSkillCardsJsonLock);
  try
    if not FileExists(SkillCardsFileName) then
      Exit;

    var SkillJsonAsString := TFileIOHelper.LoadFromFile(SkillCardsFileName);

    Result := TSkillHelper.TryToUpdateID(
      SkillJsonAsString,
      AName,
      NewId,
      procedure (NewSkillsJsonAsString: string)
      begin
        UpdatedSkillJsonAsString := NewSkillsJsonAsString;
      end);

    if Result then
      TFileIOHelper.SaveToFile(SkillCardsFileName, UpdatedSkillJsonAsString);

  finally
    TMonitor.Exit(GSkillCardsJsonLock);
  end;
end;

procedure QueuePythiaError(const Pythia: IPythiaBrowser; const Message: string);
begin
  if not Assigned(Pythia) then
    Exit;

  TThread.Queue(nil,
    procedure
    begin
      if Assigned(Pythia) then
        Pythia.DisplayError(Message);
    end);
end;

procedure QueuePythiaSuccess(const Pythia: IPythiaBrowser; const Message: string);
begin
  if not Assigned(Pythia) then
    Exit;

  TThread.Queue(nil,
    procedure
    begin
      if Assigned(Pythia) then
        Pythia.DisplaySuccess(Message);
    end);
end;

procedure QueuePythiaWarning(const Pythia: IPythiaBrowser; const Message: string);
begin
  if not Assigned(Pythia) then
    Exit;

  TThread.Queue(nil,
    procedure
    begin
      if Assigned(Pythia) then
        Pythia.DisplayWarning(Message);
    end);
end;

{ TAnthropicClientUtils }

function TAnthropicClientUtils.WhenAllRetrieve(
  const IDs: TArray<string>): TPromise<TArray<string>>;
begin
  Result := TPromise<TArray<string>>.Create(
    procedure (Resolve: TProc<TArray<string>>; Reject: TProc<Exception>)
    var
      Names: TArray<string>;
      Remaining: Integer;
      Settled: Boolean;
    begin
      SetLength(Names, Length(IDs));
      Remaining := Length(IDs);
      Settled := False;

      if Remaining = 0 then
        begin
          Resolve(Names);
          Exit;
        end;

      {--- Single-point settle helpers. All paths (sync setup failure, async
           Then/Catch bodies) must funnel through these so the outer promise
           is guaranteed to settle exactly once even when something throws
           outside the framework's try/except (e.g. CloneException failure on
           an exotic exception class, or a throw in a queued &Catch lambda). }
      var SettleResolve: TProc :=
        procedure
        begin
          if Settled then
            Exit;

          Settled := True;
          Resolve(Names);
        end;

      var SettleReject: TProc<string> :=
        procedure (Msg: string)
        begin
          if Settled then
            Exit;

          Settled := True;
          try
            Reject(Exception.Create(Msg));
          except
            {--- Last-resort guard: never let an exception escape the queued
                 lambda, otherwise the outer promise stays pending forever and
                 the surrounding flow never emits TFinalizeData. }
          end;
        end;

      {--- Per-iteration capture: an inline var Idx := I inside the for body
           does NOT create a fresh slot per iteration in Delphi (the begin..end
           block is shared by all iterations), so all inner closures would
           capture the same Idx and only the last index would be written.
           Wrapping the body in an anonymous method called with I as a
           parameter forces a new stack frame per call, giving each closure
           its own captured Idx. }
      var StartOne: TProc<Integer> :=
        procedure (Idx: Integer)
        begin
          try
            FClient.Files.AsyncAwaitRetrieve(IDs[Idx])
              .&Then(
                procedure (Value: TFile)
                begin
                  if Settled then
                    Exit;

                  try
                    Names[Idx] := Value.Filename;
                    Dec(Remaining);

                    if Remaining = 0 then
                      SettleResolve();
                  except
                    on E: Exception do
                      SettleReject(Format('Files.Retrieve Then handler failed: %s (%s)',
                        [E.Message, E.ClassName]));
                  end;
                end)
              .&Catch(
                procedure (E: Exception)
                begin
                  {--- Capture message immediately; CloneException on E later
                       (inside the framework) may dereference a freed object
                       or fail on an exotic class. Stringifying here is safe. }
                  var Msg := Format('Files.Retrieve [%s] failed: %s (%s)',
                    [IDs[Idx], E.Message, E.ClassName]);

                  SettleReject(Msg);
                end);
          except
            on E: Exception do
              SettleReject(Format('Files.Retrieve [%s] sync setup failed: %s (%s)',
                [IDs[Idx], E.Message, E.ClassName]));
          end;
        end;

      try
        for var I := Low(IDs) to High(IDs) do
          begin
            if Settled then
              Break;

            StartOne(I);
          end;
      except
        on E: Exception do
          SettleReject(Format('WhenAllRetrieve loop failed: %s (%s)',
            [E.Message, E.ClassName]));
      end;
    end);
end;

procedure TAnthropicClientUtils.AsyncDownloadAs(const ID, LocalPath: string);
begin
  {--- Capture ID into a local for the closures below. The interface method
       parameter is captured fine, but a local makes the cleanup intent
       explicit and avoids any ambiguity when the parameter naming changes. }
  var FileId := ID;

  FClient.Files.AsyncAwaitDownload(FileId)
    .&Then(
      procedure (Value: TFileDownloaded)
      begin
        try
          Value.SaveToFile(LocalPath);
        finally
          {--- Server-side cleanup: this file has now been persisted locally
               (or failed to persist — either way we don't need it on the
               provider anymore). Fire-and-forget; the delete itself logs
               nothing on success and swallows errors. }
          AsyncDeleteFire(FileId);
        end;
      end)
    .&Catch(
      procedure (E: Exception)
      begin
        if Assigned(FPythia) then
          FPythia.DisplayError(Format('Download failed:#10%s', [LocalPath]));

        {--- Even if the download failed, attempt to clean up server-side so
             we don't leak quota for a file we'll never reuse. }
        AsyncDeleteFire(FileId);
      end);
end;

procedure TAnthropicClientUtils.AsyncDeleteFire(const ID: string);
begin
  if ID.Trim.IsEmpty then
    Exit;

  try
    FClient.Files.AsyncAwaitDelete(ID)
      .&Then(
        procedure (Value: TFileDeleted)
        begin
          {--- Best-effort: success is the expected case, no UI noise. }
        end)
      .&Catch(
        procedure (E: Exception)
        begin
          {--- Silent: 404 on an already-deleted id, or transient network
               errors, are not worth surfacing in the chat UI. The file is
               either gone or will be reaped by Anthropic's own retention. }
        end);
  except
    {--- Sync setup failures (FClient in a degraded state) are also silent —
         this is best-effort cleanup, not a critical path. }
  end;
end;

procedure TAnthropicClientUtils.AsyncDeleteAllFire(const IDs: TArray<string>);
begin
  for var I := Low(IDs) to High(IDs) do
    AsyncDeleteFire(IDs[I]);
end;

procedure TAnthropicClientUtils.ASyncSessionRename(const ChatID,
  ContentToSummarize: string);
begin
  var Model := MODEL_FOR_RENAMING;
  var MaxTokens := 1000;
  var Prompt := Format('Summarize the following message:'#10'%s', [ContentToSummarize]);
  var SystemPrompt :=
    '# Rules :' + slineBreak +
    '- Do not comment on your answer' + slineBreak +
    '- Display only the answer' + slineBreak +
    '- Do not use articles or pronouns' + slineBreak +
    '- Write at most 4 words' + sLineBreak +
    '- No final punctuation';

  var Payload: TChatParamProc :=
    procedure (Params: TChatParams)
    begin
      Params
        .Model(Model)
        .System(SystemPrompt)
        .Messages( Generation.MessageParts
          .User(Prompt)
        )
        .MaxTokens(MaxTokens);
    end;

  FClient.Chat.AsyncAwaitCreate(Payload)
    .&Then(
      procedure (Value: TChat)
      begin
        var Name := '';

        for var Content in Value.Content do
          begin
            if Content.&Type = TContentBlockType.text then
              Name := Content.Text;
          end;

        if Name.IsEmpty then
          Exit;

        if not Assigned(FPythia)  then
          Exit;

        if not Assigned(FPythia.PersistentChat) then
          Exit;

        FPythia.PersistentChat.UpdateChatTitleById(ChatID, Name);
        FPythia.PersistentChat.SaveToFile();

        FPythia.ChatSessionRename(ChatID, Name);

      end)
    .&Catch(
      procedure (E: Exception)
      begin
        {--- Silent error }
      end);
end;

constructor TAnthropicClientUtils.Create(const AClient: IAnthropic;
  const ABrowser: IPythiaBrowser);
begin
  inherited Create;
  FClient := AClient;
  FPythia := ABrowser;
end;

procedure TAnthropicClientUtils.CustomSkillRegister(
  const SkillID,
  AName: string);
begin
  if not Assigned(FPythia) then
    Exit;

  var Folder := TPath.Combine(FPythia.GetAppRawName, AName);
  var SkillCardsFileName := FPythia.GetSkillCardsFileName;
  if not FileExists(SkillCardsFileName) then
    Exit;

  if not TDirectory.Exists(Folder) then
    begin
      FPythia.DisplayError(Format('Custom skill folder not found: %s', [Folder]));
      Exit;
    end;

  var Pythia := FPythia;
  var CardSkillID := SkillID;

  TTask.Run(
    procedure
    var
      RegisteredSkillID: string;
      SkillCreated: Boolean;
    begin
      try
        SkillCreated := False;
        RegisteredSkillID := FindCustomSkillIDByDisplayTitle(AName);

        if RegisteredSkillID.IsEmpty then
          begin
            RegisteredSkillID := SkillRegister(AName, Folder);
            SkillCreated := True;
          end;

        if RegisteredSkillID.IsEmpty then
          Exit;

        if CardSkillID <> RegisteredSkillID then
          begin
            if TryUpdateSkillIDInSkillCardsFile(
              SkillCardsFileName,
              AName,
              RegisteredSkillID) then
              QueuePythiaSuccess(Pythia, Format('Custom skill card updated: %s', [RegisteredSkillID]))
            else
              QueuePythiaWarning(Pythia, Format('Custom skill card update failed: %s', [AName]));
          end;

        if SkillCreated then
          QueuePythiaSuccess(Pythia, Format('Custom skill registered: %s', [RegisteredSkillID]))
        else
          QueuePythiaSuccess(Pythia, Format('Custom skill found: %s', [RegisteredSkillID]));
      except
        on E: Exception do
          QueuePythiaError(Pythia, Format('Custom skill registration failed (%s): %s', [AName, E.Message]));
      end;
    end);
end;

function TAnthropicClientUtils.FindCustomSkillIDByDisplayTitle(
  const AName: string): string;
begin
  Result := '';

  var Page := '';
  repeat
    var SkillList := FClient.Skills.List(
      procedure (Params: TSkillListParams)
      begin
        Params
          .Source('custom')
          .Limit(100);

        if not Page.IsEmpty then
          Params.Page(Page);
      end);

    try
      for var Item in SkillList.Data do
        if SameText(Item.DisplayTitle, AName) then
          Exit(Item.Id);

      if SkillList.HasMore and not SkillList.NextPage.IsEmpty then
        Page := SkillList.NextPage
      else
        Page := '';
    finally
      SkillList.Free;
    end;
  until Page.IsEmpty;
end;

function TAnthropicClientUtils.SkillRegister(
  const AName,
  Folder: string): string;
begin
  Result := '';

  var Payload: TSkillFormDataParamProc :=
    procedure (Params: TSkillFormDataParams)
    begin
      Params
        .DisplayTitle(AName)
        .Files(Folder);
    end;

  {--- The Skills API creates the skill and its first immutable version in one upload. }
  var Skill := FClient.Skills.Create(Payload);
  try
    Result := Skill.Id;
  finally
    Skill.Free;
  end;
end;

initialization
  GSkillCardsJsonLock := TObject.Create;

finalization
  GSkillCardsJsonLock.Free;
end.
