unit Demo.Grep.Plugin.Intf;

interface

uses
  WVPythia.Chat.Interfaces;

type
  /// <summary>
  /// Result of a grep operation, surfaced back to the command layer through
  /// the standard Ok/Fail factory pair.
  /// </summary>
  TGrepOperationResult = record
    Success: Boolean;
    Message: string;
    class function Ok(const AMessage: string = ''): TGrepOperationResult; static;
    class function Fail(const AMessage: string): TGrepOperationResult; static;
  end;

  /// <summary>
  /// Lightweight reference to a single match, filled by the service and
  /// shipped to the JS picker as JSON.
  /// </summary>
  TGrepMatchRef = record
    FullPath: string;
    RelativePath: string;
    LineNumber: Integer;
    Snippet: string;
  end;

  /// <summary>
  /// Code search service.
  /// <para>
  /// Abstraction: the plugin does not know how the service walks the file
  /// system, what regex engine it uses, or how it ships matches to the
  /// WebView. Replace this implementation rather than modifying the plugin
  /// to swap the search backend (ripgrep, native scan, indexed lookup...).
  /// </para>
  /// <para>
  /// The service is a two-way participant: it pushes a picker UI into the
  /// WebView via ExecuteScript, then receives the user selection back as a
  /// custom-event JSON payload through HandleCustomEvent.
  /// </para>
  /// </summary>
  IGrepService = interface
    ['{6F6CC9F0-A2E0-4DA9-A4A5-94C2A8E4B6A1}']
    function GetBrowser: IPythiaBrowser;
    procedure SetBrowser(const Value: IPythiaBrowser);

    function GetRootDir: string;
    procedure SetRootDir(const Value: string);

    /// <summary>
    /// Run a search under <c>RootDir</c> (or under a sub-path beneath it)
    /// and inject the picker UI into the WebView.
    /// </summary>
    function Find(const APattern, ASubPath: string): TGrepOperationResult;

    /// <summary>
    /// Re-inject the previous picker without re-running the search.
    /// Useful if the user accidentally dismissed it.
    /// </summary>
    function Last: TGrepOperationResult;

    /// <summary>
    /// Print the current configuration in the chat (root dir, last pattern,
    /// last result count).
    /// </summary>
    function Status: TGrepOperationResult;

    /// <summary>
    /// Dispatch a custom-event payload addressed to this plugin (event names
    /// starting with "grep."). The host adapter should route incoming
    /// custom events to this method by name prefix.
    /// </summary>
    /// <param name="AEventName">Full event name as received from the bridge,
    /// e.g. "grep.pick", "grep.cancel".</param>
    /// <param name="APayloadJson">Raw JSON of the custom-event payload.</param>
    /// <returns>True when the event was consumed.</returns>
    function HandleCustomEvent(const AEventName,
      APayloadJson: string): Boolean;

    property Browser: IPythiaBrowser read GetBrowser write SetBrowser;
    property RootDir: string read GetRootDir write SetRootDir;
  end;

implementation

{ TGrepOperationResult }

class function TGrepOperationResult.Ok(
  const AMessage: string): TGrepOperationResult;
begin
  Result.Success := True;
  Result.Message := AMessage;
end;

class function TGrepOperationResult.Fail(
  const AMessage: string): TGrepOperationResult;
begin
  Result.Success := False;
  Result.Message := AMessage;
end;

end.
