unit Demo.Anthropic.DisplayBlocks;

interface

uses
  System.SysUtils, System.JSON,
  Anthropic, Anthropic.Types, Anthropic.Chat.StreamEvents, Anthropic.Chat.StreamCallbacks,
  Anthropic.API.JsonSafeReader,
  WVPythia.ChatSession.Controller;

type
  /// <summary>
  /// Live accumulator that turns Anthropic typed stream events into the
  /// ordered TChatDisplayBlock list expected by Pythia for replay and
  /// persistence.
  /// </summary>
  IDisplayBlockAggregator = interface
    ['{8B6F1F3C-4E5D-4F3E-9C2A-1F0E7D5A6B22}']
    procedure AppendAssistantDelta(const Delta: string);
    procedure AppendReasoningDelta(const Delta: string);
    procedure RegisterToolUseStop(const Snapshot: TToolCallSnapshot;
      const DisplayTitle: string);
    procedure AppendToolResultDelta(const Delta: string);
    procedure RegisterToolResultStop(const Snapshot: TToolResultSnapshot);
    procedure AppendAssistantText(const Text: string);
    procedure CloseCurrent;
    function CloneAll: TArray<TChatDisplayBlock>;
    function IsEmpty: Boolean;
  end;

  TDisplayBlockAggregator = class(TInterfacedObject, IDisplayBlockAggregator)
  private
    FBlocks: TArray<TChatDisplayBlock>;
    FCurrent: TChatDisplayBlock;
    FCurrentToolEntry: TChatDisplayBlock;

    function StartBlock(const Kind: string): TChatDisplayBlock;
    procedure EnsureKind(const Kind: string);
  public
    destructor Destroy; override;

    procedure AppendAssistantDelta(const Delta: string);
    procedure AppendReasoningDelta(const Delta: string);
    procedure RegisterToolUseStop(const Snapshot: TToolCallSnapshot;
      const DisplayTitle: string);
    procedure AppendToolResultDelta(const Delta: string);
    procedure RegisterToolResultStop(const Snapshot: TToolResultSnapshot);
    procedure AppendAssistantText(const Text: string);
    procedure CloseCurrent;
    function CloneAll: TArray<TChatDisplayBlock>;
    function IsEmpty: Boolean;
  end;

  TToolDisplayTitle = record
  private
    class function BaseTitle(const ABlockType: TContentBlockType;
      const AToolName: string): string; static;
    class function HumanizeIdentifier(const Value: string): string; static;
    class function ResolveDisplayName(const AInternalName: string): string; static;
    class function TryReadInputJsonString(
      const Reader: TJsonReader;
      const FieldName: string;
      out Value: string): Boolean; static;
  public
    class function FromInput(
      const ABlockType: TContentBlockType;
      const AToolName, AInputJson: string): string; static;
    class function FromBlockType(
      const ABlockType: TContentBlockType): string; static;
  end;

  TToolUseDisplayDetails = record
  private
    class procedure AppendDetailLine(
      const Builder: TStringBuilder;
      const LabelName, Value: string); static;
    class procedure AppendInputJson(
      const Builder: TStringBuilder;
      const LabelName, Value: string); static;
    class function FormatJson(const Value: string): string; static;
    class function HumanizeIdentifier(const Value: string): string; static;
    class function IsComputerTool(
      const Snapshot: TToolCallSnapshot): Boolean; static;
    class function BuildComputerDetails(
      const Snapshot: TToolCallSnapshot;
      out Details: string): Boolean; static;
    class function BuildMCPToolUseDetails(
      const Snapshot: TToolCallSnapshot;
      out Details: string): Boolean; static;
  public
    class function TryFromSnapshot(
      const Snapshot: TToolCallSnapshot;
      out Details: string): Boolean; static;
  end;

  TToolResultDisplayDetails = record
  private
    class procedure AppendDetailLine(
      const Builder: TStringBuilder;
      const LabelName, Value: string); static;
    class function BuildToolErrorSummary(
      const AFailureLabel, AErrorCode, AErrorMessage: string): string; overload; static;
    class function BuildToolErrorSummary(
      const AFailureLabel, ARawContent: string): string; overload; static;
    class function BuildWebFetchDetails(
      const Block: TContentBlock;
      out Details: string): Boolean; static;
    class function BuildWebSearchDetails(
      const Block: TContentBlock;
      out Details: string): Boolean; static;
    class function BuildToolSearchDetails(
      const Block: TContentBlock;
      out Details: string): Boolean; static;
    class function BuildMCPToolDetails(
      const Block: TContentBlock;
      out Details: string): Boolean; static;
    class function HumanizeIdentifier(const Value: string): string; static;
  public
    class function TryFromEvent(
      const Event: TChatStream;
      out Details: string): Boolean; static;
  end;

implementation

uses
  WVPythia.Chat.Consts;

type
  TToolDisplayNameMapItem = record
    InternalName: string;
    DisplayName: string;
  end;

{ TDisplayBlockAggregator }

destructor TDisplayBlockAggregator.Destroy;
begin
  FreeChatDisplayBlocks(FBlocks);
  inherited;
end;

function TDisplayBlockAggregator.StartBlock(const Kind: string): TChatDisplayBlock;
begin
  Result := TChatDisplayBlock.Create;
  Result.Kind := Kind;
  FBlocks := FBlocks + [Result];
  FCurrent := Result;
end;

procedure TDisplayBlockAggregator.EnsureKind(const Kind: string);
begin
  {--- Merge consecutive same-kind deltas into a single block; switch otherwise. }
  if not Assigned(FCurrent) or not SameText(FCurrent.Kind, Kind) then
    StartBlock(Kind);
end;

procedure TDisplayBlockAggregator.AppendAssistantDelta(const Delta: string);
begin
  if Delta.IsEmpty then
    Exit;
  EnsureKind(DISPLAY_BLOCK_KIND_ASSISTANT);
  FCurrent.Text := FCurrent.Text + Delta;
end;

procedure TDisplayBlockAggregator.AppendAssistantText(const Text: string);
begin
  if Text.IsEmpty then
    Exit;
  EnsureKind(DISPLAY_BLOCK_KIND_ASSISTANT);
  FCurrent.Text := FCurrent.Text + Text;
end;

procedure TDisplayBlockAggregator.AppendReasoningDelta(const Delta: string);
begin
  if Delta.IsEmpty then
    Exit;
  EnsureKind(DISPLAY_BLOCK_KIND_REASONING);
  FCurrent.Text := FCurrent.Text + Delta;
end;

procedure TDisplayBlockAggregator.RegisterToolUseStop(
  const Snapshot: TToolCallSnapshot;
  const DisplayTitle: string);
var
  Block: TChatDisplayBlock;
  Title: string;
begin
  {--- A tool invocation is emitted only when its input is complete so
       the persisted title carries the actual command (e.g. the bash
       line or the text_editor view path) instead of the opaque
       block-type identifier. }
  Block := StartBlock(DISPLAY_BLOCK_KIND_TOOL_STATUS);

  Title := DisplayTitle.Trim;
  if Title.IsEmpty then
    Title := Snapshot.ToolName.Trim;
  if Title.IsEmpty then
    Title := Snapshot.BlockType.ToString;

  Block.Title := Title;
  FCurrentToolEntry := Block;
end;

procedure TDisplayBlockAggregator.AppendToolResultDelta(const Delta: string);
begin
  if Delta.IsEmpty then
    Exit;

  {--- Stream the result text into the tool-call entry opened by the
       matching RegisterToolUseStop. Falls back to opening a standalone
       tool-output block when a result arrives without a preceding
       tool_use (defensive - shouldn't happen on a well-formed stream). }
  if not Assigned(FCurrentToolEntry) then
    begin
      FCurrentToolEntry := StartBlock(DISPLAY_BLOCK_KIND_TOOL_OUTPUT);
      FCurrent := FCurrentToolEntry;
    end;

  FCurrentToolEntry.Text := FCurrentToolEntry.Text + Delta;
  FCurrent := FCurrentToolEntry;
end;

procedure TDisplayBlockAggregator.RegisterToolResultStop(
  const Snapshot: TToolResultSnapshot);
begin
  {--- Errors are only marked at content_block_stop; demote the open
       tool entry to the error kind when the server reports IsError. }
  if Snapshot.IsError and Assigned(FCurrentToolEntry) then
    FCurrentToolEntry.Kind := DISPLAY_BLOCK_KIND_TOOL_ERROR;

  FCurrentToolEntry := nil;
  FCurrent := nil;
end;

procedure TDisplayBlockAggregator.CloseCurrent;
begin
  FCurrent := nil;
  FCurrentToolEntry := nil;
end;

function TDisplayBlockAggregator.CloneAll: TArray<TChatDisplayBlock>;
begin
  Result := CloneChatDisplayBlocks(FBlocks);
end;

function TDisplayBlockAggregator.IsEmpty: Boolean;
begin
  Result := Length(FBlocks) = 0;
end;

{ TToolDisplayTitle }

class function TToolDisplayTitle.BaseTitle(
  const ABlockType: TContentBlockType;
  const AToolName: string): string;
begin
  Result := ResolveDisplayName(AToolName);
  if Result.IsEmpty then
    Result := ResolveDisplayName(ABlockType.ToString);
  if Result.IsEmpty then
    Result := AToolName.Trim;
  if Result.IsEmpty then
    Result := ABlockType.ToString;
end;

class function TToolDisplayTitle.HumanizeIdentifier(
  const Value: string): string;
begin
  Result := Value.Trim.Replace('_', ' ');
end;

class function TToolDisplayTitle.ResolveDisplayName(
  const AInternalName: string): string;
const
  TOOL_DISPLAY_NAMES: array[0..14] of TToolDisplayNameMapItem = (
    (InternalName: 'bash_code_execution'; DisplayName: 'Shell command'),
    (InternalName: 'bash_code_execution_tool_result'; DisplayName: 'Shell command'),
    (InternalName: 'text_editor_code_execution'; DisplayName: 'File editor'),
    (InternalName: 'text_editor_code_execution_tool_result'; DisplayName: 'File editor'),
    (InternalName: 'code_execution'; DisplayName: 'Python execution'),
    (InternalName: 'python_code_execution'; DisplayName: 'Python execution'),
    (InternalName: 'code_execution_tool_result'; DisplayName: 'Python execution'),
    (InternalName: 'web_search'; DisplayName: 'Web search'),
    (InternalName: 'web_search_tool_result'; DisplayName: 'Web search'),
    (InternalName: 'web_fetch'; DisplayName: 'Web fetch'),
    (InternalName: 'web_fetch_tool_result'; DisplayName: 'Web fetch'),
    (InternalName: 'computer'; DisplayName: 'Computer control'),
    (InternalName: 'tool_search'; DisplayName: 'Tool search'),
    (InternalName: 'tool_search_tool_result'; DisplayName: 'Tool search'),
    (InternalName: 'mcp_tool'; DisplayName: 'MCP tool')
  );
var
  Normalized: string;
begin
  Normalized := AInternalName.Trim.ToLowerInvariant;
  if Normalized.IsEmpty then
    Exit('');

  for var Item in TOOL_DISPLAY_NAMES do
    if (Normalized = Item.InternalName) or
       Normalized.StartsWith(Item.InternalName + '_') then
      Exit(Item.DisplayName);

  Result := '';
end;

class function TToolDisplayTitle.TryReadInputJsonString(
  const Reader: TJsonReader;
  const FieldName: string;
  out Value: string): Boolean;
begin
  Value := Reader.AsString(FieldName);
  Result := not Value.Trim.IsEmpty;
end;

class function TToolDisplayTitle.FromBlockType(
  const ABlockType: TContentBlockType): string;
begin
  Result := BaseTitle(ABlockType, '');
end;

class function TToolDisplayTitle.FromInput(
  const ABlockType: TContentBlockType;
  const AToolName, AInputJson: string): string;
var
  Reader: TJsonReader;
  Command: string;
  Path: string;
  Query: string;
  Url: string;
  Action: string;
  ToolTitle: string;
begin
  {--- The input JSON is complete only at content_block_stop. This helper keeps
       title extraction close to stream display concerns while avoiding
       localized labels in the vendor service. }
  ToolTitle := BaseTitle(ABlockType, AToolName);

  Result := ToolTitle;

  if AInputJson.Trim.IsEmpty then
    Exit;

  Reader := TJsonReader.Parse(AInputJson);
  if not Reader.IsValid then
    Exit;

  case ABlockType of
    TContentBlockType.server_tool_use,
    TContentBlockType.tool_use:
      begin
        {--- bash uses "command", text_editor uses "command" + "path",
             web_search uses "query", web_fetch uses "url", computer uses
             "action". Try the richest combinations first. }
        if AToolName.Trim.ToLowerInvariant.StartsWith('computer') and
           TToolDisplayTitle.TryReadInputJsonString(Reader, 'action', Action) then
          begin
            Result := Format('%s - %s', [ToolTitle, HumanizeIdentifier(Action)]);
            Exit;
          end;

        if TToolDisplayTitle.TryReadInputJsonString(Reader, 'command', Command) then
          begin
            if TToolDisplayTitle.TryReadInputJsonString(Reader, 'path', Path) then
              Result := Format('%s - %s %s', [ToolTitle, Command, Path])
            else
              Result := Format('%s - %s', [ToolTitle, Command]);
            Exit;
          end;

        if TToolDisplayTitle.TryReadInputJsonString(Reader, 'path', Path) then
          begin
            Result := Format('%s - %s', [ToolTitle, Path]);
            Exit;
          end;

        if TToolDisplayTitle.TryReadInputJsonString(Reader, 'query', Query) then
          begin
            Result := Format('%s - %s', [ToolTitle, Query]);
            Exit;
          end;

        if TToolDisplayTitle.TryReadInputJsonString(Reader, 'url', Url) then
          begin
            Result := Format('%s - %s', [ToolTitle, Url]);
            Exit;
          end;
      end;

    TContentBlockType.mcp_tool_use:
      begin
        if TToolDisplayTitle.TryReadInputJsonString(Reader, 'name', Command) or
           TToolDisplayTitle.TryReadInputJsonString(Reader, 'tool', Command) then
          begin
            Result := Format('%s - %s', [ToolTitle, Command]);
            Exit;
          end;
      end;
  end;
end;

{ TToolUseDisplayDetails }

class procedure TToolUseDisplayDetails.AppendDetailLine(
  const Builder: TStringBuilder;
  const LabelName, Value: string);
var
  Text: string;
begin
  Text := Value.Trim;
  if Text.IsEmpty then
    Exit;

  Builder.Append(LabelName).Append(': ').AppendLine(Text);
end;

class procedure TToolUseDisplayDetails.AppendInputJson(
  const Builder: TStringBuilder;
  const LabelName, Value: string);
var
  Text: string;
begin
  Text := FormatJson(Value);
  if Text.IsEmpty or SameText(Text, '{}') then
    Exit;

  Builder.Append(LabelName).Append(':').AppendLine;
  Builder.AppendLine(Text);
end;

class function TToolUseDisplayDetails.FormatJson(
  const Value: string): string;
var
  Reader: TJsonReader;
begin
  Result := Value.Trim;
  if Result.IsEmpty then
    Exit;

  Reader := TJsonReader.Parse(Result);
  if Reader.IsValid then
    Result := Reader.Format(2).Trim;
end;

class function TToolUseDisplayDetails.HumanizeIdentifier(
  const Value: string): string;
begin
  Result := Value.Trim.Replace('_', ' ');
end;

class function TToolUseDisplayDetails.IsComputerTool(
  const Snapshot: TToolCallSnapshot): Boolean;
var
  ToolName: string;
begin
  ToolName := Snapshot.ToolName.Trim.ToLowerInvariant;
  Result := (ToolName = 'computer') or ToolName.StartsWith('computer_');
end;

class function TToolUseDisplayDetails.BuildComputerDetails(
  const Snapshot: TToolCallSnapshot;
  out Details: string): Boolean;
var
  Reader: TJsonReader;
  Builder: TStringBuilder;
  Action: string;
  Coordinate: string;
  StartCoordinate: string;
  InputText: string;
  Key: string;
  ScrollDirection: string;
  ScrollAmount: string;
  Duration: string;
begin
  Details := '';
  if not IsComputerTool(Snapshot) then
    Exit(False);

  Reader := TJsonReader.Parse(Snapshot.InputJson);
  if not Reader.IsValid then
    Exit(False);

  Action := HumanizeIdentifier(Reader.AsString('action'));
  Coordinate := Reader.AsString('coordinate').Trim;
  StartCoordinate := Reader.AsString('start_coordinate').Trim;
  InputText := Reader.AsString('text').Trim;
  Key := Reader.AsString('key').Trim;
  ScrollDirection := HumanizeIdentifier(Reader.AsString('scroll_direction'));
  ScrollAmount := Reader.AsString('scroll_amount').Trim;
  Duration := Reader.AsString('duration').Trim;

  Builder := TStringBuilder.Create;
  try
    Builder.AppendLine('Computer action details:');
    AppendDetailLine(Builder, 'Action', Action);
    AppendDetailLine(Builder, 'Coordinate', Coordinate);
    AppendDetailLine(Builder, 'Start coordinate', StartCoordinate);
    AppendDetailLine(Builder, 'Text', InputText);
    AppendDetailLine(Builder, 'Key', Key);
    AppendDetailLine(Builder, 'Scroll direction', ScrollDirection);
    AppendDetailLine(Builder, 'Scroll amount', ScrollAmount);
    AppendDetailLine(Builder, 'Duration', Duration);

    Details := Builder.ToString.Trim;
    Result := not SameText(Details, 'Computer action details:');
  finally
    Builder.Free;
  end;
end;

class function TToolUseDisplayDetails.BuildMCPToolUseDetails(
  const Snapshot: TToolCallSnapshot;
  out Details: string): Boolean;
var
  Builder: TStringBuilder;
begin
  Details := '';
  if Snapshot.BlockType <> TContentBlockType.mcp_tool_use then
    Exit(False);

  Builder := TStringBuilder.Create;
  try
    Builder.AppendLine('MCP tool call details:');
    AppendDetailLine(Builder, 'Server', Snapshot.ServerName);
    AppendDetailLine(Builder, 'Tool', Snapshot.ToolName);
    AppendInputJson(Builder, 'Input', Snapshot.InputJson);

    Details := Builder.ToString.Trim;
    Result := not SameText(Details, 'MCP tool call details:');
  finally
    Builder.Free;
  end;
end;

class function TToolUseDisplayDetails.TryFromSnapshot(
  const Snapshot: TToolCallSnapshot;
  out Details: string): Boolean;
begin
  if BuildComputerDetails(Snapshot, Details) then
    Exit(True);

  Result := BuildMCPToolUseDetails(Snapshot, Details);
end;

{ TToolResultDisplayDetails }

class procedure TToolResultDisplayDetails.AppendDetailLine(
  const Builder: TStringBuilder;
  const LabelName, Value: string);
var
  Text: string;
begin
  Text := Value.Trim;
  if Text.IsEmpty then
    Exit;

  Builder.Append(LabelName).Append(': ').AppendLine(Text);
end;

class function TToolResultDisplayDetails.BuildToolErrorSummary(
  const AFailureLabel, AErrorCode, AErrorMessage: string): string;
var
  Code: string;
  Message: string;
  ErrorText: string;
begin
  Code := HumanizeIdentifier(AErrorCode);
  Message := AErrorMessage.Trim;

  if Code.IsEmpty and Message.IsEmpty then
    Exit('');

  if Code.IsEmpty then
    ErrorText := Message
  else
    if Message.IsEmpty then
      ErrorText := Code
    else
      ErrorText := Format('%s - %s', [Code, Message]);

  Result := Format('%s: %s', [AFailureLabel, ErrorText]);
end;

class function TToolResultDisplayDetails.BuildToolErrorSummary(
  const AFailureLabel, ARawContent: string): string;
var
  ErrorCode: string;
  ErrorMessage: string;
  Reader: TJsonReader;
begin
  Result := '';

  Reader := TJsonReader.Parse(ARawContent);
  if not Reader.IsValid then
    Exit;

  ErrorCode := Reader.AsString('error_code').Trim;
  if ErrorCode.IsEmpty then
    ErrorCode := Reader.AsString('content.error_code').Trim;

  ErrorMessage := Reader.AsString('error_message').Trim;
  if ErrorMessage.IsEmpty then
    ErrorMessage := Reader.AsString('message').Trim;
  if ErrorMessage.IsEmpty then
    ErrorMessage := Reader.AsString('content.error_message').Trim;

  Result := BuildToolErrorSummary(AFailureLabel, ErrorCode, ErrorMessage);
end;

class function TToolResultDisplayDetails.BuildWebFetchDetails(
  const Block: TContentBlock;
  out Details: string): Boolean;
var
  FetchBlock: TWebFetchToolResultBlock;
  Content: TWebFetchToolResultBlockContent;
  Builder: TStringBuilder;
  Title: string;
  Url: string;
  RetrievedAt: string;
  MediaType: string;
  HasDetails: Boolean;
begin
  Details := '';

  if not Assigned(Block.ToolContent) then
    Exit(False);

  FetchBlock := Block.ToolContent.WebFetchToolResultBlock;
  if (not Assigned(FetchBlock)) or (not FetchBlock.HasValue) then
    begin
      Details := BuildToolErrorSummary('Fetch failed', Block.RawContent);
      Exit(not Details.IsEmpty);
    end;

  Content := FetchBlock.Content;
  if not Assigned(Content) then
    Exit(False);

  if not Content.ErrorCode.Trim.IsEmpty then
    begin
      Details := BuildToolErrorSummary('Fetch failed', Content.ErrorCode, '');
      Exit(not Details.IsEmpty);
    end;

  Title := '';
  MediaType := '';

  if Assigned(Content.Content) then
    begin
      Title := Content.Content.Title.Trim;
      if Assigned(Content.Content.Source) then
        MediaType := Content.Content.Source.MediaType.Trim;
    end;

  Url := Content.Url.Trim;
  RetrievedAt := Content.RetrievedAt.Trim;

  Builder := TStringBuilder.Create;
  try
    Builder.AppendLine('Fetched web content:');
    HasDetails := False;

    if not Title.IsEmpty then
      begin
        AppendDetailLine(Builder, 'Title', Title);
        HasDetails := True;
      end;

    if not Url.IsEmpty then
      begin
        AppendDetailLine(Builder, 'URL', Url);
        HasDetails := True;
      end;

    if not RetrievedAt.IsEmpty then
      begin
        AppendDetailLine(Builder, 'Retrieved at', RetrievedAt);
        HasDetails := True;
      end;

    if not MediaType.IsEmpty then
      begin
        AppendDetailLine(Builder, 'Media type', MediaType);
        HasDetails := True;
      end;

    Details := Builder.ToString.Trim;
    Result := HasDetails and not Details.IsEmpty;
  finally
    Builder.Free;
  end;
end;

class function TToolResultDisplayDetails.BuildWebSearchDetails(
  const Block: TContentBlock;
  out Details: string): Boolean;
var
  SearchBlock: TWebSearchToolResultBlock;
  ContentCount: Integer;
  Builder: TStringBuilder;
  ResultIndex: Integer;
  Title: string;
  Url: string;
  PageAge: string;
begin
  Details := '';

  if not Assigned(Block.ToolContent) then
    Exit(False);

  SearchBlock := Block.ToolContent.WebSearchToolResultBlock;
  if (not Assigned(SearchBlock)) or (not SearchBlock.HasValue) then
    begin
      Details := BuildToolErrorSummary('Search failed', Block.RawContent);
      Exit(not Details.IsEmpty);
    end;

  ContentCount := Length(SearchBlock.Content);
  if ContentCount = 0 then
    Exit(False);

  Builder := TStringBuilder.Create;
  try
    if ContentCount = 1 then
      Builder.AppendLine('Found 1 web result:')
    else
      Builder.AppendLine(Format('Found %d web results:', [ContentCount]));

    ResultIndex := 0;
    for var Item in SearchBlock.Content do
      begin
        if not Assigned(Item) then
          Continue;

        Title := Item.Title.Trim;
        Url := Item.Url.Trim;
        PageAge := Item.PageAge.Trim;

        if Title.IsEmpty and Url.IsEmpty then
          Continue;

        Inc(ResultIndex);
        Builder.Append(Format('%d. ', [ResultIndex]));

        if not Title.IsEmpty then
          Builder.Append(Title)
        else
          Builder.Append(Url);

        if not Url.IsEmpty and not SameText(Url, Title) then
          Builder.AppendLine.Append('   ').Append(Url);

        if not PageAge.IsEmpty then
          Builder.AppendLine.Append('   Page age: ').Append(PageAge);

        Builder.AppendLine;
      end;

    Details := Builder.ToString.Trim;
    Result := not Details.IsEmpty;
  finally
    Builder.Free;
  end;
end;

class function TToolResultDisplayDetails.BuildToolSearchDetails(
  const Block: TContentBlock;
  out Details: string): Boolean;
var
  SearchBlock: TToolSearchToolResultBlock;
  Content: TToolSearchToolResultBlockContent;
  ContentCount: Integer;
  Builder: TStringBuilder;
  ResultIndex: Integer;
  ToolName: string;
begin
  Details := '';

  if not Assigned(Block.ToolContent) then
    Exit(False);

  SearchBlock := Block.ToolContent.ToolSearchToolResultBlock;
  if (not Assigned(SearchBlock)) or (not SearchBlock.HasValue) then
    begin
      Details := BuildToolErrorSummary('Tool search failed', Block.RawContent);
      Exit(not Details.IsEmpty);
    end;

  Content := SearchBlock.Content;
  if not Assigned(Content) then
    Exit(False);

  if (not Content.ErrorCode.Trim.IsEmpty) or
     (not Content.ErrorMessage.Trim.IsEmpty) then
    begin
      Details := BuildToolErrorSummary(
        'Tool search failed',
        Content.ErrorCode,
        Content.ErrorMessage);
      Exit(not Details.IsEmpty);
    end;

  ContentCount := Length(Content.ToolReferences);
  if ContentCount = 0 then
    begin
      Details := 'No matching tools found.';
      Exit(True);
    end;

  Builder := TStringBuilder.Create;
  try
    if ContentCount = 1 then
      Builder.AppendLine('Found 1 tool reference:')
    else
      Builder.AppendLine(Format('Found %d tool references:', [ContentCount]));

    ResultIndex := 0;
    for var Item in Content.ToolReferences do
      begin
        if not Assigned(Item) then
          Continue;

        ToolName := Item.ToolName.Trim;
        if ToolName.IsEmpty then
          Continue;

        Inc(ResultIndex);
        Builder.AppendLine(Format('%d. %s', [ResultIndex, ToolName]));
      end;

    Details := Builder.ToString.Trim;
    if Details.IsEmpty or (ResultIndex = 0) then
      Details := 'No matching tools found.';
    Result := not Details.IsEmpty;
  finally
    Builder.Free;
  end;
end;

class function TToolResultDisplayDetails.BuildMCPToolDetails(
  const Block: TContentBlock;
  out Details: string): Boolean;
var
  MCPBlock: TMCPToolResultBlock;
  Builder: TStringBuilder;
  ContentCount: Integer;
  TextBlockCount: Integer;
  CitationCount: Integer;
  TextValue: string;
begin
  Details := '';

  if not Assigned(Block.ToolContent) then
    Exit(False);

  MCPBlock := Block.ToolContent.MCPToolResultBlock;
  if (not Assigned(MCPBlock)) or (not MCPBlock.HasValue) then
    begin
      if Block.IsError then
        Details := BuildToolErrorSummary('MCP tool failed', Block.RawContent);
      Exit(not Details.IsEmpty);
    end;

  Builder := TStringBuilder.Create;
  try
    if Block.IsError then
      Builder.AppendLine('MCP tool failed:')
    else
      Builder.AppendLine('MCP tool returned:');

    if SameText(MCPBlock.&Type, 'text') then
      begin
        TextValue := MCPBlock.StringContent.Trim;
        if not TextValue.IsEmpty then
          AppendDetailLine(Builder, 'Text', TextValue);
      end
    else
      begin
        ContentCount := Length(MCPBlock.Content);
        if ContentCount > 0 then
          AppendDetailLine(Builder, 'Content blocks', IntToStr(ContentCount));

        TextBlockCount := 0;
        CitationCount := 0;
        for var Item in MCPBlock.Content do
          begin
            if not Assigned(Item) then
              Continue;

            Inc(CitationCount, Length(Item.Citations));
            TextValue := Item.Text.Trim;
            if TextValue.IsEmpty then
              Continue;

            Inc(TextBlockCount);
            Builder.AppendLine(Format('%d. %s', [TextBlockCount, TextValue]));
          end;

        if CitationCount > 0 then
          AppendDetailLine(Builder, 'Citations', IntToStr(CitationCount));
      end;

    Details := Builder.ToString.Trim;
    if SameText(Details, 'MCP tool failed:') then
      Details := 'MCP tool failed.';

    Result := not Details.IsEmpty and
      not SameText(Details, 'MCP tool returned:') and
      not SameText(Details, 'MCP tool failed:');
  finally
    Builder.Free;
  end;
end;

class function TToolResultDisplayDetails.HumanizeIdentifier(
  const Value: string): string;
begin
  Result := Value.Trim.Replace('_', ' ');
end;

class function TToolResultDisplayDetails.TryFromEvent(
  const Event: TChatStream;
  out Details: string): Boolean;
var
  Block: TContentBlock;
begin
  Details := '';

  if (not Assigned(Event)) or
     (Event.EventType <> TEventType.content_block_start) then
    Exit(False);

  Block := Event.ContentBlock;
  if not Assigned(Block) then
    Exit(False);

  case Block.&Type of
    TContentBlockType.web_search_tool_result:
      Exit(BuildWebSearchDetails(Block, Details));

    TContentBlockType.web_fetch_tool_result:
      Exit(BuildWebFetchDetails(Block, Details));

    TContentBlockType.tool_search_tool_result:
      Exit(BuildToolSearchDetails(Block, Details));

    TContentBlockType.mcp_tool_result:
      Exit(BuildMCPToolDetails(Block, Details));
  else
    Result := False;
  end;
end;

end.
