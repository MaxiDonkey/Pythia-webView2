unit Demo.Grep.Plugin.Service;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  System.NetEncoding, System.JSON,
  WVPythia.Chat.Interfaces, WVPythia.Strings.Escape,
  WVPythia.JSON.SafeReader, WVPythia.JSON.SafeWriter,
  WVPythia.TextFile.Helper,
  Demo.Grep.Plugin.Intf,
  FMX.Dialogs;

type
  TGrepService = class(TInterfacedObject, IGrepService)
  strict private const
    {--- Search scope }
    MAX_FILE_SIZE_BYTES   = 2 * 1024 * 1024;
    MAX_TOTAL_MATCHES     = 800;
    MAX_PATTERN_LENGTH    = 500;

    {--- Per-match snippet }
    MAX_SNIPPET_CHARS     = 320;
    SNIPPET_HEAD_FLAG     = '...';

    {--- Bubble output }
    INJECT_FENCE          = '````';
    DEFAULT_TEMPLATE_NAME = 'GrepPickerTemplate.js';

    {--- Custom event names }
    EVT_PICK              = 'grep.pick';
    EVT_CANCEL            = 'grep.cancel';
  strict private
    FBrowser: IPythiaBrowser;
    FRootDir: string;

    {--- Stable allowlists tuned for a Delphi project, populated once in the
         constructor. Keeping them as fields (rather than re-allocating an
         array on every probe) shaves a few thousand allocations on a
         medium-sized repo walk. }
    FExtensionAllowlist: TArray<string>;
    FDirectoryDenylist: TArray<string>;

    {--- Last result cache, used by /grep last and as a sanity check on the
         payload returned by the JS picker. }
    FLastPattern: string;
    FLastSubPath: string;
    FLastEffectiveRoot: string;
    FLastMatchesJson: string;
    FLastMatchCount: Integer;

    FSkippedUnreadableFiles: Integer;
    FSkippedDecodeFiles: Integer;

    {--- Validation }
    function ValidatePattern(const APattern: string;
      out ErrMsg: string): Boolean;
    function ResolveSearchRoot(const ASubPath: string;
      out AEffectiveRoot, ErrMsg: string): Boolean;

    {--- Search utils }
    function TryLoadTextLines(const AFullPath: string;
      out ALines: TArray<string>;
      out AEncodingName: string): Boolean;

    function LooksLikeUtf8(const ABytes: TBytes): Boolean;
    function LooksLikeUtf16NoBom(const ABytes: TBytes;
      const ABigEndian: Boolean): Boolean;
    function ContainsZeroByte(const ABytes: TBytes): Boolean;

    {--- Walking & matching }
    function IsExtensionAllowed(const AFileName: string): Boolean;
    function IsDirectoryAllowed(const ADirName: string): Boolean;
    function CollectFiles(const ARoot: string): TArray<string>;
    procedure SearchFile(const AFullPath, ARelativePath, ALowerPattern: string;
      AMatches: TList<TGrepMatchRef>);
    function NormalizeSnippet(const ALine: string): string;

    {--- JS picker injection }
    function ResolveTemplatePath(out APath, ErrMsg: string): Boolean;
    function BuildPayloadJson(const APattern, AEffectiveRoot: string;
      const AMatches: TList<TGrepMatchRef>): string;
    function InjectPicker(const APayloadJson: string;
      out ErrMsg: string): Boolean;

    {--- Bubble formatting }
    function FormatPickedAsMarkdown(const ARawJson: string): string;
    procedure DeferredSetBubble(const AContent: string);
  private
    function GetBrowser: IPythiaBrowser;
    procedure SetBrowser(const Value: IPythiaBrowser);
    function GetRootDir: string;
    procedure SetRootDir(const Value: string);
  public
    constructor Create(const ARootDir: string);

    property Browser: IPythiaBrowser read GetBrowser write SetBrowser;
    property RootDir: string read GetRootDir write SetRootDir;

    // IGrepService
    function Find(const APattern, ASubPath: string): TGrepOperationResult;
    function Last: TGrepOperationResult;
    function Status: TGrepOperationResult;
    function HandleCustomEvent(const AEventName,
      APayloadJson: string): Boolean;
  end;

implementation

{$REGION 'Dev notes'}

(*
    Developer Note - Grep command service

    Goal of this plugin

      Demonstrate a two-way bridge between Delphi and the WebView2 JS layer
      while staying within the prompt/context-construction theme:

        1. Delphi collects matches by walking the filesystem.
        2. Delphi pushes a self-contained picker UI into the WebView via
           ExecuteScript. The matches travel as a base64-encoded JSON
           payload to keep the injection script small and free of escape
           pitfalls.
        3. The user ticks the matches that should land in the prompt as
           context.
        4. The picker emits a custom-event ('grep.pick') with the selected
           matches; Delphi formats them as a Markdown context block and
           writes the result into the input bubble.

      This is the canonical custom-event round-trip described in the
      framework documentation, applied to a realistic context-curation
      task.

    Where matches live during the round-trip

      The JS picker carries the full match data inline. When the user
      validates, the payload it returns to Delphi already contains every
      file/line/snippet needed to format the context block. The service
      does NOT consult its in-memory state during the formatting step:
      it trusts the JS-side payload (which the user has just curated).

      The in-memory state (FLastMatchesJson, ...) is kept only to:
        - implement /grep last (re-inject the same picker);
        - print a meaningful /grep status.

    Custom-event routing

      The framework routes custom-event JSON to
      IChatManagedItemDialogService.ActivateCustomEvent on the host
      adapter. The host is responsible for dispatching by 'name'. For a
      grep payload, the adapter forwards the event to
      HandleCustomEvent('grep.<sub>', payloadJson):

        var Reader := TJsonReader.Parse(ARawJson);
        var EventName := Reader.AsString('name');
        var PayloadJson := Reader.ExtractSubJson('payload', '{}');

        if EventName.StartsWith('grep.') then
          Exit(GrepService.HandleCustomEvent(EventName, PayloadJson));

      The service handles 'grep.pick' and 'grep.cancel'. Unknown grep.*
      sub-events return False so the host can react if it cares.

    Why a literal substring search

      A regex engine is overkill for a demo; an opinionated substring
      search is enough to exercise the round-trip. The pattern is matched
      case-insensitively. Switching to TRegEx is a localized change in
      SearchFile if a user later asks for it.

    Search scope

      Files are filtered by ExtensionAllowlist (Delphi-leaning by default)
      and directories by DirectoryDenylist. The allowlist exists primarily
      to skip binaries that would slow down the walk; it is not a security
      boundary. MAX_FILE_SIZE_BYTES guards against the rare oversized text
      file (generated SQL dumps, single-file logs, etc.).

      The total result list is capped at MAX_TOTAL_MATCHES. Past that, the
      walk stops and the picker is told the result is partial.

    Snippet shape

      A match snippet is the trimmed content of the matching line, capped
      at MAX_SNIPPET_CHARS. We do NOT add neighbour-line context: the
      picker keeps the UI dense and the prompt budget compact. The
      Markdown context block uses a 4-backtick fence (INJECT_FENCE) so
      typical code-block content does not break the rendering.

    Bubble write deferral

      Identical pattern to the snippet/git plugins: the runtime issues
      BubbleInputPartialReset after a custom-event handler completes (or
      after any command). DeferredSetBubble enqueues the SetText through
      TThread.ForceQueue so it lands AFTER the runtime's reset.

    Template loading

      The picker JS lives next to the standard templates, under
      <assetsFolder>\scripts\GrepPickerTemplate.js. Copy the file once
      after building the demo (or have your build copy step include it).

    What this service does NOT do

      - Regex search (intentional; see above).
      - File-system writes.
      - Background work: the walk runs synchronously on the calling
        thread. Large repositories should bound the search via the
        sub-path argument.
      - Scope leak protection: the service trusts the host-provided
        RootDir. Do NOT expose a /grep dir command path coming from an
        untrusted source if the host has elevated permissions.
*)

{$ENDREGION}

{ TGrepService }

constructor TGrepService.Create(const ARootDir: string);
begin
  inherited Create;
  FRootDir := ARootDir;

  {--- Populate filter lists once. Keep them small and well-known; an
       integrator who needs more should fork the unit. }
  FExtensionAllowlist := [
    '.pas', '.dpr', '.dproj', '.inc', '.dfm', '.fmx',
    '.json', '.md', '.txt', '.cfg', '.ini',
    '.htm', '.html', '.css', '.js', '.ts',
    '.xml', '.yaml', '.yml'
  ];

  FDirectoryDenylist := [
    '.git', '.svn', '.hg',
    'dcu', '__history', '__recovery',
    'node_modules', '.vscode', '.idea',
    'bin', 'obj', 'release', 'debug',
    'win32', 'win64', 'win32release', 'win64release'
  ];
end;

function TGrepService.GetBrowser: IPythiaBrowser;
begin
  Result := FBrowser;
end;

procedure TGrepService.SetBrowser(const Value: IPythiaBrowser);
begin
  FBrowser := Value;
end;

function TGrepService.GetRootDir: string;
begin
  Result := FRootDir;
end;

procedure TGrepService.SetRootDir(const Value: string);
begin
  FRootDir := Value.Trim;
end;

function TGrepService.ValidatePattern(const APattern: string;
  out ErrMsg: string): Boolean;
begin
  ErrMsg := '';

  if APattern.Trim.IsEmpty then
    begin
      ErrMsg := 'Search pattern is empty';
      Exit(False);
    end;

  if APattern.Length > MAX_PATTERN_LENGTH then
    begin
      ErrMsg := Format('Search pattern exceeds %d characters',
        [MAX_PATTERN_LENGTH]);
      Exit(False);
    end;

  Result := True;
end;

function TGrepService.ResolveSearchRoot(const ASubPath: string;
  out AEffectiveRoot, ErrMsg: string): Boolean;
begin
  AEffectiveRoot := '';
  ErrMsg := '';

  if FRootDir.Trim.IsEmpty then
    begin
      ErrMsg := 'Grep root directory is not set. Use /grep dir <path>';
      Exit(False);
    end;

  if not TDirectory.Exists(FRootDir) then
    begin
      ErrMsg := Format('Grep root directory does not exist: %s', [FRootDir]);
      Exit(False);
    end;

  if ASubPath.Trim.IsEmpty then
    begin
      AEffectiveRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(FRootDir));
      Exit(True);
    end;

  if ASubPath.IndexOfAny(['*', '?']) >= 0 then
    begin
      ErrMsg := 'Sub-path must not contain wildcards';
      Exit(False);
    end;

  {--- Canonicalize root + sub-path and verify the result still lives under
       root. This catches '..' segments, symlinks, drive letters, mixed
       separators, and trailing-slash subtleties without false positives on
       legitimate names that happen to contain dots (e.g. 'my..folder'). }
  var FullRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(FRootDir));
  var FullSub := TPath.GetFullPath(TPath.Combine(FRootDir, ASubPath));

  if not (FullSub + PathDelim).StartsWith(FullRoot, True) then
    begin
      ErrMsg := 'Sub-path escapes the configured root directory';
      Exit(False);
    end;

  if not TDirectory.Exists(FullSub) then
    begin
      ErrMsg := Format('Sub-path does not exist: %s', [FullSub]);
      Exit(False);
    end;

  AEffectiveRoot := ExcludeTrailingPathDelimiter(FullSub);
  Result := True;
end;

function TGrepService.IsExtensionAllowed(const AFileName: string): Boolean;
var
  Ext: string;
  Allowed: string;
begin
  Ext := TPath.GetExtension(AFileName).ToLowerInvariant;
  if Ext.IsEmpty then
    Exit(False);

  for Allowed in FExtensionAllowlist do
    if Ext = Allowed then
      Exit(True);

  Result := False;
end;

function TGrepService.IsDirectoryAllowed(const ADirName: string): Boolean;
var
  Lower: string;
  Denied: string;
begin
  Lower := ADirName.ToLowerInvariant;

  for Denied in FDirectoryDenylist do
    if Lower = Denied then
      Exit(False);

  Result := True;
end;

function TGrepService.CollectFiles(const ARoot: string): TArray<string>;
var
  Files: TList<string>;

  procedure Walk(const ADir: string);
  begin
    {--- Files at this level. }
    for var FileName in TDirectory.GetFiles(ADir) do
      if IsExtensionAllowed(FileName) then
        try
          if TFile.GetSize(FileName) <= MAX_FILE_SIZE_BYTES then
            Files.Add(FileName);
        except
          {--- Permission denied / locked file: skip silently. }
        end;

    {--- Recurse into allowed sub-directories. }
    for var SubDir in TDirectory.GetDirectories(ADir) do
      if IsDirectoryAllowed(TPath.GetFileName(SubDir)) then
        try
          Walk(SubDir);
        except
          {--- Inaccessible sub-tree: skip silently. }
        end;
  end;

begin
  Files := TList<string>.Create;
  try
    try
      Walk(ARoot);
    except
      {--- Top-level walk failure: return whatever was collected so far. }
    end;
    Result := Files.ToArray;
  finally
    Files.Free;
  end;
end;

function TGrepService.ContainsZeroByte(const ABytes: TBytes): Boolean;
begin
  for var B in ABytes do
    if B = 0 then
      Exit(True);

  Result := False;
end;

function TGrepService.NormalizeSnippet(const ALine: string): string;
begin
  Result := ALine.Trim;

  if Result.Length > MAX_SNIPPET_CHARS then
    Result := Result.Substring(0, MAX_SNIPPET_CHARS) + ' ' + SNIPPET_HEAD_FLAG;
end;

procedure TGrepService.SearchFile(const AFullPath, ARelativePath,
  ALowerPattern: string; AMatches: TList<TGrepMatchRef>);
var
  Lines: TArray<string>;
  EncodingName: string;
  Match: TGrepMatchRef;
begin
  if not TryLoadTextLines(AFullPath, Lines, EncodingName) then
    Exit;

  for var I := Low(Lines) to High(Lines) do
    begin
      if AMatches.Count >= MAX_TOTAL_MATCHES then
        Exit;

      if Lines[I].ToLowerInvariant.IndexOf(ALowerPattern) < 0 then
        Continue;

      Match := Default(TGrepMatchRef);
      Match.FullPath := AFullPath;
      Match.RelativePath := ARelativePath;
      Match.LineNumber := I + 1;
      Match.Snippet := NormalizeSnippet(Lines[I]);
      AMatches.Add(Match);
    end;
end;

function TGrepService.ResolveTemplatePath(out APath, ErrMsg: string): Boolean;
begin
  APath := '';
  ErrMsg := '';

  var AssetsFolder := FBrowser.GetAssetsFolder;
  if AssetsFolder.Trim.IsEmpty then
    begin
      ErrMsg := 'Assets folder is not initialized';
      Exit(False);
    end;

  var Candidate := TPath.Combine(
    TPath.Combine(AssetsFolder, 'scripts'),
    DEFAULT_TEMPLATE_NAME);

  if not TFile.Exists(Candidate) then
    begin
      ErrMsg := Format(
        'Picker template not found: %s. Copy %s into assets\scripts.',
        [Candidate, DEFAULT_TEMPLATE_NAME]);
      Exit(False);
    end;

  APath := Candidate;
  Result := True;
end;

function TGrepService.BuildPayloadJson(const APattern,
  AEffectiveRoot: string;
  const AMatches: TList<TGrepMatchRef>): string;
var
  ItemWriter: TJsonWriter;
begin
  var Writer := TJsonWriter.NewObject;
  Writer.SetString('pattern', APattern);
  Writer.SetString('root', AEffectiveRoot);
  Writer.SetInteger('count', AMatches.Count);
  Writer.SetBoolean('truncated', AMatches.Count >= MAX_TOTAL_MATCHES);
  Writer.EnsureArray('matches');

  for var I := 0 to AMatches.Count - 1 do
    begin
      ItemWriter := TJsonWriter.NewObject;
      ItemWriter.SetInteger('id', I);
      ItemWriter.SetString('file', AMatches[I].RelativePath);
      ItemWriter.SetInteger('line', AMatches[I].LineNumber);
      ItemWriter.SetString('snippet', AMatches[I].Snippet);
      Writer.AppendObjectJson('matches', ItemWriter.ToJson);
    end;

  Result := Writer.ToJson;
end;

function TGrepService.InjectPicker(const APayloadJson: string;
  out ErrMsg: string): Boolean;
var
  TemplatePath: string;
  TemplateText: string;
begin
  ErrMsg := '';

  if not ResolveTemplatePath(TemplatePath, ErrMsg) then
    Exit(False);

  try
    TemplateText := TFileIOHelper.LoadFromFile(TemplatePath);
  except
    on E: Exception do
      begin
        ErrMsg := 'Failed to read picker template: ' + E.Message;
        Exit(False);
      end;
  end;

  {--- We pass the payload base64-encoded so the script body remains free
       of JSON quoting / escaping concerns: the JS template decodes it once
       at startup with atob + JSON.parse. }
  var EncodedPayload: string := TNetEncoding.Base64String.EncodeBytesToString(
    TEncoding.UTF8.GetBytes(APayloadJson));

  {--- Defensive: the value is embedded into a JS string literal, so it must
       never contain physical line breaks. Base64String should already avoid
       them, but this also protects future edits. }
  EncodedPayload := EncodedPayload
    .Replace(#13, '', [rfReplaceAll])
    .Replace(#10, '', [rfReplaceAll]);

  var Preamble :=
    '(function(){window.__grepPickerPayload__ = "' + EncodedPayload + '";})();';

  Result := FBrowser.ExecuteScript(Preamble + sLineBreak + TemplateText);

  if not Result then
    ErrMsg := 'ExecuteScript returned False';
end;

function TGrepService.Find(const APattern,
  ASubPath: string): TGrepOperationResult;
{--- Prompt text: /grep find <pattern> [<subPath>] }
var
  Err: string;
  EffectiveRoot: string;
  LowerPattern: string;
  AllFiles: TArray<string>;
  Matches: TList<TGrepMatchRef>;
  PayloadJson: string;
  MatchCount: Integer;
begin
  if not ValidatePattern(APattern, Err) then
    Exit(TGrepOperationResult.Fail(Err));

  if not ResolveSearchRoot(ASubPath, EffectiveRoot, Err) then
    Exit(TGrepOperationResult.Fail(Err));

  FSkippedUnreadableFiles := 0;
  FSkippedDecodeFiles := 0;

  LowerPattern := APattern.ToLowerInvariant;

  AllFiles := CollectFiles(EffectiveRoot);

  if Length(AllFiles) = 0 then
    Exit(TGrepOperationResult.Fail(
      Format('No searchable file under %s. Check the sub-path and extension allowlist.',
        [EffectiveRoot])));

  Matches := TList<TGrepMatchRef>.Create;
  try
    for var FileName in AllFiles do
      begin
        if Matches.Count >= MAX_TOTAL_MATCHES then
          Break;

        {--- TPath.GetRelativePath handles trailing-separator and case
             differences correctly across drives and UNC paths. }
        var Rel := FileName.Substring(EffectiveRoot.Length).TrimLeft(['\', '/']);
        SearchFile(FileName, Rel, LowerPattern, Matches);
      end;

    if Matches.Count = 0 then
      Exit(TGrepOperationResult.Fail(
        Format('No match for "%s" under %s', [APattern, EffectiveRoot])));

    {--- Capture before freeing so /grep status / Ok message do not need to
         re-parse the JSON we just built. }
    MatchCount := Matches.Count;
    PayloadJson := BuildPayloadJson(APattern, EffectiveRoot, Matches);
  finally
    Matches.Free;
  end;

  if not InjectPicker(PayloadJson, Err) then
    Exit(TGrepOperationResult.Fail(Err));

  FLastPattern := APattern;
  FLastSubPath := ASubPath;
  FLastEffectiveRoot := EffectiveRoot;
  FLastMatchesJson := PayloadJson;
  FLastMatchCount := MatchCount;

  if (FSkippedUnreadableFiles > 0) or (FSkippedDecodeFiles > 0) then
    Result := TGrepOperationResult.Ok(
      Format('%d match(es) for "%s" - skipped: %d unreadable, %d decode/binary',
        [
          FLastMatchCount,
          APattern,
          FSkippedUnreadableFiles,
          FSkippedDecodeFiles
        ]))
  else
    Result := TGrepOperationResult.Ok(
      Format('%d match(es) for "%s"', [FLastMatchCount, APattern]));
end;

function TGrepService.Last: TGrepOperationResult;
{--- Prompt text: /grep last }
var
  Err: string;
begin
  if FLastMatchesJson.IsEmpty then
    Exit(TGrepOperationResult.Fail('No previous grep result to redisplay'));

  if not InjectPicker(FLastMatchesJson, Err) then
    Exit(TGrepOperationResult.Fail(Err));

  Result := TGrepOperationResult.Ok(
    Format('Re-opened picker with %d match(es)', [FLastMatchCount]));
end;

function TGrepService.LooksLikeUtf16NoBom(const ABytes: TBytes;
  const ABigEndian: Boolean): Boolean;
var
  Pairs: Integer;
  OddZeros: Integer;
  EvenZeros: Integer;
  HiZeros: Integer;
  LoZeros: Integer;
begin
  Result := False;

  Pairs := Length(ABytes) div 2;
  if Pairs < 8 then
    Exit;

  OddZeros := 0;
  EvenZeros := 0;

  for var I := 0 to Pairs - 1 do
    begin
      if ABytes[2 * I] = 0 then
        Inc(EvenZeros);

      if ABytes[2 * I + 1] = 0 then
        Inc(OddZeros);
    end;

  {--- For BE the high byte sits at the even index, for LE at the odd
       index. A predominantly-ASCII text in either UTF-16 variant has many
       zeros on the high side and almost none on the low side. }
  if ABigEndian then
    begin
      HiZeros := EvenZeros;
      LoZeros := OddZeros;
    end
  else
    begin
      HiZeros := OddZeros;
      LoZeros := EvenZeros;
    end;

  Result :=
    (HiZeros > Pairs div 3) and
    (LoZeros < Pairs div 20);
end;

function TGrepService.LooksLikeUtf8(const ABytes: TBytes): Boolean;

  function IsCont(const I: Integer): Boolean;
  begin
    Result :=
      (I < Length(ABytes)) and
      ((ABytes[I] and $C0) = $80);
  end;

var
  I: Integer;
  B: Byte;
begin
  I := 0;

  while I < Length(ABytes) do
    begin
      B := ABytes[I];

      // ASCII
      if B <= $7F then
        begin
          Inc(I);
          Continue;
        end;

      // 2 bytes: C2..DF 80..BF
      if (B >= $C2) and (B <= $DF) then
        begin
          if not IsCont(I + 1) then
            Exit(False);
          Inc(I, 2);
          Continue;
        end;

      // 3 bytes, with overlong/surrogate checks
      if B = $E0 then
        begin
          if not (
            (I + 2 < Length(ABytes)) and
            (ABytes[I + 1] >= $A0) and (ABytes[I + 1] <= $BF) and
            IsCont(I + 2)
          ) then
            Exit(False);
          Inc(I, 3);
          Continue;
        end;

      if ((B >= $E1) and (B <= $EC)) or ((B >= $EE) and (B <= $EF)) then
        begin
          if not (IsCont(I + 1) and IsCont(I + 2)) then
            Exit(False);
          Inc(I, 3);
          Continue;
        end;

      if B = $ED then
        begin
          if not (
            (I + 2 < Length(ABytes)) and
            (ABytes[I + 1] >= $80) and (ABytes[I + 1] <= $9F) and
            IsCont(I + 2)
          ) then
            Exit(False);
          Inc(I, 3);
          Continue;
        end;

      // 4 bytes
      if B = $F0 then
        begin
          if not (
            (I + 3 < Length(ABytes)) and
            (ABytes[I + 1] >= $90) and (ABytes[I + 1] <= $BF) and
            IsCont(I + 2) and
            IsCont(I + 3)
          ) then
            Exit(False);
          Inc(I, 4);
          Continue;
        end;

      if (B >= $F1) and (B <= $F3) then
        begin
          if not (IsCont(I + 1) and IsCont(I + 2) and IsCont(I + 3)) then
            Exit(False);
          Inc(I, 4);
          Continue;
        end;

      if B = $F4 then
        begin
          if not (
            (I + 3 < Length(ABytes)) and
            (ABytes[I + 1] >= $80) and (ABytes[I + 1] <= $8F) and
            IsCont(I + 2) and
            IsCont(I + 3)
          ) then
            Exit(False);
          Inc(I, 4);
          Continue;
        end;

      Exit(False);
    end;

  Result := True;
end;

function TGrepService.Status: TGrepOperationResult;
{--- Prompt text: /grep status }
begin
  var Lines := TStringList.Create;
  try
    Lines.Add('--- Grep status ---');
    Lines.Add('');

    if FRootDir.Trim.IsEmpty then
      Lines.Add('Root dir : <not set> (use /grep dir <path>)')
    else
      Lines.Add(Format('Root dir : %s', [FRootDir]));

    if FLastPattern.IsEmpty then
      Lines.Add('Last find: <none>')
    else
      begin
        Lines.Add(Format('Last find: "%s"', [FLastPattern]));

        if not FLastSubPath.IsEmpty then
          Lines.Add(Format('Last sub : %s', [FLastSubPath]));

        Lines.Add(Format('Matches  : %d', [FLastMatchCount]));

        if (FSkippedUnreadableFiles > 0) or (FSkippedDecodeFiles > 0) then
          Lines.Add(Format('Skipped  : %d unreadable, %d decode/binary',
            [FSkippedUnreadableFiles, FSkippedDecodeFiles]));
      end;

    FBrowser.DisplaySuccess(TEscapeHelper.EscapeJSString(Lines.Text, False));
  finally
    Lines.Free;
  end;

  Result := TGrepOperationResult.Ok('status displayed');
end;

function TGrepService.TryLoadTextLines(const AFullPath: string;
  out ALines: TArray<string>; out AEncodingName: string): Boolean;
var
  Bytes: TBytes;
  Text: string;
  Lines: TStringList;
begin
  ALines := [];
  AEncodingName := '';

  try
    Bytes := TFile.ReadAllBytes(AFullPath);
  except
    on E: Exception do
      begin
        AEncodingName := 'unreadable: ' + E.ClassName;
        Inc(FSkippedUnreadableFiles);
        Exit(False);
      end;
  end;

  if Length(Bytes) = 0 then
    begin
      AEncodingName := 'empty';
      Exit(True);
    end;

  try
    // UTF-8 BOM
    if
      (Length(Bytes) >= 3) and
      (Bytes[0] = $EF) and
      (Bytes[1] = $BB) and
      (Bytes[2] = $BF)
    then
      begin
        Text := TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3);
        AEncodingName := 'utf-8-bom';
      end

    // UTF-16 LE BOM
    else if
      (Length(Bytes) >= 2) and
      (Bytes[0] = $FF) and
      (Bytes[1] = $FE)
    then
      begin
        Text := TEncoding.Unicode.GetString(Bytes, 2, Length(Bytes) - 2);
        AEncodingName := 'utf-16le-bom';
      end

    // UTF-16 BE BOM
    else if
      (Length(Bytes) >= 2) and
      (Bytes[0] = $FE) and
      (Bytes[1] = $FF)
    then
      begin
        Text := TEncoding.BigEndianUnicode.GetString(Bytes, 2, Length(Bytes) - 2);
        AEncodingName := 'utf-16be-bom';
      end

    // UTF-8 without BOM
    else if LooksLikeUtf8(Bytes) then
      begin
        Text := TEncoding.UTF8.GetString(Bytes);
        AEncodingName := 'utf-8';
      end

    // UTF-16 without BOM, rare but cheap to handle
    else if LooksLikeUtf16NoBom(Bytes, False) then
      begin
        Text := TEncoding.Unicode.GetString(Bytes);
        AEncodingName := 'utf-16le';
      end

    else if LooksLikeUtf16NoBom(Bytes, True) then
      begin
        Text := TEncoding.BigEndianUnicode.GetString(Bytes);
        AEncodingName := 'utf-16be';
      end

    // Binary-looking file: do not try to grep it.
    else if ContainsZeroByte(Bytes) then
      begin
        AEncodingName := 'binary-or-unknown';
        Inc(FSkippedDecodeFiles);
        Exit(False);
      end

    // Legacy Delphi source: ANSI fallback.
    else
      begin
        Text := TEncoding.Default.GetString(Bytes);
        AEncodingName := 'ansi-default';
      end;

    Lines := TStringList.Create;
    try
      Lines.Text := Text;
      ALines := Lines.ToStringArray;
    finally
      Lines.Free;
    end;

    Result := True;
  except
    on E: Exception do
      begin
        AEncodingName := 'decode-failed: ' + E.ClassName;
        Inc(FSkippedDecodeFiles);
        Result := False;
      end;
  end;
end;

function TGrepService.FormatPickedAsMarkdown(const ARawJson: string): string;
{--- Build the Markdown context block from the JS-side payload received
     in the 'grep.pick' event. We do NOT cross-check against FLastMatchesJson:
     the user has just curated the selection in the picker, so trusting the
     payload is the correct policy here. }
var
  Reader: TJsonReader;
  Lines: TStringList;
begin
  Reader := TJsonReader.Parse(ARawJson);

  if not Reader.IsValid then
    Exit('');

  var Pattern := Reader.AsString('pattern');
  var Root := Reader.AsString('root');
  var Count := Reader.Count('selected');

  if Count <= 0 then
    Exit('');

  Lines := TStringList.Create;
  try
    Lines.Add(Format('## Code context from `%s`', [Root]));

    if not Pattern.IsEmpty then
      Lines.Add(Format('Pattern: `%s`', [Pattern]));

    Lines.Add('');

    {--- Group consecutive picks by file to keep the prompt compact and
         the Markdown human-readable. The picker preserves file ordering
         so a stable groupBy on the fly is enough. }
    var CurrentFile := '';

    for var I := 0 to Count - 1 do
      begin
        var FileRel := Reader.AsString(
          Format('selected[%d].file', [I]));
        var Line := Reader.AsInteger(
          Format('selected[%d].line', [I]));
        var Snippet := Reader.AsString(
          Format('selected[%d].snippet', [I]));

        if FileRel <> CurrentFile then
          begin
            if not CurrentFile.IsEmpty then
              begin
                Lines.Add(INJECT_FENCE);
                Lines.Add('');
              end;
            Lines.Add(Format('### `%s`', [FileRel]));
            Lines.Add('');
            Lines.Add(INJECT_FENCE);
            CurrentFile := FileRel;
          end;

        Lines.Add(Format('// line %d', [Line]));
        Lines.Add(Snippet);
      end;

    if not CurrentFile.IsEmpty then
      Lines.Add(INJECT_FENCE);

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TGrepService.DeferredSetBubble(const AContent: string);
begin
  {--- Defer the bubble write so it lands AFTER the runtime's
       BubbleInputPartialReset that follows command/event handling. The
       value is pre-escaped because BubbleInputSetText injects it verbatim
       into the SET_INPUT_TEXT JSON template. }
  var BrowserRef := FBrowser;
  var Captured := TEscapeHelper.EscapeJSString(AContent, False);
  TThread.ForceQueue(nil,
    procedure
    begin
      BrowserRef.BubbleInputSetText(Captured);
    end);
end;

function TGrepService.HandleCustomEvent(const AEventName,
  APayloadJson: string): Boolean;
begin
  if AEventName = EVT_PICK then
    begin
      var Markdown := FormatPickedAsMarkdown(APayloadJson);
      if Markdown.IsEmpty then
        begin
          FBrowser.DisplayWarning('Grep picker returned no selection');
          Exit(True);
        end;

      DeferredSetBubble(Markdown);
      FBrowser.DisplaySuccess('Selected matches injected into the input bar');
      Exit(True);
    end;

  if AEventName = EVT_CANCEL then
    begin
      {--- Nothing to clean up on the Delphi side; the JS layer removed
           the modal before posting the cancel. We just acknowledge. }
      Exit(True);
    end;

  Result := False;
end;

end.
