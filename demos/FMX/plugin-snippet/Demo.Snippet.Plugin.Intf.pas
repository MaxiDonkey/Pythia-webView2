unit Demo.Snippet.Plugin.Intf;

interface

uses
  WVPythia.Chat.Interfaces;

type
  /// <summary>
  /// Result of a snippet operation, used to surface a clear message back to
  /// the command layer.
  /// </summary>
  TSnippetOperationResult = record
    Success: Boolean;
    Message: string;
    class function Ok(const AMessage: string = ''): TSnippetOperationResult; static;
    class function Fail(const AMessage: string): TSnippetOperationResult; static;
  end;

  /// <summary>
  /// Snippet management service.
  /// <para>
  /// Abstraction: the plugin does not know WHERE or HOW the snippets are
  /// stored (flat JSON file, SQLite, encrypted store, shared library...).
  /// </para>
  /// <para>
  /// To change the storage policy, replace this implementation rather than
  /// modifying the command plugin.
  /// </para>
  /// </summary>
  ISnippetService = interface
    ['{DB03D2E1-B944-4C19-A93E-D74EDC8F858F}']
    function GetBrowser: IPythiaBrowser;
    procedure SetBrowser(const Value: IPythiaBrowser);

    /// <summary>
    /// Save (or overwrite) the snippet identified by <c>AName</c>.
    /// </summary>
    function Save(const AName, AContent: string): TSnippetOperationResult;

    /// <summary>
    /// Push the snippet content into the input bubble. The runtime is left
    /// in charge of submission; the user remains in control.
    /// </summary>
    function Use(const AName: string): TSnippetOperationResult;

    /// <summary>
    /// Render the snippet content in the chat as a fenced block.
    /// </summary>
    function Show(const AName: string): TSnippetOperationResult;

    /// <summary>
    /// Render the list of stored snippet names in the chat.
    /// </summary>
    function List: TSnippetOperationResult;

    /// <summary>
    /// Rename a stored snippet. Fails if the source does not exist or the
    /// destination already does.
    /// </summary>
    function Rename(const AOldName, ANewName: string): TSnippetOperationResult;

    /// <summary>
    /// Delete the snippet. Fails if it does not exist.
    /// </summary>
    function Delete(const AName: string): TSnippetOperationResult;

    /// <summary>
    /// Merge snippets from a JSON file. Existing snippets with the same
    /// normalized name are overwritten.
    /// </summary>
    function ImportFromFile(const AFileName: string): TSnippetOperationResult;

    /// <summary>
    /// Dump the current storage to a JSON file.
    /// </summary>
    function ExportToFile(const AFileName: string): TSnippetOperationResult;

    property Browser: IPythiaBrowser read GetBrowser write SetBrowser;
  end;

implementation

{ TSnippetOperationResult }

class function TSnippetOperationResult.Ok(
  const AMessage: string): TSnippetOperationResult;
begin
  Result.Success := True;
  Result.Message := AMessage;
end;

class function TSnippetOperationResult.Fail(
  const AMessage: string): TSnippetOperationResult;
begin
  Result.Success := False;
  Result.Message := AMessage;
end;

end.
