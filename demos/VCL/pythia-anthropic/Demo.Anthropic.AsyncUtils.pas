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
  end;

  TAnthropicClientUtils = class(TInterfacedObject, IAnthropicClientUtils)
  private
    FClient: IAnthropic;
    FPythia: IPythiaBrowser;
  protected
    function FindCustomSkillIDByDisplayTitle(const AName: string): string;
    function SkillRegister(const AName: string; const Folder: string): string;
  public
    constructor Create(const AClient: IAnthropic; const ABrowser: IPythiaBrowser);

    procedure ASyncSessionRename(const ChatID: string; const ContentToSummarize: string);
    procedure CustomSkillRegister(const SkillID: string; const AName: string);

    {--- Resolves all retrieve promises in parallel and yields the server-side
         filenames in the same order as the input IDs. The returned promise
         rejects on first failure. }
    function WhenAllRetrieve(const IDs: TArray<string>): TPromise<TArray<string>>;

    {--- Fire-and-forget download that saves the payload at LocalPath. }
    procedure AsyncDownloadAs(const ID, LocalPath: string);
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
          FClient.Files.AsyncAwaitRetrieve(IDs[Idx])
            .&Then(
              procedure (Value: TFile)
              begin
                if Settled then
                  Exit;
                Names[Idx] := Value.Filename;
                Dec(Remaining);
                if Remaining = 0 then
                  begin
                    Settled := True;
                    Resolve(Names);
                  end;
              end)
            .&Catch(
              procedure (E: Exception)
              begin
                if Settled then
                  Exit;
                Settled := True;
                Reject(Exception.Create(E.Message));
              end);
        end;

      for var I := Low(IDs) to High(IDs) do
        StartOne(I);
    end);
end;

procedure TAnthropicClientUtils.AsyncDownloadAs(const ID, LocalPath: string);
begin
  FClient.Files.AsyncAwaitDownload(ID)
    .&Then(
      procedure (Value: TFileDownloaded)
      begin
        Value.SaveToFile(LocalPath);
      end)
    .&Catch(
      procedure (E: Exception)
      begin
        if Assigned(FPythia) then
          FPythia.DisplayError(Format('Download failed:#10%s', [LocalPath]));
      end);
end;

procedure TAnthropicClientUtils.ASyncSessionRename(const ChatID,
  ContentToSummarize: string);
begin
  var Model := 'claude-haiku-4-5';
  var MaxTokens := 1000;
  var SystemPrompt :=
    '# Rules :' + slineBreak +
    '- Do not comment on your answer' + slineBreak +
    '- Display only the answer' + slineBreak +
    '- Do not use articles or pronouns' + slineBreak +
    '- Write at most 4 words' + sLineBreak +
    '- No final punctuation';
  var Prompt := Format('Summarize the following message:'#10'%s', [ContentToSummarize]);

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

  var Promise := FClient.Chat.AsyncAwaitCreate(Payload);

  Promise
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
