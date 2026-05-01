unit Demo.Snippet.Plugin.Service;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Generics.Collections,
  WVPythia.Chat.Interfaces, WVPythia.JSON.SafeReader, WVPythia.JSON.SafeWriter,
  WVPythia.TextFile.Helper,
  Demo.Snippet.Plugin.Intf;

type
  TSnippetService = class(TInterfacedObject, ISnippetService)
  strict private const
    SOFT_LIMIT_CHARS = 8 * 1024;
    HARD_LIMIT_CHARS = 64 * 1024;
    EMPTY_OBJECT     = '{}';
    SHOW_FENCE       = '~~~';
  strict private
    FBrowser: IPythiaBrowser;

    function Normalize(const AName: string): string;

    function ValidateName(const AName: string;
      out Normalized: string; out ErrMsg: string): Boolean;
    function ValidateContent(const AContent: string;
      out ErrMsg: string): Boolean;

    function StorageFileName: string;
    function LoadStorage: string;
    procedure SaveStorage(const AJsonAsString: string);

    procedure DeferredSetBubble(const AContent: string);
  private
    function GetBrowser: IPythiaBrowser;
    procedure SetBrowser(const Value: IPythiaBrowser);
  public
    constructor Create;

    property Browser: IPythiaBrowser read GetBrowser write SetBrowser;

    // ISnippetService
    function Save(const AName, AContent: string): TSnippetOperationResult;
    function Use(const AName: string): TSnippetOperationResult;
    function Show(const AName: string): TSnippetOperationResult;
    function List: TSnippetOperationResult;
    function Rename(const AOldName, ANewName: string): TSnippetOperationResult;
    function Delete(const AName: string): TSnippetOperationResult;
    function ImportFromFile(const AFileName: string): TSnippetOperationResult;
    function ExportToFile(const AFileName: string): TSnippetOperationResult;
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Snippet command service

    Storage location

      The snippets file lives next to the other JSON support files of the
      host application:

          <exe-dir>\<AppRawName>\support\<AppRawName>-snippets.json

      The path is derived from IBrowser without requiring any new method on
      the interface:

          dir  := TPath.GetDirectoryName(Browser.GetCapabilitiesFileName)
          file := dir + '\' + Browser.GetAppRawName + '-snippets.json'

      GetCapabilitiesFileName always points inside the support folder, so
      its directory part is the support folder itself.

    Storage shape

      A flat JSON object: { "name1": "content", "name2": "content", ... }

      Keys are normalized snippet names (Trim + ToLowerInvariant). Values
      are the raw snippet text, stored as JSON strings.

    Why flat instead of nested

      TJsonReader / TJsonWriter use a path syntax where '.', '[', ']' are
      structural separators. A flat object lets us reach a snippet with a
      single-token path (the name itself), provided the name does not
      contain those characters. ValidateName rejects them up-front.

    Bubble write deferral

      The runtime calls IBrowser.BubbleInputPartialReset after a command
      returns Ok (TFMXBrowserCommandLine.DispatchCommand). That reset clears
      the textarea on the JS side. If 'use' wrote the snippet synchronously
      via BubbleInputSetText, the partial-reset would erase it.

      DeferredSetBubble enqueues the write through TThread.ForceQueue so
      that it is processed AFTER DoExecute has returned and the runtime has
      already issued the partial reset. The deferred SetText then arrives
      last and fills the bubble.

    Size limits

      Two thresholds, both per-snippet:
        SOFT_LIMIT_CHARS = 8 KB  -> warn but accept
        HARD_LIMIT_CHARS = 64 KB -> reject

      These are demo defaults. They protect the bubble from abusive
      content; tune them in production based on the target vendor's prompt
      size budget.

    Import / export

      Import merges source snippets into the current storage. Conflicts
      are resolved by overwriting. Entries with invalid names or non-string
      values are silently skipped and counted; the user is warned about
      the skip count.

      Export simply writes the current storage to the requested path.

    Tokenizer caveat

      TCommandParser.Tokenize preserves quoted strings as a single
      argument but does NOT support escape sequences. A snippet content
      containing a double-quote cannot be passed via the command line in
      one shot. Document this if you wrap the demo in user-facing help.

    What this service does NOT do

      - Templating / placeholders (e.g. {{name}}). Adding a templating
        engine here would couple the snippet store to a substitution
        policy. Keep it as a future, separate service.

      - Auto-submission of the prompt. The 'use' action fills the bubble;
        the user remains in control of the actual send.

      - Per-user secrets. Snippets are plain text. If a snippet must hold
        a secret, route the secret through ApiKeySecretStore and let the
        snippet reference its name.
*)

{$ENDREGION}

{ TSnippetService }

constructor TSnippetService.Create;
begin
  inherited Create;
end;

function TSnippetService.GetBrowser: IPythiaBrowser;
begin
  Result := FBrowser;
end;

procedure TSnippetService.SetBrowser(const Value: IPythiaBrowser);
begin
  FBrowser := Value;
end;

function TSnippetService.Normalize(const AName: string): string;
begin
  {--- Snippet names are case-insensitive and free of extraneous spaces. }
  Result := AName.Trim.ToLowerInvariant;
end;

function TSnippetService.ValidateName(const AName: string;
  out Normalized, ErrMsg: string): Boolean;
begin
  Normalized := Normalize(AName);
  ErrMsg := '';

  if Normalized.IsEmpty then
    begin
      ErrMsg := 'Snippet name is empty';
      Exit(False);
    end;

  {--- Reject characters that would conflict with TJsonReader / TJsonWriter
       path syntax or with file-system separators. }
  if Normalized.IndexOfAny(['.', '[', ']', '/', '\']) >= 0 then
    begin
      ErrMsg := Format('Invalid character in snippet name "%s"', [AName]);
      Exit(False);
    end;

  Result := True;
end;

function TSnippetService.ValidateContent(const AContent: string;
  out ErrMsg: string): Boolean;
begin
  ErrMsg := '';

  if AContent.Trim.IsEmpty then
    begin
      ErrMsg := 'Snippet content is empty';
      Exit(False);
    end;

  if AContent.Length > HARD_LIMIT_CHARS then
    begin
      ErrMsg := Format('Snippet content exceeds the %d character limit',
        [HARD_LIMIT_CHARS]);
      Exit(False);
    end;

  Result := True;
end;

function TSnippetService.StorageFileName: string;
begin
  {--- The capabilities file lives in the support folder, so its directory
       part is the support folder we want to share with other JSON stores. }
  Result := TPath.Combine(
    TPath.GetDirectoryName(FBrowser.GetCapabilitiesFileName),
    FBrowser.GetAppRawName + '-snippets.json'
  );
end;

function TSnippetService.LoadStorage: string;
begin
  var FileName := StorageFileName;

  if not TFile.Exists(FileName) then
    Exit(EMPTY_OBJECT);

  try
    Result := TFileIOHelper.LoadFromFile(FileName);
  except
    Exit(EMPTY_OBJECT);
  end;

  if not TJsonCheck.IsValid(Result) then
    Result := EMPTY_OBJECT;
end;

procedure TSnippetService.SaveStorage(const AJsonAsString: string);
begin
  TFileIOHelper.SaveToFile(StorageFileName, AJsonAsString);
end;

procedure TSnippetService.DeferredSetBubble(const AContent: string);
begin
  {--- The runtime issues BubbleInputPartialReset after a command returns Ok,
       which clears the textarea on the JS side. We post the SetText to the
       main thread queue so it lands AFTER that reset has fired. }
  var BrowserRef := FBrowser;
  var Content := AContent;
  TThread.ForceQueue(nil,
    procedure
    begin
      BrowserRef.BubbleInputSetText(Content);
    end);
end;

function TSnippetService.Save(const AName,
  AContent: string): TSnippetOperationResult;
{--- Prompt text: /snippet save <name> "<content>" }
var
  Key, Err: string;
begin
  if not ValidateName(AName, Key, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  if not ValidateContent(AContent, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  var Writer := TJsonWriter.Parse(LoadStorage);
  if not Writer.IsValid then
    Writer := TJsonWriter.NewObject;

  Writer.SetString(Key, AContent);
  SaveStorage(Writer.Format());

  if AContent.Length > SOFT_LIMIT_CHARS then
    FBrowser.DisplayWarning(
      Format('Snippet "%s" stored, content larger than %d characters',
      [AName, SOFT_LIMIT_CHARS]))
  else
    FBrowser.DisplaySuccess(Format('Snippet "%s" saved', [AName]));

  Result := TSnippetOperationResult.Ok(Format('"%s" saved', [AName]));
end;

function TSnippetService.Use(const AName: string): TSnippetOperationResult;
{--- Prompt text: /snippet use <name> }
var
  Key, Err: string;
begin
  if not ValidateName(AName, Key, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  var Reader := TJsonReader.Parse(LoadStorage);
  if not Reader.Exists(Key) then
    begin
      var M := Format('Snippet "%s" not found', [AName]);
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  DeferredSetBubble(Reader.AsString(Key));

  Result := TSnippetOperationResult.Ok(Format('"%s" loaded', [AName]));
end;

function TSnippetService.Show(const AName: string): TSnippetOperationResult;
{--- Prompt text: /snippet show <name> }
var
  Key, Err: string;
begin
  if not ValidateName(AName, Key, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  var Reader := TJsonReader.Parse(LoadStorage);
  if not Reader.Exists(Key) then
    begin
      var M := Format('Snippet "%s" not found', [AName]);
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  var Content := Reader.AsString(Key);

  {--- Wrap the snippet in a tilde fence so its Markdown / code is rendered
       verbatim. A 4-backtick fence would also work; tildes avoid clashing
       with the typical backtick blocks found inside snippets. }
  var Block :=
    SHOW_FENCE + sLineBreak +
    Content + sLineBreak +
    SHOW_FENCE;

  FBrowser.DisplaySuccess(
    Format('**%s**' + sLineBreak + sLineBreak + '%s', [AName, Block]));

  Result := TSnippetOperationResult.Ok(Format('"%s" displayed', [AName]));
end;

function TSnippetService.List: TSnippetOperationResult;
{--- Prompt text: /snippet list }
begin
  var Reader := TJsonReader.Parse(LoadStorage);
  var Obj := Reader.JSONObject;

  if (Obj = nil) or (Obj.Count = 0) then
    begin
      var M := 'No snippet stored';
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Ok(M));
    end;

  var Lines := TStringList.Create;
  try
    Lines.Add('--- Availabled Snippets ---');
    Lines.Add('');

    for var I := 0 to Obj.Count - 1 do
      Lines.Add(Format('%s', [Obj.Pairs[I].JsonString.Value]));

    FBrowser.DisplaySuccess(Lines.Text);
  finally
    Lines.Free;
  end;

  Result := TSnippetOperationResult.Ok(Format('%d snippet(s)', [Obj.Count]));
end;

function TSnippetService.Rename(const AOldName,
  ANewName: string): TSnippetOperationResult;
{--- Prompt text: /snippet rename <oldName> <newName> }
var
  OldKey, NewKey, Err: string;
begin
  if not ValidateName(AOldName, OldKey, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  if not ValidateName(ANewName, NewKey, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  if OldKey = NewKey then
    begin
      var M := 'Old and new names are identical';
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  var Reader := TJsonReader.Parse(LoadStorage);

  if not Reader.Exists(OldKey) then
    begin
      var M := Format('Snippet "%s" not found', [AOldName]);
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  if Reader.Exists(NewKey) then
    begin
      var M := Format('Snippet "%s" already exists', [ANewName]);
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  var Content := Reader.AsString(OldKey);

  var Writer := TJsonWriter.Parse(Reader.Source);
  Writer.SetString(NewKey, Content);
  Writer.Remove(OldKey);
  SaveStorage(Writer.Format());

  FBrowser.DisplaySuccess(
    Format('Snippet "%s" renamed to "%s"', [AOldName, ANewName]));

  Result := TSnippetOperationResult.Ok(
    Format('"%s" -> "%s"', [AOldName, ANewName]));
end;

function TSnippetService.Delete(const AName: string): TSnippetOperationResult;
{--- Prompt text: /snippet delete <name> }
var
  Key, Err: string;
begin
  if not ValidateName(AName, Key, Err) then
    begin
      FBrowser.DisplayError(Err);
      Exit(TSnippetOperationResult.Fail(Err));
    end;

  var Writer := TJsonWriter.Parse(LoadStorage);
  if (not Writer.IsValid) or (not Writer.Remove(Key)) then
    begin
      var M := Format('Snippet "%s" not found', [AName]);
      FBrowser.DisplayWarning(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  SaveStorage(Writer.Format());

  FBrowser.DisplaySuccess(Format('Snippet "%s" deleted', [AName]));
  Result := TSnippetOperationResult.Ok(Format('"%s" deleted', [AName]));
end;

function TSnippetService.ImportFromFile(
  const AFileName: string): TSnippetOperationResult;
{--- Prompt text: /snippet import <jsonFile> }
var
  SourceText: string;
begin
  if AFileName.Trim.IsEmpty then
    begin
      var M := 'Import path is empty';
      FBrowser.DisplayError(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  if not TFile.Exists(AFileName) then
    begin
      var M := Format('Import file not found: %s', [AFileName]);
      FBrowser.DisplayError(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  try
    SourceText := TFileIOHelper.LoadFromFile(AFileName);
  except
    on E: Exception do
      begin
        FBrowser.DisplayError(E.Message);
        Exit(TSnippetOperationResult.Fail(E.Message));
      end;
  end;

  var Source := TJsonReader.Parse(SourceText);
  var SourceObj := Source.JSONObject;
  if (not Source.IsValid) or (SourceObj = nil) then
    begin
      var M := 'Import file is not a JSON object';
      FBrowser.DisplayError(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  var Target := TJsonWriter.Parse(LoadStorage);
  if not Target.IsValid then
    Target := TJsonWriter.NewObject;

  var Imported := 0;
  var Skipped := 0;

  for var I := 0 to SourceObj.Count - 1 do
    begin
      var Pair := SourceObj.Pairs[I];
      var Key := Normalize(Pair.JsonString.Value);

      if Key.IsEmpty or (Key.IndexOfAny(['.', '[', ']', '/', '\']) >= 0) then
        begin
          Inc(Skipped);
          Continue;
        end;

      if not (Pair.JsonValue is TJSONString) then
        begin
          Inc(Skipped);
          Continue;
        end;

      var Content := TJSONString(Pair.JsonValue).Value;
      if Content.Length > HARD_LIMIT_CHARS then
        begin
          Inc(Skipped);
          Continue;
        end;

      Target.SetString(Key, Content);
      Inc(Imported);
    end;

  SaveStorage(Target.Format());

  if Skipped > 0 then
    FBrowser.DisplayWarning(
      Format('%d snippet(s) imported, %d skipped', [Imported, Skipped]))
  else
    FBrowser.DisplaySuccess(Format('%d snippet(s) imported', [Imported]));

  Result := TSnippetOperationResult.Ok(
    Format('imported=%d skipped=%d', [Imported, Skipped]));
end;

function TSnippetService.ExportToFile(
  const AFileName: string): TSnippetOperationResult;
{--- Prompt text: /snippet export <jsonFile> }
begin
  if AFileName.Trim.IsEmpty then
    begin
      var M := 'Export path is empty';
      FBrowser.DisplayError(M);
      Exit(TSnippetOperationResult.Fail(M));
    end;

  try
    TFileIOHelper.SaveToFile(AFileName, LoadStorage);
  except
    on E: Exception do
      begin
        FBrowser.DisplayError(E.Message);
        Exit(TSnippetOperationResult.Fail(E.Message));
      end;
  end;

  FBrowser.DisplaySuccess(Format('Snippets exported to %s', [AFileName]));
  Result := TSnippetOperationResult.Ok(
    Format('exported to %s', [AFileName]));
end;

end.
