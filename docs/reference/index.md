# Pythia-Webview2 Technical Reference

A focused, lookup-oriented reference for the four pillars of the framework: **interfaces**, **events**, **templates**, and **JSON files**. Where the main documentation ([pythia-documentation.md](../../docs/pythia-documentation.md#pythia--documentation)) explains *why* and *how*, this file answers *what is the exact shape of X* — fast, dense, scannable.

This document complements the integrator tutorial ([integrator.md](../../docs/integrator/index.md#build-your-first-application-based-on-pythia)). Use the tutorial when you want to learn the workflow; use this reference when you need to look up a specific contract, payload, or file schema.

<br>

## Table of Contents
- [How to read this reference](#how-to-read-this-reference)
- [Part 1 — Interfaces](#part-1--interfaces)
  - [`IPythiaBrowser` — component façade](#ibrowser--component-façade)
  - [`IChatManagedItemDialogService` — service adapter](#ichatmanageditemdialogservice--service-adapter)
  - [`IVendorServices` — LLM vendor](#ivendorservices--llm-vendor)
  - [`IApiKeyService` — API key CRUD](#iapikeyservice--api-key-crud)
  - [`ISecretStore` — secret persistence](#isecretstore--secret-persistence)
  - [`ICapabilities` — fluent capability builder](#icapabilities--fluent-capability-builder)
  - [`ITemplateProvider` — template loading](#itemplateprovider--template-loading)
  - [`ICommandRegistry` / `ICommandPlugin` — slash commands](#icommandregistry--icommandplugin--slash-commands)
  - [`IOpenDialog` — file dialog abstraction](#iopendialog--file-dialog-abstraction)
  - [`IProcessExecute` — external process abstraction](#iprocessexecute--external-process-abstraction)
  - [`IPersistentChat` — chat session persistence](#ipersistentchat--chat-session-persistence)
- [Part 2 — Events (`TBrowserChatEvent`)](#part-2--events-tbrowserchatevent)
  - [Dispatch mechanism](#dispatch-mechanism)
  - [Prompt & orchestration](#prompt--orchestration)
  - [Chat sessions](#chat-sessions)
  - [Message actions](#message-actions)
  - [Integration dialogs](#integration-dialogs)
  - [Model selector](#model-selector)
  - [Card selector](#card-selector)
  - [Settings & appearance](#settings--appearance)
  - [Extension channel](#extension-channel)
- [Part 3 — Templates (`TTemplateType`)](#part-3--templates-ttemplatetype)
  - [Loading model](#loading-model)
  - [Template catalog](#template-catalog)
  - [Override patterns](#override-patterns)
  - [Embedded UI security model](#embedded-ui-security-model)
  - [Embedded UI permission model](#embedded-ui-permission-model)
- [Part 4 — JSON files](#part-4--json-files)
  - [File tree at runtime](#file-tree-at-runtime)
  - [Application root files](#application-root-files)
  - [Support folder files](#support-folder-files)
  - [Schemas in detail](#schemas-in-detail)
- [Part 5 — Cross-reference index](#part-5--cross-reference-index)

<br>

## How to read this reference

Each entry follows a consistent layout to make scanning fast.

For **interfaces**:

| Field | Meaning |
|---|---|
| **Unit** | Source file where the interface is declared. |
| **Purpose** | One-sentence description. |
| **Key members** | Methods, properties, with signatures. |
| **Consumers** | Who calls this interface. |
| **Implementers** | Where the concrete class lives (or "host application"). |

For **events**: each row gives the Delphi enum name, the wire (JSON) string, the producer (UI side), the consumer (Delphi side), and the payload structure when relevant.

For **templates**: enum value, file path under `assets/scripts/`, role, dependencies on other templates.

For **JSON files**: location, schema, consumer code, whether it can be edited manually.

Code samples use `<ExeName>` as a placeholder for the executable's base name (without extension). Pythia-Webview2 derives the JSON file paths from this name.

<br>

## Part 1 — Interfaces

The interfaces below form the stable API surface of Pythia-Webview2. The concrete VCL/FMX classes consume them without exposing their internals; integrator code should always go through the interface.

### `IPythiaBrowser` — component façade

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Chat.Interfaces.pas` |
| **Purpose** | The main façade for talking to the browser component from the application side. |
| **Implementers** | `TVCLPythia`, `TFMXPythia` (via inheritance through the `T*Browser*` chain). |
| **Consumers** | Service adapters, vendor services, command plugins. |

**Key members (selection — see source for the full surface):**

```pascal
function ExecuteScript(const AScript: string): Boolean;
procedure DisplayStream(const AText, AThinking: string;
 const AIsFinal: Boolean);
function Display(const AText: string; const AIsFinal: Boolean): Boolean;
function DisplayError(const AText: string): Boolean;
function DisplayWarning(const AText: string): Boolean;
function DisplaySuccess(const AText: string): Boolean;
function BrowserInput(const AText: string): Boolean;
procedure ApiKeyValuesUpdate(const KeyName: string);
procedure ReasoningHide;
function UpdateFileDrawer(const Files, Images, Knowledge: TArray<string>): Boolean;

property Escape: Boolean;             // true when the user clicked Stop
property Locked: Boolean;
property Theme: string;
property ApiKeySecretStore: ISecretStore;
property CommandLine: ICommandRegistry;

function GetExchangeDebugFileName: string;
function GetAPIKeyNamesFileName: string;
function GetCapabilitiesFileName: string;
// ... + GetXxxCardsFileName for every card family
```

**Where to use it.** A vendor service receives `IPythiaBrowser` in its constructor and calls `DisplayStream` during streaming, `DisplayError`/`DisplaySuccess` for status messages, and reads `Escape` to detect cancellation. Plugins use `BrowserInput` to inject text into the input bar.

<br>

### `IChatManagedItemDialogService` — service adapter

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Adapter.pas` |
| **Purpose** | The single contract through which Pythia-Webview2 delivers UI-driven actions to the host application. |
| **Implementers** | Host application (concrete class, conventionally `TVCLChatManagedItemDialogService` or `TFMXChatManagedItemDialogService`, inheriting from `TCustomChatManagedItemDialogService`). |
| **Consumers** | `TBrowserEventManager`. |

**Full interface:**

```pascal
IChatManagedItemDialogService = interface
 ['{D6471685-67A1-42E6-8BA8-B517AA02A313}']

 function SelectItem(
   const AKind: TAdapterManagedItemKind;
   out AItem: TChatManagedItemRef): Boolean;

 function ActivateManagedItemEvent(
   const AKind: TAdapterManagedItemKind): Boolean; overload;

 function ActivateManagedItemEvent(
   const AState: TInputPromptState;
   const AOnFinalize: TManagedItemFinalizeProc): Boolean; overload;

 function ActivateCopyItemEvent(
   const APairId, AKind, AContent: string): Boolean;

 function ActivateCodeCopyItemEvent(
   const ALang, AText: string): Boolean;

 function ActivateNewChatEvent: Boolean;

 function ActivateCustomEvent(const ARawJson: string): Boolean;
end;
```

**Base class.** `TCustomChatManagedItemDialogService` (`WVPythia.ManagedItemService.pas`) implements this interface and exposes virtual hook methods named `Do…` that the host class overrides:

| Hook | Status | Purpose |
|---|---|---|
| `DoSelectFunctionItem` | virtual | Function card selection. |
| `DoSelectMCPItem` | virtual | MCP card selection. |
| `DoSelectSkillItem` | virtual | Skill card selection. |
| `DoSelectAgentItem` | virtual | Agent card selection. |
| `DoSelectCustomItem` | virtual | Custom card selection. |
| `DoActivateSystemSettings` | virtual | System settings request. |
| `DoActivateModelSelection` | virtual | Model selector request. |
| `DoActivateInputState` | **abstract** | Prompt submission. The most important one. |
| `DoActivateNewChatEvent` | **abstract** | New session creation. |
| `DoActivateCardSettingsEvent` | **abstract** | Card settings request. |
| `DoActivateAudioInputEvent` | **abstract** | Microphone click. |
| `DoActivateCopyItemEvent` | virtual | Copy of a message. |
| `DoActivateCodeCopyItemEvent` | virtual | Copy of a code block. |
| `DoActivateCustomEvent` | virtual | Custom JSON event from a JS template. |

The four `abstract` methods **must** be overridden, otherwise compilation fails when you instantiate the class.

<br>

### `IVendorServices` — LLM vendor

| Field | Value |
|---|---|
| **Unit** | `Vendors.Services.pas` |
| **Purpose** | Bridge to the actual LLM API (Anthropic, OpenAI, Mistral, …). |
| **Implementers** | Host application (e.g. `TAnthropicServices` in the `pythia-anthropic` demo). |
| **Consumers** | `TToolContainer.ActivateInputState` (in the application's adapter unit). |

**Full interface:**

```pascal
IVendorServices = interface
 ['{E7464431-EB15-4121-ADB4-76C40F1A9BEE}']

 procedure AsyncAwaitStreamChat(
   const AState: TInputPromptState;
   const AOnFinalize: TManagedItemFinalizeProc);

 procedure UpdateApiKey;
end;
```
**Companion types** (all in `WVPythia.Chat.ManagedFlow.pas`):

- `TInputPromptState` — class containing every field of the input bar at submission time: `Text`, `Endpoint`, `Thinking`, `Files`, `Images`, `KnowledgeSearch`, `Integration`, `Custom`, `Media`, `RequestParams`, `Models`. **Convert to `TStateBuffer` (record) immediately for safe async capture.**
- `TStateBuffer` (`Vendors.Services.pas`) — record projection of `TInputPromptState` plus streaming helpers (`AddStreamedText`, `AddStreamedThinking`, `AddJsonResponse`).
- `TManagedItemLLMResult` — fluent builder for the final response: `UsedModel`, `Response`, `Reasoning`, `PromptJson`, `ResponseJson`, `Files`, `Images`, `Audios`, `Videos`, `Error`, `ErrorMessage`.
- `TManagedItemFinalizeProc = reference to procedure(const AResult: TManagedItemLLMResult);`

>[!NOTE]
>**Asynchronous Execution Requirement**
>
>The *AsyncAwaitStreamChat* method **MUST** be implemented using a fully asynchronous, non-blocking execution model.
>
>- Implementations **MUST NOT** block the calling thread.
>- In particular, when invoked from a UI context, any synchronous behavior **WILL** result in interface freezes and is therefore considered non-compliant.
>- Streaming callbacks and finalization **SHOULD** be dispatched in a thread-safe manner consistent with the host application's concurrency model. 

<br>

>[!NOTE]
>**Vendor SDK Usage**
>
>Implementers **SHOULD** prefer using Delphi SDKs targeting the supported vendors (Anthropic, OpenAI, Mistral, etc.), including those provided in the associated GitHub repositories.
>- These SDKs are community-maintained (non-official), but are widely used in practice and provide native support for asynchronous operations and streaming.
>- Using them reduces integration complexity and minimizes the risk of incorrect concurrency handling.
>- Custom HTTP implementations **MAY** be used, but the implementer assumes full responsibility for correctness, performance, and streaming behavior.

<br>

>[!NOTE]
>**Interface Extensibility**
>The IVendorServices interface is intentionally designed to be extensible.
>- Implementations **MAY** introduce additional methods to support:
>   - vendor-specific features,
>   - advanced request/response handling,
>   - custom processing pipelines.
>- Such extensions **SHOULD** remain consistent with the abstraction goals of the interface and **MUST NOT** break compatibility with existing consumers.

<br>

### `IApiKeyService` — API key CRUD

| Field | Value |
|---|---|
| **Unit** | `WVPythia.ApiKey.Service.Intf.pas` |
| **Purpose** | Create, delete, query API keys by logical name. |
| **Implementers** | `TApiKeyService` (`WVPythia.ApiKey.Service.pas`). |
| **Consumers** | `TApiKeyPlugin` (the preinstalled `/api-key` slash command). |

**Full interface:**

```pascal
IApiKeyService = interface
 function CreateKey(const AName: string): TApiKeyOperationResult;
 function DeleteKey(const AName: string): TApiKeyOperationResult;
 function Exists(const AName: string): Boolean;
end;
```

**`TApiKeyOperationResult`** is a record:

```pascal
TApiKeyOperationResult = record
 Success: Boolean;
 Message: string;
 class function Ok(const AMessage: string): TApiKeyOperationResult; static;
 class function Fail(const AMessage: string): TApiKeyOperationResult; static;
end;
```

> **Note:** there is no `IsOk` property. Test the `Success` field directly.

Names are normalized: `Trim.ToLowerInvariant`. `Anthropic` and `anthropic` refer to the same key.

<br>

### `ISecretStore` — secret persistence

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Chat.Interfaces.pas` |
| **Purpose** | Abstract the storage of secret values. |
| **Implementers** | `TWinSecretStore` (`Windows.ApiKey.Management.pas`) — uses the Windows Registry under `HKEY_CURRENT_USER\Environment`. |
| **Consumers** | `IApiKeyService`, vendor services that need to read the API key. |

**Key members:**

```pascal
ISecretStore = interface
 function ReadSecret(const AName: string; out AValue: string): Boolean;
 function WriteSecret(const AName, AValue: string): Boolean;
 function DeleteSecret(const AName: string): Boolean;
 function Exists(const AName: string): Boolean;
end;
```

A vendor service typically does:

```pascal
if FBrowser.ApiKeySecretStore.ReadSecret('myvendor', LKey) then
 FClient := TMyVendorFactory.CreateInstance(LKey);
```

There is currently no DPAPI encryption layer; values land in the registry in clear text.

>[!IMPORTANT] 
>
>**Secret Management Responsibility** 
>
> The default implementation of `ISecretStore` relies on OS-level storage mechanisms (e.g., Windows Registry under `HKEY_CURRENT_USER`) and benefits from the associated access control protections.
>- By default, secrets are **protected at the OS level (user isolation)**.
>- No additional cryptographic protection is applied; secrets are stored in clear form and remain accessible to the current user and process.
>- Secret management strategy **IS THE RESPONSIBILITY** of the implementer.
>- Developers MAY replace or extend the provided implementation to meet stricter security requirements, such as:
>   - encrypted storage,
>   - OS-protected secret APIs (e.g., DPAPI),
>   - external secret management systems.
>- Any alternative implementation MUST remain compatible with the `ISecretStore` contract.
>
>This design allows the host application to adapt secret handling according to its security and compliance requirements.

<br>

### `ICapabilities` — fluent capability builder

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Capabilities.Manager.pas` |
| **Purpose** | Toggle which UI surfaces are exposed. |
| **Implementers** | `TCapabilities`. |
| **Consumers** | The component on startup (drives the JSON support file and the UI visibility). |

The interface is a chain of `.<Capability>(Boolean)` methods that all return `ICapabilities`, ending in `.Update`. Categories:

| Family | Capabilities |
|---|---|
| Endpoints | `Endpoint`, `EndpointChatCompletion`, `EndpointChatResponse`, `EndpointMessage`, `EndpointGenerateContent`, `EndpointInteractions`, `EndpointConversation` |
| Textual tools | `WebSearch`, `Thinking`, `ThinkingLow`, `ThinkingMedium`, `ThinkingHigh`, `DeepResearch`, `KnowledgeSearch`, `Files`, `Vision` |
| Integrations | `Integration` (master), `IntegrationFunction`, `IntegrationMcp`, `IntegrationSkills`, `IntegrationAgents` |
| Media | `Media` (master), `MediaCreateImage`, `MediaCreateVideo`, `MediaCreateAudio`, `MediaSpeechToText`, `MediaTextToSpeech` |
| Generic | `Custom`, `SystemPrompt`, `Model` |

`Update` writes the configuration to `<ExeName>-capabilities.json` (under `support/`) and sends a `setCapabilities` message to the WebView.

<br>

### `ITemplateProvider` — template loading

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Template.Manager.pas` |
| **Purpose** | Load and serve the JS templates that compose the chat UI. |
| **Implementers** | `TTemplateProvider`. |
| **Consumers** | The component during WebView2 bootstrap. |

**Key methods:**

```pascal
function GetInitialHtml: string;            // index.htm
function GetPromptTemplate: string;
function GetDisplayTemplate: string;

// ... 22 such getters in total

function LoadCustomTemplate(const FileName: string): string;
procedure TemplateAllwaysReloading(const APath: string = '');
procedure TemplateNeverReloading;
```

`TemplateAllwaysReloading` re-reads files on every access (dev mode).
`TemplateNeverReloading` caches in memory (production).

The full enum (23 entries) is reproduced in [Part 3 — Template catalog](#template-catalog).

> The typo "Allways" in `TemplateAllwaysReloading` is preserved verbatim from the source.

<br>

### `ICommandRegistry` / `ICommandPlugin` — slash commands

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Chat.Interfaces.pas` |
| **Purpose** | Pipeline that parses, validates, and executes slash commands. |
| **Implementers** | `TCommandRegistry`, `TCommandPlugin` (subclassed by host code). |
| **Consumers** | `TBrowserEventManager` on input submit. |

**Plugin contract** (subclasses inherit from `TCommandPlugin` which inherits from `TCommandSpec`):

```pascal
type
 TMyPlugin = class(TCommandPlugin)
 strict protected
   function DoExecute(
     const Action: string;
     const Args: TArray<string>): TCommandExecResult; override;
 public
   constructor Create;
 end;

constructor TMyPlugin.Create;
begin
 inherited Create('my-command');
 AddAction('run',    1, 1);
 AddAction('status', 0, 0);
end;
```

**Result type:**

```pascal
TCommandExecResult = record
 class function Ok(const AMessage: string): TCommandExecResult; static;
 class function Fail(const AMessage: string): TCommandExecResult; static;
end;
```

**Validation statuses** (returned by the registry):

| Status | Meaning |
|---|---|
| `csOk` | Command and action recognized, arg count matches. |
| `csNotACommand` | Input doesn't start with `/`. Falls back to standard prompt flow. |
| `csUnknownCommand` | Unknown slash command. |
| `csUnknownAction` | Action not declared in the plugin. |
| `csWrongArgCount` | Action declared but with a different arg cardinality. |

Plugins are registered through the `OnRegisterCommandPlugins: TProc` hook of the component (called after the automatic registration of `TApiKeyPlugin`).

<br>

### `IOpenDialog` — file dialog abstraction

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Chat.Interfaces.pas` |
| **Purpose** | Open a system file-selection dialog with a target-specific filter. |
| **Implementers** | `TVCLOpenDialog` (`VCL.WVPythia.OpenDialog.pas`), `TFMXOpenDialog` (`FMX.WVPythia.OpenDialog.pas`). |
| **Consumers** | `TBrowserEventManager` on `open-file-dialog`. |

**Key method:**

```pascal
function SelectFile(const ATarget: TOpenFileTarget): string;
```

`TOpenFileTarget` (`WVPythia.Types.pas`) values: `Images`, `Documents`, `Knowledge`, `Speech`. Each value applies a different extension filter.

<br>

### `IProcessExecute` — external process abstraction

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Chat.Interfaces.pas` |
| **Purpose** | Launch an external process from a slash command or a custom event. |
| **Implementers** | `TProcessExecute` (`Windows.Process.Execution.pas`). |
| **Consumers** | Application code that needs to launch external tools. |

**Key methods:**

```pascal
function Execute(const AFileName, AParameters: string): Boolean;
function ExecuteAndWait(const AFileName, AParameters: string;
 out AOutput: string): Boolean;
```

<br>

### `IPersistentChat` — chat session persistence

| Field | Value |
|---|---|
| **Unit** | `WVPythia.Chat.Interfaces.pas` |
| **Purpose** | Persist chat sessions and turns to disk; expose pagination. |
| **Implementers** | Provided by `WVPythia.ChatSession.Controller.pas` via `TPersistentChatFactory`. |
| **Consumers** | `TBrowserEventManager` for session events; the chat session manager class for paging. |

The persistent store lives in `<ExeName>-chat-sessions.json`. Each structural mutation (add, delete, rename) triggers an immediate write — no batching. Pagination is handled by `TChatSessionEventHandler` which loads one page at a time on `chat-next-page`.

<br>

## Part 2 — Events (`TBrowserChatEvent`)

### Dispatch mechanism

Source: `WVPythia.Types.pas`. **38 enum values**, each mapped to a wire-format string via `TBrowserChatEventHelper.Map` — that string is the value of the `event` field in the JSON sent by the WebView.

**Pipeline:**

```
JS template
  └─► postMessage({event: "...", ...})
         ▼
  TBrowserEventManager.Aggregate(RawJson)
      1. CanHandleEvents() ?
      2. FReader := TJsonReader.Parse(RawJson)
      3. eventName = FReader[PROP_EVENT] → TBrowserChatEvent
      4. FDispatch[EventKind]()
         ▼
  TBrowserEventHandlers (specialized handlers)
         ▼
  IPythiaBrowser / IPersistentChat / IOpenDialog /
  IProcessExecute / IChatManagedItemDialogService /
  ICommandRegistry / ISecretStore
         ▼
  ExecuteScript() / PostWebMessageAsJson() — UI feedback
```

The framework parses each JSON exactly once into `FReader`; handlers execute, they do not re-route. `custom-event` payloads pass through raw without any framework-side deserialization.

### Prompt & orchestration

| Delphi | Wire | Producer | Consumer | Notes |
|---|---|---|---|---|
| `InputSubmit` | `input-submit` | Input bar (Enter) | `DoActivateInputState` of the adapter | Carries the full `TInputPromptState`. The most important event. |
| `InputState` | `input-state` | Input bar | Handler chain | Live updates while typing. |
| `InputString` | — | Internal | Internal | Has no wire mapping; used for purely Delphi-side flows. |
| `StopSubmit` | `stop-submit` | Input bar (Stop button) | Sets `IPythiaBrowser.Escape := True` | The vendor must poll `Escape` to cancel. |
| `AudioInput` | `audio-input` | Input bar (microphone) | `DoActivateAudioInputEvent` | No default handler — host implements. |

### Chat sessions

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `NewChatEvent` | `new-chat` | "+" button | Session creation handler |
| `ChatSelectionEvent` | `chat-selection` | Session list click | Loads + redraws the session |
| `ChatNextPageEvent` | `chat-next-page` | Scroll bottom of list | Paginates the store |
| `ChatItemDeleteEvent` | `chat-item-delete` | Session item context menu | Triggers two-step confirmation |
| `ChatItemRenameEvent` | `chat-item-rename` | Inline rename | Mutates the store |

### Message actions

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `&Copy` | `copy` | Message copy button | `DoActivateCopyItemEvent` |
| `CopyEvent` | `copy-event` | Generic copy | `DoActivateCopyItemEvent` |
| `BranchEvent` | `branch-event` | Branch button | Application — typically duplicates a session |
| `DeleteEvent` | `delete-event` | Message delete button | Two-step confirmation |
| `ScrollRequest` | `scroll-request` | Programmatic scroll | UI scroll helper |

### Integration dialogs

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `OpenFileDialog` | `open-file-dialog` | Paperclip icon | `IOpenDialog.SelectFile(target)` |
| `OpenIntegrationFunctionDialog` | `open-integration-function-dialog` | Cards panel — function tab | `DoSelectFunctionItem` |
| `OpenIntegrationMcpDialog` | `open-integration-mcp-dialog` | Cards panel — MCP tab | `DoSelectMCPItem` |
| `OpenIntegrationSkillsDialog` | `open-integration-skills-dialog` | Cards panel — Skills tab | `DoSelectSkillItem` |
| `OpenIntegrationAgentsDialog` | `open-integration-agents-dialog` | Cards panel — Agents tab | `DoSelectAgentItem` |
| `OpenCustomDialog` | `open-custom-dialog` | Cards panel — Custom tab | `DoSelectCustomItem` |
| `DisplayFileClick` | `display-file-click` | Click on a file card in the chat | Application |
| `DialogConfirmationResponse` | `dialog-confirmation-response` | Confirm / Cancel button in modals | Step 2 of the two-step pattern |

### Model selector

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `ModelSelection` | `model-selection` | User picks a model | UI updates the active model |
| `ModelSelectorCategoryChanged` | `model-selector-category-changed` | Category tab switch | Filters the visible list |
| `ModelSelectorSelectionChanged` | `model-selector-selection-changed` | Hover/select | Live preview |
| `ModelSelectorGetReplaceVersion` | `model-selector-get-replace-version` | Version-resolution request | Reads `<ExeName>-model-get-replace-version.json` |

### Card selector

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `CardSelectionDialogSettings` | `card-selection-dialog-settings` | Settings icon on a card | `DoActivateCardSettingsEvent` |
| `CardSelectionDialogSelect` | `card-selection-dialog-select` | Card tile click | Marks card for inclusion |
| `CardSelectionDialogSelectionChanged` | `card-selection-dialog-selection-changed` | Selection state change | Updates `TInputPromptState.Integration.*` |
| `CardSelectionDialogCancel` | `card-selection-dialog-cancel` | Dialog dismiss | UI cleanup |

### Settings & appearance

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `SystemSettings` | `system-settings` | Settings panel main page | `DoActivateSystemSettings` |
| `RequestParamsValues` | `request-params-values` | Settings panel apply | Persists to `-request-params-config.json` |
| `ResquestParamsPageChanged` | `resquest-params-page-changed` | Settings tabs | UI navigation only *(typo preserved verbatim)* |
| `LookAndFeelSelectedEvent` | `look-and-feel-selected` | Theme switch | Updates `Pythia.Theme`, fires `OnThemeChanged` |
| `LanguageSelectedEvent` | `language-selected` | Language switch | Calls `SetLanguage` then fires `OnTranslationsLoaded` |
| `ScrollButtonSelectedEvent` | `scroll-button-selected` | Scroll-button visibility toggle | Persists to main values |

### Extension channel

| Delphi | Wire | Producer | Consumer |
|---|---|---|---|
| `CustomEvent` | `custom-event` | Any user-authored JS template | `DoActivateCustomEvent(ARawJson: string)` |

The framework does **not** parse the payload; it forwards the raw JSON. The application reads `name` to route, then parses `payload` as needed. Recommended JSON shape:

```json
{
 "event": "custom-event",
 "name": "<namespaced.event-name>",
 "payload": { },
 "requestId": "<uuid, optional>"
}
```

<br>

## Part 3 — Templates (`TTemplateType`)

### Loading model

Templates are loaded from the disk path `<exe folder>\..\assets` (resolved at runtime). The 22 JS files plus `index.htm` make up the entire UI surface.

Two loading strategies:

| Method | Behavior | Use case |
|---|---|---|
| `TemplateAllwaysReloading(APath)` | Reads each file on every access | Development: hot-edit JS, restart, observe |
| `TemplateNeverReloading` | Reads once, caches in memory | Production |

`LoadCustomTemplate(FileName)` returns the contents of an alternative file, used by `provider.LoadCustomTemplate('scripts\MyPromptTemplate.js')` to override a specific template without recompilation.

### Template catalog

Defined by the enum `TTemplateType` (`WVPythia.Template.Manager.pas`). Files under `assets/scripts/` unless otherwise noted.

| # | Enum | File | Role |
|---|---|---|---|
| 1 | `main_html` | `assets/index.htm` | Root HTML skeleton; declares the DOM containers and loads injected scripts. |
| 2 | `js_response` | `DisplayTemplate.js` | Rendering of an assistant turn (markdown, code blocks, citations). |
| 3 | `js_prompt` | `PromptTemplate.js` | Rendering of a user turn. |
| 4 | `js_waitfor` | `ReasoningTemplate.js` | Animation and display of the reasoning (thinking) block. |
| 5 | `js_inputbubble` | `InputBubbleTemplate.js` | Input bar: textarea, buttons, submit/stop state. |
| 6 | `js_scrollButtons` | `ScrollButtonsTemplate.js` | Up/down scroll buttons floating over the chat. |
| 7 | `js_images` | `DisplayImageTemplate.js` | Rendering of generated images. |
| 8 | `js_promptFile` | `PromptFileTemplate.js` | Display of attachments inside the user turn. |
| 9 | `js_audio` | `DisplayAudioTemplate.js` | Inline audio player. |
| 10 | `js_video` | `DisplayVideoTemplate.js` | Inline video player. |
| 11 | `js_displayfile` | `DisplayFileTemplate.js` | Clickable file card inside the assistant turn. |
| 12 | `js_selector` | `SelectorTemplate.js` | Card selector core (functions, MCP, skills, agents, custom). |
| 13 | `js_confirmationDialog` | `ConfirmationDialogTemplate.js` | Two-step confirmation dialog. |
| 14 | `js_filesMenager` | `FilesDrawerTemplate.js` | Drawer of files attached to the input bar. |
| 15 | `js_errors` | `ErrorsTemplate.js` | Rendering of error messages. |
| 16 | `js_requestParams` | `RequestParamsTemplate.js` | Settings panel (temperature, top-p, system prompt…). |
| 17 | `js_bootstrapDictionary` | `BootstrapDictionaryTemplate.js` | i18n dictionary loader and `window.AppI18n.t` helper. |
| 18 | `js_models` | `ModelsTemplate.js` | Model selector. |
| 19 | `js_chatFooter` | `ChatFooterTemplate.js` | Chat footer (icons, status indicators). |
| 20 | `js_cardSelector` | `CardSelectorTemplate.js` | Multi-card selection dialog. |
| 21 | `js_promptSummary` | `PromptSummaryTemplate.js` | Compact summary of a submitted prompt. |
| 22 | `js_inputDialog` | `InputDialogTemplate.js` | Modal input box (used by `/api-key new`, etc.). |
| 23 | `js_injectionEnded` | `InjectionEndedTemplate.js` | End-of-injection signal — final readiness flag. |

### Override patterns

To replace a template:

```pascal
Pythia.OnBrowserCreated :=
 procedure
 begin
   var Provider := Pythia.TemplateProvider;
   Provider.TemplateAllwaysReloading;
   Provider.LoadCustomTemplate('scripts\MyPromptTemplate.js');
 end;
```

Within the JS template itself, follow the conventions used by the shipped templates:
- **IIFE** wrapping: `(() => { /* code */ })();` to avoid polluting `window`.
- **i18n** through `window.AppI18n.t('key')` exposed by `BootstrapDictionaryTemplate.js`.
- **postMessage** to talk back to Delphi: `window.chrome.webview.postMessage({event: 'custom-event', name: '...', payload: {...}});`.

These are conventions, not enforced by the framework; only the `postMessage` channel is mandatory for any communication with Delphi.

<br>

### Embedded UI security model

The WebView2 surface is protected by two complementary mechanisms:

1. **Content Security Policy (CSP)** declared in `assets/index.htm`.
2. **Navigation locking** enforced by the Delphi WebView2 bridge.

The default `index.htm` declares a CSP that restricts the resources allowed to load inside the embedded UI. In particular, scripts, styles, fonts, images, and media are limited to the local document context and to explicitly allowed origins such as `https://cdn.jsdelivr.net` and `https://app.local`.

```html
<meta http-equiv="Content-Security-Policy"
      content="
        default-src 'self';
        script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net;
        style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net;
        font-src 'self' data: https://cdn.jsdelivr.net;
        img-src 'self' data: blob: https://app.local;
        media-src 'self' data: blob: https://app.local;
      ">
```

The default CSP allows `https://cdn.jsdelivr.net` for front-end dependencies. Applications requiring a fully offline deployment **SHOULD** package these dependencies locally and remove the CDN origin from the CSP.

In addition to the CSP, the WebView2 host locks navigation during initialization:

```pascal
procedure TFMXPythiaBridgeManager.LockNavigation;
begin
  FBrowser.OnNavigationStarting := DoNavigationStarting;
end;
```

Navigation requests are then filtered before WebView2 loads the target URI:

```pascal
procedure TFMXPythiaBridgeManager.DoNavigationStarting(Sender: TObject;
  const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2NavigationStartingEventArgs);
var
  uri: PWideChar;
  url: string;
begin
  aArgs.Get_uri(uri);
  try
    url := uri;

    {--- Disable navigation with unauthorized external links }
    aArgs.Set_Cancel(Ord(not IsAllowedNavigation(url)));
  finally
    CoTaskMemFree(uri);
  end;
end;
```

>[!IMPORTANT]
>Template customization **MUST NOT** assume that arbitrary external navigation is allowed.
> - The CSP defines which resource origins may be loaded by the HTML document.
> - The WebView2 navigation filter defines which top-level navigations are accepted.
> - Custom templates **SHOULD** use the existing `postMessage` bridge for communication with Delphi instead of forcing browser navigation.
> - Integrators **MAY** adapt `IsAllowedNavigation` **and the CSP when adding trusted origins, but both layers SHOULD remain consistent.**
> - Any relaxation of these rules **SHOULD** be treated as a security-sensitive change.

This layered design keeps the embedded UI constrained while still allowing the host application to explicitly authorize additional origins when required.

<br>

### Embedded UI permission model

The embedded WebView2 surface is designed to host trusted local application UI, composed of `index.htm` and the internal JavaScript templates shipped with the project.

The host application also blocks unauthorized external navigation during WebView2 initialization. As a result, the WebView2 instance is not intended to behave as a general-purpose browser.

Microphone access is granted automatically to support local browser-side audio features, such as Speech-to-Text.

>[!IMPORTANT]
>Microphone access is the only WebView2 permission granted automatically by the default implementation.
>
>- This permission is limited to `COREWEBVIEW2_PERMISSION_KIND_MICROPHONE`.
>- It is required for local audio capture features.
>- Other WebView2 permissions are not granted automatically by the default implementation.
>- Applications that relax the default navigation policy, load remote UI content, or render untrusted HTML/Markdown output should review this permission policy accordingly.

This design keeps Speech-to-Text available while keeping the WebView2 permission surface intentionally narrow.

<br>

## Part 4 — JSON files

### File tree at runtime

Pythia-Webview2 auto-creates the following tree on first launch, based on the executable name. Example with `MyApp.exe`:

```
bin32
├── MyApp.exe
├── WebView2Loader.dll
└── MyApp
   ├── MyApp-request-params-config.json
   ├── MyApp-request-params-main-values.json
   ├── MyApp-chat-sessions.json
   ├── MyApp-model-get-replace-version.json
   ├── MyApp-api-key-names.json
   ├── MyApp-exchange-debug.json          (DEV_MODE only)
   └── support
       ├── MyApp-capabilities.json
       ├── MyApp-model-list.json
       ├── MyApp-mcp-cards.json
       ├── MyApp-function-cards.json
       ├── MyApp-skill-cards.json
       ├── MyApp-agent-cards.json
       ├── MyApp-custom-cards.json
       └── MyApp-custom-template-js.json
```

### Application root files

| File | Role | Editable |
|---|---|---|
| `<ExeName>-request-params-config.json` | Full state of the settings panel (temperature, top-p, system prompt, model selection). Reloaded each time the panel opens. | Yes |
| `<ExeName>-request-params-main-values.json` | Application main values: theme, language, scroll-button visibility. **Deleting it forces a reset to `english-us`.** | Yes |
| `<ExeName>-chat-sessions.json` | Full history of chat sessions (titles, turns, timestamps). Deleting it wipes all history. | Yes (with care) |
| `<ExeName>-model-get-replace-version.json` | Version-substitution mapping for the model selector (stable id → effective version). | Yes |
| `<ExeName>-api-key-names.json` | Registry of declared API key names (not secrets — those live in the Windows Registry). | Yes (carefully) |
| `<ExeName>-exchange-debug.json` | Last JSON message received by the event pipeline. **Only when compiled with `{$DEFINE DEV_MODE}`.** | No (overwritten) |

### Support folder files

| File | Role | Editable |
|---|---|---|
| `<ExeName>-capabilities.json` | `ICapabilities` configuration. Generated with all-true defaults if absent. | Yes |
| `<ExeName>-model-list.json` | List of models for the selector. Generated with placeholders if absent. | Yes |
| `<ExeName>-mcp-cards.json` | MCP integration cards. | Yes |
| `<ExeName>-function-cards.json` | Function-calling cards. | Yes |
| `<ExeName>-skill-cards.json` | Skill cards. | Yes |
| `<ExeName>-agent-cards.json` | Agent cards. | Yes |
| `<ExeName>-custom-cards.json` | Application-specific custom cards. | Yes |
| `<ExeName>-custom-template-js.json` | References to custom JS templates loaded via `LoadCustomTemplate`. Lets the component re-inject overrides on restart. | Yes |

### Schemas in detail

#### `<ExeName>-capabilities.json`

```json
{
   "type": "setCapabilities",
   "endpoint": true,
   "endpointChatCompletion": true,
   "endpointChatResponse": true,
   "endpointMessage": true,
   "endpointGenerateContent": true,
   "endpointInteractions": true,
   "endpointConversation": true,
   "webSearch": true,
   "thinking": true,
   "files": true,
   "knowledgeSearch": true,
   "vision": true,
   "deepResearch": true,
   "integration": true,
   "integrationFunction": true,
   "integrationMcp": true,
   "integrationSkills": true,
   "integrationAgents": true,
   "thinkingLow": true,
   "thinkingMedium": true,
   "thinkingHigh": true,
   "media": true,
   "mediaCreateImage": true,
   "mediaCreateVideo": true,
   "mediaCreateAudio": true,
   "mediaSpeechToText": true,
   "mediaTextToSpeech": true,
   "custom": true,
   "systemPrompt": true,
   "model": true
}
```

The `type` field must remain `"setCapabilities"` — it is the signature recognized by the JS configuration channel. Altering it causes the message to be silently ignored.

#### `<ExeName>-model-list.json`

```json
{
 "type": "model-selector-set-data",
 "models": [
   {
     "id": "claude-sonnet-4-5",
     "label": "Claude Sonnet 4.5",
     "capabilityLabels": ["Thinking", "Vision"],
     "categoryId": "textGeneration"
   }
 ],
 "activeCategoryId": "allModels",
 "selectedModelId": ""
}
```

| Field | Purpose |
|---|---|
| `id` | UI-side identifier. Used to retrieve the selected model. |
| `label` | Display name. |
| `capabilityLabels` | Tags shown under the label (visual filtering only). |
| `categoryId` | Filter category. Standard values: `textGeneration`, `imageCreation`, `videoCreation`, `audioCreation`, `textToSpeech`, `speechToText`, `deepResearch`. |
| `activeCategoryId` | Default filter (root-level). `"allModels"` shows everything. |
| `selectedModelId` | Pre-selected model id. |

#### Card files (`-function-cards.json`, `-mcp-cards.json`, `-skill-cards.json`, `-agent-cards.json`, `-custom-cards.json`)

All five share the same schema. The `dialog` field changes per family:

```json
{
 "type": "card-selection-dialog-set-data",
 "dialog": "function",
 "cards": [
   {
     "id": "1EC2521C-9E0A-410B-8DD4-1D6997F9AFFF",
     "name": "Get weather",
     "commentaire": "Localized weather data injection",
     "content": ""
   }
 ],
 "selectedId": ""
}
```

| Field | Purpose |
|---|---|
| `dialog` | One of `function`, `mcp`, `skills`, `agents`, `custom`. Must match the file family. |
| `cards[].id` | GUID, unique per card. |
| `cards[].name` | Short label. |
| `cards[].commentaire` | Long description (tooltip). |
| `cards[].content` | **Free-form** payload. The framework never parses it; the vendor decides its meaning. |
| `cards[].badge` | Optional: small label like "Beta" or "Pro". |
| `selectedId` | Pre-ticked card. |

#### `<ExeName>-model-get-replace-version.json`

Maps stable identifiers to effective versions.

```json
{
 "type": "model-selector-get-replace-version",
 "models": [
   { "id": "claude-sonnet-latest", "version": "claude-sonnet-4-5-20251015" }
 ]
}
```

#### `<ExeName>-request-params-config.json`

Persisted state of the settings panel. Auto-generated on first save; format mirrors `TCoreParamsState` in `WVPythia.Chat.ManagedFlow.pas`.

#### `<ExeName>-request-params-main-values.json`

Main UI preferences (theme, language, scroll-button visibility). **Deleting this file is the standard way to force a language reset** — for example when adding a new locale that isn't picked up automatically.

#### `<ExeName>-chat-sessions.json`

Persisted chat history. Each session contains a list of turns, each turn the prompt JSON and the response. Editable but the JSON must remain valid: malformed content prevents the application from loading sessions.

#### `<ExeName>-api-key-names.json`

Tracks the **names** of registered API keys (not the values — those live in the Windows Registry under `HKEY_CURRENT_USER\Environment`). Synced on `/api-key new` and `/api-key delete`.

#### `<ExeName>-custom-template-js.json`

Lists the template overrides registered through `LoadCustomTemplate`, allowing them to be re-injected on restart.

#### Language files (`assets/lang/<country>-<code>.json`)

Not generated — shipped with Pythia-Webview2. 23 locales by default. Each file is a tree of nested objects containing translation strings. Top-level sections include `more`, `settings`, and `dialogs`. The host application can add a `custom` sibling section for its own strings (see §24 of the main documentation).

<br>

## Part 5 — Cross-reference index

Quick lookup by topic.

| Looking for | See |
|---|---|
| Send a message to the WebView | `IPythiaBrowser.ExecuteScript` / `IPythiaBrowser.DisplayStream` |
| Receive a prompt submission | `DoActivateInputState` (see [`IChatManagedItemDialogService`](#ichatmanageditemdialogservice--service-adapter)) |
| Cancel a streaming request | Set `IPythiaBrowser.Escape := True` from the Stop button (`StopSubmit` event) |
| Toggle a UI feature | Use `ICapabilities.<Capability>(Boolean).Update` |
| List the slash command statuses | [`ICommandRegistry`](#icommandregistry--icommandplugin--slash-commands) |
| Find the file path for a JSON config | `IPythiaBrowser.GetXxxFileName` (e.g. `GetCapabilitiesFileName`) |
| Add a card | Edit `<ExeName>-<family>-cards.json` |
| Add a model | Edit `<ExeName>-model-list.json` |
| Add a translation key | Edit `assets/lang/<locale>.json` and define a `MyTranslation` proc |
| Override a JS template | `Provider.LoadCustomTemplate('scripts\MyTemplate.js')` |
| Catch a custom JS event | Override `DoActivateCustomEvent(ARawJson: string)` |
| Read the last received message (DEV_MODE) | `<ExeName>-exchange-debug.json` |
| Two-step deletion confirmation | `ConfirmationRequest` records, `DialogConfirmationResponse` executes |
| Vendor service contract | [`IVendorServices`](#ivendorservices--llm-vendor) |

<br>

## Companion documents

- **[pythia-documentation.md](../../docs/pythia-documentation.md#pythia--documentation)** — full reference with explanations, rationale, and end-to-end examples.
- **[integrator.md](../../docs/integrator/index.md#build-your-first-application-based-on-pythia)** — step-by-step tutorial to build your first Pythia-Webview2 application.

This `technical.md` is the dense lookup layer. Use it when you know what you want and need the precise contract or schema.

