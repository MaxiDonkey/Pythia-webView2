unit Demo.Anthropic.FileIds;

interface

uses
  System.SysUtils, System.JSON,
  System.Generics.Collections,
  WVPythia.JSON.SafeReader;

type
  TAnthropicFileIdExtractor = record
  private
    class procedure AddUnique(
      const AFileIds: TList<string>;
      const AFileId: string); static;

    class procedure HandleContentBlockStart(
      const AReader: TJsonReader;
      const AOutputType: string;
      const AFileIds: TList<string>); static;

    class procedure AddOutputPathsFromHostedJson(
      const AHostedJson: string;
      const AOutputPaths: TList<string>); static;

    class procedure HandleInputJsonDelta(
      const AReader: TJsonReader;
      var AHostedJson: string;
      const AOutputPaths: TList<string>); static;

    class procedure ProcessOutputPathEvent(
      const AReader: TJsonReader;
      var AHostedJson: string;
      const AOutputPaths: TList<string>); static;

    class procedure ProcessOutputPathLine(
      const ALine: string;
      var AEventBuffer: string;
      var AHostedJson: string;
      const AOutputPaths: TList<string>); static;

    class procedure ProcessEvent(
      const AReader: TJsonReader;
      const AOutputType: string;
      const AFileIds: TList<string>); static;

    class procedure ProcessLine(
      const ALine: string;
      var AEventBuffer: string;
      const AOutputType: string;
      const AFileIds: TList<string>); static;

  public
    class function Extract(
      const AJsonResponse: string;
      const AOutputType: string): TArray<string>; static;

    class function ExtractOutputPaths(
      const AJsonResponse: string): TArray<string>; static;

    class function ExtractBashCodeExecutionOutputs(
      const AJsonResponse: string): TArray<string>; static;
  end;

implementation

{ TAnthropicFileIdExtractor }

class procedure TAnthropicFileIdExtractor.AddUnique(
  const AFileIds: TList<string>;
  const AFileId: string);
begin
  var FileId := AFileId.Trim;

  if FileId.IsEmpty then
    Exit;

  if AFileIds.IndexOf(FileId) < 0 then
    AFileIds.Add(FileId);
end;

class procedure TAnthropicFileIdExtractor.HandleContentBlockStart(
  const AReader: TJsonReader;
  const AOutputType: string;
  const AFileIds: TList<string>);
const
  OutputArrayPath = 'content_block.content.content';
begin
  var ItemCount := AReader.Count(OutputArrayPath, 0);

  for var I := 0 to ItemCount - 1 do
    begin
      var ItemPath := Format('%s[%d]', [OutputArrayPath, I]);

      var FileId := AReader.AsString(ItemPath + '.file_id');
      if FileId.Trim.IsEmpty then
        Continue;

      var ItemType := AReader.AsString(ItemPath + '.type');
      if not SameText(ItemType, AOutputType) then
        Continue;

      AddUnique(AFileIds, FileId);
    end;
end;

class procedure TAnthropicFileIdExtractor.AddOutputPathsFromHostedJson(
  const AHostedJson: string;
  const AOutputPaths: TList<string>);
const
  OutputPathName = 'output_path';
  HostedDoubleQuote = '\"';
  HostedSingleQuote = '''';
begin
  if AOutputPaths = nil then
    Exit;

  var SearchOffset := 0;

  while True do
    begin
      var NamePos := AHostedJson.IndexOf(OutputPathName, SearchOffset);

      if NamePos < 0 then
        Break;

      var EqualPos := AHostedJson.IndexOf('=', NamePos + OutputPathName.Length);

      if EqualPos < 0 then
        Break;

      var ValueStart := EqualPos + 1;

      while (ValueStart < AHostedJson.Length) and
            CharInSet(AHostedJson.Chars[ValueStart], [' ', #9]) do
        Inc(ValueStart);

      var ValueEnd := -1;

      if AHostedJson.Substring(ValueStart).StartsWith(HostedDoubleQuote) then
        begin
          ValueStart := ValueStart + HostedDoubleQuote.Length;
          ValueEnd := AHostedJson.IndexOf(HostedDoubleQuote, ValueStart);
        end
      else if AHostedJson.Substring(ValueStart).StartsWith(HostedSingleQuote) then
        begin
          ValueStart := ValueStart + Length(HostedSingleQuote);
          ValueEnd := AHostedJson.IndexOf(HostedSingleQuote, ValueStart);
        end;

      if ValueEnd < 0 then
        Break;

      AddUnique(
        AOutputPaths,
        AHostedJson.Substring(ValueStart, ValueEnd - ValueStart));

      SearchOffset := ValueEnd + 1;
    end;
end;

class procedure TAnthropicFileIdExtractor.HandleInputJsonDelta(
  const AReader: TJsonReader;
  var AHostedJson: string;
  const AOutputPaths: TList<string>);
begin
  if not SameText(AReader.AsString('delta.type'), 'input_json_delta') then
    Exit;

  AHostedJson := AHostedJson + AReader.AsString('delta.partial_json');

  AddOutputPathsFromHostedJson(
    AHostedJson,
    AOutputPaths);
end;

class procedure TAnthropicFileIdExtractor.ProcessOutputPathEvent(
  const AReader: TJsonReader;
  var AHostedJson: string;
  const AOutputPaths: TList<string>);
begin
  if not AReader.IsValid then
    Exit;

  if SameText(AReader.AsString('type'), 'content_block_start') and
     SameText(AReader.AsString('content_block.type'), 'server_tool_use') then
    begin
      AHostedJson := '';
      Exit;
    end;

  if SameText(AReader.AsString('type'), 'content_block_delta') then
    HandleInputJsonDelta(
      AReader,
      AHostedJson,
      AOutputPaths);
end;

class procedure TAnthropicFileIdExtractor.ProcessOutputPathLine(
  const ALine: string;
  var AEventBuffer: string;
  var AHostedJson: string;
  const AOutputPaths: TList<string>);
begin
  if ALine.Trim.IsEmpty and AEventBuffer.Trim.IsEmpty then
    Exit;

  if AEventBuffer.IsEmpty then
    AEventBuffer := ALine
  else
    AEventBuffer := AEventBuffer + sLineBreak + ALine;

  var Reader := TJsonReader.Parse(AEventBuffer);

  if not Reader.IsValid then
    Exit;

  Reader := TJsonReader.Parse(Reader.ToJson);

  ProcessOutputPathEvent(
    Reader,
    AHostedJson,
    AOutputPaths);

  AEventBuffer := '';
end;

class procedure TAnthropicFileIdExtractor.ProcessEvent(
  const AReader: TJsonReader;
  const AOutputType: string;
  const AFileIds: TList<string>);
begin
  if not AReader.IsValid then
    Exit;

  if SameText(AReader.AsString('type'), 'content_block_start') then
    HandleContentBlockStart(
      AReader,
      AOutputType,
      AFileIds);
end;

class procedure TAnthropicFileIdExtractor.ProcessLine(
  const ALine: string;
  var AEventBuffer: string;
  const AOutputType: string;
  const AFileIds: TList<string>);
begin
  if ALine.Trim.IsEmpty and AEventBuffer.Trim.IsEmpty then
    Exit;

  if AEventBuffer.IsEmpty then
    AEventBuffer := ALine
  else
    AEventBuffer := AEventBuffer + sLineBreak + ALine;

  var Reader := TJsonReader.Parse(AEventBuffer);

  if not Reader.IsValid then
    Exit;

  Reader := TJsonReader.Parse(Reader.ToJson);

  ProcessEvent(
    Reader,
    AOutputType,
    AFileIds);

  AEventBuffer := '';
end;

class function TAnthropicFileIdExtractor.Extract(
  const AJsonResponse: string;
  const AOutputType: string): TArray<string>;
begin
  Result := [];

  if AJsonResponse.Trim.IsEmpty then
    Exit;

  var OutputType := AOutputType.Trim;

  if OutputType.IsEmpty then
    Exit;

  var FileIds := TList<string>.Create;
  try
    var EventBuffer := '';

    for var Line in AJsonResponse.Split([sLineBreak]) do
      ProcessLine(
        Line,
        EventBuffer,
        OutputType,
        FileIds);

    Result := FileIds.ToArray;
  finally
    FileIds.Free;
  end;
end;

class function TAnthropicFileIdExtractor.ExtractOutputPaths(
  const AJsonResponse: string): TArray<string>;
begin
  Result := [];

  if AJsonResponse.Trim.IsEmpty then
    Exit;

  var OutputPaths := TList<string>.Create;
  try
    var EventBuffer := '';
    var HostedJson := '';

    for var Line in AJsonResponse.Split([sLineBreak]) do
      ProcessOutputPathLine(
        Line,
        EventBuffer,
        HostedJson,
        OutputPaths);

    Result := OutputPaths.ToArray;
  finally
    OutputPaths.Free;
  end;
end;

class function TAnthropicFileIdExtractor.ExtractBashCodeExecutionOutputs(
  const AJsonResponse: string): TArray<string>;
begin
  Result := Extract(
    AJsonResponse,
    'bash_code_execution_output');
end;

end.
