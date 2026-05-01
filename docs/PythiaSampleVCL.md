# PythiaSampleVCL — discovery walkthrough

> Purpose of this document: explain what `PythiaSampleVCL` is, what it lets you discover, and how to read its source units when you want to understand what each part of the **Pythia-Webview2** UI actually does.
> This demo is **not** a vendor integration sample and **not** a plugin. It is a guided exploration of the component, its panels, its capabilities, and the scriptable surface of `IPythiaBrowser`.

<br>

>[!IMPORTANT]
>
> `PythiaSampleVCL` does not call any real LLM. It ships with a fake vendor (`TVendorTest`) that intercepts prompt submissions and renders the raw `TInputPromptState` as a preformatted block in the chat.
>
> This is **deliberate**: the goal of the demo is to let you observe how the WebView side composes a prompt, what the Delphi side receives, and how the visual surface reacts to capability/panel/button changes — without requiring an API key or a network call.

___

<br>

## 1. Why this demo exists

A new integrator usually has the same first questions:

- what does the chat surface actually look like at runtime?
- which panels can be toggled, hidden, or replaced?
- which buttons live in the input bar, and how are they enabled?
- what does a `TInputPromptState` actually contain when the user clicks **Send**?
- how does the component render generated images, audios, videos, files?
- how is a chat session built programmatically?
- where do the capabilities, model lists, and card files live?
- what does a typical error UI look like (e.g. `DialogService not assigned`)?

`PythiaSampleVCL` answers each of those questions in a single runnable application. The form exposes around 35 checkboxes and a dozen buttons, each wired to a small piece of behavior that you can toggle, observe, then turn off again.

---

## 2. Position among the demos

| Family | Demo | What you observe |
|---|---|---|
| **Discovery** | `PythiaSampleVCL` (this document) | The component itself: panels, buttons, capabilities, content rendering, sessions, configuration files |
| Starter | `NewVCLproject`, `NewFMXproject` | The minimal correct wiring to host the component |
| Vendor | `VCL_Anthropic` | A real LLM connected through a Delphi vendor SDK |
| Plugin | `PythiaSnippetDemo`, `PythiaGitDemo`, `PythiaGrepDemo` | Extension through slash commands and the JS↔Delphi bridge |

`PythiaSampleVCL` is the one you should run **first**. It does not pretend to be a real product; it is the application equivalent of an inspector window.

---

## 3. The form layout

When you open `Main.dfm` you see four scrollable areas:

| Area | Purpose |
|---|---|
| **Custom panels** (top-left scroll box) | Toggles for the three replaceable panels: Cards, Models, Settings, plus button-visibility toggles for the input bar (microphone, function, parameters, models). |
| **Capabilities** (middle-left scroll box) | One checkbox per `ICapabilities` boolean: endpoint, web research, reasoning, attach file, knowledge search, vision, deep research, integration, media, custom. |
| **Capability sub-menus** (right of the capabilities, paged) | Sub-toggles that only make sense when the parent capability is on: endpoint variants, thinking tiers, integration kinds (function / MCP / skill / agent), media kinds. The Next/Previous buttons cycle through the sub-pages. |
| **Discovery pages** (bottom, paged) | Action buttons that **populate** the chat with curated scenarios: generated media, attached files, long prompts, LaTeX, code blocks, programmatic sessions, JSON-file edition, error helpers, *How to start*. The Next/Previous buttons cycle through the pages. |

The host form is intentionally crowded. Treat it as a control panel, not as a product mockup.

---

## 4. Three units, three responsibilities

The demo's logic is split across three units. Reading them in this order will give you the clearest mental model.

### 4.1. `Demo.Browser.Services.pas` — the diagnostic vendor

This unit defines `TVendorTest`, the fake vendor that replaces a real LLM call.

It does three things, all small:

1. holds a reference to the `IPythiaBrowser` so it can write back into the chat;
2. registers itself as the auto-rename handler (`OnChatSessionAutoRename`) — the first line of the prompt becomes the session title;
3. exposes `Validation`, the entry point reached when the user clicks **Send**.

`Validation` is the interesting part:

```pascal
procedure TVendorTest.Validation(const AState: TInputPromptState;
  const AOnFinalize: TManagedItemFinalizeProc);
begin
  var Reader := TJsonReader.Parse(AState.Source);
  var S := TEscapeHelper.ToPreformattedHTML(Reader.Format);
  ...
  FBrowser.Display(S);
  ...
  AOnFinalize(ResponseFlow);
end;
```

It parses the raw JSON of `TInputPromptState`, formats it as a preformatted HTML block, and renders that block as the assistant turn. There is no network, no token, no streaming.

Why this matters: every time you click **Send** in this demo, you can read **exactly** what the WebView side packed into the prompt state — selected models, selected cards, attached files, capabilities snapshot, request parameters, custom event payload, everything. This is the fastest way to learn the schema you would need to handle in a real vendor service.

### 4.2. `Demo.ContentComposer.pas` — the scenario factory

`TContentComposer` is the unit that exposes one method per discovery scenario. It does not react to events; it is called explicitly by the form's buttons.

The methods fall into five groups.

| Group | Methods | What they demonstrate |
|---|---|---|
| **Generated media** | `DisplayImageGenerated`, `DisplayAudioGenerated`, `DisplayVideoGenerated`, `DisplayFilesGenerated` | How the component renders an image, audio, video, or set of files returned by an LLM. Uses `IPythiaBrowser.DisplayMedia` with `dkImages`, `dkAudio`, `dkVideo`, `dkFile`. |
| **Attached prompts** | `ImageAttachedToThePrompt`, `FilesAttachedToThePrompt`, `ImagesAndFilesAttached`, `PromptsVeryLong` | How the user-side bubble renders attachments and how a very long prompt is summarized. Uses `PromptMedia` and `Prompt`. |
| **Rich content** | `LaTeXUsing`, `CodeAndArrayUsing` | How the chat renders LaTeX (KaTeX) and code/tables (Markdown + highlight.js) via `Display(Response, Reasoning)`. |
| **Programmatic sessions** | `CreateSessionByCode`, `CreateSessionAboutReadme` | How to build a multi-turn chat session purely from Delphi (`PersistentChat.AddChat`, `AddPrompt`, `SaveToFile`, `ChatSessionAdd`) without a real LLM call. |
| **Configuration files** | `ModelListJsonEdition`, `ModelGetReplaceVersion`, `CapabilitiesEdition`, `CustomTemplateEdition`, `FunctionCardEdition`, `McpCardEdition`, `SkillsCardEdition`, `AgentsCardEdition`, `CustomCardEdition` | How to open the JSON configuration files of the application support folder, with explanatory text and the file content rendered inline. The actual files used are returned by `Browser.GetCapabilitiesFileName`, `GetModelListFileName`, `GetFunctionCardsFileName`, etc. |
| **Helper screens** | `DialogServiceError`, `DefaultModelError`, `HowToStart` | The didactic walkthroughs shown when an integrator first runs into the typical setup mistakes. |

The reusable building block of this unit is `DoEdition`:

```pascal
procedure TContentComposer.DoEdition(const Filenames: TArray<string>;
  const Prompt: string);
```

It clears the chat, prints the explanatory `Prompt`, displays the JSON content as a preformatted block, attaches the JSON file as an inline document, and scrolls back to the top. This is the same pattern any host application can reuse to render its own "open this configuration file in the chat" experience.

### 4.3. `Demo.Support.pas` — the wiring

`TCheckComponent` is the glue:

- it owns the `TContentComposer`;
- it remembers which sub-menu page and which discovery page is currently visible;
- it implements one handler per checkbox / button on the form;
- each handler either flips a capability, toggles a panel, toggles an input-bar button, or calls a `TContentComposer` method.

`TDidacticCustomProc.MyChatContentBuilder` is the second piece — it is plugged into `Pythia.OnRenderChatContent` and produces the welcome screen displayed when the chat is empty.

You will rarely write code that looks like this unit in a real application. It exists here only to hook a large amount of UI affordance to a small amount of behavior.

---

## 5. The minimal Pythia setup

Despite the size of the form, the actual Pythia setup is the same four lines you find in `NewVCLproject`:

```pascal
Pythia := TVCLPythia.Create(Panel2);
Pythia.ServiceAdapter := TVCLChatManagedItemDialogService.Create;
Pythia.OnThemeChanged := UpdateTheme;
Pythia.OnRenderChatContent := TDidacticCustomProc.MyChatContentBuilder;
Pythia.OnInitialized := DoOnInitialized;
Pythia.Update;
```

The diagnostic vendor and the content composer are created in `DoOnInitialized` — that is, **after** the WebView2 chat runtime has finished booting. This is the correct order if any of those services need to read paths produced by the runtime (e.g. `GetMediaFolder`, `GetCapabilitiesFileName`).

`UpdateTheme` is also worth noting: it shows the recommended pattern for synchronizing the host application's chrome (panel colors here) with the chat's selected look-and-feel through `Pythia.OnThemeChanged`.

---

## 6. Suggested exploration order

The demo deliberately exposes everything at once. Here is a path that builds knowledge step by step.

### 6.1. Start with the diagnostic vendor

1. Run the demo.
2. Type any prompt and click **Send**.
3. Observe the assistant turn: it shows the **complete** JSON of the `TInputPromptState` that was sent.
4. Note the fields you recognize and the ones you do not — they are exactly what a real vendor service would have to read.

### 6.2. Toggle the capabilities

1. Tick / untick a capability checkbox (e.g. `Reasoning`, `Vision`).
2. Watch the chat input bar update accordingly.
3. Re-send a prompt. The new JSON snapshot reflects the toggled capability.

This is where the relationship between `ICapabilities`, the JSON capability file, and the visible UI becomes concrete.

### 6.3. Toggle the panels

1. Tick **Custom Cards** / **Custom Models** / **Custom Parameters**.
2. Try to open the Cards / Models / Settings panels: the host now owns rendering — the framework does not show its default panel.
3. Untick to restore the default panel.

This shows the contract behind `Pythia.CustomPanels`.

### 6.4. Trigger curated scenarios

Click the discovery buttons in order and observe the chat:

| Button | What you see |
|---|---|
| `Display image / audio / video / files` | How `DisplayMedia` renders generated content. |
| `Image attached / Files attached / Both attached` | How the user bubble renders attachments. |
| `Prompts very long` | How the input rendering handles a long user prompt summary. |
| `LaTeX using` | KaTeX rendering of presheaves + Yoneda lemma. |
| `Code and array using` | Markdown code blocks + tables. |
| `Create session by code` / `about README` | A programmatic multi-turn session appears in the session drawer, fully persisted. |

### 6.5. Inspect the configuration files

Click the *edition* buttons (`Model list`, `Model categories`, `Capabilities`, `Custom template`, `Function cards`, `MCP cards`, `Skills cards`, `Agents cards`, `Custom cards`):

1. The chat clears.
2. A short prompt explains the role of the file.
3. The current content is displayed inline as a preformatted block.
4. The actual file is attached as a downloadable item.

This is the fastest way to understand which JSON files exist in the support folder and what each of them controls.

### 6.6. See the helper screens

Click `Dialog service error`, `Default model error`, `How to start`. These produce the same in-chat walkthroughs that ship as didactic content; they are what a new integrator hits when something is missing in the setup.

---

## 7. Reading the captured prompt state

The first thing the diagnostic vendor displays is a JSON snapshot of `TInputPromptState`. Browse it with these landmarks in mind:

| JSON field | Where it comes from |
|---|---|
| `models.categories[*].model` | The model selector. The integrator's vendor service typically reads `models.categories[<index>].model` to pick the model to call. |
| `endpoint`, `thinking`, `vision`, ... | A snapshot of the active capabilities. |
| `attachments.images`, `attachments.files`, `attachments.knowledge` | The files the user dropped or selected. |
| `cards.function`, `cards.mcp`, `cards.skills`, `cards.agents`, `cards.custom` | The cards selected in the Cards panel. Only the identity (`id`, `name`) is here — the full `content` payload of each card lives in the matching JSON file. |
| `prompt`, `language` | The prompt text and the active locale. |
| `requestParams` | The values currently set in the Settings panel. |

`Demo.Browser.Services.Validation` shows how to read one such field directly:

```pascal
var Model := Reader.AsString('models.categories[1].model');
```

That single line is the entire boilerplate a real vendor service would need to extract the active model.

---

## 8. What this demo intentionally does not cover

- **Real LLM calls.** Use `VCL_Anthropic` for a vendor-native integration sample.
- **Slash command plugins.** Use `PythiaSnippetDemo`, `PythiaGitDemo`, or `PythiaGrepDemo`.
- **Custom JS templates beyond `OnRenderChatContent`.** The `/grep` plugin demo is the canonical example of a JS picker injected at runtime.
- **Production styling.** The form is a control panel, not a polished UI.

If you need any of those, run the matching demo afterwards.

---

## 9. From discovery to a real integration

Once you have explored `PythiaSampleVCL`, the next steps are:

1. Open [`docs/integrator/index.md`](integrator/index.md) — the how-to guide for building a first real application.
2. Run [`VCL_Anthropic`](VCL_Anthropic.md) to see a real vendor service replace `TVendorTest`.
3. Read [`docs/reference/index.md`](reference/index.md) for the exact interfaces, events, JSON schemas, and template list referenced throughout this walkthrough.
4. Optionally explore one of the plugin demos (`/snippet`, `/git`, `/grep`) to see how the chat surface can be extended with command-layer logic.

`PythiaSampleVCL` does not replace any of those. It is the warm-up that makes them readable.

---

## 10. Summary

`PythiaSampleVCL` is the application equivalent of opening every drawer of the component. It demonstrates:

- the visible surface — chat area, input bar, sessions drawer, panels;
- the toggleable surface — capabilities, panels, buttons;
- the rendering surface — text, Markdown, code, LaTeX, generated media, attachments;
- the configuration surface — capabilities JSON, model list, model categories, card files, custom-template manifest;
- the diagnostic surface — `TInputPromptState` printed verbatim on every submit.

It does this without a real LLM, without an API key, and without a plugin. After running it once, you should have a clear mental map of what `IPythiaBrowser` exposes, where its data lives, and which extension points you will want to plug into in a real application.
