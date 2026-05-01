unit WVPythia.Chat.Interfaces;

interface

uses
  System.SysUtils, WVPythia.Types, WVPythia.ChatSession.Controller, WVPythia.Command.Parser;

type
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

  IPythiaBrowser = interface
    ['{B6D390AF-CEFB-436A-9560-6BACCC390F25}']

    //setters et getters
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

end.
