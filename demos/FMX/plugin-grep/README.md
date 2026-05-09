# `/grep` — interactive code-context picker for Pythia-webview2

> Purpose of this document: illustrate the user and developer value of the `/grep` command in an application based on Pythia-webview2.
> This document presents the Grep plugin as a third plugin example after `/snippet` and `/git`: where `/snippet` demonstrates local prompt reuse and `/git` demonstrates external context collection from a developer tool, `/grep` demonstrates a **two-way bridge** between Delphi and the WebView2 JS layer — the user curates the context interactively before it is injected into the prompt input field.
> Unlike the previous two documents, this one **does** cover plugin installation, because the `/grep` plugin requires both Pascal units **and** a JavaScript template to be deployed alongside the host application.

<br>

>[!IMPORTANT]
>
> The `/grep` command is available only when the corresponding plugin is installed and loaded by the host application.
> It also requires:
> - a configured search root directory;
> - the `GrepPickerTemplate.js` file copied next to the standard Pythia-webview2 templates;
> - a custom-event router wired in the host's `IChatManagedItemDialogService`.
>
> Without these three pieces, the command will either fail to find the picker template or the user's selection will silently never reach Delphi.

___

<br>

## 1. Why a `/grep` command?

An LLM is most useful when it sees the **right** code, not all of it.

Without a tool, a developer who wants to discuss four occurrences of `OnRender` across a 200-file project ends up doing this:

```
Cmd+Shift+F → scroll → copy 4 snippets manually → paste into the chat
→ remember which file each came from → add line numbers manually
→ ask the question
```

The repetitive part is exactly what loses focus and introduces copy/paste mistakes.

The `/grep` command turns that workflow into:

```
/grep find OnRender
→ a modal appears with every match grouped by file
→ tick the 4 occurrences that matter
→ click "Inject as context"
→ the prompt input field receives a clean Markdown block
→ add the actual question and send
```

The command does not submit anything automatically. It does not pick the matches for the user. It only prepares the context, then lets the user decide.

---

## 2. Position in the plugin examples

`/grep` is the third plugin example.

| Plugin | Demonstrates | Direction across the JS bridge | Main value |
|---|---|---|---|
| `/snippet` | local prompt reuse and persistence | one-way (Delphi → JS bubble) | avoid retyping stable instructions |
| `/git` | external process-based context collection | one-way (Delphi → JS bubble) | bring live development context into the LLM workflow |
| `/grep` | interactive curation before injection | **two-way** (Delphi → JS picker → user → Delphi → JS bubble) | let the user select exactly the context the LLM should receive |

The progression matters: `/snippet` and `/git` push content into the bubble; `/grep` first pushes a UI into the WebView, listens for the user's answer, and only then writes into the bubble.

---

## 3. What this command demonstrates

`/grep` is the most architecturally rich of the three example plugins. It demonstrates:

1. a Pythia command with multiple actions;
2. recursive filesystem walking with allowlist / denylist filters;
3. tolerant text decoding (UTF-8 BOM, UTF-16 LE/BE BOM and BOM-less, ANSI fallback, binary skip);
4. structured payload assembly using `WVPythia.JSON.SafeWriter`;
5. **base64 transport** of the payload through a single `ExecuteScript` injection — no JSON-escape pitfalls;
6. **custom-event reception** via `IChatManagedItemDialogService.ActivateCustomEvent`;
7. host-side dispatch by `name` prefix routed back to the plugin service;
8. deferred bubble writes (`TThread.ForceQueue`) so the SetText lands after the runtime's `BubbleInputPartialReset`;
9. canonical path-traversal protection via `TPath.GetFullPath`;
10. clean separation between the command adapter, the business service, and the JS UI layer.

This is therefore not only a "search the codebase" sample. It is the canonical example of how to build a plugin whose UI lives inside the WebView and whose validation happens on the user's side before Delphi acts on it.

---

## 4. Installation

The `/grep` plugin lives at `demos/FMX/plugin-grep`. Three artefacts must be deployed: the four Pascal units, the JS template, and the custom-event wiring inside the host adapter.

### 4.1. Pascal units

Add the four units to the host's Delphi project, exactly as you would for any other plugin:

| Unit | Role |
|---|---|
| `Demo.Grep.Plugin.Intf.pas` | Declares the `IGrepService` contract, the `TGrepOperationResult` Ok/Fail factories, and the `TGrepMatchRef` record shipped to the JS picker as JSON. Always added first because the other two units depend on it. |
| `Demo.Grep.Plugin.Service.pas` | Implements `IGrepService`. Handles validation, filesystem walking, encoding detection, JSON assembly, JS template loading, base64 injection, custom-event reception, Markdown formatting, and deferred bubble writes. |
| `Demo.Grep.Plugin.pas` | Thin `TGrepPlugin : TCommandPlugin`. Declares the four supported actions through `AddAction`, then forwards each one to the matching `IGrepService` method. |
| `FMX.WVPythia.Services.pas` | Host adapter (`TFMXChatManagedItemDialogService`). The version shipped with this plugin overrides `DoActivateCustomEvent` to dispatch every event name starting with `grep.` to `GrepService.HandleCustomEvent`. The unit also declares the `GrepService: IGrepService` global used by that dispatch. |

>[!IMPORTANT]
>
> If your host already has its own `FMX.WVPythia.Services.pas` (typical: it was copied from the `new-projet` starter or from another plugin demo), do **not** simply replace it. Instead, **merge** the changes:
>
> 1. add the `Demo.Grep.Plugin.Intf` unit to its `uses` clause;
> 2. add the `GrepService: IGrepService = nil` global at unit scope;
> 3. add the `DoActivateCustomEvent` override that forwards `grep.*` events to `GrepService.HandleCustomEvent`.
>
> Doing it this way preserves the rest of your adapter (model selection, item selection, audio input handlers, etc.).

### 4.2. JavaScript picker template

The picker UI is a self-contained JavaScript file injected on demand into the WebView2. It must be deployed at the same level as the standard Pythia-webview2 templates:

```
<your-app>\assets\scripts\GrepPickerTemplate.js
```

The `assets\scripts\` folder is the same directory that already holds `DisplayTemplate.js`, `InputBubbleTemplate.js`, `BootstrapDictionaryTemplate.js`, and the other shipped templates.

The service computes the path through `IPythiaBrowser.GetAssetsFolder` so it always resolves correctly relative to the running executable, regardless of `bin32` / `bin64` choice. If the file is missing at runtime, `/grep find` returns:

```
Picker template not found: <path>. Copy GrepPickerTemplate.js into assets\scripts.
```

A typical post-build step in `PythiaGrepDemo.dproj` copies the file automatically; alternatively, copy it once manually before the first run.

### 4.3. Host registration

Wire the plugin in `TForm1.FormCreate` (or wherever the rest of the Pythia setup lives), through the standard `OnRegisterCommandPlugins` hook:

```pascal
uses
  FMX.WVPythia.Chat,
  WVPythia.Types,
  FMX.WVPythia.Services,        // declares the GrepService global
  Demo.Grep.Plugin.Intf,
  Demo.Grep.Plugin.Service,
  Demo.Grep.Plugin;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TFMXPythia.Create(Layout1);
  Pythia.AttachHost(Self);
  Pythia.ServiceAdapter := TFMXChatManagedItemDialogService.Create;

  Pythia.OnRegisterCommandPlugins :=
    procedure
    begin
      GrepService := TGrepService.Create('C:\path\to\repo');
      GrepService.Browser := Pythia;
      Pythia.CommandLine.RegisterPlugin(TGrepPlugin.Create(GrepService));
    end;

  Pythia.Update;
end;
```

Three things to notice:

1. `GrepService` is the **global** declared in `FMX.WVPythia.Services.pas`. Assigning to it (rather than to a local variable) is what allows the adapter's `DoActivateCustomEvent` to find the service when the JS picker emits `grep.pick`.
2. `GrepService.Browser := Pythia` is mandatory: the service uses the browser façade to inject scripts, write into the bubble, and read the assets folder.
3. The root directory passed to the constructor is the only mandatory configuration. It can be changed at runtime through `/grep dir <path>`.

### 4.4. Verification checklist

After installation, run the application once and verify each of these in order:

| # | Action | Expected result |
|:---:|---|---|
| 1 | Type `/grep status` | Shows the configured root directory; "Last find" is `<none>` |
| 2 | Type `/grep find ThisStringWillNotMatchAnything` | Returns `No match for "..." under <root>` |
| 3 | Type `/grep find <something common in your repo>` | A modal appears overlaying the chat |
| 4 | Click "Cancel" in the modal | The modal closes; nothing lands in the input bar |
| 5 | Re-run the same `find`, tick one match, click "Inject as context" | The input field is filled with a Markdown context block |

If any step fails, the message will identify which piece is missing (template path, root directory, or the custom-event wiring).

---

## 5. Command surface

```
/grep find   <pattern>
/grep find   <pattern> <subPath>
/grep dir    <path>
/grep last
/grep status
```

### Quick reference

| Command | Purpose |
|---|---|
| `/grep find pattern` | Walks the configured root, opens a picker listing every line containing `pattern` (case-insensitive). |
| `/grep find pattern subPath` | Same, but limits the walk to a subdirectory under the root. |
| `/grep dir path` | Updates the root directory for subsequent searches. Validates that the path exists. |
| `/grep last` | Re-opens the picker for the last `find` result, without re-running the search. Useful if the modal was dismissed by accident. |
| `/grep status` | Prints the current root, last pattern, last subpath, last result count, and any skip counters in the chat. |

The command surface is deliberately read-only with respect to the filesystem. The plugin walks the project; it never writes, deletes, or modifies any file.

---

## 6. Central workflow: collect, pick, inject

The central workflow is:

```
/grep find OnRender
```

Expected effect: a centered modal appears over the chat. It lists every line of every project file that contains the substring `OnRender`, grouped by file, with checkboxes.

The user ticks 4 of the 27 occurrences and clicks **Inject as context**.

The prompt input field is then pre-filled with a Markdown block:

````markdown
## Code context from `C:\repo`
Pattern: `OnRender`

### `src/Forms/MainForm.pas`
```
// line 142
procedure TMainForm.OnRender(Sender: TObject);
```

### `src/Components/Renderer.pas`
```
// line 56
FOnRender := nil;
// line 78
if Assigned(FOnRender) then
```
````

The user can then add the actual question:

```
Why is FOnRender cleared at line 56? Could it leak in line 78?
```

The final prompt sent to the LLM contains both:

1. the curated context;
2. the user's explicit request.

`/grep find` does not ask the LLM anything by itself. It does not auto-submit. It does not pick on the user's behalf. It simply prepares the prompt input field once the user has confirmed.

---

## 7. The picker UI

The picker is rendered entirely in JavaScript inside the WebView2. It is a transient element: the host injects it on demand, the user answers, the modal disappears.

<p align="center">
  <img src="../../../images/screenshots/grep-plugin-dark.png?raw=true" width="700"/>
</p>       
<br>

### 7.1. Layout

| Region | Content |
|---|---|
| **Header** | Pattern, total match count, root directory. |
| **Toolbar** | A search field that filters the visible matches by file path or text content; a counter showing the number of currently selected items. |
| **List** | One block per file, with the file path, an occurrence count, a per-file "select all" checkbox, and one row per match (line number + snippet, with the search pattern highlighted). |
| **Truncation banner** | Visible only when the result set was capped (see §10). |
| **Footer** | A reminder that Esc cancels and Ctrl+Enter injects, plus the **Cancel** and **Inject as context** buttons. |

### 7.2. Keyboard shortcuts

| Key | Action |
|---|---|
| `Esc` | Cancel and close the modal. |
| `Ctrl+Enter` | Inject the current selection (only when at least one match is ticked). |
| `Tab` | Cycle through filter, checkboxes, and buttons. |

### 7.3. Theming

The modal honors the `data-theme` attribute set by the standard Pythia-webview2 theme manager, so it follows the active light or dark theme automatically. No additional configuration is needed.

---

## 8. Command behavior by action

### 8.1. `/grep find pattern`

Walks the root, runs a literal case-insensitive substring search, and opens the picker.

Typical use cases:

- find every site of an event handler before discussing a refactor;
- locate every read of a global flag before asking how to remove it;
- collect every TODO comment matching a tag.

Example:

```
/grep find TODO_BUDGET
```

Then add:

```
Could we group these and propose an implementation order?
```

---

### 8.2. `/grep find pattern subPath`

Same behavior, but the walk is restricted to a subdirectory.

The sub-path is canonicalized through `TPath.GetFullPath` and verified to still live under the configured root, so input like `..\..\Windows` is rejected with a clear error before any filesystem walk happens.

Example:

```
/grep find AssignedTo src\Modules\Auth
```

This is the right command when the global walk would return too many matches and you already know which subtree matters.

---

### 8.3. `/grep dir path`

Updates the root directory. The path is validated up front: if it is empty or does not exist, the action fails and the previous root remains active.

Example:

```
/grep dir C:\projects\acme-backend
```

`/grep dir` is the only way to change the root after the application has started. The constructor argument supplies the initial value; if the developer does not pass anything, the user must call `/grep dir` once before `/grep find`.

---

### 8.4. `/grep last`

Re-opens the picker for the **previous** `find` result, without re-running the search.

Use case: the modal was dismissed by clicking outside or pressing Esc, but the user wants the same picker back to refine the selection.

If no previous search happened in the current session, the action returns:

```
No previous grep result to redisplay
```

---

### 8.5. `/grep status`

Prints the current configuration in the chat:

```
--- Grep status ---

Root dir : C:\projects\acme-backend
Last find: "OnRender"
Last sub : src\Components
Matches  : 27
```

When applicable, a `Skipped` line shows how many files were unreadable or could not be decoded as text during the last run. This is useful when matches are surprisingly low.

---

## 9. Naming, paths, and validation

### 9.1. Pattern

The pattern is matched **literally** as a substring; there is no regex engine and no glob syntax.

| Rule | Behavior |
|---|---|
| Case | Ignored: `OnRender` and `onrender` match the same lines. |
| Empty pattern | Rejected. |
| Length | Rejected over 500 characters. |
| Trailing whitespace | Trimmed before validation but not before the search itself. |

### 9.2. Sub-path

The sub-path follows three rules:

| Rule | Behavior |
|---|---|
| Wildcards (`*`, `?`) | Rejected. The walk is recursive by construction; wildcards would be ambiguous. |
| Directory traversal (`..`, absolute paths, mixed separators) | Detected by canonicalizing root + sub-path through `TPath.GetFullPath` and verifying the result still lives under the canonical root. |
| Existence | The canonical sub-path must exist as a directory. |

The traversal protection is path-canonical, not filesystem-canonical: it does not follow symlinks. If the host trusts the configured root, that is sufficient; if not, replace the implementation of `ResolveSearchRoot` accordingly.

---

## 10. Search scope and limits

### 10.1. Extension allowlist

Files are only opened if their extension is in the allowlist:

```
.pas .dpr .dproj .inc .dfm .fmx
.json .md .txt .cfg .ini
.htm .html .css .js .ts
.xml .yaml .yml
```

The allowlist is a Delphi-leaning default. To support other source kinds (e.g. `.py`, `.sql`, `.go`), edit `FExtensionAllowlist` in the constructor of `TGrepService`.

The allowlist exists primarily to skip binaries that would slow the walk; it is not a security boundary.

### 10.2. Directory denylist

These directories are skipped entirely:

```
.git .svn .hg
dcu __history __recovery
node_modules .vscode .idea
bin obj release debug
win32 win64 win32release win64release
```

Edit `FDirectoryDenylist` in the constructor to adjust this list. The match is case-insensitive on the directory's leaf name only, so `c:\repo\Bin` is also skipped.

### 10.3. Hard caps

Three caps protect against runaway walks:

| Cap | Default | Behavior |
|---|---|---|
| `MAX_FILE_SIZE_BYTES` | 2 MB | Files larger than this are skipped silently. |
| `MAX_TOTAL_MATCHES` | 800 | The walk stops once this many matches have been accumulated. The picker shows a banner: *Result set was truncated. Narrow the pattern or use a sub-path.* |
| `MAX_PATTERN_LENGTH` | 500 chars | Patterns longer than this are rejected. |

Each constant lives at the top of `TGrepService` and is documented inline.

---

## 11. Encoding handling

The walk reads each candidate file as raw bytes and decodes them with this priority:

1. UTF-8 BOM (`EF BB BF`);
2. UTF-16 LE BOM (`FF FE`);
3. UTF-16 BE BOM (`FE FF`);
4. UTF-8 without BOM, validated against the strict UTF-8 grammar (overlong sequences and surrogate pairs are rejected);
5. UTF-16 LE without BOM, detected heuristically;
6. UTF-16 BE without BOM, detected heuristically;
7. Files containing a `0x00` byte that did not match any of the above are treated as binary and skipped;
8. Everything else falls back to the system's ANSI default — typical for legacy Delphi `.pas` files saved with Windows-1252.

Unreadable files (locked, permission denied) and files that fail decoding are counted separately and reported by `/grep status`. They are silently skipped during the walk so a single bad file never breaks the search.

---

## 12. Custom-event payload schema

The `/grep` plugin is the example case of the framework's `custom-event` channel. Two events flow back from the JS picker to Delphi.

### 12.1. `grep.pick`

Emitted when the user clicks **Inject as context** with at least one match selected.

```json
{
  "event": "custom-event",
  "name": "grep.pick",
  "payload": {
    "pattern": "OnRender",
    "root": "C:\\repo",
    "selected": [
      { "file": "src/Forms/MainForm.pas",      "line": 142, "snippet": "procedure TMainForm.OnRender(Sender: TObject);" },
      { "file": "src/Components/Renderer.pas", "line": 56,  "snippet": "FOnRender := nil;" }
    ]
  }
}
```

The payload carries the **full** match data (file, line, snippet), not just IDs. This is intentional: the user has just curated the selection in the picker, so Delphi can format the Markdown block from the payload alone, without re-correlating against any in-memory state.

### 12.2. `grep.cancel`

Emitted when the user clicks **Cancel**, presses Esc, or clicks the modal backdrop.

```json
{
  "event": "custom-event",
  "name": "grep.cancel",
  "payload": { "pattern": "OnRender" }
}
```

The Delphi handler simply acknowledges the cancellation. The JS layer has already removed the modal from the DOM and reset its inline payload before posting.

### 12.3. Routing on the host side

The host adapter forwards every event whose name starts with `grep.` to `GrepService.HandleCustomEvent`:

```pascal
function TFMXChatManagedItemDialogService.DoActivateCustomEvent(
  const ARawJson: string): Boolean;
var
  Reader: TJsonReader;
begin
  Reader := TJsonReader.Parse(ARawJson);
  if not Reader.IsValid then
    Exit(False);

  var EventName := Reader.AsString('name');
  if EventName.StartsWith('grep.') and Assigned(GrepService) then
    Exit(GrepService.HandleCustomEvent(EventName,
      Reader.ExtractSubJson('payload', '{}')));

  Result := False;
end;
```

Adding a fourth plugin that uses the same channel follows the same pattern: a name prefix, a global service reference, and a forwarding line in `DoActivateCustomEvent`.

---

## 13. Common errors

| Symptom | Likely cause |
|---|---|
| `Grep root directory is not set` | The plugin was constructed without a root and `/grep dir` was not called. |
| `Grep root directory does not exist` | The constructor argument or the `/grep dir` value points to a missing folder. |
| `Sub-path escapes the configured root directory` | The user passed an absolute path or a `..` chain to `/grep find`. |
| `Picker template not found: ...` | `GrepPickerTemplate.js` was not copied into `assets\scripts`. |
| `No searchable file under ...` | The chosen subtree contains no file matching the extension allowlist. |
| `No match for "..." under ...` | The walk completed but the pattern was not found. |
| Selection is ticked but nothing lands in the bubble | The host adapter's `DoActivateCustomEvent` does not forward `grep.*` events to `GrepService`. |
| Modal opens but never disappears after Inject | Same as above — the JS removes the modal only after Delphi acknowledges the event through the runtime. Verify the wiring in §4.3. |

---

## 14. Suggested walkthrough

### Preparation

1. install the plugin (§4);
2. set the constructor root directory to a real Delphi project, ideally one with at least 50 source files;
3. run the application in debug mode.

### Walkthrough

| # | Command | Expected result |
|:---:|---|---|
| 1 | `/grep status` | Root dir is shown, "Last find" is `<none>` |
| 2 | `/grep find DoesNotExist` | `No match for "DoesNotExist" under <root>` |
| 3 | `/grep find OnRender` (or any term known to exist) | Picker modal appears |
| 4 | Type "Form" in the toolbar filter | Visible matches are narrowed |
| 5 | Click the per-file checkbox of a single file | Every match in that file becomes ticked |
| 6 | Click **Inject as context** | Modal closes; input field receives a Markdown block |
| 7 | Press Esc immediately on the next `/grep find` | Modal closes without filling the bubble |
| 8 | `/grep last` | Same picker re-opens with the same matches |
| 9 | `/grep status` | "Last find" reflects the previous pattern |

### Custom-event wiring sanity check

Add a temporary `OutputDebugString` in `DoActivateCustomEvent` to log incoming event names. Run a `/grep find`, tick one match, and click Inject. The log should show:

```
grep.pick
```

If nothing logs, the event router is not reached — check that the host's `ServiceAdapter` is actually the version shipped with the plugin (not the copy from another demo).

---

## 15. What the developer should observe

### 15.1. A two-way bridge with no new framework

The plugin uses only the standard `IPythiaBrowser.ExecuteScript` and the framework's `custom-event` channel. It does **not** add a new template type, does not extend `ITemplateProvider`, and does not modify the framework. The same recipe can be applied to any plugin that needs a transient picker, a configuration form, or a confirmation dialog.

### 15.2. Base64 transport for the payload

The payload travels base64-encoded inside the injected script. This avoids every JSON-escape pitfall (quotes, backslashes, line breaks inside snippets) and keeps the injected preamble on a single line. The JS template decodes it once at startup with `atob` + `decodeURIComponent(escape(...))` to handle UTF-8 correctly.

### 15.3. Trust the user's payload at format time

The Markdown block is formatted from the JSON payload that comes back from the picker, **not** from the in-memory match cache. The user has just curated the selection; that is the source of truth.

### 15.4. Deferred bubble write

Like `/snippet` and `/git`, the final `BubbleInputSetText` is queued through `TThread.ForceQueue`, so it lands after the runtime's `BubbleInputPartialReset` that follows event handling. Without this deferral the bubble would render empty.

### 15.5. Canonical path checks

The path-traversal guard uses `TPath.GetFullPath` + `StartsWith(FullRoot)`. This catches `..` segments, mixed separators, drive changes, and trailing-slash quirks, **without** rejecting legitimate names that happen to contain `..` (e.g. `my..folder`).

---

## 16. Limits and possible extensions

### Regex search

The current pattern is matched as a literal substring. Switching to `TRegEx` is a localized change in `SearchFile` if a user later asks for it. Keep the validation step (`MAX_PATTERN_LENGTH`, empty-pattern rejection) intact — a malformed regex would otherwise stall the walk.

### Neighbour-line context

The picker shows the matching line only. For some prompts the LLM benefits from one or two lines of context above and below. This can be added in `SearchFile` and propagated to the JSON payload; the JS picker would then render an expandable `<details>` inside each row.

### Multi-pattern search

The current command takes a single pattern. A `/grep find-many <patternA> <patternB>` action could collect matches from multiple patterns into a single picker.

### Indexed search

For very large repositories, walking the filesystem on every search becomes too slow. An indexed backend (`ripgrep`, `ctags`, or an in-memory inverted index) can replace `CollectFiles` + `SearchFile` without touching the plugin layer or the JS template — that is the entire point of the `IGrepService` abstraction.

### Stricter sandbox

The current implementation trusts the configured root and skips a hand-curated set of build directories. A stricter integration could replace `IsDirectoryAllowed` with a `.gitignore`-aware version, or restrict the search to files tracked by `git ls-files`.

---

## 17. Summary

`/grep` is a small command, but it demonstrates the most complete pattern of the three example plugins:

- it lets the user curate the LLM's context interactively;
- it walks the project, decodes mixed encodings tolerantly, and ships a structured payload to the WebView;
- it uses the standard `custom-event` channel as a return path;
- it formats the user's selection into a Markdown block and writes it into the prompt input field;
- it documents its limits and integration requirements clearly.

For an application that integrates an LLM, `/grep` shows how to give the user the last word on what the model sees, without leaving the chat interface.
