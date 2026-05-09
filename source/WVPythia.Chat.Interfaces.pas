unit WVPythia.Chat.Interfaces;

interface

uses
  System.SysUtils, WVPythia.Types, WVPythia.ChatSession.Controller, WVPythia.Command.Parser;

type
  TClipboardTextKind = (
    ctkInline,
    ctkTempFile
  );

  TClipboardTextData = record
    Kind: TClipboardTextKind;
    Text: string;
    FileName: string;
  end;

  IClipboardReader = interface
    ['{5EE91EF1-87FD-4544-95AB-D863F4DB7742}']
    function IsAvailable: Boolean;
    function TryGetText(out AText: TClipboardTextData): Boolean;
    function TrySaveImageToTempPng(out AFileName: string): Boolean;
    function TryGetFiles(out AFiles: TArray<string>): Boolean;
  end;

  ISecretStore = interface
    ['{0828CA5A-491F-41E5-B127-9037F22CCF79}']
    function ReadSecret(const Name: string; out Value: string; const ParamProc: TProc<string> = nil): Boolean;
    procedure WriteSecret(const Name, Value: string);
    procedure DeleteSecret(const Name: string);
  end;

  IOpenDialog = interface
    ['{4ABD78A5-4281-4930-B55A-BF6A259E914C}']
    function Execute(const Filter: string; const index: Integer; out FileName: string): Boolean;
  end;

  IProcessExecute = interface
    ['{CD67CA09-B39A-47F0-BFF1-5F50DFDA3A53}']
    procedure Open(const FileName: string);
  end;

  TCommandExecResult = record
    Success: Boolean;
    Message: string;
    class function Ok(const AMessage: string = ''): TCommandExecResult; static;
    class function Fail(const AMessage: string): TCommandExecResult; static;
  end;

  ICommandPlugin = interface
    ['{8F2E4A91-5C3D-4B72-A6E0-1D9F8B4C2A35}']
    function GetName: string;
    function Execute(const Action: string;
      const Args: TArray<string>): TCommandExecResult;
    property Name: string read GetName;
  end;

  ICommandRegistry = interface
    ['{45EF7138-C258-4913-9965-37885F647971}']
    function RegisterPlugin(const APlugin: ICommandPlugin): ICommandPlugin;
    function Validate(const Source: string;
      out Res: TCommandResult): Boolean;
    function Execute(const Res: TCommandResult): TCommandExecResult;
  end;

  {--- Result of a single file upload attempt, surfaced to the host through
       TUploadCompleteProc when an IFileUploadService implementation finishes
       processing a file. The record is the only piece of upload state that
       crosses the service boundary; the local path is preserved as the
       correlation key. }
  TUploadResult = record
    LocalPath: string;
    Success: Boolean;
    FileId: string;
    ErrorMessage: string;
    class function Ok(const ALocalPath, AFileId: string): TUploadResult; static;
    class function Fail(const ALocalPath, AErrorMessage: string): TUploadResult; static;
  end;

  TUploadCompleteProc = TProc<TUploadResult>;

  {--- Optional vendor-provided service used by Pythia when the host wants to
       transfer selected files asynchronously to a remote storage / Files API
       and reference them later by an opaque file id (rather than inlining
       them as document blocks).

       Lifecycle contract:
       • ShouldHandle is called synchronously on the UI thread for every
         file selected through the open dialog. The implementation decides
         per-file whether it wants to take ownership of the upload.
       • SubmitForUpload returns immediately. The actual transfer runs
         asynchronously. AOnComplete is invoked exactly once, on the UI
         thread, when this specific file is Ready or Failed. AOnComplete
         may be nil when the host only relies on TryGetFileId at submit time.
       • CancelOrDelete is called when the user removes an attachment from
         the compose box, or when the host wants to evict a previously
         uploaded file. Implementations must tolerate calls for unknown
         paths.
       • TryGetFileId is queried at submit time, just before the chat
         payload is built. It must not block.
       • PendingCount + OnPendingChanged are exposed so the host UI can
         disable the send button while at least one upload is still in
         flight. OnPendingChanged is invoked on the UI thread whenever
         PendingCount transitions to or from zero, at minimum.

       Implementations are responsible for thread-marshaling, concurrency
       control (rate limit, parallel cap) and persistence of file ids for
       later cleanup. Pythia core is intentionally agnostic of those
       concerns. }
  IFileUploadService = interface
    ['{7D4A2C8E-9F31-4E5B-B3A7-1C0E6D2F5A48}']
    function ShouldHandle(const ALocalPath: string;
                          const ATarget: TOpenFileTarget): Boolean;

    procedure SubmitForUpload(
      const ALocalPath: string;
      const ATarget: TOpenFileTarget;
      const AOnComplete: TUploadCompleteProc = nil);

    procedure CancelOrDelete(const ALocalPath: string);

    function TryGetFileId(const ALocalPath: string;
                          out AFileId: string): Boolean;

    function PendingCount: Integer;

    function GetOnPendingChanged: TProc;
    procedure SetOnPendingChanged(const Value: TProc);
    property OnPendingChanged: TProc
      read GetOnPendingChanged write SetOnPendingChanged;
  end;

  IPythiaBrowser = interface
    ['{B6D390AF-CEFB-436A-9560-6BACCC390F25}']

    //setters et getters
    function GetClipboard: IClipboardReader;
    procedure SetClipboard(const Value: IClipboardReader);
    function GetScrollButtonsVisible: Boolean;
    procedure SetScrollButtonsVisible(const Value: Boolean);
    function GetSettingsPanelPage: Integer;
    procedure SetSettingsPanelPage(const Value: Integer);
    function GetPromptCount: Integer;
    procedure SetPromptCount(const Value: Integer);
    function GetLocked: Boolean;
    procedure SetLocked(const Value: Boolean);
    function GetEscape: Boolean;
    procedure SetEscape(const Value: Boolean);
    function GetCustomPanels: TCustomPanels;
    procedure SetCustomPanels(const Value: TCustomPanels);
    function GetEnabledButtons: TEnabledButtons;
    procedure SetEnabledButtons(const Value: TEnabledButtons);

    function GetOnChatSessionAutoRename: TProc<string, string>;
    procedure SetOnChatSessionAutoRename(const Value: TProc<string, string>);

    function GetPersistentChat: IPersistentChat;
    procedure SetPersistentChat(const Value: IPersistentChat);
    function GetApiKeySecretStore: ISecretStore;
    procedure SetApiKeySecretStore(const Value: ISecretStore);
    function GetCommandLine: ICommandRegistry;
    procedure SetCommandLine(const Value: ICommandRegistry);
    function GetApiKeyNamesAsJsonString: string;
    procedure SetApiKeyNamesAsJsonString(const Value: string);
    function GetFileUploadService: IFileUploadService;
    procedure SetFileUploadService(const Value: IFileUploadService);

    //accessible uniquement avec via l'interface
    function ExecuteScript(const Script: string): Boolean;
    function PostWebMessageAsJson(const Script: string): Boolean;

    procedure SetTheme(const Value: string);
    function CapabilitiesInitialization: Boolean;

    function ChatSessionDrawerOpen: Boolean;
    function ChatSessionDrawerClose: Boolean;
    function ChatSessionDrawerClear: Boolean;

    function Confirmation(const Value, Goal, Tag: string; const Index: Integer): Boolean;
    function ChatSessionAdd(const ID: string; const Text: string): Boolean;
    function ChatSessionRemove(const Id: string): Boolean;
    function ChatSessionRename(const Id: string; const ATitle: string): Boolean;
    function ChatSessionToTop(const Id: string): Boolean;
    function ChatSessionUnselect: Boolean;
    procedure SessionAutoRename(const Id: string; const ATitle: string);

    function BubbleInputMenuOpen: Boolean;
    function BubbleInputMenuClose: Boolean;
    function BubbleInputPartialReset: Boolean;
    function BubbleInputAudioButtonVisible(const Value: Boolean = True): Boolean;
    function BubbleInputFunctionButtonVisible(const Value: Boolean = True): Boolean;
    function BubbleInputClear: Boolean;
    function BubbleInputSetText(const Value: string): Boolean;
    function BubbleInputWelcome(const Value: string): Boolean;

    function ReasoningCollapse: Boolean;
    function ReasoningExpand: Boolean;
    function ReasoningToggle: Boolean;
    function ReasoningHide: Boolean;
    function ReasoningShow: Boolean;

    function SettingsPanelShowPage(const Page: Integer): Boolean;
    function SettingsPanelHide: Boolean;
    function SettingsPanelRequestCurrentSettingsState: Boolean;
    function SettingsPanelInitializeFullState(const JsonAsString: string): Boolean;
    function SettingsPanelUpdatePropertiesByFullPath(const JsonAsString: string): Boolean;
    function SettingsPanelUpdateApplicationSettings(const JsonAsString: string): Boolean;
    function SettingsPanelForceLanguageSelection(const JsonAsString: string): Boolean;
    function SettingsPanelGetValues: Boolean;
    function SettingsPanelLoadPage: Boolean;
    procedure SettingsPanelSaveAppSettings;

    function ModelInitialize: Boolean;
    function ModelListFileCheck: Boolean;
    function ModelsSelectorShow: Boolean;
    function ModelsSelectorHide: Boolean;
    function ModelsSelectorCategoryVisible(const Category: string; const Visible: Boolean): Boolean;
    function ModelsSelectorSetModelList: Boolean;
    function ModelsSelectorCategoryAdd: Boolean;
    function ModelsSelectorGetReplaceVersion: Boolean;

    function CardSelectorShow(const Dialog: string): Boolean;
    function CardSelectorHide: Boolean;
    function CardSelectorSetData(const JsonString: string): Boolean;
    function CardSettingsButtonVisible(const Value: Boolean): Boolean;
    function TryGetCardFileContent(const AType: string; ParamProc: TFunc<string, Boolean>): Boolean;

    procedure ScrollToAfterEnd(SizeAfter: Integer; Smooth: Boolean = True); overload;
    procedure ScrollToAfterEnd(Smooth: Boolean = True); overload;
    procedure ScrollToEnd(Smooth: Boolean = False);
    procedure ScrollToTop(Smooth: Boolean = false);

    procedure SetLanguage(const Value: string);
    procedure StopMedia;
    function DisplayChatSession: Boolean;
    function UpdateFileDrawer: Boolean;

    function GetAssetsFolder: string;
    function GetLanguageFolder: string;
    function GetMediaFolder: string;
    function GetAppRawName: string;
    function GetParamsConfigFileName: string;
    function GetParamsMainValuesFileName: string;
    function GetChatSessionsFileName: string;
    function GetModelCategoriesFileName: string;
    function GetModelListFileName: string;
    function GetMcpCardsFileName: string;
    function GetFunctionCardsFileName: string;
    function GetSkillCardsFileName: string;
    function GetAgentCardsFileName: string;
    function GetCustomCardsFileName: string;
    function GetExchangeDebugFileName: string;
    function GetAPIKeyNamesFileName: string;
    function GetCustomJSFileName: string;
    function GetCapabilitiesFileName: string;

    procedure DispatchCommand(const ACommandResult: TCommandResult);
    function TryHandleAsCommand(const PromptText: string): Boolean;

    procedure ChatSessionAutoRename(const ID: string; const Content: string);
    procedure ApiKeyValuesUpdate(const KeyName: string);

    {--- Pushes the upload status of a file (identified by its local path,
         already present in the compose box) to the JS layer so the bubble
         can carry the file_id and reflect a visual indicator.

         IMPORTANT — convention de pré-échappement : l'implémentation côté
         host se contente d'injecter chaque paramètre via Format dans le
         template JS. L'appelant doit donc fournir des littéraux JS prêts à
         l'emploi (chaîne entre guillemets et échappée, ou 'null'). Les
         constantes FILE_UPLOAD_STATUS_UPLOADING / READY / FAILED de
         WVPythia.Chat.Consts sont déjà au bon format pour AStatus. }
    function SetFileUploadStatus(
      const APath: string;
      const AStatus: string;
      const AFileId: string = '';
      const AErrorMessage: string = ''): Boolean;

    {--- Toggles the orthogonal availability flag of the send button (i.e.
         whether the button is clickable, independently of its input/stop
         visual mode). Used by the upload pipeline to lock submit while at
         least one transfer is still in flight. }
    function SetSendButtonAvailability(const AEnabled: Boolean): Boolean;

    // Methods exposed by the object
    procedure Clear;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure SetFocus;

    function Prompt(const AText: string): Boolean;

    function PromptMedia(Kind: TDisplayKind;
      const Value: TArray<string>;
      Scroll: Boolean = True): Boolean; overload;

    function Display(const AText: string;
      Scroll: Boolean = True): Boolean; overload;

    function Display(const AText: string;
      const AThink: string;
      Scroll: Boolean = True): Boolean; overload;

    function DisplayStream(const AText: string;
      Scroll: Boolean = True): Boolean; overload;

    function DisplayStream(const AText: string;
      const AThink: string;
      Scroll: Boolean = True): Boolean; overload;

    function DisplayMedia(Kind: TDisplayKind;
      const Value: TArray<string>;
      Scroll: Boolean = True): Boolean; overload;

    function DisplayError(const Value: string): Boolean;
    function DisplayWarning(const Value: string): Boolean;
    function DisplaySuccess(const Value: string): Boolean;
    function DisplayFooter(const Value: string): Boolean;
    function DisplaySpacer(const AHeight: Integer = 190): Boolean;

    function ResetCapabilities: Boolean;

    procedure Hide;
    procedure Show;

    function BrowserInput(
      const AMessage: string;
      const AKey: string;
      const AValue: string;
      const ADefault: string;
      const Hidden: Boolean = False): Boolean; overload;

    function BrowserInput(
      const AMessage: string;
      const AKey: string;
      const ADefault: string): Boolean; overload;

    function BrowserInput(
      const AMessage: string;
      const AKey: string;
      const Hidden: Boolean = False): Boolean; overload;

    property Clipboard: IClipboardReader read GetClipboard write SetClipboard;
    property PromptCount: Integer read GetPromptCount write SetPromptCount;
    property Locked: Boolean read GetLocked write SetLocked;
    property Escape: Boolean read GetEscape write SetEscape;
    property LocalScrollButtonsVisible: Boolean read GetScrollButtonsVisible write SetScrollButtonsVisible;
    property SettingsPanelPage: Integer read GetSettingsPanelPage write SetSettingsPanelPage;
    property CustomPanels: TCustomPanels read GetCustomPanels write SetCustomPanels;
    property EnabledButtons: TEnabledButtons read GetEnabledButtons write SetEnabledButtons;
    property OnChatSessionAutoRename: TProc<string, string> read GetOnChatSessionAutoRename write SetOnChatSessionAutoRename;
    property PersistentChat: IPersistentChat read GetPersistentChat write SetPersistentChat;
    property ApiKeySecretStore: ISecretStore read GetApiKeySecretStore write SetApiKeySecretStore;
    property CommandLine: ICommandRegistry read GetCommandLine write SetCommandLine;
    property ApiKeyNamesAsJsonString: string read GetApiKeyNamesAsJsonString write SetApiKeyNamesAsJsonString;
    {--- Optional vendor-provided service called when a file is selected through
         the open dialog. Set it from the host bootstrap to enable remote file
         transfer (Files API and similar). When unset, files keep flowing through
         the existing inline pipeline unchanged. }
    property FileUploadService: IFileUploadService read GetFileUploadService write SetFileUploadService;
  end;

implementation

class function TCommandExecResult.Ok(const AMessage: string): TCommandExecResult;
begin
  Result.Success := True;
  Result.Message := AMessage;
end;

class function TCommandExecResult.Fail(const AMessage: string): TCommandExecResult;
begin
  Result.Success := False;
  Result.Message := AMessage;
end;

{ TUploadResult }

class function TUploadResult.Ok(
  const ALocalPath, AFileId: string): TUploadResult;
begin
  Result.LocalPath := ALocalPath;
  Result.Success := True;
  Result.FileId := AFileId;
  Result.ErrorMessage := '';
end;

class function TUploadResult.Fail(
  const ALocalPath, AErrorMessage: string): TUploadResult;
begin
  Result.LocalPath := ALocalPath;
  Result.Success := False;
  Result.FileId := '';
  Result.ErrorMessage := AErrorMessage;
end;

end.
