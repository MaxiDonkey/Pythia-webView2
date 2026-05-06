unit Demo.Anthropic.Upload;

{-------------------------------------------------------------------------------

  Anthropic-side implementation of the IFileUploadService contract exposed by
  Pythia core. Every selected file routed here is uploaded asynchronously to
  the Anthropic Files API, and its file_id is pushed back to the JS layer via
  IPythiaBrowser.SetFileUploadStatus so the input bubble can carry it into the
  submit payload.

  Threading model:
    All public methods are expected to run on the UI thread. The Anthropic SDK
    promises resolve their .Then / .Catch handlers on the UI thread as well,
    so the internal dictionary is never touched concurrently.

  Cancellation model:
    The SDK does not currently expose a cancel primitive on an in-flight
    upload promise. CancelOrDelete therefore flags the entry as Cancelled;
    when the promise eventually resolves, the resolution handler detects the
    flag, deletes the resulting file_id remotely (fire and forget) and drops
    the entry. Already-Ready entries are deleted immediately.

-------------------------------------------------------------------------------}

interface

uses
  System.SysUtils, System.Generics.Collections,
  WVPythia.Chat.Interfaces, WVPythia.Chat.Consts, WVPythia.Types,
  WVPythia.Strings.Escape,
  Anthropic, Anthropic.Async.Promise;

type
  TUploadEntryStatus = (uesUploading, uesReady, uesFailed);

  TUploadEntry = class
  public
    LocalPath: string;
    Target: TOpenFileTarget;
    Status: TUploadEntryStatus;
    FileId: string;
    ErrorMessage: string;
    Cancelled: Boolean;
  end;

  TDownloadService = class(TInterfacedObject, IFileUploadService)
  private const
    {--- Documents target: only archives go through Files API. PDFs and text
         files keep flowing through the existing inline document-block path. }
    ARCHIVE_EXTENSIONS: array[0..3] of string = ('.zip', '.tar', '.tgz', '.gz');
  private
    FPythia: IPythiaBrowser;
    FClient: IAnthropic;
    FOnPending: TProc;
    FEntries: TObjectDictionary<string, TUploadEntry>;

    function GetOnPendingChanged: TProc;
    procedure SetOnPendingChanged(const Value: TProc);

    class function IsArchiveExtension(const ALocalPath: string): Boolean; static;
    class function ToJSStringOrNull(const S: string): string; static;

    procedure PushUploadStatus(
      const APath, AStatus, AFileId, AErrorMessage: string);
    procedure UpdateAvailability;
    procedure FireAndForgetDelete(const AFileId: string);

  public
    constructor Create(
      const APythia: IPythiaBrowser;
      const AClient: IAnthropic);
    destructor Destroy; override;

    function ShouldHandle(
      const ALocalPath: string;
      const ATarget: TOpenFileTarget): Boolean;

    procedure SubmitForUpload(
      const ALocalPath: string;
      const ATarget: TOpenFileTarget;
      const AOnComplete: TUploadCompleteProc = nil);

    procedure CancelOrDelete(const ALocalPath: string);

    function TryGetFileId(
      const ALocalPath: string;
      out AFileId: string): Boolean;

    function PendingCount: Integer;

    property OnPendingChanged: TProc read GetOnPendingChanged write SetOnPendingChanged;
  end;

implementation

uses
  System.IOUtils;

{ TDownloadService }

constructor TDownloadService.Create(
  const APythia: IPythiaBrowser; const AClient: IAnthropic);
begin
  inherited Create;
  FPythia := APythia;
  FClient := AClient;
  FEntries := TObjectDictionary<string, TUploadEntry>.Create([doOwnsValues]);
end;

destructor TDownloadService.Destroy;
begin
  FEntries.Free;
  inherited;
end;

class function TDownloadService.IsArchiveExtension(
  const ALocalPath: string): Boolean;
begin
  var Ext := TPath.GetExtension(ALocalPath).ToLowerInvariant;

  for var X in ARCHIVE_EXTENSIONS do
    if Ext = X then
      Exit(True);

  Result := False;
end;

class function TDownloadService.ToJSStringOrNull(const S: string): string;
begin
  {--- Build a JS literal expression: 'null' for empty input, otherwise a
       fully-quoted, fully-escaped JS string. The Pythia helpers do not
       pre-escape, so the caller owns this responsibility (project convention,
       see [BubbleInputSetText n'échappe pas]). }
  if S.IsEmpty then
    Result := 'null'
  else
    Result := TEscapeHelper.EscapeJSString(S);
end;

procedure TDownloadService.PushUploadStatus(
  const APath, AStatus, AFileId, AErrorMessage: string);
begin
  {--- AStatus is already a JS literal coming from the FILE_UPLOAD_STATUS_*
       constants in WVPythia.Chat.Consts. Path / fileId / errorMessage are
       converted here. }
  FPythia.SetFileUploadStatus(
    TEscapeHelper.EscapeJSString(APath),
    AStatus,
    ToJSStringOrNull(AFileId),
    ToJSStringOrNull(AErrorMessage)
  );
end;

procedure TDownloadService.UpdateAvailability;
begin
  {--- Push the send-button availability flag to JS, then notify the host
       (the OnPendingChanged hook is intentionally fired on every state
       transition; the contract guarantees a notification at least on every
       zero crossing, which this satisfies). }
  FPythia.SetSendButtonAvailability(PendingCount = 0);
  if Assigned(FOnPending) then
    FOnPending();
end;

procedure TDownloadService.FireAndForgetDelete(const AFileId: string);
begin
  if AFileId.IsEmpty then
    Exit;

  {--- Empty .Then / .Catch handlers ensure the promise chain executes and
       does not surface unhandled rejection in case the remote file was
       already evicted server-side. }
  FClient.Files.AsyncAwaitDelete(AFileId)
    .&Then(procedure (Value: TFileDeleted) begin end)
    .&Catch(procedure (E: Exception) begin end);
end;

function TDownloadService.GetOnPendingChanged: TProc;
begin
  Result := FOnPending;
end;

procedure TDownloadService.SetOnPendingChanged(const Value: TProc);
begin
  FOnPending := Value;
end;

function TDownloadService.ShouldHandle(
  const ALocalPath: string; const ATarget: TOpenFileTarget): Boolean;
begin
  case ATarget of
    TOpenFileTarget.Documents:
      {--- Only archives go through Files API. Other documents keep their
           inline base64 path in BuildContentBlocks. }
      Result := IsArchiveExtension(ALocalPath);

    TOpenFileTarget.Knowledge:
      {--- Knowledge files are always tracked here so a future vectorization
           pipeline can rely on the same status / file_id propagation. }
      Result := True;
  else
    Result := False;
  end;
end;

procedure TDownloadService.SubmitForUpload(
  const ALocalPath: string;
  const ATarget: TOpenFileTarget;
  const AOnComplete: TUploadCompleteProc);
var
  Entry: TUploadEntry;
begin
  {--- Defensive duplicate handling. JS deduplicates by path before reaching
       us, but a removal followed by an immediate re-add of the same path
       could in principle race here. If we already have a Ready entry, just
       short-circuit with the cached file_id. }
  if FEntries.TryGetValue(ALocalPath, Entry) then
  begin
    if (Entry.Status = uesReady) and Assigned(AOnComplete) then
      AOnComplete(TUploadResult.Ok(ALocalPath, Entry.FileId));
    Exit;
  end;

  Entry := TUploadEntry.Create;
  Entry.LocalPath := ALocalPath;
  Entry.Target := ATarget;
  Entry.Status := uesUploading;
  Entry.Cancelled := False;
  FEntries.Add(ALocalPath, Entry);

  PushUploadStatus(ALocalPath, FILE_UPLOAD_STATUS_UPLOADING, '', '');
  UpdateAvailability;

  {--- Capture by value for the closures so the promise resolution can
       correlate back to the right entry even if the caller's frame is gone. }
  var CapturedPath := ALocalPath;
  var CapturedComplete := AOnComplete;

  FClient.Files.AsyncAwaitUpload(
      procedure (Params: TUploadParams)
      begin
        Params.&File(CapturedPath);
      end)
    .&Then(procedure (Value: Anthropic.TFile)
      var
        LocalEntry: TUploadEntry;
      begin
        if not FEntries.TryGetValue(CapturedPath, LocalEntry) then
          begin
            {--- Entry was dropped before completion (rare path: bulk reset).
                 Avoid leaving an orphan on the server. }
            FireAndForgetDelete(Value.Id);
            Exit;
          end;

        if LocalEntry.Cancelled then
          begin
            FireAndForgetDelete(Value.Id);
            FEntries.Remove(CapturedPath);
            UpdateAvailability;
            if Assigned(CapturedComplete) then
              CapturedComplete(TUploadResult.Fail(CapturedPath, 'cancelled'));
            Exit;
          end;

        LocalEntry.Status := uesReady;
        LocalEntry.FileId := Value.Id;

        PushUploadStatus(
          CapturedPath, FILE_UPLOAD_STATUS_READY, Value.Id, '');
        UpdateAvailability;

        if Assigned(CapturedComplete) then
          CapturedComplete(TUploadResult.Ok(CapturedPath, Value.Id));
      end)
    .&Catch(procedure (E: Exception)
      var
        LocalEntry: TUploadEntry;
      begin
        if not FEntries.TryGetValue(CapturedPath, LocalEntry) then
          Exit;

        if LocalEntry.Cancelled then
          begin
            FEntries.Remove(CapturedPath);
            UpdateAvailability;
            Exit;
          end;

        LocalEntry.Status := uesFailed;
        LocalEntry.ErrorMessage := E.Message;

        PushUploadStatus(
          CapturedPath, FILE_UPLOAD_STATUS_FAILED, '', E.Message);
        UpdateAvailability;

        if Assigned(CapturedComplete) then
          CapturedComplete(TUploadResult.Fail(CapturedPath, E.Message));
      end);
end;

procedure TDownloadService.CancelOrDelete(const ALocalPath: string);
var
  Entry: TUploadEntry;
begin
  if not FEntries.TryGetValue(ALocalPath, Entry) then
    Exit;

  case Entry.Status of
    uesUploading:
      {--- Promise still in flight: mark Cancelled and let the resolution
           handler delete the resulting file_id and drop the entry. }
      Entry.Cancelled := True;

    uesReady:
      begin
        var FileIdToDelete := Entry.FileId;
        FEntries.Remove(ALocalPath);
        UpdateAvailability;
        FireAndForgetDelete(FileIdToDelete);
      end;

    uesFailed:
      begin
        FEntries.Remove(ALocalPath);
        UpdateAvailability;
      end;
  end;
end;

function TDownloadService.TryGetFileId(
  const ALocalPath: string; out AFileId: string): Boolean;
var
  Entry: TUploadEntry;
begin
  AFileId := '';
  if not FEntries.TryGetValue(ALocalPath, Entry) then
    Exit(False);

  if Entry.Status <> uesReady then
    Exit(False);

  AFileId := Entry.FileId;
  Result := True;
end;

function TDownloadService.PendingCount: Integer;
var
  Entry: TUploadEntry;
begin
  Result := 0;
  for Entry in FEntries.Values do
    if Entry.Status = uesUploading then
      Inc(Result);
end;

end.
