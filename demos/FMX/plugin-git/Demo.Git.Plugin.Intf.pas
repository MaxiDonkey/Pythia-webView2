unit Demo.Git.Plugin.Intf;

interface

uses
  WVPythia.Chat.Interfaces;

type
  /// <summary>
  /// Result of a git operation, used to surface a clear message back to
  /// the command layer.
  /// </summary>
  TGitOperationResult = record
    Success: Boolean;
    Message: string;
    class function Ok(const AMessage: string = ''): TGitOperationResult; static;
    class function Fail(const AMessage: string): TGitOperationResult; static;
  end;

  /// <summary>
  /// Git-context service.
  /// <para>
  /// The plugin does not know how the binary is located, how its output is
  /// captured, or how the working directory is resolved. All of that lives
  /// in the implementation through an injected IShellRunner.
  /// </para>
  /// <para>
  /// To switch to libgit2, gitoxide, or a sandboxed runner, replace this
  /// implementation rather than modifying the command plugin.
  /// </para>
  /// </summary>
  IGitService = interface
    ['{5F8C2A19-4E3D-4B7A-9C82-1D6E7B4F3A8C}']
    function GetBrowser: IPythiaBrowser;
    procedure SetBrowser(const Value: IPythiaBrowser);

    /// <summary>
    /// Run "git status --short" and inject the output into the bubble.
    /// </summary>
    function Status: TGitOperationResult;

    /// <summary>
    /// Run "git diff [&lt;ref&gt;]" and inject the diff into the bubble.
    /// AReference is empty for the working-tree-vs-index diff.
    /// </summary>
    function Diff(const AReference: string): TGitOperationResult;

    /// <summary>
    /// Run "git diff --cached" and inject the staged diff into the bubble.
    /// </summary>
    function Staged: TGitOperationResult;

    /// <summary>
    /// Run "git log --oneline -n &lt;ACount&gt;" and inject the log into
    /// the bubble. ACount must be a positive integer; default 10 when 0.
    /// </summary>
    function Log(const ACount: Integer): TGitOperationResult;

    /// <summary>
    /// Run "git branch --show-current" and inject the current branch
    /// name into the bubble.
    /// </summary>
    function Branch: TGitOperationResult;

    /// <summary>
    /// Run "git show &lt;ARef&gt;" and inject the commit message + diff
    /// into the bubble.
    /// </summary>
    function Show(const ARef: string): TGitOperationResult;

    /// <summary>
    /// Run "git blame [-L &lt;ARange&gt;] &lt;AFile&gt;" and inject the
    /// blame view into the bubble. ARange is empty when the user wants
    /// the full file.
    /// </summary>
    function Blame(const AFile, ARange: string): TGitOperationResult;

    property Browser: IPythiaBrowser read GetBrowser write SetBrowser;
  end;

implementation

{ TGitOperationResult }

class function TGitOperationResult.Ok(
  const AMessage: string): TGitOperationResult;
begin
  Result.Success := True;
  Result.Message := AMessage;
end;

class function TGitOperationResult.Fail(
  const AMessage: string): TGitOperationResult;
begin
  Result.Success := False;
  Result.Message := AMessage;
end;

end.
