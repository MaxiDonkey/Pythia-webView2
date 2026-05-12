# Pythia-Webview2 — Documentation

## Table of Contents

[Part I — Overview](#part-i--overview)
  - [1 Pitch & positioning](#1-pitch--positioning)
  - [2 Use cases](#2-use-cases)
  - [3 Layered architecture](#3-layered-architecture)
  - [4 Event flow — from the DOM to the Delphi service](#4-event-flow--from-the-dom-to-the-delphi-service)
  - [5 Technical stack & prerequisites](#5-technical-stack--prerequisites)

[Part II — Operation](#part-ii--operation)
   - [6 Installation & first build](#6-installation--first-build)
   - [7 Recommended start — from the starter project pattern](#7-recommended-start--from-the-starter-project-pattern)
   - [8 Exhaustive instantiation — overview of hooks and options](#8-exhaustive-instantiation--overview-of-hooks-and-options)
   - [9 API key configuration](#9-api-key-configuration)
   - [10 Slash command system](#10-slash-command-system)
   - [11 Loading UI templates](#11-loading-ui-templates)
   - [12 Writing a custom command plugin](#12-writing-a-custom-command-plugin)
   - [13 Configuring capabilities via `ICapabilities`](#13-configuring-capabilities-via-icapabilities)
   - [14 Card system — function, MCP, skill, agent, custom](#14-card-system--function-mcp-skill-agent-custom)
   - [15 Model selector](#15-model-selector)
   - [16 Implementing a vendor service (`IVendorServices`)](#16-implementing-a-vendor-service-ivendorservices)
   - [17 Media output — image, audio, video, TTS](#17-media-output--image-audio-video-tts)
   - [18 Audio input (transcription)](#18-audio-input-transcription)
   - [19 File attachments & file drawer](#19-file-attachments--file-drawer)
   - [20 Themes & Look & Feel](#20-themes--look--feel)
   - [21 Two-step confirmation](#21-two-step-confirmation)
   - [22 Chat sessions, persistence, pagination](#22-chat-sessions-persistence-pagination)
   - [23 Plugin UI and JS ↔ Delphi bridge](#23-plugin-ui-and-js--delphi-bridge)
   - [24 Internationalization](#24-internationalization)
   - [25 JSON configuration files](#25-json-configuration-files)

[Part III — Reference](#part-iii--reference)
   - [26 API surface — key interfaces](#26-api-surface--key-interfaces)
   - [27 `TBrowserChatEvent` event table](#27-tbrowserchatevent-event-table)
   - [28 FMX ↔ VCL matrix](#28-fmx--vcl-matrix)
   - [29 JS template catalog](#29-js-template-catalog)
   - [30 Developer mode & diagnostics](#30-developer-mode--diagnostics)
   - [31 Deployment](#31-deployment)
   - [32 Glossary](#32-glossary)
   - [33 Security & limits](#33-security--limits)
   - [34 FAQ / pitfalls](#34-faq--pitfalls)

___

<br>

# Part I — Overview

## 1 Pitch & positioning

**Pythia-Webview2** is a Delphi library that embeds a modern LLM chat interface, similar to ChatGPT or Claude, into a desktop application — both **VCL** and **FMX** — by relying on **WebView2**, which entails an explicit dependency on Windows.

Rendering and interactions happen in **HTML/JS**; business logic, persistence, security, and extensibility remain in **Delphi**.

### For whom?

- Delphi vendors who want to integrate a ready-to-use chat UI without rewriting a web frontend.
- Internal-tooling developers who need a brandable chat through JS templates, with business commands shipped as Delphi plugins.
- Multi-vendor integrators — Anthropic, OpenAI, etc. — who want a single frontend wired to their own services.

### What the product is not

Pythia-Webview2 is not:

- a vendor SDK;
- a REST wrapper;
- an agent orchestrator.

It is a **presentation / control** layer that delegates every LLM call to the application code through stable interfaces.

<br>

## 2 Use cases

- AI assistant embedded in a line-of-business application: CRM, ERP, IDE, support tools.
- Prompt console for developer tools: log analysis, local code review, trace inspection.
- Multi-model desktop client: model selector, agent cards, skills, MCP.
- Administration chat interface with slash commands to trigger system actions, for example:

  - `/api-key new anthropic`

<br>

## 3 Layered architecture

Pythia-Webview2 is organized around a clear boundary between WebView2 rendering and Delphi services. The HTML/JS side produces events and maintains the visual state; Pascal code receives those messages, validates them, then delegates to injected services. The layers below read top-to-bottom: from the embedded UI down to the application contracts, then to the services and persistence infrastructure.

| Layer | Components |
|---|---|
| UI framework | `FMX.WVPythia.Chat` | `VCL.WVPythia.Chat`<br>FMX/VCL specific, symmetric |
| WebView2 host + JS templates | `uWVFMX*`, `WebView4Delphi`, WebView2 runtime<br>`assets/scripts/*.js` — 22 templates |
| Event routing | `WVPythia.Chat.EventManager` — dispatch<br>`WVPythia.Chat.EventHandlers` — execution |
| Neutral contracts | `WVPythia.Adapter`<br>`WVPythia.ManagedItemService`<br>`WVPythia.Chat.Interfaces` |
| Command layer | Parser → Registry → Plugin (+ApiKey) |
| Services | `WVPythia.ApiKey.Service`<br>`WVPythia.ChatSession.Controller`<br>`WVPythia.Template.Manager`<br>`WVPythia.Capabilities.Manager` |
| Infra | `WVPythia.JSON.SafeReader/Writer/Resource`<br>`Windows.ApiKey.Management`<br>`WVPythia.Net.MediaCodec`<br>`VCL.WVPythia.OpenDialog` / `FMX.WVPythia.OpenDialog`<br>`Windows.Process.Execution` |

>[!IMPORTANT]
> **Note — WebView4Delphi**
>
> [`WebView4Delphi`](https://github.com/salvadordf/WebView4Delphi) is an open-source project available on GitHub, maintained by [`salvadordf`](https://github.com/salvadordf).
>
> The version included under `dependencies/` is not necessarily the latest one.
> For project use, it is recommended to clone the official `WebView4Delphi` repository, then add its source path to the `Browser` project options under the **Source** section.
>
> The provided `dependencies/` folder is primarily intended to allow quick execution of the examples, mainly to streamline the user experience.

<br>

### Separation principle

The event layer is independent of the VCL and FMX frameworks: it relies solely on abstract interfaces.

This separation allows roughly 95% of the code to be shared between the two targets.

<br>

## 4 Event flow — from the DOM to the Delphi service

According to `WVPythia.Chat.EventManager.pas`:

```
JS (template)
   └─► window.chrome.webview.postMessage({event: "...", ...})
          │
          ▼
   TBrowserEventManager.Aggregate(RawJson)
       1. CanHandleEvents() ?  (readiness invariant)
       2. FReader := TJsonReader.Parse(RawJson)
       3. EventName = FReader[PROP_EVENT] → TBrowserChatEvent
       4. FDispatch[EventKind]()   ◄── dispatch table
          │
          ▼
   TBrowserEventHandlers (hierarchy of specialized handlers)
       Orchestrator / Card / DialogConfirmation /
       ChatSession / OpenFile / Selector / Models / Settings
          │
          ▼
   Services: IPythiaBrowser, IPersistentChat, IOpenDialog,
             IProcessExecute, IChatManagedItemDialogService,
             ICommandRegistry, ISecretStore
          │
          ▼
   UI feedback: ExecuteScript() / PostWebMessageAsJson()
```

### Invariants

The event manager is intentionally strict: it processes a message only if the `IPythiaBrowser` bridge is injected, if the received JSON is valid, and if the `event` field can be resolved to a `TBrowserChatEvent`. Once these conditions are met, the method bound to that event in the `FDispatch` table is called; on an unknown event, the browser receives an error and the message is not executed.

1. The JSON is parsed only once into `FReader`.
2. Handlers do not route: they execute.
3. `custom-event` payloads are never deserialized by the framework: they pass through raw.

<br>

## 5 Technical stack & prerequisites

**Pythia-Webview2** rests on a fixed Windows desktop stack: Delphi hosts the application layer, WebView2 renders the bundled HTML/JS interface, and the application code supplies the LLM/vendor behavior.

| Component | Version / note |
|-|-|
| Delphi | 11 / 12 / 13 — RTTI Generics required. Older versions are not supported. |
| UI frameworks | VCL and/or FMX. |
| Pythia-Webview2 repository | Required locally, with access to `source/`, `assets/`, `bin32/`, `bin64/`, and the starter projects under `demos/VCL/new-projet` and `demos/FMX/new-projet`. |
| WebView2 Runtime | Microsoft Edge WebView2 Evergreen Runtime installed or deployable on the target machine. |
| WebView4Delphi | The repository contains a bundled copy under `dependencies/WebView4Delphi/source`, useful for demos and quick discovery. For real application work, clone the official WebView4Delphi repository and add that source path to the Delphi project. |
| Platform | Windows x86 / x64 — binaries conventionally produced in `bin32` / `bin64`. |
| Secret storage | Default implementation through `Windows.ApiKey.Management.pas`; applications may replace the backend via `ISecretStore`. |
| JSON | `System.JSON` plus the framework helpers such as `WVPythia.JSON.SafeReader.pas`. |

You do **not** need npm, Node.js, Python, Docker, or a web build chain to use the shipped interface. The JavaScript layer is already bundled in `assets/`.

<br>

## 6 Installation & first build

The recommended way to start is **not** to create a Delphi project from scratch. The recommended path is to clone one of the minimal starter project patterns provided with the repository:

```
<Pythia-Webview2>\demos\VCL\new-projet
```

or:

```
<Pythia-Webview2>\demos\FMX\new-projet
```

Use the first one for a **VCL** application and the second one for an **FMX** application. These starter projects already contain the expected structure, the browser setup, and the ready-to-use service unit:

```
VCL.WVPythia.Services.pas
```

or:

```
FMX.WVPythia.Services.pas
```

Starting from these templates avoids the most common setup errors: missing `ServiceAdapter`, incorrect output folder, missing `assets`, or missing `WebView2Loader.dll`.

A fully manual setup from an empty Delphi project is still possible, but it should be treated as an advanced path used mainly to understand the wiring.

### 6.1 Clone the starter project pattern

Copy the matching folder, then rename the folder, the Delphi project, and the files as needed for your application.

```
<Pythia-Webview2>\demos\VCL\new-projet
<Pythia-Webview2>\demos\FMX\new-projet
```

### 6.2 Define IDE environment variables

In Delphi, open:

```
Tools → Options → IDE → Environment Variables
```

Create a variable pointing to the Pythia-Webview2 repository:

```
PYTHIA = C:\Path\To\Pythia-Webview2
```

It is also recommended to clone the official WebView4Delphi repository and create a second variable:

```
WEBVIEW4DELPHI = C:\Path\To\WebView4Delphi
```

### 6.3 Configure the project search paths

In:

```
Project → Options → Building → Delphi Compiler → Search path
```

add at least:

```
$(PYTHIA)\source
$(WEBVIEW4DELPHI)\source
```

The bundled WebView4Delphi path can be used for demos and quick discovery:

```
$(PYTHIA)\dependencies\WebView4Delphi\source
```

For a real application, prefer the official WebView4Delphi clone.

### 6.4 Configure output folders

Pythia-Webview2 resolves several paths from the executable location. Keep a consistent structure around `bin32`, `bin64`, and `assets`.

Use:

```
..\bin32
```

for Win32, or:

```
..\bin64
```

for Win64.

Set the DCU output directory to:

```
..\dcu
```

During early development, compiling directly into the Pythia-Webview2 repository folders is also possible:

```
$(PYTHIA)\bin32
$(PYTHIA)\bin64
```

This is convenient because `WebView2Loader.dll` and `assets` are already in the expected layout.

### 6.5 Check `WebView2Loader.dll`

`WebView2Loader.dll` must be placed next to the executable and must match the target architecture.

For Win32:

```
$(PYTHIA)\bin32\WebView2Loader.dll
```

For Win64:

```
$(PYTHIA)\bin64\WebView2Loader.dll
```

Without this file, the application may start, but WebView2 will not initialize correctly.

### 6.6 Check the `assets` folder

The `assets` folder must be available at the same level as `bin32` and `bin64`.

Recommended structure:

```
MyProject
├── assets
│   ├── index.htm
│   ├── scripts
│   ├── media
│   └── lang
├── bin32
│   ├── MyProject.exe
│   └── WebView2Loader.dll
├── bin64
│   ├── MyProject.exe
│   └── WebView2Loader.dll
└── dcu
```

For deployment, ship your own complete copy of `assets` with your executable.

<br>

## 7 Recommended start — from the starter project pattern

The first goal is not merely to display a WebView. The first goal is to run a minimal Pythia-Webview2 project whose browser surface and Delphi event chain are already wired.

### 7.1 Open the starter project

Open the project copied from:

```
<Pythia-Webview2>\demos\VCL\new-projet
```

or:

```
<Pythia-Webview2>\demos\FMX\new-projet
```

The starter project already contains:

- the Delphi host application;
- the WebView2-backed chat surface;
- the browser setup;
- the service adapter unit;
- the expected output structure;
- the support folder generation path.

### 7.2 Minimal VCL wiring

The essential VCL ordering is:

```pascal
uses
  VCL.WVPythia.Chat,
  WVPythia.Types,
  VCL.WVPythia.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel2);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.Update;
end;
```

### 7.3 Minimal FMX wiring

The essential FMX ordering is:

```pascal
uses
  FMX.WVPythia.Chat,
  WVPythia.Types,
  FMX.WVPythia.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TFMXPythia.Create(Layout1);
  Pythia.AttachHost(Self);
  Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;
  Pythia.Update;
end;
```

The order is critical:

```
Create browser
Attach host if FMX
Assign ServiceAdapter
Call Update
```

If the adapter is missing, or if it is assigned after `Update`, the UI can render but prompt submissions and other browser events will not reach Delphi code.

### 7.4 Run the project

Press F9.

You should see:

- the form opens;
- the WebView2 host warms up;
- the Pythia-Webview2 chat interface appears;
- the input bar is visible at the bottom;
- prompt submission reaches the service adapter.

Depending on the starter behavior, the adapter may display a diagnostic response, a JSON dump, or a placeholder result. Replacing that diagnostic behavior with a real vendor call is covered in §16.

### 7.5 First-launch support folder

On first launch, Pythia-Webview2 creates an application support folder such as:

```
bin32\MyProject\support
```

or:

```
bin64\MyProject\support
```

This folder contains generated or pre-filled JSON configuration files: capabilities, model list, runtime category configuration, cards, and other support files.

>[!IMPORTANT]
>
>After creating the `TVCLPythia` or `TFMXPythia` instance and wiring the required initialization code, it is recommended to run the application once as early as possible.
>
>This first execution lets **Pythia-Webview2** create the application support folder and generate the initial **JSON** configuration files. From that point on, you can inspect, pre-fill, or replace those files with your application-specific configuration instead of working against a folder structure that does not exist yet.

<br>

## 8 Exhaustive instantiation — overview of hooks and options

The recommended starter projects give you the minimal correct wiring. A production application then adds optional panels, lifecycle hooks, capability configuration, and vendor-specific initialization.

Three families of customization points coexist:

- **state properties** such as `CustomPanels` and `EnabledButtons`, which enable or delegate parts of the UI;
- **the service adapter** through `ServiceAdapter`, which is the boundary between WebView2 events and application logic;
- **lifecycle hooks** such as `OnBrowserCreated`, `OnThemeChanged`, `OnTranslationsLoaded`, `OnRenderChatContent`, `OnApiKeyChanged`, `OnChatSessionAutoRename`, and `OnRegisterCommandPlugins`.

The call to `Update` must remain last. It starts the WebView2 bootstrap and may immediately consume the values configured on the component.

<br>

- [VCL skeleton](#vcl-skeleton)
- [FMX skeleton](#fmx-skeleton)
- [Recap](#recap)
- [Service adapter — already present in the starter projects](#service-adapter--already-present-in-the-starter-projects)
  - [Why the adapter is mandatory](#why-the-adapter-is-mandatory)
  - [What the unit contains](#what-the-unit-contains)
  - [The link with Pythia.ServiceAdapter](#the-link-with-webbrowserserviceadapter)
  - [When to use pythia-sample or pythia-anthropic](#when-to-use-pythia-sample-or-pythia-anthropic)
  - [Recommended approach for a new project](#recommended-approach-for-a-new-project)

<br>

### VCL skeleton

```pascal
uses
  VCL.WVPythia.Chat, WVPythia.Types, WVPythia.Adapter;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {--- Component creation. The parent (Panel2) must exist at this point
       and will host the WebView2 host. }
  Pythia := TVCLPythia.Create(Panel2);

  {--- Disables default rendering for the following panels: the host
       application provides its own implementation.
       cpCards    : card management panel (MCP, function, skill, agent)
       cpModels   : model selector
       cpSettings : settings panel (temperature, top-p, system prompt, etc.)
       Union with the current value lets you cumulate with the defaults. }
  Pythia.CustomPanels :=
    Pythia.CustomPanels + [cpCards, cpModels, cpSettings];

  {--- Enables optional buttons in the input bar:
       ebSettings   : shortcut to open the settings panel
       ebMicrophone : audio input (not enabled here) }
  Pythia.EnabledButtons :=
    Pythia.EnabledButtons + [ebSettings];

  {--- Application adapter implementing IChatManagedItemDialogService
       (WVPythia.Adapter.pas). Targets: item selection (cards),
       message or code copy, session creation, and most importantly
       reception of JS custom-events via ActivateCustomEvent.
       TChatManagedItemDialogService is a class that the host
       application must provide. }
  Pythia.ServiceAdapter := TMyChatManagedItemDialogService.Create;

  Pythia.OnBrowserCreated :=
    procedure
    begin
      {--- Called once, after WebView2 initialization and the initial
           navigation (VCL.WVPythia.Chat.pas).
           Entry point for post-init configuration that requires the
           WebView instance to be ready: cookie placement, telemetry,
           global script injection, first ExecuteScript. }
    end;

  Pythia.OnThemeChanged :=
    procedure
    begin
      {--- Triggered when a look-and-feel change is applied through
           the settings panel (VCL.WVPythia.Chat.pas).
           Synchronize here the host application's chrome — window
           colors, toolbars, icons — with the theme selected in the
           chat. }
    end;

  Pythia.OnTranslationsLoaded :=
    procedure
    begin
      {--- Called after every dictionary reload, right after the
           native S_… strings of WVPythia.Strs have been retranslated
           (WVPythia.Strs.pas). This is where the host application's
           custom-string retranslation belongs (see §24 — custom
           section of the language JSON). }
    end;

  Pythia.OnRenderChatContent :=
    function: Boolean
    begin
      {--- Lets the host intercept chat-content rendering before the
           standard pipeline runs (VCL.WVPythia.Chat.pas).
           Return True to short-circuit the default rendering, False
           to let Pythia-Webview2 continue. Use case: inject a dynamic
           welcome screen or restore an archived session with
           specific rendering. }
      Result := False;
    end;

  Pythia.OnApiKeyChanged :=
    procedure (Value: string)
    begin
      {--- Called after creation, modification, or deletion of an
           API key via /api-key new|delete (VCL.WVPythia.Chat.pas).
           Value = normalized name (Trim + lowercase). Use this hook
           to invalidate cached vendor clients, rebuild services
           that consume the key, update the host UI that reflects
           the connection state. }
    end;

  Pythia.OnChatSessionAutoRename :=
    procedure (Value1, Value2: string)
    begin
      {--- Triggered when the session controller requests an
           automatic title for a new conversation
           (VCL.WVPythia.Chat.pas).
           Value1 = session ID
           Value2 = textual content to use as a naming reference
           Call the LLM to generate a short title, then persist it
           via Pythia.SessionAutoRename(Value1, NewTitle). }
    end;

  Pythia.OnRegisterCommandPlugins :=
    procedure
    begin
      {--- Called during CommandLineInitialize, after the automatic
           registration of TApiKeyPlugin (VCL.WVPythia.Chat.pas).
           Plug in the application's business command plugins here
           via Pythia.CommandLine.RegisterPlugin(...) — see §12
           for the custom plugin skeleton. }
    end;

  {--- Optional vendor-provided service called when a file is selected through
         the open dialog. Set it from the host bootstrap to enable remote file
         transfer (Files API and similar). When unset, files keep flowing through
         the existing inline pipeline unchanged. }
  Pythia.FileUploadService := "instance of" IFileUploadService; 

  {--- Optional vendor-provided service invoked when a TOpenFileTarget.Knowledge
         file is selected. Set it from the host bootstrap to enable remote
         vectorization (vector store, semantic retrieval corpus, libraries, …)
         and reference indexed files at submit time through TryGetIndexRef.
         When unset, knowledge files remain in the compose box but are not
         processed asynchronously. }
  Pythia.KnowledgeIndexingService := "instance of" IKnowledgeIndexingService;  

  Pythia.OnInitialized :=
    procedure
    begin
      {--- Called after the complete chat runtime initialization
           (VCL.WVPythia.Chat.pas).
           At this point WebView2 is created, the page has emitted "ready",
           the JS templates have been injected, capabilities/settings/model
           list/session drawer have been synchronized, enabled buttons have
           been applied, and the input surface has been focused.

           This is the safe post-init hook for actions that require the
           Pythia-Webview2 chat UI to be operational: first prompt/display,
           late host synchronization, service refresh, or custom JS relying
           on the injected runtime.

           Difference with OnBrowserCreated:
           OnBrowserCreated only means that the native WebView2 instance
           exists and initial navigation has started. OnInitialized means
           that the chat bridge and UI runtime are ready. }
    end;

  {--- Starts the WebView2 bootstrap. Must be called last, after every
       property and hook has been assigned. }
  Pythia.Update;
end;
```

### FMX skeleton

```pascal
uses
  FMX.WVPythia.Chat, WVPythia.Types, WVPythia.Adapter;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {--- Component creation: the parent (Layout1) will host the FMX-
       specific WebView2 host. }
  Pythia := TFMXPythia.Create(Layout1);

  {--- Mandatory link between the component and the FMX form.
       FMX-specific: without this call, the WebView host cannot
       attach itself to the FireMonkey rendering cycle. }
  Pythia.AttachHost(Self);

  {--- Disables default rendering for the following panels: the host
       application provides its own implementation.
       cpCards    : card management panel (MCP, function, skill, agent)
       cpModels   : model selector
       cpSettings : settings panel (temperature, top-p, system prompt, etc.) }
  Pythia.CustomPanels :=
    Pythia.CustomPanels + [cpCards, cpModels, cpSettings];

  {--- Enables optional buttons in the input bar:
       ebSettings   : shortcut to open the settings panel
       ebMicrophone : audio input (not enabled here) }
  Pythia.EnabledButtons :=
    Pythia.EnabledButtons + [ebSettings];

  {--- Application adapter implementing IChatManagedItemDialogService
       (WVPythia.Adapter.pas). Targets: item selection (cards),
       message or code copy, session creation, and most importantly
       reception of JS custom-events via ActivateCustomEvent.
       TChatManagedItemDialogService is a class that the host
       application must provide. }
  Pythia.ServiceAdapter := TMyChatManagedItemDialogService.Create;

  Pythia.OnBrowserCreated :=
    procedure
    begin
      {--- Called once, after WebView2 initialization and the initial
           navigation. Entry point for post-init configuration that
           requires the WebView instance to be ready: cookie placement,
           telemetry, global script injection, first ExecuteScript. }
    end;

  Pythia.OnThemeChanged :=
    procedure
    begin
      {--- Triggered when a look-and-feel change is applied through
           the settings panel. Synchronize here the host application's
           chrome — window colors, toolbars, icons — with the theme
           selected in the chat. }
    end;

  Pythia.OnTranslationsLoaded :=
    procedure
    begin
      {--- Called after every dictionary reload, right after the
           native S_… strings of WVPythia.Strs have been retranslated.
           This is where the host application's custom-string
           retranslation belongs (see §24 — custom section of the
           language JSON). }
    end;

  Pythia.OnRenderChatContent :=
    function: Boolean
    begin
      {--- Lets the host intercept chat-content rendering before the
           standard pipeline runs. Return True to short-circuit the
           default rendering, False to let Pythia-Webview2 continue. Use case:
           inject a dynamic welcome screen or restore an archived
           session with specific rendering. }
      Result := False;
    end;

  Pythia.OnApiKeyChanged :=
    procedure (Value: string)
    begin
      {--- Called after creation, modification, or deletion of an API key
           via /api-key new|delete. Value = normalized name (Trim + lowercase).
           Use this hook to invalidate cached vendor clients, rebuild
           services that consume the key, update the host UI that
           reflects the connection state. }
    end;

  Pythia.OnChatSessionAutoRename :=
    procedure (Value1, Value2: string)
    begin
      {--- Triggered when the session controller requests an automatic
           title for a new conversation.
           Value1 = session ID
           Value2 = textual content to use as a naming reference
           Call the LLM to generate a short title, then persist it
           via Pythia.SessionAutoRename(Value1, NewTitle). }
    end;

  Pythia.OnRegisterCommandPlugins :=
    procedure
    begin
      {--- Called during CommandLineInitialize, after the automatic
           registration of TApiKeyPlugin. Plug in the application's
           business command plugins here via
           Pythia.CommandLine.RegisterPlugin(...) — see §12 for
           the custom plugin skeleton. }
    end;

  {--- Optional vendor-provided service called when a file is selected through
         the open dialog. Set it from the host bootstrap to enable remote file
         transfer (Files API and similar). When unset, files keep flowing through
         the existing inline pipeline unchanged. }
  Pythia.FileUploadService := "instance of" IFileUploadService; 

  {--- Optional vendor-provided service invoked when a TOpenFileTarget.Knowledge
         file is selected. Set it from the host bootstrap to enable remote
         vectorization (vector store, semantic retrieval corpus, libraries, …)
         and reference indexed files at submit time through TryGetIndexRef.
         When unset, knowledge files remain in the compose box but are not
         processed asynchronously. }
  Pythia.KnowledgeIndexingService := "instance of" IKnowledgeIndexingService;  

  Pythia.OnInitialized :=
    procedure
    begin
      {--- Called after the complete chat runtime initialization
           (VCL.WVPythia.Chat.pas).
           At this point WebView2 is created, the page has emitted "ready",
           the JS templates have been injected, capabilities/settings/model
           list/session drawer have been synchronized, enabled buttons have
           been applied, and the input surface has been focused.

           This is the safe post-init hook for actions that require the
           Pythia-Webview2 chat UI to be operational: first prompt/display,
           late host synchronization, service refresh, or custom JS relying
           on the injected runtime.

           Difference with OnBrowserCreated:
           OnBrowserCreated only means that the native WebView2 instance
           exists and initial navigation has started. OnInitialized means
           that the chat bridge and UI runtime are ready. }
    end;

  {--- Starts the WebView2 bootstrap. Must be called last, after every
       property and hook has been assigned. }
  Pythia.Update;
end;
```

### Recap

| Component | Family | Type | Role |
|---|---|---|---|
| `CustomPanels` | UI state | `TCustomPanels` set | Delegates Settings / Models / Cards panels to the host application. |
| `EnabledButtons` | UI state | `TEnabledButtons` set | Enables optional buttons such as Settings or Microphone. |
| `ServiceAdapter` | Application boundary | `IChatManagedItemDialogService` | Routes prompts, selections, copies, custom events, and application actions toward Delphi logic. |
| `OnBrowserCreated` | Lifecycle | `TProc` | Post-initialization WebView2 hook. |
| `OnThemeChanged` | Lifecycle | `TProc` | Reacts to look-and-feel changes. |
| `OnTranslationsLoaded` | Lifecycle | `TProc` | Reloads host custom translations after dictionary loading. |
| `OnRenderChatContent` | Lifecycle | `TFunc<Boolean>` | Lets the host intercept chat-content rendering. |
| `OnApiKeyChanged` | Lifecycle | `TProc<string>` | Notifies key creation, modification, or deletion. |
| `OnChatSessionAutoRename` | Lifecycle | `TProc<string,string>` | Requests a generated title for a session. |
| `OnRegisterCommandPlugins` | Lifecycle | `TProc` | Registers business slash-command plugins. |
| `ApiKeySecretStore` | Application boundary | `ISecretStore` | Reads, writes, and deletes API key values. |
| `OnInitialized` | Lifecycle | `TProc` | Runs after the complete chat runtime initialization; safe hook for actions requiring the WebView2 chat UI, bridge, templates, capabilities/settings/models, buttons, and input surface to be ready. |

### Service adapter — already present in the starter projects

The assignment:

```pascal
Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
```

or:

```pascal
Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;
```

is not cosmetic. It is the routing layer that lets the WebView2 event pipeline reach the application code.

The official `new-projet` starter patterns already include the matching service unit:

```
VCL.WVPythia.Services.pas
FMX.WVPythia.Services.pas
```

You normally adapt that unit. You do not need to copy the adapter from `pythia-sample` when starting from `new-projet`.

#### Why the adapter is mandatory

The component knows the outside world through `IChatManagedItemDialogService`. Prompt submission, message copy, code-block copy, card selection, settings requests, audio input, new-chat events, and `custom-event` messages are all routed through this interface.

If the adapter is missing, or assigned after `Update`, the interface may render but the downstream event chain is unavailable. A typical diagnostic is:

```
DialogService not assigned
```

Typical causes are:

- `ServiceAdapter` was not assigned;
- `ServiceAdapter` was assigned after `Pythia.Update`;
- the service unit exists on disk but was not added to the Delphi project;
- the VCL service unit was used in an FMX project, or the reverse;
- abstract methods were not overridden when a custom adapter was written manually.

#### What the unit contains

The service unit usually contains two complementary types.

**1. An adapter class** — by convention `TVCLChatManagedItemDialogService` or `TFMXChatManagedItemDialogService` — inheriting from `TCustomChatManagedItemDialogService`. The parent class implements the common interface; the project-specific class overrides the `Do...` methods needed by the application.

**2. A static-method container** — by convention `TToolContainer` — that hosts the routing/business entry points. The adapter remains thin and delegates to this container.

#### The link with `Pythia.ServiceAdapter`

Once assigned before `Update`, the chain becomes:

```
WebView2 DOM
   │
   └── postMessage
          │
          ▼
TBrowserEventManager
          │
          ▼
ServiceAdapter
          │
          ▼
TToolContainer / application service methods
          │
          ▼
Business logic / vendor service
```

The adapter should remain a routing layer, not the place where SDK-specific logic accumulates.

#### When to use `pythia-sample` or `pythia-anthropic`

The sample projects remain useful references:

- `demos\VCL\pythia-sample\VCL.WVPythia.Services.pas` is a diagnostic skeleton for understanding event routing;
- `demos\VCL\pythia-anthropic\VCL.WVPythia.Services.pas` shows a real vendor wiring through `AnthropicVendor: IVendorServices`.

Use them as references, or copy one manually only if you deliberately started from an empty Delphi project or want to replace the starter service unit with a more specific implementation.

#### Recommended approach for a new project

The recommended approach is to start from the official starter pattern, not from a copied sample adapter and not from an empty Delphi project. The `pythia-sample` and `pythia-anthropic` projects remain useful references, but they are not the normal starting point for a new application.

The normal sequence is the following.

**1. Clone the project pattern**

Copy the folder that matches your framework:

```
<Pythia-Webview2>\demos\VCL\new-projet
```

or:

```
<Pythia-Webview2>\demos\FMX\new-projet
```

Use the first one for a VCL application and the second one for an FMX application. Then rename the folder, the Delphi project, and the files as needed for your application.

The `new-projet` templates are intended to be minimal starting points for applications based on Pythia-Webview2. They already contain the expected structure, the browser setup, and the ready-to-use service unit:

```
VCL.WVPythia.Services.pas
```

or:

```
FMX.WVPythia.Services.pas
```

Starting from these templates avoids the common setup issues: missing `ServiceAdapter`, incorrect output folder, missing `assets`, or missing `WebView2Loader.dll`.

**2. Define IDE environment variables in Delphi**

In Delphi, open:

```
Tools → Options → IDE → Environment Variables
```

Create a variable pointing to the Pythia-Webview2 repository:

```
PYTHIA = C:\Path\To\Pythia-Webview2
```

It is also recommended to clone the official WebView4Delphi repository and create a second variable:

```
WEBVIEW4DELPHI = C:\Path\To\WebView4Delphi
```

These variables let the project use portable paths such as:

```
$(PYTHIA)\source
$(WEBVIEW4DELPHI)\source
```

This makes the project easier to move between machines or folders without rewriting all paths manually.

**3. Configure the project search paths**

In the Delphi project options, open:

```
Project → Options → Building → Delphi Compiler → Search path
```

Add at least:

```
$(PYTHIA)\source
$(WEBVIEW4DELPHI)\source
```

Pythia-Webview2 also includes a copy of WebView4Delphi under:

```
$(PYTHIA)\dependencies\WebView4Delphi\source
```

This bundled path is useful for compiling demos quickly and for first discovery. For a real project, prefer the official WebView4Delphi clone:

```
$(WEBVIEW4DELPHI)\source
```

If WebView4Delphi code is redistributed with your project or kept in your repository, preserve the original license and copyright notices in the corresponding third-party files.

**4. Configure the output directory**

Pythia-Webview2 resolves several paths from the executable location. Keep a consistent folder structure around `bin32`, `bin64`, and `assets`.

In:

```
Project → Options → Building → Delphi Compiler → Output directory
```

use:

```
..\bin32
```

for a Win32 target, or:

```
..\bin64
```

for a Win64 target.

Set the DCU output directory to:

```
..\dcu
```

During early development, you may also compile directly into the Pythia-Webview2 repository folders:

```
$(PYTHIA)\bin32
```

or:

```
$(PYTHIA)\bin64
```

This can be useful because `WebView2Loader.dll` and the `assets` folder are already available in the expected structure. For a standalone application, keep your own project structure and copy the required files into it.

**5. Check that `WebView2Loader.dll` is present**

`WebView2Loader.dll` must be placed next to the executable and must match the target architecture.

For a 32-bit application, copy:

```
$(PYTHIA)\bin32\WebView2Loader.dll
```

to:

```
<MyProject>\bin32\WebView2Loader.dll
```

For a 64-bit application, copy:

```
$(PYTHIA)\bin64\WebView2Loader.dll
```

to:

```
<MyProject>\bin64\WebView2Loader.dll
```

Without this file, the application may start, but WebView2 will not initialize correctly.

**6. Check the `assets` folder**

The `assets` folder must be available at the same level as `bin32` and `bin64`.

Recommended structure:

```
MyProject
├── assets
│   ├── index.htm
│   ├── scripts
│   ├── media (empty)
│   └── lang
├── bin32
│   ├── MyProject.exe
│   └── WebView2Loader.dll
├── bin64
│   ├── MyProject.exe
│   └── WebView2Loader.dll
└── dcu
```

The `assets` folder contains the HTML interface, JavaScript scripts, media folder, and language files used by Pythia-Webview2. Copy it as a complete folder.

If you compile directly into:

```
$(PYTHIA)\bin32
```

or:

```
$(PYTHIA)\bin64
```

you can rely on:

```
$(PYTHIA)\assets
```

during development, without copying the assets into your own project immediately. For deployment, ship your own copy of the `assets` folder with your executable.

**7. Install or verify the Microsoft WebView2 Evergreen Runtime**

There are two separate elements to keep in mind:

```
WebView2Loader.dll
```

and the Microsoft Edge WebView2 Runtime.

`WebView2Loader.dll` is the DLL loaded by your application. The WebView2 Runtime is the Microsoft Edge-based runtime used to render the web interface.

The target machine must have the Microsoft Edge WebView2 Evergreen Runtime installed. On recent Windows versions, it is often already present with Microsoft Edge. If it is not present, install it separately.

The Evergreen Runtime is the recommended deployment mode for most applications because it is installed on the machine and updated automatically by Microsoft. The official Microsoft download page provides the Evergreen Bootstrapper, the Evergreen Standalone Installer, and x86, x64, and ARM64 versions.

**8. Recommended final structure**

For a standalone project, the expected structure is:

```
MyProject
├── assets
│   ├── index.htm
│   ├── scripts
│   ├── media (empty)
│   └── lang
├── bin32
│   ├── MyProject.exe
│   └── WebView2Loader.dll
├── bin64
│   ├── MyProject.exe
│   └── WebView2Loader.dll
├── dcu
├── Main.pas
├── Main.dfm or Main.fmx
├── VCL.WVPythia.Services.pas
│   or
├── FMX.WVPythia.Services.pas
└── MyProject.dproj
```

On first launch, Pythia-Webview2 creates the application support folder, for example:

```
bin32\MyProject\support
```

or:

```
bin64\MyProject\support
```

This folder contains the generated or pre-filled JSON configuration files: capabilities, model list, category configuration, cards, and other support files. These files can be pre-populated before deployment so the application starts with a controlled configuration.

**Summary**

To start as simply as possible:

1. Copy `demos\VCL\new-projet` or `demos\FMX\new-projet`.
2. Rename the project for your application.
3. Create a `PYTHIA` IDE environment variable pointing to the Pythia-Webview2 repository.
4. Clone the official WebView4Delphi repository.
5. Create a `WEBVIEW4DELPHI` IDE environment variable pointing to that repository.
6. Configure the Search path with `$(PYTHIA)\source` and `$(WEBVIEW4DELPHI)\source`.
7. Configure the Output directory as `..\bin32` or `..\bin64`.
8. Make sure `WebView2Loader.dll` is next to the executable.
9. Make sure the `assets` folder is available at the correct level.
10. Make sure the Microsoft Edge WebView2 Evergreen Runtime is installed.
11. Verify that `ServiceAdapter` is assigned before `Update`.
12. Run the project and then replace the diagnostic behavior in `TToolContainer.ActivateInputState` with a real vendor call.

By starting from the `new-projet` templates, you get a clean baseline for integrating Pythia-Webview2 while keeping full control over paths, dependencies, and deployment structure.

<br>

## 9 API key configuration

### Introduction

API key management is built natively into **Pythia-Webview2** as a preinstalled command plugin. The end user can manage keys directly from the chat input bar, and the application can also trigger the same command flow programmatically when a vendor service starts and detects that its key is missing.

The implementation rests on four units:

- `WVPythia.Command.Plugin.ApiKey.pas` — command plugin (`TApiKeyPlugin`);
- `WVPythia.ApiKey.Service.Intf.pas` — `IApiKeyService` contract and `TApiKeyOperationResult`;
- `WVPythia.ApiKey.Service.pas` — default service (`TApiKeyService`);
- `Windows.ApiKey.Management.pas` — default secret store (`TSecretStore`).

<br>

- [User surface in the chat](#user-surface-in-the-chat)
- [Actual signatures](#actual-signatures)
- [Rules](#rules)
- [Custom security policy](#custom-security-policy)
- [Vendor-owned key name](#vendor-owned-key-name)
- [Automatic first-run API-key request](#automatic-first-run-api-key-request)
- [Delphi-side usage](#delphi-side-usage)

<br>

### User surface in the chat

```
/api-key new    <name>   → opens a hidden input, stores the secret
/api-key delete <name>   → removes the secret + JSON entry
/api-key exists <name>   → reports presence
```

For example:

```
/api-key new anthropic
```

### Actual signatures

Declared in `WVPythia.ApiKey.Service.Intf.pas`:

```pascal
IApiKeyService = interface
  ['{A7C3E812-4D5F-4B91-8E2A-9F6B3C7D1E40}']
  function GetBrowser: IPythiaBrowser;
  procedure SetBrowser(const Value: IPythiaBrowser);
  function CreateKey(const AName: string): TApiKeyOperationResult;
  function DeleteKey(const AName: string): TApiKeyOperationResult;
  function Exists(const AName: string): Boolean;
  property Browser: IPythiaBrowser read GetBrowser write SetBrowser;
end;
```

`TApiKeyOperationResult` is a record with two fields, `Success: Boolean` and `Message: string`, plus two class constructors `Ok` and `Fail`. There is no `IsOk` property.

### Rules

An API key is identified by a logical name, not by its value.

- Names are normalized: `Trim.ToLowerInvariant`.
- `Anthropic` is therefore equivalent to `anthropic`.
- The name is persisted in a tracking JSON file.
- The secret value is read and written through `IPythiaBrowser.ApiKeySecretStore` (`ISecretStore`).
- After any mutation, `IPythiaBrowser.ApiKeyValuesUpdate` notifies UI consumers.

### Custom security policy

`TApiKeyService` never needs to access the Windows Registry directly. Reads and writes go through `FBrowser.ApiKeySecretStore`, which holds an `ISecretStore` implementation.

```pascal
ISecretStore = interface
  ['{0828CA5A-491F-41E5-B127-9037F22CCF79}']
  function ReadSecret(const Name: string; out Value: string;
    const ParamProc: TProc<string> = nil): Boolean;
  procedure WriteSecret(const Name, Value: string);
  procedure DeleteSecret(const Name: string);
end;
```

`ApiKeySecretStore` is a public property on `TFMXPythia` / `TVCLPythia`, initialized to the default store in the constructor. To substitute another backend, implement `ISecretStore` and assign it before `Update`:

```pascal
uses WVPythia.Chat.Interfaces;

Pythia.ApiKeySecretStore := TMySecretStore.Create;
Pythia.Update;
```

### Vendor-owned key name

A vendor service should own the logical key name it uses. Do not duplicate this string across the application.

For Anthropic, define the key name on the service class:

```pascal
TAnthropicServices = class(TInterfacedObject, IVendorServices)
const
  API_KEY_NAME = 'anthropic';
private
  FClient: IAnthropic;
  FBrowser: IPythiaBrowser;
public
  constructor Create(const ABrowser: IPythiaBrowser);
  procedure UpdateApiKey;
end;
```

The value `anthropic` is the name used by the browser secret store. Keep it consistent everywhere the Anthropic service reads, creates, or refreshes the key.

### Automatic first-run API-key request

The user should not be forced to type `/api-key new anthropic` manually on first launch. A vendor service can trigger the same command automatically when it starts and the key does not already exist:

```pascal
constructor TAnthropicServices.Create(const ABrowser: IPythiaBrowser);
var
  Anthropic_key: string;
begin
  FBrowser := ABrowser;

  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
    FBrowser.TryHandleAsCommand(Format('/api-key new %s', [API_KEY_NAME]));

  FClient := TAnthropicFactory.CreateInstance(Anthropic_key);
end;
```

When the key is added or changed, reload the SDK client from the same constant:

```pascal
procedure TAnthropicServices.UpdateApiKey;
var
  Anthropic_key: string;
begin
  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
    begin
      FClient.API.Token := '';
      Exit;
    end;

  FClient.API.Token := Anthropic_key;
  FBrowser.DisplaySuccess('Anthropic client is up to date.');
end;
```

A typical host-side wiring is:

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel2);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.OnApiKeyChanged := UpdateApiKey;
  Pythia.Update;
end;

procedure TForm1.UpdateApiKey(KeyName: string);
begin
  if SameText(KeyName, TAnthropicServices.API_KEY_NAME) then
    AnthropicVendor.UpdateApiKey;
end;
```

### Delphi-side usage

`TApiKeyPlugin` is registered automatically by the component during command-line initialization. The slash-command surface requires no modification, but vendor services should still own their key name and refresh their SDK client through `OnApiKeyChanged`.

<br>

## 10 Slash command system

The command layer defines a native extension point for the browser: it allows you to associate textual commands of the form `/command action` with explicitly declared Delphi handlers, validated by the registry, then executed by dedicated plugins.

### Syntax

```
/command-name action [arg1] [arg2] ...
```

### Cycle

```
parse (TCommandParser)
  → validate (TCommandRegistry)
  → execute (TCommandPlugin.DoExecute)
```

### Validation statuses

- `csNotACommand`
- `csOk`
- `csUnknownCommand`
- `csUnknownAction`
- `csWrongArgCount`

### Error policy

`Execute` wraps `DoExecute` in a `try/except` block.

- Expected failure: `TCommandExecResult.Fail(...)`.
- Unexpected exception: automatically converted into a failure result.

When user input is not a command, that is `csNotACommand`, the framework falls back on the standard prompt flow. There is nothing to handle on the developer side.

<br>

## 11 Loading UI templates

### Introduction

The chat interface is not a monolithic rendering: it is composed from **one root HTML file and 22 JavaScript files** injected into WebView2. Loading is driven by `ITemplateProvider` (`WVPythia.Template.Manager.pas`).

<br>

- [Locations](#locations)
- [TTemplateType enumeration (23 entries)](#ttemplatetype-enumeration-23-entries)
- [Two loading strategies](#two-loading-strategies)
- [Replacing a template without recompiling](#replacing-a-template-without-recompiling)
- [Conventions observed in the shipped templates](#conventions-observed-in-the-shipped-templates)

<br>

### Locations

```
assets/index.htm              ← HTML skeleton (main_html)
assets/scripts/*.js           ← 22 JS templates (PromptTemplate, DisplayTemplate, ...)
```

### `TTemplateType` enumeration (23 entries)

Defined in `WVPythia.Template.Manager.pas`. Each value is mapped to a file via `FileNames` (`WVPythia.Template.Manager.pas`).

### Two loading strategies

`ITemplateProvider` exposes two methods (`WVPythia.Template.Manager.pas`):

|Method|Effect|
|-|-|
|`TemplateAllwaysReloading(APath)`|Reads the file from disk **on every access**. Dev mode: JS edits are picked up without recompilation. Note: the original name preserves the typo "Allways".|
|`TemplateNeverReloading`|Loads once, keeps in memory. Production mode.|

> The dev notes (`WVPythia.Template.Manager.pas`) state: "no advanced caching logic — goal = clarity & simplicity for the community".

### Replacing a template without recompiling

```pascal
Provider.LoadCustomTemplate('scripts\MyPromptTemplate.js');
```

`LoadCustomTemplate` (`WVPythia.Template.Manager.pas`) lets you substitute a template with an alternative file. Combined with `TemplateAllwaysReloading`, this is the lightest UI extension point — edit a JS file, restart the app, see the result.

### Conventions observed in the shipped templates

The shipped templates are simple JavaScript fragments loaded into the same WebView context. They must therefore stay self-contained, limit global exports, and only publish on `window` the APIs that are deliberately shared. The framework does not validate their internal structure; it only observes the messages sent to the WebView2 bridge.

The following patterns are **observed** in the 22 shipped templates, not enforced by the framework:

- IIFE `(() => { ... })();` to encapsulate local state.
- Internationalization via `window.AppI18n.t('key')` — exposed by `BootstrapDictionaryTemplate.js`.
- Event emission via `window.chrome.webview.postMessage({event, ...})`.

The only contract truly enforced by Delphi is: **all communication toward the Pascal code goes through `window.chrome.webview.postMessage`**. The rest is the template author's freedom.

<br>

## 12 Writing a custom command plugin

### Skeleton

Modeled on `TApiKeyPlugin` (`WVPythia.Command.Plugin.ApiKey.pas`):

```pascal
type
  TMyPlugin = class(TCommandPlugin)
  strict private
    FService: IMyService;
  strict protected
    function DoExecute(const Action: string;
      const Args: TArray<string>): TCommandExecResult; override;
  public
    constructor Create(const AService: IMyService);
  end;

constructor TMyPlugin.Create(const AService: IMyService);
begin
  inherited Create('my-command');        // slash name → /my-command
  FService := AService;
  AddAction('run',    1, 1);             // AddAction(name, minArgs, maxArgs)
  AddAction('status', 0, 0);
end;

function TMyPlugin.DoExecute(const Action: string;
  const Args: TArray<string>): TCommandExecResult;
begin
  if Action = 'run' then
    Result := TCommandExecResult.Ok(FService.Run(Args[0]))
  else if Action = 'status' then
    Result := TCommandExecResult.Ok('running')
  else
    Result := TCommandExecResult.Fail('Unmanaged action');
end;
```

### Verified signatures

The skeleton above corresponds to the form expected by the registry. Command validation rests on the actions declared in the constructor; `DoExecute` should therefore only contain the execution logic for actions already announced by `AddAction`.

- `TCommandPlugin` inherits from `TCommandSpec` — `Create(AName)` and `AddAction(AName, AMinArgs, AMaxArgs)` come from the parent class (`WVPythia.Command.Parser.pas`).
- `DoExecute` is `abstract`, with the fixed signature `(Action: string; Args: TArray<string>): TCommandExecResult` (`WVPythia.Command.Plugin.pas`).
- `TCommandExecResult.Ok(msg)` / `.Fail(msg)` are class functions (`WVPythia.Chat.Interfaces.pas`).

### Registration from the host

Custom plugins are wired through the published property `OnRegisterCommandPlugins: TProc` of the component (`FMX.WVPythia.Chat.pas`, `VCL.WVPythia.Chat.pas`). The registry itself is reachable via `CommandLine: ICommandRegistry` (`WVPythia.Chat.Interfaces.pas`).

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TFMXPythia.Create(Layout1);
  Pythia.AttachHost(Self);
  Pythia.OnRegisterCommandPlugins :=
    procedure
    begin
      Pythia.CommandLine.RegisterPlugin(TMyPlugin.Create(FMyService));
    end;
  Pythia.Update;
end;
```

The hook is invoked by the component after `CommandLineInitialize` (`FMX.WVPythia.Chat.pas`), therefore **after** the automatic registration of `TApiKeyPlugin`. Custom plugins are added; they do not replace existing ones.

<br>

## 13 Configuring capabilities via `ICapabilities`

### Introduction

When **Pythia-Webview2** starts, the application decides which features the UI exposes: thinking controls, vision, file attachment, web search, integration cards, media creation, model selector, and related surfaces. These choices are carried by `ICapabilities` (`WVPythia.Capabilities.Manager.pas`) and persisted in the application support folder.

On first launch, the generated file is stored under a path such as:

```
bin32\MyProject\support\MyProject-capabilities.json
```

or:

```
bin64\MyProject\support\MyProject-capabilities.json
```

<br>

- [Capability catalog](#capability-catalog)
- [Configuration via the builder](#configuration-via-the-builder)
- [Manual editing of the capabilities JSON](#manual-editing-of-the-capabilities-json)

<br>

### Capability catalog

Capabilities are declared in the `TFunctionsType` enum and grouped into coherent families.

| Capability group | Purpose |
|---|---|
| `Endpoint*` | Surfaces tied to the LLM endpoint families. |
| `Thinking` and thinking tiers | Reasoning-related controls. |
| `Vision` | Image input and vision-related UI. |
| `Files` and `KnowledgeSearch` | File and knowledge-related input surfaces. |
| `Integration*` | Function, MCP, skill, agent, and custom card families. |
| `Media*` | Image, audio, video, speech-to-text, and text-to-speech surfaces. |
| `WebSearch` and `DeepResearch` | Research-oriented tools. |
| `Model` | Model selector visibility. |
| `Custom` and `SystemPrompt` | Application-specific and prompt-parameter surfaces. |

### Configuration via the builder

A typical configuration is written before `Update` or after initialization when the application deliberately refreshes the UI state:

```pascal
Pythia.Capabilities
  .Endpoint(True)
  .Thinking(True)
  .ThinkingHigh(True)
  .Vision(True)
  .Integration(True)
  .IntegrationFunction(True)
  .Media(False)
  .DeepResearch(False)
  .Model(True)
  .Update;
```

The builder route is preferable when the configuration should be locked in code.

### Manual editing of the capabilities JSON

The capabilities JSON file is deliberately flat and readable:

```json
{
  "type": "setCapabilities",
  "endpoint": true,
  "thinking": true,
  "vision": true,
  "media": false,
  "mediaCreateImage": false,
  "mediaCreateVideo": false,
  "deepResearch": false,
  "integration": true,
  "integrationFunction": true,
  "model": true
}
```

Editing JSON is convenient during integration and deployment. The `type` field must remain:

```json
"setCapabilities"
```

Otherwise the JS configuration message is ignored and the WebView keeps its previous state.

<br>

## 14 Card system — function, MCP, skill, agent, custom

### Introduction

A **card** is the configuration unit for a user-selectable integration in **Pythia-Webview2**. Each card represents a tool or integration that the user can enable for a prompt: a function, an MCP server, a skill, an agent, or a custom application-specific feature.

<br>

- [Five families, five JSON files](#five-families-five-json-files)
- [JSON schema of a card file](#json-schema-of-a-card-file)
- [Manual editing of cards](#manual-editing-of-cards)
- [Selection cycle — from click to prompt](#selection-cycle--from-click-to-prompt)

<br>

### Five families, five JSON files

The `TChatManagedItemKind` enum lists the five families: `function`, `mcp`, `skills`, `agents`, `custom`. Each family corresponds to a dedicated file under the application support folder:

| File | Family | Role |
|---|---|---|
| `<ExeName>-function-cards.json` | Functions | Callable functions / function-calling schemas. |
| `<ExeName>-mcp-cards.json` | MCP | Available Model Context Protocol servers. |
| `<ExeName>-skill-cards.json` | Skills | Application skills. |
| `<ExeName>-agent-cards.json` | Agents | Pre-configured agents. |
| `<ExeName>-custom-cards.json` | Custom | Application-specific business integrations. |

Example location:

```
bin32\MyProject\support\MyProject-function-cards.json
```

### JSON schema of a card file

All card files share the same shape:

```json
{
  "type": "card-selection-dialog-set-data",
  "dialog": "function",
  "cards": [
    {
      "id": "1EC2521C-9E0A-410B-8DD4-1D6997F9AFFF",
      "name": "Get weather",
      "commentaire": "Returns weather data for a given city",
      "content": "{\"name\":\"get_weather\",\"description\":\"Get current weather\",\"parameters\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}"
    },
    {
      "id": "10B03BB4-B9D6-4D94-B181-0094434FEE9F",
      "name": "Get local time",
      "commentaire": "Returns the current local time",
      "badge": "",
      "content": "{\"name\":\"get_local_time\",\"description\":\"Get local time\",\"parameters\":{\"type\":\"object\"}}"
    }
  ],
  "selectedId": ""
}
```

Field meaning:

| Field | Purpose |
|---|---|
| `id` | Unique identifier. A GUID is recommended. Used for selection routing. |
| `name` | Short label shown in the cards panel. |
| `commentaire` | Description shown as subtitle or tooltip. |
| `badge` | Optional small label such as `Beta`, `Pro`, or `Local`. |
| `content` | Free-form payload owned by the application/vendor service. |
| `selectedId` | Optional startup selection. |
| `dialog` | Family name. It must match the file family. |

`content` may contain JSON encoded as a string, an internal identifier, XML, or another application-specific payload. Pythia-Webview2 does not interpret this value.

### Manual editing of cards

To add a function card, duplicate an entry in the `cards` array, generate a new GUID for `id`, fill in `name` and `commentaire`, then populate `content` with the business payload expected by the vendor service. Save the file and restart the application.

The same method applies to MCPs, skills, agents, and custom cards.

### Selection cycle — from click to prompt

When the user selects cards and submits a prompt, the selected identities arrive in the prompt state. For functions, they appear in:

```pascal
TInputPromptState.Integration.&Function
```

Each item contains identity data such as `Id` and `Name`:

```pascal
for var Item in State.Integration.&Function do
begin
  // Item.Id   identifies the selected card.
  // Item.Name is the label visible to the user.
end;
```

The full `content` payload of the card is not necessarily carried inside `TInputPromptState`. Keep the prompt state lightweight and resolve `Item.Id` to the full card definition inside the service layer. The vendor service can then parse the matching `content` value and inject the resulting function schema, MCP manifest, skill descriptor, agent configuration, or custom payload into the vendor request.

The adapter can still intercept upstream selections through methods such as `DoSelectFunctionItem`, `DoSelectMCPItem`, `DoSelectSkillItem`, `DoSelectAgentItem`, and `DoSelectCustomItem`, for example when a Delphi dialog must be opened before returning an item.

<br>

## 15 Model selector

### Introduction

The model selector has two distinct configuration levels:

1. the list of models available in the application;
2. the runtime category configuration that decides which operation categories are visible and which model is currently selected by default for each category.

A model can be used as a category default only if it is first declared in the model list.

<br>

- [Declare the available models](#declare-the-available-models)
- [Configure visible categories and default models](#configure-visible-categories-and-default-models)
- [Avoid `No default model configured` warnings](#avoid-no-default-model-configured-warnings)
- [User-side correction in production](#user-side-correction-in-production)
- [Read the selected model in the vendor](#read-the-selected-model-in-the-vendor)

<br>

### Declare the available models

The generated model list file is stored under the support folder:

```
bin32\MyProject\support\MyProject-model-list.json
```

or:

```
bin64\MyProject\support\MyProject-model-list.json
```

Example:

```json
{
  "type": "model-selector-set-data",
  "models": [
    {
      "id": "anthropic-sonnet-example",
      "label": "Claude Sonnet",
      "capabilityLabels": ["Thinking", "Vision"],
      "categoryId": "textGeneration"
    },
    {
      "id": "image-model-example",
      "label": "Image Model",
      "capabilityLabels": ["Create Image", "Vision"],
      "categoryId": "imageCreation"
    },
    {
      "id": "deep-research-model-example",
      "label": "Deep Research Model",
      "capabilityLabels": ["Deep Research"],
      "categoryId": "deepResearch"
    }
  ],
  "activeCategoryId": "textGeneration",
  "selectedModelId": "anthropic-sonnet-example"
}
```

Field meaning:

| Field | Purpose |
|---|---|
| `id` | UI-side identifier. It can be an alias or the exact vendor model name, depending on the adapter. |
| `label` | Human-readable label shown in the selector. |
| `capabilityLabels` | Tags displayed under the label. |
| `categoryId` | Category such as `textGeneration`, `imageCreation`, `videoCreation`, `audioCreation`, `textToSpeech` or `deepResearch`. |

Replace example `id` values with the exact identifiers expected by your vendor implementation, or keep stable aliases and map them inside the vendor service.

### Configure visible categories and default models

The second configuration level is the runtime model-selector category configuration, usually stored in:

```
bin32\MyProject\support\MyProject-model-get-replace-version.json
```

or:

```
bin64\MyProject\support\MyProject-model-get-replace-version.json
```

Despite the historical event name `model-selector-get-replace-version`, this file is not merely a version-alias table. It defines:

- which model categories are visible;
- which source category each category is linked to;
- which model is currently selected by default for each category.

Example:

```json
{
  "categoryConfigMode": "replace",
  "categories": [
    {
      "id": "allModels",
      "label": "Model list",
      "badge": "",
      "sourceCategoryId": "none",
      "featureLabels": ["All"],
      "model": "",
      "visible": true
    },
    {
      "id": "textGeneration",
      "label": "Text Generation",
      "badge": "",
      "sourceCategoryId": "text",
      "featureLabels": [
        "Thinking",
        "Attach files",
        "Web research",
        "Vision"
      ],
      "model": "anthropic-sonnet-example",
      "visible": true
    },
    {
      "id": "imageCreation",
      "label": "Image Creation",
      "badge": "",
      "sourceCategoryId": "image",
      "featureLabels": [
        "Create Image",
        "Vision"
      ],
      "model": "",
      "visible": true
    },
    {
      "id": "videoCreation",
      "label": "Video Creation",
      "sourceCategoryId": "video",
      "featureLabels": ["Create Video"],
      "model": "",
      "visible": false
    }
  ],
  "type": "model-selector-set-runtime-config"
}
```

The important field is:

```json
"model": "anthropic-sonnet-example"
```

The value must match the `id` of a model declared in `<ExeName>-model-list.json`.

A visible category with an empty `model` field means that the category is exposed in the UI, but no model has been selected for it yet:

```json
{
  "id": "imageCreation",
  "label": "Image Creation",
  "model": "",
  "visible": true
}
```

This can be intentional if the user should make the first selection from the model configuration panel. Once the user selects a model, that choice is persisted.

### Avoid `No default model configured` warnings

Warnings such as:

```
No default model: text generation cannot be processed
No default model configured: Image creation aborted
No default model configured: Video creation aborted
No default model configured: Audio creation aborted
No default model configured: TTS operation aborted
No default model configured: Deep Research operation aborted
```

mean that the requested operation category is visible or reachable, but no default model is currently assigned to it.

Before shipping, choose one of three strategies for every category.

| Strategy | Configuration | Result |
|---|---|---|
| Provide a default model | `visible: true` and `model` contains a valid model id | The feature can be used immediately. |
| Let the user choose | `visible: true` and `model` is empty | The first use may warn until the user selects a model. |
| Hide unsupported category | `visible: false` | The feature is not exposed. |

If a category is not supported by the application, or if no matching model is provided, hide it:

```json
{
  "id": "videoCreation",
  "label": "Video Creation",
  "model": "",
  "visible": false
}
```

### User-side correction in production

In production, the user should not edit JSON files manually.

If the user sees a warning such as:

```
No default model configured: Image creation aborted
```

it means that the category is visible, but no model is currently selected for it. The user-side procedure is:

1. open the model configuration panel;
2. look for categories marked as not assigned, usually with a red dot;
3. select the relevant category, such as Text Generation, Image Creation, Video Creation, Audio Creation, Text to Speech, or Deep Research;
4. choose one of the compatible models from the filtered list;
5. retry the operation.

The developer decides which categories exist and are visible. The user only chooses or changes the current model for visible categories.

### Read the selected model in the vendor

Inside the vendor service, read the selected model from the buffered state and convert it into the exact model identifier expected by the SDK.

A sample architecture may use an indexed category lookup:

```pascal
State.Model := State.Models.Items[TEXT_GENERATION_INDEX].Model;
```

Make sure the `categoryId` values in the model list and the category ids in the runtime configuration match what the vendor service expects. If the category mapping does not match, the vendor may read the wrong slot or fail to find a default model.

<br>

## 16 Implementing a vendor service (`IVendorServices`)

### Introduction

**Pythia-Webview2** contains no LLM call. It delegates provider communication to an application service implementing `IVendorServices`. The service adapter receives the UI event, then routes prompt submission to that vendor service.

LLM-related processing must be asynchronous so the UI remains responsive. Network calls, streaming, and long-running generations must not be performed directly on the UI thread.

<br>

- [The IVendorServices interface](#the-ivendorservices-interface)
- [TInputPromptState and TStateBuffer](#tinputpromptstate-and-tstatebuffer)
- [TManagedItemFinalizeProc — the request end](#tmanageditemfinalizeproc--the-request-end)
- [Route prompt submission to the vendor](#route-prompt-submission-to-the-vendor)
- [Vendor service skeleton](#vendor-service-skeleton)
- [Initialize the vendor after the browser is ready](#initialize-the-vendor-after-the-browser-is-ready)
- [Streaming and UI](#streaming-and-ui)

<br>

### The `IVendorServices` interface

Declared in `WVPythia.Vendors.Services.pas`:

```pascal
IVendorServices = interface
  ['{E7464431-EB15-4121-ADB4-76C40F1A9BEE}']
  procedure AsyncAwaitStreamChat(
    const AState: TInputPromptState;
    const AOnFinalize: TManagedItemFinalizeProc);
  procedure UpdateApiKey;
end;
```

`AsyncAwaitStreamChat` is invoked on prompt submission. It receives the complete input state and a finalization callback. `UpdateApiKey` lets the SDK client reload credentials after key creation or rotation.

### `TInputPromptState` and `TStateBuffer`

`TInputPromptState` aggregates the prompt text, endpoint, thinking configuration, files, images, knowledge selections, selected cards, media state, request parameters, and model selections.

For asynchronous vendor calls, do not capture `TInputPromptState` directly in long-lived closures. It is a class reference and may be freed by the component before a long streaming request finishes.

Copy it immediately into a value buffer:

```pascal
var State := TStateBuffer.FromState(AState);
```

Then capture `State`, not `AState`, inside asynchronous callbacks.

### `TManagedItemFinalizeProc` — the request end

```pascal
TManagedItemFinalizeProc = reference to procedure(
  const AResult: TManagedItemLLMResult);
```

At the end of the request — success, cancellation, or exception — the vendor service fills a `TManagedItemLLMResult` and invokes the callback:

```pascal
var Result := TManagedItemLLMResult.New;
try
  Result
    .UsedModel(State.Model)
    .Response(FinalText)
    .Reasoning(FinalThinking)
    .PromptJson(RequestJson)
    .ResponseJson(ResponseJson)
    .Error(False);

  if Assigned(AOnFinalize) then
    AOnFinalize(Result);
finally
  Result.Free;
end;
```

### Route prompt submission to the vendor

In the service unit, locate the method that handles prompt activation. A diagnostic implementation can be replaced with:

```pascal
class function TToolContainer.ActivateInputState(
  const AState: TInputPromptState;
  const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
  Result := True;
  AnthropicVendor.AsyncAwaitStreamChat(AState, AOnFinalize);
end;
```

The adapter does not need to know the SDK. It only routes the prompt state toward the selected application service.

### Vendor service skeleton

```pascal
type
  TAnthropicServices = class(TInterfacedObject, IVendorServices)
  const
    API_KEY_NAME = 'anthropic';
  private
    FBrowser: IPythiaBrowser;
    FClient: IAnthropic;
  public
    constructor Create(const ABrowser: IPythiaBrowser);
    procedure AsyncAwaitStreamChat(
      const AState: TInputPromptState;
      const AOnFinalize: TManagedItemFinalizeProc);
    procedure UpdateApiKey;
  end;

constructor TAnthropicServices.Create(const ABrowser: IPythiaBrowser);
var
  Anthropic_key: string;
begin
  FBrowser := ABrowser;

  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
    FBrowser.TryHandleAsCommand(Format('/api-key new %s', [API_KEY_NAME]));

  FClient := TAnthropicFactory.CreateInstance(Anthropic_key);
end;

procedure TAnthropicServices.UpdateApiKey;
var
  Anthropic_key: string;
begin
  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
    begin
      FClient.API.Token := '';
      Exit;
    end;

  FClient.API.Token := Anthropic_key;
  FBrowser.DisplaySuccess('Anthropic client is up to date.');
end;

procedure TAnthropicServices.AsyncAwaitStreamChat(
  const AState: TInputPromptState;
  const AOnFinalize: TManagedItemFinalizeProc);
begin
  var State := TStateBuffer.FromState(AState);

  // 1. Build the request from State.
  // 2. Resolve selected cards by Id if tools are enabled.
  // 3. Start the SDK request asynchronously.
  // 4. Stream chunks toward FBrowser.DisplayStream(...).
  // 5. Invoke AOnFinalize with TManagedItemLLMResult at the end.
end;
```

For another provider, keep the same structure and change the service class, SDK factory, model mapping, and `API_KEY_NAME` value.

### Initialize the vendor after the browser is ready

Instantiate the vendor after the form is shown and the browser has had time to initialize. One simple pattern is to delay the initialization and create the vendor from `DoInitialize`:

```pascal
uses
  VCL.WVPythia.Chat,
  WVPythia.Types,
  VCL.WVPythia.Services,
  Anthropic.Browser.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel2);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.OnApiKeyChanged := UpdateApiKey;
  Pythia.OnInitialized := DoOnInitialized;
  Pythia.Update;
end;

procedure TForm1.DoInitialize;
begin
  AlphaBlend := False;
  AnthropicVendor := TAnthropicServices.Create(Pythia);
end;

procedure TForm1.UpdateApiKey(KeyName: string);
begin
  if SameText(KeyName, TAnthropicServices.API_KEY_NAME) then
    AnthropicVendor.UpdateApiKey;
end;
```

The resulting flow is:

```
Application starts
  │
  ▼
DoInitialize creates TAnthropicServices
  │
  ▼
The service reads the secret named "anthropic"
  │
  ├── Key exists: create the Anthropic client with the stored key
  │
  └── Key missing: trigger /api-key new anthropic automatically
                 │
                 ▼
              User enters the key
                 │
                 ▼
              OnApiKeyChanged calls UpdateApiKey
                 │
                 ▼
              The Anthropic client receives the new token
```

### Streaming and UI

During the stream, the vendor service pushes chunks to the WebView through:

```pascal
IPythiaBrowser.DisplayStream(TextDelta, ThinkingDelta, IsFinal)
```

The component accumulates fragments and renders them in real time inside the current chat bubble. The final callback closes the sequence and triggers persistence of the complete turn.

User cancellation is funneled through `FBrowser.Escape: Boolean`. The vendor service should poll this value in its progress callback and stop cleanly when it becomes `True`. After cancellation, reset the relevant browser state so the UI is released.

<br>

## 17 Media output — image, audio, video, TTS

**Pythia-Webview2** natively renders media outputs produced by an LLM: images, audios, videos, files. Rendering relies on dedicated JS templates (`DisplayImageTemplate.js`, `DisplayAudioTemplate.js`, `DisplayVideoTemplate.js`, `DisplayFileTemplate.js`) and on the `WVPythia.Net.MediaCodec.pas` utility unit on the Delphi side.

### Vendor-side expected format

The vendor service fills the `Images`, `Audios`, `Videos`, `Files` arrays of `TManagedItemLLMResult` with **strings** that may take three forms: a local file path (`C:\path\to\image.png`), an HTTP or HTTPS URL (`https://...`), or a complete data URI (`data:image/png;base64,...`). The component detects the format at render time and adapts its strategy: a local file is encoded into a data URI on the fly via `TMediaCodec.ToDataURI`, an HTTP URL is inserted as is in the matching tag, a data URI is used directly without transformation.

### `TMediaCodec` — toolbox

The `WVPythia.Net.MediaCodec.pas` unit exposes a `TMediaCodec` helper record with a complete suite of static methods to encode and decode Base64 and data URIs. The most useful ones in a vendor service are `EncodeDataUri(FilePath, MimeType)` which produces `data:<mime>;base64,...` from a file; `TryDecodeDataUriToFile(DataUri, FilePath, out MimeType)` which saves a data URI into a file on disk; `TryToBytes(FileLocation, out Bytes, out MimeType)` which resolves any source — file, URL, data URI — into bytes; `TryToDataUri(FileLocation, out DataUri, out MimeType)` which converts any source into a data URI; and `GetMimeType(FileLocation)` which returns the MIME type of a local file (by extension) or of a remote URL (HTTP HEAD).

### `https://app.local` naming convention

Files returned by the vendor that point to a local resource exposed through the WebView2 virtual mapping use the `https://app.local/...` prefix. When `TInputPromptState.ToImageSources` encounters this prefix, it leaves the URL as is; otherwise it converts to a data URI. This distinction lets you serve large files from disk without paying the cost of Base64 conversion at every render — typically useful for generated videos that may reach several tens of megabytes.

### Capabilities to enable

For a media family to be visible in the UI, the matching capability must be active in `<ExeName>-capabilities.json`: `mediaCreateImage`, `mediaCreateVideo`, `mediaCreateAudio`, `mediaTextToSpeech`. Without these flags, the UI hides the toggles in the input bar and the vendor never receives any media-generation state to handle.

<br>

## 18 Audio input (transcription)

**Current state.** This version of **Pythia-Webview2** does not offer live audio recording. The supported flow consists of **providing an existing audio file** that the application code then transcribes before pushing the result into the input bar. The microphone icon in the bar — enabled via `ebMicrophone` — is present in the UI but **no default handler is associated with it**: it is entirely the developer's responsibility to wire the desired logic.

### Enabling the microphone icon

A single line in `FormCreate` adds the icon to the input bar:

```pascal
Pythia.EnabledButtons := Pythia.EnabledButtons + [ebMicrophone];
```

The `mediaSpeechToText` capability must also be active in `<ExeName>-capabilities.json`. Without it, the icon stays hidden even if `ebMicrophone` is in the set.

### Implementation is the application's responsibility

When the user clicks the icon, the WebView emits `audio-input` and `TBrowserEventManager` routes the event to the adapter's `DoActivateAudioInputEvent`. The application is then free to define the behavior: open an audio-file selection dialog (`.wav`, `.mp3`, `.m4a`…), call an external transcription service, then inject the resulting transcription into the input bar via `IPythiaBrowser.BrowserInput(transcription)`.

Direct recording from the system microphone is not provided by the framework in this version. It can be implemented by the host application if needed, for example through a third-party Delphi audio-capture component.

### Selecting the transcription model

Audio transcription uses the **Audio** category in the model selector.

This category is used for models that can process an audio input and return text.

For example, a transcription model can be declared in `<ExeName>-model-list.json` like this:

```json
{
  "id": "WHISPER_LARGE",
  "label": "Whisper large-v3",
  "capabilityLabels": ["Speech to text"],
  "categoryId": "speechToText"
}
```

To make transcription available immediately, assign a default model to the Audio category in <ExeName>-model-get-replace-version.json:

```json
{
  "id": "speechToText",
  "label": "Speech to Text",
  "sourceCategoryId": "speech",
  "model": "WHISPER_LARGE",
  "visible": true
}
```

If no default model is assigned to the Audio category, the user may see:

```
No default model configured: Audio creation aborted
```

The user can fix this from the model configuration panel by selecting a model for the Audio category.

<br>

## 19 File attachments & file drawer

The user can attach files to a prompt through the paperclip icon in the input bar. The file drawer displays the selected pieces before submission; on send, they are forwarded to the vendor service in `TInputPromptState.Files`, `Images`, or `KnowledgeSearch`, depending on the chosen category.

### Attachment flow

Clicking the paperclip emits the `open-file-dialog` event, accompanied by a `target` field that indicates the expected category (`Images`, `Documents`, `Knowledge`, `Speech`). `TBrowserEventManager` routes to `IOpenDialog.SelectFile(target)`. The default implementation, provided by `VCL.WVPythia.OpenDialog.pas` or `FMX.WVPythia.OpenDialog.pas` depending on the framework, opens a system file-selection dialog. The resulting path is sent back to the WebView via `IPythiaBrowser.UpdateFileDrawer(Files, Images, Knowledge)`, which refreshes the drawer display. At prompt submission, files are serialized into `TInputPromptState` according to their category: images go into `Images`, documents (`.pdf`, `.docx`, `.txt`) go into `Files`, files intended for retrieval (RAG) go into `KnowledgeSearch`. The vendor then decides how to forward them to the LLM — typically through `TMediaCodec.EncodeDataUri` for vendors that accept data URIs, or via a prior S3 upload for large files that would exceed payload limits.

### Per-category filters

The `TOpenFileTarget` enum (`WVPythia.Types.pas`) lists the four supported categories: `Images`, `Documents`, `Knowledge`, `Speech`. Each category applies a different extension filter in the open dialog. To customize a filter — for example to allow `.csv` in `Knowledge` — provide a custom implementation of `IOpenDialog` and inject it into the component via the event pipeline.

### Capabilities to enable

The `Files`, `Vision`, and `KnowledgeSearch` capabilities must be active in `<ExeName>-capabilities.json` for the corresponding attachment buttons to be visible. Without these flags, the paperclip is hidden for the affected category and the user cannot attach a file of that nature.

<br>

## 20 Themes & Look & Feel

**Pythia-Webview2** ships two native themes defined by the `TLookAndFeel` enum (`WVPythia.Types.pas`):

```pascal
TLookAndFeel = (light, dark);
```

The user selects the theme through the settings panel. The component emits the `look-and-feel-selected` event, applies the theme on the WebView side by updating root CSS variables, then calls the `OnThemeChanged` hook on the Delphi side. The current theme is readable through the property `Pythia.Theme: string`, parsable into an enum via `TLookAndFeel.Parse`.

### Synchronizing the host application

The `OnThemeChanged` hook is where the host application aligns its chrome — window colors, toolbars, icons — with the chat theme. Without this synchronization, the user may end up with a dark chat framed by a light window, which breaks immersion:

```pascal
Pythia.OnThemeChanged :=
  procedure
  begin
    case TLookAndFeel.Parse(Pythia.Theme) of
      TLookAndFeel.light: ApplyLightTheme;
      TLookAndFeel.dark:  ApplyDarkTheme;
    end;
  end;
```

`ApplyLightTheme` and `ApplyDarkTheme` are to be written according to your host application's conventions: VCL Themes via `TStyleManager`, FireMonkey palette through the `StyleBook` property, direct chrome colors…

### Customizing themes visually

The CSS variables and classes used by the JS templates are defined in `assets/index.htm` and the files of `assets/scripts/*.js`. To modify the chat's visual appearance — palette, typography, spacing, border radius — you simply edit those files directly. Combined with `TemplateAllwaysReloading` (see §11), changes are visible without recompilation: edit a CSS or JS file, save, restart the application, see the result. To go further and add a third theme, you must extend the `TLookAndFeel` enum on the Pascal side **and** add the matching set of CSS variables on the JS side, respecting the `--theme-<name>-...` naming to stay consistent with the conventions of the shipped templates.

<br>

## 21 Two-step confirmation

Several destructive actions — deleting a message, deleting a chat session — go through a confirmation dialog before being executed. The pattern relies on **two distinct events** that must not be conflated, on pain of an infinite loop or silent deletion without confirmation.

### The pitfall to avoid

A naive implementation that executes the deletion as soon as the request event is received falls into one of two classic traps. Either the dialog reopens indefinitely because the deletion re-emits the initial event. Or the deletion happens without user validation, because the "request" was confused with the "response". The framework therefore enforces a strict separation between **request** and **response**.

### The correct pattern

On reception of the **request** — `ConfirmationRequest` emitted by the UI when the user clicks the trash icon — the Delphi handler simply records the **pending action** (for example, the ID of the message to delete) in a state variable. It executes nothing. The UI itself opens the confirmation dialog. When the user clicks "Confirm" in that dialog, the UI emits a second event, `DialogConfirmationResponse`. **Only this second event** triggers the actual execution of the action recorded in the previous step.

```pascal
type
  TPendingAction = record
    Goal: TDialogGoal;       // DeleteDomBlock | DeleteChatSession
    TargetId: string;
  end;

var
  FPendingAction: TPendingAction;

// Step 1 — Recording only, NO execution.
procedure HandleConfirmationRequest(const Goal: TDialogGoal; const Id: string);
begin
  FPendingAction.Goal := Goal;
  FPendingAction.TargetId := Id;
  // The UI opens the dialog; no execution here.
end;

// Step 2 — Conditional execution of the pending action.
procedure HandleDialogConfirmationResponse(const Confirmed: Boolean);
begin
  if not Confirmed then
    Exit;
  case FPendingAction.Goal of
    TDialogGoal.DeleteDomBlock:    DeleteMessage(FPendingAction.TargetId);
    TDialogGoal.DeleteChatSession: DeleteSession(FPendingAction.TargetId);
  end;
  FPendingAction := Default(TPendingAction);
end;
```

The `TDialogGoal` enum (`WVPythia.Types.pas`) lists the two natively supported goals: `DeleteDomBlock` for deleting a message in the DOM and `DeleteChatSession` for deleting an entire conversation. For any additional application goal, simply extend the enum **and** handle the new value in both steps of the pattern. Resetting `FPendingAction` after execution avoids accidental executions if the user clicks Confirm again in another context.

<br>

## 22 Chat sessions, persistence, pagination

Sessions form the chat's continuity layer: they retain the history of turns, allow returning to an existing conversation, and keep the display synchronized with the JSON store. The event manager activates, renames, paginates, or prepares deletion through `IPersistentChat` and `IPythiaBrowser`, so that the UI and persistence stay aligned.

Provided by `WVPythia.ChatSession.Controller.pas`.

- `TChatSession` aggregates `TChatTurn` objects.
- Incremental JSON persistence via `WVPythia.JSON.Resource.pas`.
- Every structural mutation triggers a write.
- Pagination handled by `TChatSessionEventHandler`.

### Relevant events

Exact names in `TBrowserChatEvent` (`WVPythia.Types.pas`):

|Delphi name|Wire (JSON)|
|-|-|
|`NewChatEvent`|`new-chat`|
|`ChatSelectionEvent`|`chat-selection`|
|`ChatNextPageEvent`|`chat-next-page`|
|`ChatItemDeleteEvent`|`chat-item-delete`|
|`ChatItemRenameEvent`|`chat-item-rename`|

In the current flow, `new-chat` only creates a session if a conversation already contains at least one prompt and the browser is not locked. Selection loads the persisted session and redraws the conversation, pagination reloads a list page before refreshing the file drawer, and session deletion goes through a confirmation before mutating the store.

### Alignment rule

Deletion relies on alignment between the UI and the persistent state. Never delete on the persistence side without notifying the UI in the same turn — under penalty of a desync between the list shown in the DOM and the JSON store.

<br>

## 23 Plugin UI and JS ↔ Delphi bridge

### Introduction

A command plugin (§12) executes Delphi code. As long as the action is limited to returning a text message via `TCommandExecResult.Ok(...)`, everything happens on the Pascal side. But as soon as the command needs to **display something specific, offer a choice, gather a structured input**, two paths open up.

<br>

- [Two ways to interact with the user](#two-ways-to-interact-with-the-user)
- [The JS → Delphi bridge](#the-js--delphi-bridge)
- [JSON contract](#json-contract)
- [Building a JS template for your plugin](#building-a-js-template-for-your-plugin)
- [Delphi side: receiving and routing](#delphi-side-receiving-and-routing)
- [Channel limits](#channel-limits)

<br>

### Two ways to interact with the user

**Option A — Drive the UI from Delphi.**
The plugin calls methods of `IPythiaBrowser` (`WVPythia.Chat.Interfaces.pas`) to display a message, open a dialog, or inject a script. All the logic stays in `DoExecute` and the Delphi handlers. This is the fastest path when the existing UI covers the need — no JavaScript to write.

**Option B — Write your own JS template.**
If the command needs a rich display (custom form, visualization, interactive component), the plugin author ships a dedicated JS template. That template is loaded via `LoadCustomTemplate` (§11). User interactions inside the template — clicks, validations, end of animation — must travel up to the plugin's Delphi code. That is the role of the `custom-event` channel.

### The JS → Delphi bridge

WebView2 offers only one path to talk to Delphi:

```javascript
window.chrome.webview.postMessage(json);
```

Pythia-Webview2 reserves the value `"event": "custom-event"` for user-defined messages. These messages are not routed to a typed framework handler: they arrive raw in `CustomEvent` and are forwarded to:

```
IChatManagedItemDialogService.ActivateCustomEvent(RawJson)
```

Exact signature: `function ActivateCustomEvent(const ARawJson: string): Boolean;` (`WVPythia.Adapter.pas`). It is up to the application to parse `RawJson` and dispatch on the `name` field.

### JSON contract

```json
{
  "event": "custom-event",
  "name": "<free, namespaced name>",
  "payload": { },
  "requestId": "<uuid, optional>"
}
```

The framework looks at neither `name` nor `payload`. The only mandatory field it interprets is `event`, which must be literally `"custom-event"`.

### Building a JS template for your plugin

Two rules to follow.

**1. Wrap in an IIFE.**

Each template is written as a self-executing function that does not pollute the global `window` namespace:

```javascript
(() => {
  // local state, DOM, event listeners…
})();
```

Variables, functions, and listeners declared inside stay confined to the closure. This is the convention followed by the 22 shipped templates; it is necessary for several templates to coexist without name collisions.

**2. Return JSON to Delphi.**

Every notification toward the Pascal code — user click, form validation, data request — goes through a `postMessage` call respecting the `custom-event` contract:

```javascript
(() => {
  const btn = document.getElementById('my-plugin-confirm');

  btn.addEventListener('click', () => {
    window.chrome.webview.postMessage({
      event: "custom-event",
      name: "myplugin.run-confirmed",
      payload: { id: 42, label: "Option A" }
    });
  });
})();
```

To avoid repeating the structure in each template, inject a helper once from a bootstrap template:

```javascript
window.AppHost = Object.freeze({
  emit(name, payload = {}, requestId = crypto.randomUUID()) {
    window.chrome.webview.postMessage({
      event: "custom-event",
      name, payload, requestId
    });
    return requestId;
  }
});
```

Usage from a plugin template:

```javascript
(() => {
  document.getElementById('my-plugin-confirm')
    .addEventListener('click', () => {
      AppHost.emit("myplugin.run-confirmed", { id: 42 });
    });
})();
```

### Delphi side: receiving and routing

`ActivateCustomEvent` receives the raw message. The application parses it and dispatches by `name`:

```pascal
function TMyDialogService.ActivateCustomEvent(const ARawJson: string): Boolean;
begin
  var Reader := TJsonReader.Parse(ARawJson);
  var EventName := Reader['name'].AsString;

  if EventName = 'myplugin.run-confirmed' then
  begin
    var Id := Reader['payload.id'].AsInteger;
    FMyPluginController.HandleRunConfirmed(Id);
    Exit(True);
  end;

  Result := False; // not consumed; lets other consumers take over
end;
```

`name`-based routing belongs to the application. Recommendation: namespace event names (`myplugin.run-confirmed`, `user.form-validated`) to avoid collisions between plugins that coexist.

### Channel limits

* No automatic typed binding — always go through `TJsonReader.Parse`.
* One-way channel by construction. For a structured response on the JS side, combine `requestId` + an `ExecuteScript` call from Delphi that triggers a registered JS callback.
* No sandbox: all templates share the same WebView context. A template can read/write the DOM produced by another.
* Scripts injected via `ExecuteScript` execute in the same global scope as the templates — beware of exported function names.

<br>

## 24 Internationalization

Pythia-Webview2 ships ready-to-use locale files under `assets/lang/`. Each JSON file describes the strings displayed by the interface, grouped by logical sections such as `more`, `settings`, and `dialogs`. The mechanism covers both the JavaScript layer — which queries labels through a `t('key')` API — and the Pascal layer, where strings are stored in global variables reloaded on every language switch.

```
assets/lang/*.json
```

A few standard locales:

- `english-us`
- `english-gb`
- `french-fr`
- `japan-jp`

<br>

- [Loading](#loading)
- [The dictionary](#the-dictionary)
   - [JS side](#js-side)
   - [Delphi side](#delphi-side)
   - [Adding a language](#adding-a-language)
- [Extending translations to application-specific strings](#extending-translations-to-application-specific-strings)
   - [1. Add a "custom" section to the language JSON](#1-add-a-custom-section-to-the-language-json)
   - [2. Declare your own translation variables](#2-declare-your-own-translation-variables)
   - [3. Write the MyTranslation procedure](#3-write-the-mytranslation-procedure)
   - [4. Wire the procedure via OnTranslationsLoaded](#4-wire-the-procedure-via-ontranslationsloaded)

<br>

### Loading

Loading is driven by the VCL or FMX browser language manager. Both expose the same conceptual surface: `SetLanguage` to activate a locale, `GetLocalLanguage` to query the current locale, `LoadDictionaryContent` to retrieve the content of a dictionary, and `GetNormalizedFileNames` to enumerate available locales.

### The dictionary

#### JS side

Templates access labels through:

```javascript
window.AppI18n.t('key')
```

The API is exposed by `BootstrapDictionaryTemplate.js`, which loads the active dictionary at WebView startup and updates it on every `SetLanguage` call.

#### Delphi side

Native strings are defined as global variables in `WVPythia.Strs.pas`. They are reloaded on every language switch: the JSON dictionary is parsed, each known key updates its corresponding global variable, and the current value is kept as fallback when a key is missing.

#### Adding a language

Duplicate an existing `.json` file, translate its values, and name the new file following the schema:

```
<country>-<code>.json
```

Once the file is dropped into `assets/lang/`, it is detected on next startup. If the application has already been run, the selected language may be remembered in `<ExeName>-request-params-main-values.json`; deleting that preference file forces the default language to be reinitialized on next startup.

<br>

### Extending translations to application-specific strings

The `S_...` variables of `WVPythia.Strs.pas` cover the component's native strings. A host application can add its own labels — custom plugin captions, business assistant messages, additional button titles — by using the same dictionary-loading cycle.

#### 1. Add a "custom" section to the language JSON

At the root of every language file, add a sub-object by convention named `custom`:

```json
{
  "more": {
    "delete_qa": "...",
    "welcome": "..."
  },
  "settings": {
    "...": "..."
  },
  "custom": {
    "my_dashboard_title": "Dashboard",
    "my_run_button": "Run",
    "myplugin_confirm_dialog": "Confirm action?"
  }
}
```

The framework does not interpret this object. It is a grouping convention for host-application strings.

#### 2. Declare your own translation variables

```pascal
unit MyApp.Strs;

interface

var
  S_MY_DASHBOARD_TITLE: string = 'Dashboard';
  S_MY_RUN_BUTTON: string = 'Run';
  S_MYPLUGIN_CONFIRM_DIALOG: string = 'Confirm action?';

implementation

end.
```

The initial values serve as fallbacks.

#### 3. Write the `MyTranslation` procedure

```pascal
procedure MyTranslation;
begin
  {--- Retrieves the content of the active dictionary via the component }
  var Content := Pythia.LoadDictionaryContent(
    Pythia.GetLocalLanguage);

  var JSONObject := TJsonReader.Parse(Content);

  S_MY_DASHBOARD_TITLE := JSONObject.AsString(
    'custom.my_dashboard_title',
    S_MY_DASHBOARD_TITLE);

  S_MY_RUN_BUTTON := JSONObject.AsString(
    'custom.my_run_button',
    S_MY_RUN_BUTTON);

  S_MYPLUGIN_CONFIRM_DIALOG := JSONObject.AsString(
    'custom.myplugin_confirm_dialog',
    S_MYPLUGIN_CONFIRM_DIALOG);
end;
```

#### 4. Wire the procedure via `OnTranslationsLoaded`

Assign `OnTranslationsLoaded` during component instantiation. The examples below are partial snippets; in a real application, keep the central rule from §7 and §8: assign `ServiceAdapter` before calling `Update`.

```pascal
{--- VCL }
Pythia := TVCLPythia.Create(Panel2);
Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
Pythia.OnTranslationsLoaded := MyTranslation;
Pythia.Update;
```

```pascal
{--- FMX }
Pythia := TFMXPythia.Create(Layout1);
Pythia.AttachHost(Self);
Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;
Pythia.OnTranslationsLoaded := MyTranslation;
Pythia.Update;
```

From that moment on, every call to `SetLanguage` retranslates both native strings and the host application's custom strings.

<br>

## 25 JSON configuration files

On first launch, **Pythia-Webview2** creates application configuration files derived from the executable name. The files most often edited by the integrator live in the application support folder:

```
bin32\MyProject\support
```

or:

```
bin64\MyProject\support
```

A standalone project usually has this shape:

```
MyProject
├── assets
│   ├── index.htm
│   ├── scripts
│   ├── media
│   └── lang
├── bin32
│   ├── MyProject.exe
│   ├── WebView2Loader.dll
│   └── MyProject
│       └── support
├── bin64
│   ├── MyProject.exe
│   ├── WebView2Loader.dll
│   └── MyProject
│       └── support
└── dcu
```

The exact set of generated files may vary with the project version and enabled features. The files below are the integration-critical ones covered by this documentation.

### Support files commonly pre-filled by the developer

| File | Role | Manually editable |
|---|---|---|
| `<ExeName>-capabilities.json` | Declares which UI features are visible or available. | Yes — useful during integration and deployment. |
| `<ExeName>-model-list.json` | Declares the models available to the selector. | Yes — add, remove, or rename available models. |
| `<ExeName>-model-get-replace-version.json` | Runtime model-selector category configuration: visible categories, source categories, and default model per category. | Yes — assign default models or hide unsupported categories. |
| `<ExeName>-function-cards.json` | Function-card definitions. | Yes — declare function-calling tools. |
| `<ExeName>-mcp-cards.json` | MCP-card definitions. | Yes — declare MCP integrations. |
| `<ExeName>-skill-cards.json` | Skill-card definitions. | Yes — declare skills. |
| `<ExeName>-agent-cards.json` | Agent-card definitions. | Yes — declare agents. |
| `<ExeName>-custom-cards.json` | Application-specific cards. | Yes — free extension point for business integrations. |
| `<ExeName>-custom-template-js.json` | References to custom JS templates loaded via `LoadCustomTemplate`, when this feature is used. | Yes — keep consistent with files under `assets/scripts`. |

### Capabilities file

`<ExeName>-capabilities.json` is a flat `setCapabilities` payload:

```json
{
  "type": "setCapabilities",
  "endpoint": true,
  "thinking": true,
  "vision": true,
  "media": false,
  "deepResearch": false,
  "integration": true,
  "integrationFunction": true,
  "model": true
}
```

### Model list file

`<ExeName>-model-list.json` declares available models:

```json
{
  "type": "model-selector-set-data",
  "models": [
    {
      "id": "anthropic-sonnet-example",
      "label": "Claude Sonnet",
      "capabilityLabels": ["Thinking", "Vision"],
      "categoryId": "textGeneration"
    }
  ],
  "activeCategoryId": "textGeneration",
  "selectedModelId": "anthropic-sonnet-example"
}
```

### Runtime category configuration

`<ExeName>-model-get-replace-version.json` configures runtime model categories:

```json
{
  "categoryConfigMode": "replace",
  "categories": [
    {
      "id": "textGeneration",
      "label": "Text Generation",
      "sourceCategoryId": "text",
      "featureLabels": ["Thinking", "Vision"],
      "model": "anthropic-sonnet-example",
      "visible": true
    },
    {
      "id": "videoCreation",
      "label": "Video Creation",
      "sourceCategoryId": "video",
      "featureLabels": ["Create Video"],
      "model": "",
      "visible": false
    }
  ],
  "type": "model-selector-set-runtime-config"
}
```

A visible category should either have a valid `model` value or be intentionally left for user assignment. Unsupported categories should be hidden.

### Card files

Card files share the same root shape:

```json
{
  "type": "card-selection-dialog-set-data",
  "dialog": "function",
  "cards": [],
  "selectedId": ""
}
```

The `dialog` value must match the family represented by the file.

### Other generated files

Other files may be created near the executable or under the application folder, such as request-parameter values, chat-session history, API-key name tracking, or developer-mode exchange dumps. Their exact location and shape can depend on project configuration and version. When a file is not covered by the sections above, treat its format as version-specific unless the corresponding source unit documents it explicitly.

<br>

## 26 API surface — key interfaces

The table below gathers the main contracts to know in order to integrate the component. These interfaces are the stable entry points between the browser, commands, application services, and configuration providers; the concrete FMX/VCL classes consume them without exposing their internal details.

|Interface|Unit|Role|
|-|-|-|
|`IPythiaBrowser`|`WVPythia.Chat.Interfaces.pas`|Component façade: `ExecuteScript`, `DisplayError`, `ApiKeyValuesUpdate`, etc. — see the full interface lines 49-238|
|`ICommandPlugin` / `ICommandRegistry`|`WVPythia.Chat.Interfaces.pas`|Command pipeline|
|`IApiKeyService`|`WVPythia.ApiKey.Service.Intf.pas`|`CreateKey` / `DeleteKey` / `Exists`|
|`ISecretStore`|`WVPythia.Chat.Interfaces.pas`|Windows-Registry abstraction|
|`IChatManagedItemDialogService`|`WVPythia.Adapter.pas`|Neutral UI contract for selection / activation, including `ActivateCustomEvent`|
|`IOpenDialog` / `IProcessExecute`|`WVPythia.Chat.Interfaces.pas`|Files and external processes|
|`ICapabilities`|`WVPythia.Capabilities.Manager.pas`|Fluent capability builder: endpoints, media, thinking, MCP, skills, agents|
|`ITemplateProvider`|`WVPythia.Template.Manager.pas`|JS template loading, `LoadCustomTemplate`, reload strategies|

<br>

## 27 `TBrowserChatEvent` event table

Enumeration: `WVPythia.Types.pas` — **38 values**, mapped to wire names via `TBrowserChatEventHelper.Map` (`WVPythia.Types.pas`).

<br>

- [Prompt & orchestration](#prompt--orchestration)
- [Chat sessions](#chat-sessions)
- [Message actions](#message-actions)
- [Integration dialogs](#integration-dialogs)
- [Model selector](#model-selector)
- [Card selector](#card-selector)
- [Settings & appearance](#settings--appearance)
- [Extension channel](#extension-channel)

<br>

### Prompt & orchestration

|Delphi|Wire|
|-|-|
|`InputSubmit`|`input-submit`|
|`InputState`|`input-state`|
|`InputString`|—|
|`StopSubmit`|`stop-submit`|
|`AudioInput`|`audio-input`|

### Chat sessions

|Delphi|Wire|
|-|-|
|`NewChatEvent`|`new-chat`|
|`ChatSelectionEvent`|`chat-selection`|
|`ChatNextPageEvent`|`chat-next-page`|
|`ChatItemDeleteEvent`|`chat-item-delete`|
|`ChatItemRenameEvent`|`chat-item-rename`|

### Message actions

|Delphi|Wire|
|-|-|
|`&Copy`|`copy`|
|`CopyEvent`|`copy-event`|
|`BranchEvent`|`branch-event`|
|`DeleteEvent`|`delete-event`|
|`ScrollRequest`|`scroll-request`|

### Integration dialogs

|Delphi|Wire|
|-|-|
|`OpenFileDialog`|`open-file-dialog`|
|`OpenIntegrationFunctionDialog`|`open-integration-function-dialog`|
|`OpenIntegrationMcpDialog`|`open-integration-mcp-dialog`|
|`OpenIntegrationSkillsDialog`|`open-integration-skills-dialog`|
|`OpenIntegrationAgentsDialog`|`open-integration-agents-dialog`|
|`OpenCustomDialog`|`open-custom-dialog`|
|`DisplayFileClick`|`display-file-click`|
|`DialogConfirmationResponse`|`dialog-confirmation-response`|

### Model selector

|Delphi|Wire|
|-|-|
|`ModelSelection`|`model-selection`|
|`ModelSelectorCategoryChanged`|`model-selector-category-changed`|
|`ModelSelectorSelectionChanged`|`model-selector-selection-changed`|
|`ModelSelectorGetReplaceVersion`|`model-selector-get-replace-version`|

### Card selector

|Delphi|Wire|
|-|-|
|`CardSelectionDialogSettings`|`card-selection-dialog-settings`|
|`CardSelectionDialogSelect`|`card-selection-dialog-select`|
|`CardSelectionDialogSelectionChanged`|`card-selection-dialog-selection-changed`|
|`CardSelectionDialogCancel`|`card-selection-dialog-cancel`|

### Settings & appearance

|Delphi|Wire|
|-|-|
|`SystemSettings`|`system-settings`|
|`RequestParamsValues`|`request-params-values`|
|`ResquestParamsPageChanged`|`resquest-params-page-changed` *(original typo preserved in the enum)*|
|`LookAndFeelSelectedEvent`|`look-and-feel-selected`|
|`LanguageSelectedEvent`|`language-selected`|
|`ScrollButtonSelectedEvent`|`scroll-button-selected`|

### Extension channel

|Delphi|Wire|
|-|-|
|`CustomEvent`|`custom-event`|

<br>

## 28 FMX ↔ VCL matrix

|Element|VCL|FMX|
|-|-|-|
|Root component|`TVCLPythia`|`TFMXPythia`|
|WebView host|Direct via WebView4Delphi VCL|`uWVFMXHost.pas` + `uWVFMXCoreInit.pas`|
|OpenDialog|`VCL.WVPythia.OpenDialog.pas`|`FMX.WVPythia.OpenDialog.pas`|
|Language manager|`TVCLPythiaLanguageManager`|`TFMXPythiaLanguageManager`|
|Public surface|Identical|Identical|
|Demo|`demos/VCL/new-projet`, `demos/VCL/pythia-sample`, `demos/VCL/pythia-anthropic`|`demos/FMX/new-projet`, `demos/FMX/plugin-git`, `demos/FMX/plugin-snippet`|

<br>

## 29 JS template catalog

The `TTemplateType` enumeration (`WVPythia.Template.Manager.pas`) associates each template with a file under `assets/scripts/`. The table below is the complete reference, ordered by enum value, and is the starting point for any substitution via `LoadCustomTemplate` (see §11) — the developer must locate the template to override starting from the UI area they want to modify.

| Enum | File | Role |
|---|---|---|
| `main_html` | `index.htm` | Root HTML skeleton; includes DOM containers and loads injected scripts |
| `js_response` | `DisplayTemplate.js` | Rendering of an assistant turn (markdown, code, citations) |
| `js_prompt` | `PromptTemplate.js` | Rendering of a user turn |
| `js_waitfor` | `ReasoningTemplate.js` | Animation and display of the reasoning (thinking) block |
| `js_inputbubble` | `InputBubbleTemplate.js` | Input bar: textarea, buttons, submit/stop state |
| `js_scrollButtons` | `ScrollButtonsTemplate.js` | Up/down scroll buttons |
| `js_images` | `DisplayImageTemplate.js` | Rendering of generated images |
| `js_promptFile` | `PromptFileTemplate.js` | Display of attachments inside the user turn |
| `js_audio` | `DisplayAudioTemplate.js` | Inline audio player |
| `js_video` | `DisplayVideoTemplate.js` | Inline video player |
| `js_displayfile` | `DisplayFileTemplate.js` | Clickable file card inside the assistant turn |
| `js_selector` | `SelectorTemplate.js` | Card selector (functions, MCP, skills, agents) |
| `js_confirmationDialog` | `ConfirmationDialogTemplate.js` | Two-step confirmation dialog (see §21) |
| `js_filesMenager` | `FilesDrawerTemplate.js` | Drawer of files attached to the input bar |
| `js_errors` | `ErrorsTemplate.js` | Rendering of error messages |
| `js_requestParams` | `RequestParamsTemplate.js` | Settings panel (temperature, top-p, system prompt…) |
| `js_bootstrapDictionary` | `BootstrapDictionaryTemplate.js` | i18n dictionary and `window.AppI18n.t` helper |
| `js_models` | `ModelsTemplate.js` | Model selector |
| `js_chatFooter` | `ChatFooterTemplate.js` | Chat footer (icons, statuses) |
| `js_cardSelector` | `CardSelectorTemplate.js` | Multi-card selection dialog |
| `js_promptSummary` | `PromptSummaryTemplate.js` | Compact summary of a submitted prompt |
| `js_inputDialog` | `InputDialogTemplate.js` | Modal input box (for example `/api-key new`) |
| `js_injectionEnded` | `InjectionEndedTemplate.js` | End-of-injection signal for JS |

23 entries in total: one HTML root and 22 JavaScript fragments.

<br>

## 30 Developer mode & diagnostics

The `DEV_MODE` conditional define enables diagnostic output useful during integration.

### Enabling `DEV_MODE`

In:

```
Project → Options → Compilation → Conditional defines
```

add:

```
DEV_MODE
```

Then rebuild completely, not incrementally.

### Debug exchange file

With `DEV_MODE` enabled, Pythia-Webview2 writes the last JSON message received from WebView2 to a debug exchange file near the executable or the application support path, depending on the project configuration. The file is overwritten on each message and is intended for direct observation of the payload that triggered the last handler.

Use this file when a handler behaves unexpectedly. It shows the exact JSON shape received by the Delphi event pipeline.

### Diagnostic prompt-state output

During integration, keep a way to inspect `TInputPromptState` received from the UI. A diagnostic handler can render the raw prompt-state JSON in the chat area:

```pascal
class function TToolContainer.ActivateInputState(
 const AState: TInputPromptState;
 const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
  Result := True;

  var LReader := TJsonReader.Parse(AState.Source);
  var JsonContent := TEscapeHelper.ToPreformattedHTML(LReader.Format());
  Form1.Pythia.Display(JsonContent, False);

  var Returns := TManagedItemLLMResult.Create;
  try
    Returns
      .UsedModel('diagnostic')
      .Response(JsonContent)
      .Error(False);

    if Assigned(AOnFinalize) then
      AOnFinalize(Returns);
  finally
    Returns.Free;
  end;
end;
```

This is the fastest way to verify selected model, selected cards, endpoint options, capabilities-related state, prompt text, and attached context.

### WebView2 DevTools

Right-click in the chat area and choose **Inspect**. Use:

- **Console** for JavaScript errors;
- **Network** for resource loading;
- **Elements** for DOM and CSS inspection.

This is especially useful when customizing JavaScript templates, CSS, or asset loading.

### Loading diagnostics

If the UI does not load correctly, first check:

- `Update` was called;
- `assets/` is at the expected level relative to `bin32` and `bin64`;
- `WebView2Loader.dll` is next to the executable and matches the target architecture;
- the support folder being edited is the active one.

<br>

## 31 Deployment

### Introduction

A deployed **Pythia-Webview2** application needs more than the executable. It must ship the matching WebView2 loader, the complete `assets` folder, and a predictable support-folder layout.

<br>

- [Deployment manifest](#deployment-manifest)
- [Pre-populate the configuration](#pre-populate-the-configuration)
- [WebView2 runtime](#webview2-runtime)
- [First-launch behavior](#first-launch-behavior)
- [Windows x86 vs x64 distribution](#windows-x86-vs-x64-distribution)

<br>

### Deployment manifest

For a standalone project, the expected structure is:

```
MyFirstPythia-Webview2
├── assets
│   ├── index.htm
│   ├── scripts
│   ├── media
│   └── lang
├── bin32
│   ├── MyFirstPythia-Webview2.exe
│   └── WebView2Loader.dll
├── bin64
│   ├── MyFirstPythia-Webview2.exe
│   └── WebView2Loader.dll
├── dcu
├── Main.pas
├── Main.dfm or Main.fmx
├── VCL.WVPythia.Services.pas
│   or
├── FMX.WVPythia.Services.pas
└── MyFirstPythia-Webview2.dproj
```

On first launch, Pythia-Webview2 creates the application support folder, for example:

```
bin32\MyFirstPythia-Webview2\support
```

or:

```
bin64\MyFirstPythia-Webview2\support
```

This folder contains generated or pre-filled JSON configuration files: capabilities, model list, runtime category configuration, cards, and other support files.

### Pre-populate the configuration

If the application ships with curated defaults, pre-fill the support folder before deployment. Typical files include:

- `<ExeName>-capabilities.json`;
- `<ExeName>-model-list.json`;
- `<ExeName>-model-get-replace-version.json`;
- card files such as `<ExeName>-function-cards.json`;
- other support files used by the application.

If these files already exist on first launch, Pythia-Webview2 can use them instead of generating default configuration files.

### WebView2 runtime

There are two separate elements:

```
WebView2Loader.dll
```

and the Microsoft Edge WebView2 Runtime.

`WebView2Loader.dll` is the DLL loaded by your application. It must sit next to the executable and match the architecture: use the `bin32` DLL for Win32 and the `bin64` DLL for Win64.

The WebView2 Runtime is the Microsoft Edge-based runtime installed on the target machine. Recent Windows installations often already have it, but clean or enterprise machines may require deployment.

The Evergreen Runtime is the recommended deployment mode for most applications because it is installed on the machine and updated automatically by Microsoft.

Microsoft provides:

- Evergreen Bootstrapper;
- Evergreen Standalone Installer;
- x86, x64, and ARM64 installers.

The bootstrapper downloads and installs the appropriate runtime for the machine. The standalone installer is better for offline environments or enterprise deployment.

### First-launch behavior

On first launch, WebView2 may create a per-user profile under the user's local application data. This is normal browser-runtime behavior.

For kiosk or disposable-session scenarios, decide explicitly whether the WebView2 user data folder should be preserved or cleaned at startup.

### Windows x86 vs x64 distribution

Binaries are produced under `bin32` or `bin64` depending on the target. Choose x64 by default unless a project constraint requires Win32. Always ship the matching `WebView2Loader.dll`.

<br>

## 32 Glossary

| Term | Definition |
|---|---|
| **Adapter** | Application class implementing `IChatManagedItemDialogService`, which acts as a bridge between UI events and business logic (see §8 adapter sub-section). |
| **Card** | Configuration unit for an integration (function, MCP, skill, agent, custom). Stored in a JSON file under `<ExeName>/support/`; displayed by the UI in the Cards panel (see §14). |
| **Capabilities** | Boolean configuration of features exposed by the application (endpoints, media, integrations…). Driven by `ICapabilities`, persisted in `<ExeName>-capabilities.json` (see §13). |
| **Custom event** | JSON message emitted by a JS template through `postMessage` with `event: "custom-event"`. Received on the Delphi side by `IChatManagedItemDialogService.ActivateCustomEvent` (see §23). |
| **Host** | Delphi application that embeds the **Pythia-Webview2** component. |
| **Managed item** | Item selectable from the UI: a card or an integration option. Represented by `TChatManagedItemRef` (Id + Name) when returned from a selection. |
| **Plugin (command)** | Class implementing a slash command. Inherits from `TCommandPlugin`, wired via `Pythia.OnRegisterCommandPlugins` (see §12). |
| **Prompt state** | Snapshot of the input bar at submission time. Type: `TInputPromptState`. Received by `IVendorServices.AsyncAwaitStreamChat` (see §16). |
| **Template** | JS fragment injected into the WebView to render a portion of the UI. 22 templates shipped; each can be overridden via `LoadCustomTemplate` (see §11 and §29). |
| **Turn** | A `user prompt / assistant response` pair in a chat session. Type: `TChatTurn`. |
| **Vendor** | Application service implementing `IVendorServices`, which actually talks to the LLM API (Anthropic, OpenAI, etc.). Wired through the adapter (see §16). |
| **WebView (host)** | `TWVBrowser` component on the VCL side, or the `TWVFMXBrowser` + `TWVFMXHost` + `TWVFMXCoreInit` stack on the FMX side, hosting the WebView2 runtime. |

<br>

## 33 Security & limits

### Introduction

Pythia-Webview2 is designed as a **trusted local WebView2 client** controlled by the host Delphi application. It is not a general-purpose browser, not a sandbox for arbitrary web content, and not a secret-management product. Its security model is intentionally simple: local UI assets are rendered in WebView2, events are routed back to Delphi through explicit contracts, and application-specific security decisions remain under the integrator's control.

The default posture is suitable for a local desktop application, provided the host application keeps the embedded UI constrained and validates any data that crosses the JavaScript ↔ Delphi boundary.

<br>

- [Secret storage](#secret-storage)
- [Embedded WebView2 surface](#embedded-webView2-surface)
- [HTML, Markdown, and escaping](#html-markdown-and-escaping)
- [WebView2 permissions](#webView2-permissions)
- [Custom events](#custom-events)
- [Custom templates](#custom-templates)
- [JSON and threading](#json-and-threading)
- [Scope of responsibility](#scope-of-responsibility)

<br>

### Secret storage

API key values are stored through `ISecretStore`. The default implementation stores secrets in the current user's Windows Registry.

By default, these values benefit from the operating system's user-level isolation: they are protected by the current Windows user context. No additional cryptographic protection is applied by Pythia-Webview2 itself.

Applications with stricter requirements may replace the default store with another `ISecretStore` implementation, for example DPAPI-backed storage, an encrypted local store, an enterprise vault, or a hardware-backed secret provider. The API key service does not need to be changed as long as the replacement keeps the same `ISecretStore` contract.

<br>

### Embedded WebView2 surface

The WebView2 surface is intended to host Pythia-Webview2's local UI: `assets/index.htm` and the JavaScript templates shipped with the project. It is not intended to behave as a general-purpose browser.

The embedded UI is constrained by two layers:

1. a Content Security Policy declared in `assets/index.htm`;
2. a host-side navigation filter that blocks unauthorized external navigation.

The default CSP allows the local UI context and selected trusted origins used by the frontend dependencies, such as `https://cdn.jsdelivr.net`, as well as the local application origin used for media resources, such as `https://app.local`.

Applications requiring a fully offline deployment should package CDN-hosted dependencies locally and adjust the CSP accordingly.

Custom templates should use the existing WebView2 bridge:

```javascript
window.chrome.webview.postMessage({ event: "custom-event", name: "...", payload: {} });
```

They should not rely on arbitrary browser navigation to communicate with the host application.

Any change that relaxes the CSP, allows additional navigation targets, loads remote UI content, or renders untrusted HTML/Markdown output should be treated as a security-sensitive change.

<br>

### HTML, Markdown, and escaping

The chat UI renders rich content, including Markdown and code blocks. Host applications must not inject user-provided HTML into the DOM without escaping or sanitizing it first.

Use `WVPythia.Strings.Escape.pas` for the built-in escaping helpers:

- `EscapeJSString` when injecting text into a JavaScript literal;
- `EscapeHTML` when rendering text into the DOM.

Pythia-Webview2 does not currently provide a dedicated URL encoder. Add one in the host application if URLs are built from user-controlled input.

<br>

### WebView2 permissions

The default WebView2 permission surface is intentionally narrow.

When browser-side audio capture is enabled by the host application, microphone access may be granted automatically to support local audio features such as Speech-to-Text. This permission is limited to `COREWEBVIEW2\_PERMISSION\_KIND\_MICROPHONE`.

Other WebView2 permissions are not granted automatically by the default implementation.

Applications that relax the navigation policy, load remote UI content, or render untrusted HTML/Markdown output should review the permission policy before deployment.

<br>

### Custom events

The `custom-event` channel is deliberately flexible: Pythia-Webview2 forwards the raw JSON payload to the application adapter and does not impose a typed schema on it.

This means that validation is the responsibility of the application code.

Recommended practice:

* require a stable `name` field for routing;
* validate the presence and shape of `payload`;
* reject unknown event names;
* define a `requestId` convention if the host application needs request/response correlation;
* never execute privileged native operations directly from unvalidated JavaScript payloads.

The bridge is intentionally small. Structured responses, authorization rules, and business-level validation belong to the host application.

<br>

### Custom templates

All JavaScript templates execute in the same WebView2 context. Pythia-Webview2 does not provide a separate JavaScript sandbox for user-authored templates.

Custom templates should therefore be treated as trusted application code. They should keep their global footprint minimal, prefer IIFE-style encapsulation, and communicate with Delphi only through the documented `postMessage` channel.

<br>

### JSON and threading

JSON parsing should go through the framework helpers, especially:

```pascal
TJsonReader.Parse(...)
```

Do not share a `TJsonReader` instance across threads.

For asynchronous vendor calls, copy mutable prompt state into a stable value representation before capturing it in callbacks. In practice, vendor services should convert `TInputPromptState` to `TStateBuffer` as soon as `AsyncAwaitStreamChat` starts.

<br>

### Scope of responsibility

Pythia-Webview2 provides the UI, event bridge, persistence helpers, and integration contracts. It does not validate vendor API policies, business authorization rules, external tool execution, card payload semantics, or organization-specific compliance requirements.

Those decisions belong to the host application.

A deployment that keeps the WebView2 surface local, blocks unauthorized navigation, validates custom events, and treats CSP/permission changes as security-sensitive remains within the intended security model.



<br>

## 34 FAQ / pitfalls

### "The chat appears, but submitting a prompt does nothing"

Most likely, the service adapter is missing, assigned too late, or the wrong service unit is being used.

Check the main form:

```pascal
Pythia := TVCLPythia.Create(Panel2);
Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
Pythia.Update;
```

For FMX, also check `AttachHost(Self)`:

```pascal
Pythia := TFMXPythia.Create(Layout1);
Pythia.AttachHost(Self);
Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;
Pythia.Update;
```

### "DialogService not assigned"

The Pythia-Webview2 UI loaded, but no service adapter was available when the communication chain initialized.

Typical causes:

- `ServiceAdapter` was not assigned;
- it was assigned after `Update`;
- `VCL.WVPythia.Services.pas` or `FMX.WVPythia.Services.pas` was not added to the Delphi project;
- the VCL service unit was used in an FMX project, or the reverse;
- a manually written adapter did not override the required methods.

### "The application starts, but WebView2 does not initialize correctly"

Check `WebView2Loader.dll`.

It must be placed next to the executable and must match the target architecture:

```
bin32\WebView2Loader.dll  → Win32 executable
bin64\WebView2Loader.dll  → Win64 executable
```

The target machine must also have the Microsoft Edge WebView2 Evergreen Runtime installed.

### "Assets fail to load"

Check that the complete `assets` folder is present at the same level as `bin32` and `bin64`:

```
MyProject
├── assets
├── bin32
└── bin64
```

Do not copy only `index.htm`. The `scripts`, `media`, and `lang` subfolders are part of the runtime surface.

### "Cards do not appear"

Check three things:

1. the relevant `Integration*` capability is enabled;
2. the matching card JSON is valid;
3. you are editing the active support folder, for example `bin32\MyProject\support` rather than another copied folder.

### "The card is selected, but the vendor does not receive the schema"

The prompt state carries selected card identities such as `Id` and `Name`. It does not necessarily carry the full `content` payload from the card JSON.

Resolve `Item.Id` inside the service layer, load the matching card definition, parse `content`, then inject the schema or manifest into the vendor request.

### "My API key is requested repeatedly"

Check that the same logical key name is used everywhere:

```pascal
TAnthropicServices.API_KEY_NAME = 'anthropic'
```

The constructor, secret store read, automatic `/api-key new anthropic` command, `OnApiKeyChanged`, and `UpdateApiKey` should all use the same constant.

### "My API key isn't found"

Names are normalized. `Anthropic`, `ANTHROPIC`, and `anthropic` refer to the same logical name after normalization.

If a custom `ISecretStore` is used, verify that it applies the same naming policy expected by the rest of the application.

### "No default model configured"

A visible or reachable operation category has no valid default model.

Check:

- the model exists in `<ExeName>-model-list.json`;
- the category in `<ExeName>-model-get-replace-version.json` has `visible: true` only when it is supported;
- the category `model` value matches an existing model `id`;
- unsupported categories are hidden with `visible: false`.

### "Model selector shows unexpected data"

You may be editing the wrong support folder, or the generated default file may not have been replaced.

Check the active folder under the running target:

```
bin32\<ExeName>\support
bin64\<ExeName>\support
```

Also check that the model list and runtime category configuration agree on category ids.

### "My custom-event is ignored"

Check the JSON shape:

- `event` must be literally `custom-event`;
- `name` must be present;
- `payload` must be present, even if empty.

The framework forwards the raw custom payload. Application-level validation and routing belong to the service adapter or host logic.

### "JS template not reloaded in dev"

Check that `TemplateAllwaysReloading(...)` was called on the provider and that the application was restarted. The original method name preserves the typo `Allways`.

### "Confirmation dialog loops"

Use the two-step pattern:

1. the request event records the pending action and opens the dialog;
2. only `dialog-confirmation-response` executes the action.

Do not execute the destructive action in the initial request handler.

<br>

