# Build Your First Application Based on Pythia-Webview2

A step-by-step, hands-on guide that takes you from the official Pythia-Webview2 starter project pattern to a working LLM chat application.

The recommended way to start is **not** to create a Delphi project from scratch. The recommended path is to clone one of the minimal project patterns provided with the repository:

```
<Pythia-Webview2>\demos\VCL\new-projet
```

or:

```
<Pythia-Webview2>\demos\FMX\new-projet
```

Use the first one for a **VCL** application and the second one for an **FMX** application.

These starter projects already contain the expected structure, the browser setup, and the ready-to-use service unit. Starting from them avoids most common setup mistakes: missing `ServiceAdapter`, incorrect output folder, missing `assets`, or missing `WebView2Loader.dll`.

A fully manual setup from an empty Delphi project is still possible, but it should be treated as an advanced path used mainly to understand the wiring.

This tutorial assumes you have read — or at least skimmed — the main reference at [pythia-documentation.md](../../docs/pythia-documentation.md#pythia--documentation). Whenever a step touches a concept covered in depth there, this guide points to the matching section.

## Table of Contents

- [Who this guide is for](#who-this-guide-is-for)
- [What you will build](#what-you-will-build)
- [What you will learn](#what-you-will-learn)
- [Prerequisites](#prerequisites)
- [Step 1 — Set up your project from the starter pattern](#step-1--set-up-your-project-from-the-starter-pattern)
- [Step 2 — Verify the minimal chat surface](#step-2--verify-the-minimal-chat-surface)
- [Step 3 — Check the service adapter](#step-3--check-the-service-adapter)
- [Step 4 — Connect an LLM vendor](#step-4--connect-an-llm-vendor)
- [Step 5 — Configure capabilities](#step-5--configure-capabilities)
- [Step 6 — Add tool cards](#step-6--add-tool-cards)
- [Step 7 — Configure models and default categories](#step-7--configure-models-and-default-categories)
- [Step 8 — Theming and internationalization optional](#step-8--theming-and-internationalization-optional)
- [Step 9 — Test, observe, iterate](#step-9--test-observe-iterate)
- [Step 10 — Deploy](#step-10--deploy)
- [Where to go next](#where-to-go-next)

___

<br>

## Who this guide is for

You are a Delphi developer — VCL or FMX — who wants to add a chat interface backed by a Large Language Model to your application. You are comfortable opening and adapting a Delphi project, working with `uses` clauses, configuring project paths, and editing JSON.

You do **not** need to know JavaScript, HTML, or the inner workings of WebView2. Pythia-Webview2 takes care of that integration layer for you.

If you have never built any Delphi application before, this guide is too advanced. If you have built Delphi applications but never integrated WebView2, this guide is the right starting point.

## What you will build

By the end of this tutorial you will have a desktop application that:

- displays a modern chat interface, similar to ChatGPT or Claude,
- streams answers from a real LLM provider,
- exposes configurable function, MCP, skill, agent, and custom cards,
- lets the end user pick the model from a curated list,
- ships with a configurable feature surface through capabilities,
- runs from a predictable `bin32` / `bin64` layout with `WebView2Loader.dll`, the `assets` folder, and generated or pre-filled support configuration files.

The final standalone structure is simple: one Delphi project, one browser host, one service unit, a `bin32` or `bin64` output folder, the `assets` folder, and a support folder generated on first launch.

## What you will learn

Along the way you will see:

1. how to start from the official VCL or FMX `new-projet` template and adapt it to your application,
2. why the **service adapter** is the central piece of glue between the browser UI and your Delphi code,
3. how to plug in a real LLM vendor through `IVendorServices`,
4. how to control what the UI exposes through capabilities,
5. how to populate cards, model lists, and default model categories by editing JSON,
6. how to inspect the data exchanged between WebView2 and Delphi,
7. what to ship when you deploy to a target machine.

## Prerequisites

Before you start, make sure you have:

| Requirement | Notes |
|---|---|
| Delphi 11, 12, or 13 | RTTI Generics required. Older versions are not supported. |
| The Pythia-Webview2 repository cloned locally | You need access to `source/`, `assets/`, `bin32/`, `bin64/`, and the starter projects under `demos/VCL/new-projet` and `demos/FMX/new-projet`. |
| The official WebView4Delphi repository cloned locally | Recommended for real projects. The bundled `dependencies/WebView4Delphi/source` path is useful for demos and quick discovery, but the official clone should be preferred for application work. |
| Microsoft Edge WebView2 Evergreen Runtime installed or available | Without the runtime, the WebView2 surface cannot render. |
| An API key for at least one LLM vendor | Anthropic, OpenAI, Mistral, or another provider depending on the vendor service you implement. |
| 30 to 60 minutes | The path is short; most of the time is spent checking each layer before moving on. |

You do **not** need npm, Node.js, Python, Docker, or any non-Delphi tooling. Pythia-Webview2 is a pure Delphi library; the JavaScript layer ships pre-bundled inside `assets`.

<br>

## Step 1 — Set up your project from the starter pattern

**Goal:** start from the official minimal project pattern and make sure Delphi paths, output folders, WebView2 loader, and assets are all in the expected places.

<br>

### 1.1 Clone the starter project pattern

Choose the project pattern that matches your framework:

```
<Pythia-Webview2>\demos\VCL\new-projet
```

or:

```
<Pythia-Webview2>\demos\FMX\new-projet
```

Use the first one for VCL and the second one for FMX.

Copy the folder, then rename the folder, the Delphi project, and the files as needed for your application.

These starter projects are intended to be minimal skeletons for applications based on Pythia-Webview2. They already contain the expected structure, the browser setup, and the ready-to-use service unit:

```
VCL.WVPythia.Services.pas
```

or:

```
FMX.WVPythia.Services.pas
```

Starting from these templates avoids most common setup issues: missing `ServiceAdapter`, incorrect output folder, missing `assets`, or missing `WebView2Loader.dll`.

<br>

### 1.2 Define IDE environment variables

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

These variables make the project easier to move between machines or folders without rewriting all paths manually.

<br>

### 1.3 Configure the project search paths

In Delphi, open:

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

<br>

### 1.4 Configure output folders

Pythia-Webview2 resolves several paths from the executable location. Keep a consistent structure around `bin32`, `bin64`, and `assets`.

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

This can be useful because `WebView2Loader.dll` and the `assets` folder are already available in the expected structure.

For a standalone application, keep your own project structure and copy the required files into it.

<br>

### 1.5 Check `WebView2Loader.dll`

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

<br>

### 1.6 Check the `assets` folder

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

during development, without copying the assets into your own project immediately.

For deployment, ship your own copy of the `assets` folder with your executable.

### Checkpoint

You have cloned the appropriate `new-projet` template, configured the Delphi environment variables, set the search paths, verified the output directory, checked `WebView2Loader.dll`, and made sure the `assets` folder is available at the expected level.

<br>

## Step 2 — Verify the minimal chat surface

**Goal:** run the starter project and confirm that the Pythia-Webview2 chat surface renders correctly.

<br>

### 2.1 Open the starter project

Open the Delphi project copied from:

```
<Pythia-Webview2>\demos\VCL\new-projet
```

or:

```
<Pythia-Webview2>\demos\FMX\new-projet
```

The starter project already contains the minimal browser setup and the matching service unit.

For VCL, the service unit is:

```
VCL.WVPythia.Services.pas
```

For FMX, the service unit is:

```
FMX.WVPythia.Services.pas
```

<br>

### 2.2 Run it

Press F9.

You should see:

- the form opens,
- the WebView2 host warms up,
- the Pythia-Webview2 chat interface appears,
- the input bar is visible at the bottom.

If you type a prompt and press Enter, the starter service should receive the event. Depending on the template behavior, it may display a diagnostic response, a JSON dump, or a placeholder result.

<br>

### 2.3 What just happened

The starter project gives you:

- the Delphi host application,
- the WebView2-backed chat surface,
- the browser setup,
- the service adapter unit,
- the expected output structure,
- the support folder created on first launch.

On first launch, Pythia-Webview2 creates an application support folder such as:

```
bin32\MyProject\support
```

or:

```
bin64\MyProject\support
```

This folder contains generated or pre-filled JSON configuration files: capabilities, model list, category configuration, cards, and other support files.

### Checkpoint

The chat surface renders and the starter project has created its support configuration folder.

<br>

## Step 3 — Check the service adapter

**Goal:** make sure browser events can reach your Delphi code.

The service adapter is the routing layer between WebView2 browser events and Delphi-side business logic. Prompt submissions, copy actions, card selections, custom events, and other UI messages are forwarded through it.

<br>

### 3.1 Locate the service adapter unit

If you started from `demos\VCL\new-projet`, the service unit is already present:

```
VCL.WVPythia.Services.pas
```

If you started from `demos\FMX\new-projet`, the service unit is already present:

```
FMX.WVPythia.Services.pas
```

You do not need to copy the adapter from `pythia-sample` when using the official starter project pattern.

The sample adapters are still useful as references:

- `demos\VCL\pythia-sample\VCL.WVPythia.Services.pas` — diagnostic skeleton, useful for understanding event routing.
- `demos\VCL\pythia-anthropic\VCL.WVPythia.Services.pas` — adapter wired to a real Anthropic vendor.

Only copy one of these manually if you deliberately started from an empty Delphi project or if you want to replace the starter service unit with a more specific sample implementation.

<br>

### 3.2 Verify that the adapter is assigned before `Update`

The starter project should already assign the service adapter before calling `Update`.

For a VCL project, the structure should be equivalent to:

```pascal
uses
  ...,
  VCL.WVPythia.Chat, WVPythia.Types,
  VCL.WVPythia.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel2);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.Update;
end;
```

The important order is:

```
Create browser
Assign ServiceAdapter
Call Update
```

If the adapter is missing, or if it is assigned after `Update`, the UI can render but prompt submissions and other browser events will not reach your Delphi code.

<br>

### 3.3 If you see `DialogService not assigned`

The warning:

```
DialogService not assigned
```

means that the Pythia-Webview2 interface has been loaded, but no service adapter is available to route UI events back to Delphi.

Typical causes are:

- `ServiceAdapter` was not assigned,
- `ServiceAdapter` was assigned after `Pythia.Update`,
- the service unit exists on disk but was not added to the Delphi project,
- the VCL service unit was used in an FMX project, or the reverse.

For VCL, check that the project includes `VCL.WVPythia.Services.pas` and that the main form uses it:

```pascal
uses
  VCL.WVPythia.Chat,
  WVPythia.Types,
  VCL.WVPythia.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel2);

  Pythia.ServiceAdapter :=
    TVCLChatManagedItemDialogService.Create;

  Pythia.Update;
end;
```

For FMX, check that the project includes `FMX.WVPythia.Services.pas`, attach the host form, then assign the adapter before `Update`:

```pascal
uses
  FMX.WVPythia.Chat,
  WVPythia.Types,
  FMX.WVPythia.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TFMXPythia.Create(Panel2);
  Pythia.AttachHost(Self);

  Pythia.ServiceAdapter :=
    TFMXChatManagedItemDialogService.Create;

  Pythia.Update;
end;
```

Once the adapter is properly wired, prompt submission, card selection, copy actions, and custom events can be transmitted to the Delphi application code.

<br>

### 3.4 Understand the event chain

Once the adapter is in place, the flow is:

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
Application service methods
          │
          ▼
Business logic / vendor service
```

The adapter should remain thin. Its job is to route UI events to stable Delphi-side services.

### Checkpoint

Submitting a prompt now produces a visible reaction or reaches the service adapter. The wiring between browser UI and Delphi code is in place.

<br>

## Step 4 — Connect an LLM vendor

**Goal:** replace the diagnostic behavior with a real call to an LLM.

This step is the heart of the integration. The example below uses an Anthropic-style vendor service, but the structure is identical for any provider. Only the SDK calls inside the vendor implementation change.

LLM-related processing must be executed asynchronously so the user interface remains responsive. Network calls, streaming, and long-running generations should not be performed directly on the UI thread.

<br>

### 4.1 Add a vendor service

A vendor service should implement the application-side contract used by your adapter. In the sample architecture, this role is represented by an `IVendorServices` implementation.

If you use the Anthropic sample as a starting point, copy the relevant vendor units from the sample project into your own project and add them to the Delphi project.

Typical files are:

```
Anthropic.Browser.Services.pas
Anthropic.Browser.Helpers.pas
```

You will also need the corresponding vendor SDK source path in the Delphi search path.

For another provider, create the equivalent service unit for that provider.

<br>

### 4.2 Route prompt submission to the vendor

In the service unit, locate the method that handles prompt activation. In the sample architecture this is usually the method that receives `TInputPromptState` and a finalization callback.

A diagnostic implementation may look like this:

```pascal
class function TToolContainer.ActivateInputState(
 const AState: TInputPromptState;
 const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
(*
   NOTE:
   - In this method, we recommend asynchronous processing to avoid UI blockage.
   - This asynchronous processing must include the `var Returns...` section
     shown below at the end of the process.
*)

  Result := True;
  Form1.Pythia.Display('test...');

  var Returns := TManagedItemLLMResult.Create;
  try
    Returns
      .UsedModel('my_model')
      .Response('test...')
      .Error(False);

    if Assigned(AOnFinalize) then
      AOnFinalize(Returns);

  finally
    Returns.Free;
  end;end;
```

Replace the diagnostic behavior with a call to your vendor service:

```pascal
class function TToolContainer.ActivateInputState(
 const AState: TInputPromptState;
 const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
 Result := True;
 AnthropicVendor.AsyncAwaitStreamChat(AState, AOnFinalize);
end;
```

Add the vendor service unit to the `uses` clause.

<br>

### 4.3 Declare the Anthropic API key name in the vendor service

The API key name should be owned by the Anthropic vendor service, not duplicated in the application code or typed manually by the user.

In `Anthropic.Browser.Services.pas`, declare a single constant on the service class:

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

The value `anthropic` is the key name used by the browser secret store. Keep this name consistent everywhere the Anthropic service reads, creates, or refreshes the secret.

<br>

### 4.4 Request the API key automatically when the service starts

The user should not have to run `/api-key new anthropic` manually. The Anthropic service can trigger the same command by itself when it is instantiated and the key does not already exist.

In the service constructor, read the secret first. If it is missing, ask the browser to handle the API-key command programmatically:

```pascal
constructor TAnthropicServices.Create(const ABrowser: IPythiaBrowser);
var
  Anthropic_key: string;
begin
  {--- The service is built around two collaborators: the browser-facing UI
       abstraction and the Anthropic SDK client used for remote execution. }
  FBrowser := ABrowser;

  if not FBrowser.ApiKeySecretStore.ReadSecret(API_KEY_NAME, Anthropic_key) then
    FBrowser.TryHandleAsCommand(Format('/api-key new %s', [API_KEY_NAME]));

  FClient := TAnthropicFactory.CreateInstance(Anthropic_key);
end;
```

With this pattern, the slash command remains the underlying mechanism, but it is launched by the service. On first launch, if the `anthropic` key is absent, the application asks for it automatically during Anthropic service initialization.

When the key is added or changed, refresh the SDK client from the same secret name:

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

The important point is that both methods use `API_KEY_NAME`. The constructor uses it to trigger the initial request when the key is missing. `UpdateApiKey` uses it to reload the stored secret into the Anthropic client.

Instantiate the vendor after the form is shown, once the browser is initialized. One simple pattern is to delay the initialization, then create the Anthropic service from `DoInitialize`:

```pascal
uses
  ...,
  System.Threading,
  VCL.WVPythia.Chat, WVPythia.Types,
  VCL.WVPythia.Services,
  Anthropic.Browser.Services;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel2);
  Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
  Pythia.OnApiKeyChanged := UpdateApiKey;
  Pythia.Update;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  DelayedFormshow;
end;

procedure TForm1.DelayedFormshow;
begin
  TTask.Run(
    procedure()
    begin
      Sleep(1200);
      TThread.Queue(nil,
        procedure
        begin
          DoInitialize;
        end);
    end);
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

For another provider, keep the same structure and change only the service class, the SDK factory, and the constant value used as the key name.

<br>

### 4.5 Run a real prompt

Type a normal prompt in the chat input and press Enter.

You should see:

- the user prompt rendered in the chat,
- a waiting or thinking state while the vendor responds,
- the answer streamed chunk by chunk,
- final markdown formatting once the stream is complete.

<br>

### 4.6 Protect long-running streams with a state buffer

When a vendor streams an answer asynchronously, do not capture `TInputPromptState` directly inside long-lived closures.

`TInputPromptState` is an object reference. The component may free it before a long streaming request finishes. If a closure captures the original object and accesses it later, the application may crash with an invalid memory access.

Use a value-copy buffer at the beginning of the vendor method:

```pascal
var State := TStateBuffer.FromState(AState);
```

Then capture the buffer in asynchronous callbacks, not the original `AState` object.

### Checkpoint

You have a working chat that can call a real LLM vendor. The rest of the guide is configuration and deployment polish.

<br>

## Step 5 — Configure capabilities

**Goal:** decide what the UI exposes to the user.

On first launch, Pythia-Webview2 creates support configuration files. The capabilities file controls which UI features are visible or available.

For exploration, it is convenient to keep many features enabled. For a focused application, disable what your vendor or product does not support.

<br>

### 5.1 Two ways to configure

You can configure capabilities in code through the fluent builder:

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
 .Project(True)
 .Update;
```

Or by editing the generated capabilities JSON file in the support folder:

```
bin32\MyProject\support\MyProject-capabilities.json
```

Example:

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
  "model": true,
  "project": true
}
```

Both routes converge on the same UI state. Editing JSON is fast during integration. The builder is better when the configuration should be locked in code.

<br>

### 5.2 Common capability groups

The exact catalog is described in the main documentation. Common groups include:

| Capability group | Purpose |
|---|---|
| `Thinking` and thinking tiers | Show or hide reasoning-related controls. |
| `Vision` | Allow image input or vision-related UI. |
| `Files` and `KnowledgeSearch` | Control file and knowledge-related input surfaces. |
| `Integration*` | Show or hide card families. |
| `Media*` | Control image, audio, and video generation surfaces. |
| `WebSearch` and `DeepResearch` | Toggle research-oriented tools. |
| `Model` | Show or hide the model selector. |
| `Project` | Show or hide the project folder surface: register one or more folders where projects are installed and pick a default project for the session. |

### Checkpoint

The chat UI now reflects the features your application actually supports.

<br>

## Step 6 — Add tool cards

**Goal:** populate the cards panel with real, business-meaningful tools.

Cards are the unit of configuration for tool integration. There are several families, such as:

- `function`,
- `mcp`,
- `skills`,
- `agents`,
- `custom`.

Each family is stored in a corresponding JSON file under the application support folder.

<br>

### 6.1 Start with function cards

For a first integration, function cards are usually the simplest. They map naturally to function-calling or tool-calling APIs.

Open the generated function-card file in the support folder, for example:

```
bin32\MyProject\support\MyProject-function-cards.json
```

<br>

### 6.2 Edit the JSON

Example:

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
| `commentaire` | Description shown in tooltip or subtitle. |
| `badge` | Optional small label such as `Beta` or `Pro`. |
| `content` | Free-form payload. Pythia-Webview2 does not interpret it. Your vendor decides its meaning. |

`content` is shown here as a JSON string, so quotes inside it are escaped. If your application expects `content` as an object instead of a string, keep the structure consistent with your own parser.

<br>

### 6.3 Receive the selection in your vendor

When the user ticks cards and submits a prompt, the selected functions arrive in `TInputPromptState.Integration.Function` as items containing identity data such as `Id` and `Name`.

Example pattern:

```pascal
for var Item in State.Integration.&Function do
begin
  // Item.Id   identifies the selected card.
  // Item.Name is the label visible to the user.

  // Look up the matching card content from your JSON file,
  // parse it, and inject the resulting schema into the vendor request.
end;
```

The full `content` payload of the card is not necessarily carried inside `TInputPromptState`. Keep the prompt state lightweight and resolve `id` to full card payload inside your service layer.

### Checkpoint

Cards appear in the UI. Selecting them sends identity data through the prompt state, and the vendor can resolve selected cards to executable tool schemas.

<br>

## Step 7 — Configure models and default categories

**Goal:** offer the user a curated list of models and make sure every visible operation category has a valid default model, or is intentionally left for the user to assign.

There are two separate configuration levels:

1. the list of models available in the application;
2. the runtime category configuration that decides which categories are visible and which model is currently selected for each category.

<br>

### 7.1 Declare the available models

The generated model list file is stored under the support folder, for example:

```
bin32\MyProject\support\MyProject-model-list.json
```

This file declares the models that the application knows about. A model can only be used as the default model of a category if it is first declared here.

Example:

```json
{
  "type": "model-selector-set-data",
  "models": [
    {
      "id": "text-generation-example",
      "label": "One of text generation model",
      "capabilityLabels": ["Thinking", "Vision"],
      "categoryId": "textGeneration"
    },
    {
      "id": "image-creation-example",
      "label": "One of image creation model",
      "capabilityLabels": ["Create Image"],
      "categoryId": "imageCreation"
    },
    {
      "id": "video-creation-example",
      "label": "One of video creation model",
      "capabilityLabels": ["Create Video"],
      "categoryId": "videoCreation"
    },
    {
      "id": "audio-creation-example",
      "label": "One of audio creation model",
      "capabilityLabels": ["Create Audio", "Text to speech"],
      "categoryId": "audioCreation"
    },
    {
      "id": "text-to-speech-example",
      "label": "One of text to speech model",
      "capabilityLabels": ["Text to speech"],
      "categoryId": "textToSpeech"
    },
    {
      "id": "speech-to-text-example",
      "label": "One of speech to text model",
      "capabilityLabels": ["Speech to text"],
      "categoryId": "speechToText"
    },
    {
      "id": "deep-research-example",
      "label": "One of deep research model",
      "capabilityLabels": ["Deep Research"],
      "categoryId": "deepResearch"
    }
  ],
  "activeCategoryId": "allModels",
  "selectedModelId": ""
}
```

This mirrors the default model list generated on first launch, which seeds one entry per category: `textGeneration`, `imageCreation`, `videoCreation`, `audioCreation`, `textToSpeech`, `speechToText`, and `deepResearch`. Replace the example `id` values with the exact model identifiers expected by your vendor implementation.

Field meaning:

| Field | Purpose |
|---|---|
| `id` | UI-side identifier. It can be an alias or the exact vendor model name, depending on your adapter. |
| `label` | Human-readable label shown in the selector. |
| `capabilityLabels` | Tags displayed under the label. |
| `categoryId` | Category such as `textGeneration`, `imageCreation`, `videoCreation`, `audioCreation`, `textToSpeech`, `speechToText`, or `deepResearch`. |

<br>

### 7.2 Configure visible categories and their default model

The second configuration level is the runtime model-selector category configuration, usually stored in:

```
bin32\MyProject\support\MyProject-model-get-replace-version.json
```

This file defines:

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
      "model": "text-generation-example",
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
      "model": "image-creation-example",
      "visible": true
    },
    {
      "id": "videoCreation",
      "label": "Video Creation",
      "badge": "",
      "sourceCategoryId": "image",
      "featureLabels": ["Create Video"],
      "model": "",
      "visible": false
    },
    {
      "id": "audioCreation",
      "label": "Audio creation",
      "badge": "",
      "sourceCategoryId": "audio",
      "featureLabels": ["Create Audio"],
      "model": "audio-creation-example",
      "visible": false
    },
    {
      "id": "textToSpeech",
      "label": "Text to speech",
      "badge": "",
      "sourceCategoryId": "audio",
      "featureLabels": ["Text to speech"],
      "model": "text-to-speech-example",
      "visible": true
    },
    {
      "id": "speechToText",
      "label": "Speech to text",
      "badge": "",
      "sourceCategoryId": "audio",
      "featureLabels": ["Speech to text"],
      "model": "speech-to-text-example",
      "visible": true
    },
    {
      "id": "deepResearch",
      "label": "Deep Research",
      "badge": "",
      "sourceCategoryId": "deepResearch",
      "featureLabels": ["Deep Research"],
      "model": "deep-research-example",
      "visible": true
    }
  ],
  "type": "model-selector-set-runtime-config"
}
```

This mirrors the runtime category configuration of a real project: one entry per category (`allModels`, `textGeneration`, `imageCreation`, `videoCreation`, `audioCreation`, `textToSpeech`, `speechToText`, `deepResearch`), each linked to a source category, with its own `model` default and `visible` flag.

The important field is:

```json
"model": "text-generation-example"
```

It defines the default model for that category. The value must match the `id` of a model declared in `<exeName>-model-list.json`.

A visible category with an empty `model` field means that the category is exposed in the UI, but no model has been selected for it yet:

```json
{
  "id": "imageCreation",
  "label": "Image Creation",
  "model": "",
  "visible": true
}
```

This can be intentional if you want the user to make the first selection from the model configuration panel. Once the user selects a model, that choice is persisted.

<br>

### 7.3 Avoid `No default model configured` warnings

Warnings such as:

```
No default model: text generation cannot be processed
No default model configured: Image creation aborted
No default model configured: Video creation aborted
No default model configured: Audio creation aborted
No default model configured: TTS operation aborted
No default model configured: STT operation aborted
No default model configured: Deep Research operation aborted
```

mean that the requested operation category is visible or reachable, but no default model is currently assigned to it.

Before shipping, choose one of two strategies for every visible category.

| Strategy | Configuration | Result |
|---|---|---|
| Provide a default model | `visible: true` and `model` contains a valid model id | The feature can be used immediately. |
| Let the user choose | `visible: true` and `model` is empty | The first use may show a warning until the user selects a model. |

If a category is not supported by the application, or if no matching model is provided, hide it:

```json
{
  "id": "videoCreation",
  "label": "Video Creation",
  "model": "",
  "visible": false
}
```

<br>

### 7.4 User-side correction in production

In production, the user should not edit JSON files manually.

If the user sees a warning such as:

```
No default model configured: Image creation aborted
```

it means that the category is visible, but no image model is currently selected for it.

The user-side procedure is:

1. open the model configuration panel;
2. look for categories marked as not assigned, usually with a red dot;
3. select the relevant category, such as Text Generation, Image Creation, Video Creation, Audio Creation, Text to Speech, Speech to Text, or Deep Research;
4. choose one of the compatible models from the filtered list;
5. retry the operation.

The developer decides which categories exist and are visible. The user only chooses or changes the current model for visible categories.

<br>

### 7.5 Read the selected model in the vendor

Inside the vendor service, read the selected model from the buffered state and convert it into the exact model identifier expected by the vendor SDK.

A sample architecture may use an indexed category lookup, for example:

```pascal
State.Model := State.Models.Items[TEXT_GENERATION_INDEX].Model;
```

Make sure the `categoryId` values in the model list and the category ids in the runtime configuration match what the vendor service expects. If the category does not match, the vendor may read the wrong slot or fail to find a default model.

### Checkpoint

The model list declares the available models, the runtime category configuration defines which categories are visible, and every visible category either has a valid default model or is intentionally left for the user to assign.

<br>
## Step 8 — Theming and internationalization optional

**Goal:** polish the UI to match your application identity.

These steps are optional for a first MVP, but useful for a product-quality integration.

<br>

### 8.1 Theme synchronization

When the user switches between light and dark themes in the Pythia-Webview2 settings panel, the host application's chrome may need to follow.

For VCL, hook `OnThemeChanged` and apply the matching VCL style:

```pascal
Pythia.OnThemeChanged :=
 procedure
 begin
   case TLookAndFeel.Parse(Pythia.Theme) of
     TLookAndFeel.light: TStyleManager.SetStyle('Windows10');
     TLookAndFeel.dark:  TStyleManager.SetStyle('Windows10 Dark');
   end;
 end;
```

Without this, your form's title bar, menus, and toolbars may remain in the OS default while the chat area changes theme.

<br>

### 8.2 Custom translations

To translate your own application strings using the same i18n mechanism as Pythia-Webview2:

1. Open the relevant file under:

   ```
   assets\lang
   ```

2. Add a `custom` object:

   ```json
   {
     "more": { "...": "..." },
     "settings": { "...": "..." },
     "custom": {
       "my_run_button": "Run",
       "my_dashboard_title": "Dashboard"
     }
   }
   ```

3. Declare global string variables in your own unit:

   ```pascal
   var
     S_MY_RUN_BUTTON: string = 'Run';
     S_MY_DASHBOARD_TITLE: string = 'Dashboard';
   ```

4. Re-read them when translations are loaded:

   ```pascal
   procedure MyTranslation;
   begin
     var Content := Pythia.LoadDictionaryContent(
       Pythia.GetLocalLanguage);
     var JSONObject := TJsonReader.Parse(Content);

     S_MY_RUN_BUTTON := JSONObject.AsString(
       'custom.my_run_button', S_MY_RUN_BUTTON);

     S_MY_DASHBOARD_TITLE := JSONObject.AsString(
       'custom.my_dashboard_title', S_MY_DASHBOARD_TITLE);
   end;
   ```

5. Wire the callback:

   ```pascal
   Pythia.OnTranslationsLoaded := MyTranslation;
   ```

Now every language reload updates both Pythia-Webview2 strings and your custom application strings.

### Checkpoint

The UI theme and custom strings can follow your host application identity.

<br>

## Step 9 — Test, observe, iterate

**Goal:** know how to debug when something does not behave as expected.

<br>

### 9.1 Use diagnostic prompt-state output

During integration, keep a way to inspect the `TInputPromptState` received from the UI.

A simple diagnostic handler can show or render the JSON request:

```pascal
class function TToolContainer.ActivateInputState(
 const AState: TInputPromptState;
 const AOnFinalize: TManagedItemFinalizeProc): Boolean;
begin
(*
   uses WVPythia.JSON.SafeReader, WVPythia.Strings.Escape
*)

  Result := True;
  var LReader := TJsonReader.Parse(AState.Source);
  var JsonContent := TEscapeHelper.ToPreformattedHTML(LReader.Format());
  Form1.Pythia.Display(JsonContent, False);

  var Returns := TManagedItemLLMResult.Create;
  try
    Returns
      .UsedModel('my_model')
      .Response(JsonContent)
      .Error(False);

    if Assigned(AOnFinalize) then
      AOnFinalize(Returns);

  finally
    Returns.Free;
  end;
end;
```

This is the fastest way to verify:

- selected model,
- selected cards,
- endpoint options,
- capabilities-related state,
- prompt text,
- attached or selected context.

<br>

### 9.2 Enable `DEV_MODE`

In:

```
Project → Options → Compilation → Conditional defines
```

add:

```
DEV_MODE
```

Then rebuild completely, not incrementally.

With `DEV_MODE` enabled, Pythia-Webview2 writes the last JSON message received from WebView2 to a debug exchange file near the executable or application support path, depending on the project configuration.

Use this file when a handler behaves unexpectedly. It shows the exact payload that triggered the call.

<br>

### 9.3 Use WebView2 DevTools

Right-click in the chat area and choose **Inspect**.

The Chromium DevTools open. Use:

- **Console** for JavaScript errors,
- **Network** for resource loading,
- **Elements** for DOM and CSS inspection.

This is especially useful when you customize JavaScript templates, CSS, or asset loading.

<br>

### 9.4 Common pitfalls

| Symptom | Likely cause |
|---|---|
| Chat appears but submitting does nothing | `ServiceAdapter` is not assigned, assigned after `Update`, or the service unit is not included in the Delphi project. |
| `DialogService not assigned` | The Pythia-Webview2 UI loaded, but no service adapter was available when the communication chain initialized. |
| Application starts but WebView2 does not initialize correctly | `WebView2Loader.dll` is missing next to the executable, or the DLL does not match the target architecture. |
| Assets fail to load | The `assets` folder is missing, incomplete, or not at the same level as `bin32` and `bin64`. |
| Cards do not appear | `Integration*` capability is disabled, the card JSON is malformed, or the wrong support folder is being edited. |
| API key seems forgotten or is requested repeatedly | The key name used by `API_KEY_NAME`, the secret store, and the `OnApiKeyChanged` refresh path do not match. |
| Custom event is ignored | The event JSON shape does not match what the service adapter expects. |
| Model selector shows unexpected data | The generated support file was not replaced, or the edited file is not in the active support folder. |
| `No default model configured` | A visible operation category has an empty `model` field in `<exeName>-model-get-replace-version.json`, or the configured model id does not exist in `<exeName>-model-list.json`. |

### Checkpoint

You know how to inspect the data flow at the browser layer, service adapter layer, and vendor layer.

<br>

## Step 10 — Deploy

**Goal:** ship a working executable to a target machine.

<br>

### 10.1 The deployment manifest

For a standalone project, the expected structure is:

```
MyFirstPythia-Webview2
├── assets
│   ├── index.htm
│   ├── scripts
│   ├── media (empty)
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

This folder contains generated or pre-filled JSON configuration files: capabilities, model list, category configuration, cards, and other support files.

<br>

### 10.2 Pre-populate the configuration

If you ship with a curated default configuration, pre-fill the application support folder with the relevant JSON files before deployment.

Typical files include:

- `<exeName>-capabilities.json`,
- `<exeName>-model-list.json`,
- `<exeName>-model-get-replace-version.json`,
- card files such as `<exeName>-function-cards.json`,
- other support files used by your application.

For example:

```
bin32\MyFirstPythia-Webview2\support
```

or:

```
bin64\MyFirstPythia-Webview2\support
```

If these files already exist on first launch, Pythia-Webview2 can use them instead of generating default configuration files.

<br>

### 10.3 WebView2 runtime on the target

The target machine must have the Microsoft Edge WebView2 Evergreen Runtime installed.

There are two separate elements to keep in mind:

```
WebView2Loader.dll
```

and the Microsoft Edge WebView2 Runtime.

`WebView2Loader.dll` is the DLL loaded by your application. The WebView2 Runtime is the Microsoft Edge-based runtime used to render the web interface.

On recent Windows versions, the runtime is often already present with Microsoft Edge. If it is not present, install it separately.

The Evergreen Runtime is the recommended deployment mode for most applications because it is installed on the machine and updated automatically by Microsoft.

The official Microsoft download page is:

```
https://developer.microsoft.com/microsoft-edge/webview2/
```

It provides:

- Evergreen Bootstrapper,
- Evergreen Standalone Installer,
- x86, x64, and ARM64 versions.

The bootstrapper downloads and installs the appropriate runtime for the machine. The standalone installer is better suited for offline environments or enterprise deployment.

<br>

### 10.4 First-launch behavior

On first launch, WebView2 may create a per-user profile under the user's local application data. This is normal browser-runtime behavior.

For kiosk or disposable-session scenarios, decide explicitly whether the WebView2 user data folder should be preserved or cleaned at startup.

### Checkpoint

Your application runs on a clean target machine with:

- the matching `WebView2Loader.dll`,
- the complete `assets` folder,
- the Microsoft Edge WebView2 Evergreen Runtime,
- and the expected generated or pre-filled support configuration files.

## Where to go next

You now have the full integration loop in your hands. From here, the main documentation is your reference.

| Topic | Section of pythia-documentation.md |
|---|---|
| Full overview of hooks and options | §8 — Exhaustive instantiation |
| Slash-command system and custom plugins | §10 and §12 |
| Customizing JavaScript templates | §11 and §29 |
| Building a custom UI for a plugin through the JS bridge | §23 |
| Persisting and paginating chat sessions | §22 |
| Handling media output | §17 |
| Two-step confirmation pattern for destructive actions | §21 |
| JSON configuration files | §25 |
| Glossary | §32 |

Suggested follow-up exercises:

1. **Add a custom slash command.** Write a plugin that reacts to `/hello` and replies with the current time.
2. **Add a second vendor.** Implement another `IVendorServices` provider and route by selected model or category.
3. **Build a custom card UI.** Write a JavaScript template that opens a modal form and posts the result back through a custom event.

You have a chat application backed by a real LLM, ready to be extended. The hard part — the wiring — is now explicit and reproducible.

## Companion documents

- **[pythia-documentation.md](../../docs/pythia-documentation.md#pythia--documentation)** — full reference with explanations, rationale, and end-to-end examples.
- **[HowToStart.txt](HowToStart.txt)** — project-start reference used as the accuracy baseline for this tutorial.
