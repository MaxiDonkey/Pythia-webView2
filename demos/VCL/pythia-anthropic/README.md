# Pythia Anthropic VCL Demo

- [GitHub MCP setup](#github-mcp-setup)
- [Discovering the skills cards](#discovering-the-skills-cards)
- [Discovering the agent cards](#discovering-the-agent-cards)
- [Demo architecture](#demo-architecture)
- [Where to dig in the code](#where-to-dig-in-the-code)
- [Caveats](#caveats)
___

<br>

## GitHub MCP setup

<p align="center">
  <img src="../../../docs/images/screenshots/mcp-cards.png?raw=true" width="500"/>
</p>

The demo ships with a pre-wired GitHub MCP server entry, but it cannot connect to GitHub on its own — it needs a personal access token (PAT) issued from your GitHub account.

### 1. Create a Personal Access Token

1. Sign in to your GitHub account.
2. Open **https://github.com/settings/personal-access-tokens**.
3. Click **Generate new token** and follow the prompts. Pick the scopes you actually need; the demo does not require any specific scope by itself, the scopes you select will determine what the MCP server is allowed to do on your behalf.
4. Copy the generated token. GitHub only shows it once.

### 2. Register the token in the demo

Open the MCP cards configuration file shipped alongside the compiled demo:

```
bin64\VCL_Anthropic\support\VCL_Anthropic-mcp-cards.json
```

Locate the `github` entry and paste your PAT into the `pat` field, replacing `your github pat`:

```json
{
  "id": "github",
  "name": "Github",
  "commentaire": "GitHub access via PAT to be provided",
  "badge": "\uE186",
  "content": "{\"type\":\"url\",\"url\":\"https:\/\/api.githubcopilot.com/mcp/\",\"name\":\"Github\",\"authorization_token\":\"%s\"}",
  "pat": "your github pat"
}
```

Save the file. The next time the demo loads the MCP card, the PAT is substituted into the `authorization_token` placeholder of `content` and the GitHub MCP server becomes usable.

### A note on automation

This step is intentionally manual in the demo. In a production application you would typically wrap PAT entry behind a small UI (for example a settings dialog backed by the OS secret store) and have the application write the token into the card itself, rather than asking the user to edit a JSON file by hand. We did not implement that flow here so the configuration surface stays explicit and easy to inspect while reading the demo.

## Security reminder

A GitHub PAT grants real access to your GitHub account. Treat the JSON file as you would any credential file:

- Do not commit it with a real token inside.
- Do not share it.
- Revoke the token from the GitHub settings page as soon as you no longer need it.

<br>

## Discovering the skills cards

<p align="center">
  <img src="../../../docs/images/screenshots/skills-cards.png?raw=true" width="500"/>
</p>

To understand how the demo skill available from its card in the skills list works, you must provide a ZIP file containing a Delphi project and all of its source files.

The file available in the [assets\media\pythia-anthropic.zip](../../../assets/media) folder can be used as an example and attached to your prompt.

Next, try using the following text as your prompt:
> Here is an archive of my Delphi project. It uses the `delphi-uses-graph` skill to generate a graph of unit usage. It filters out the prefixes `System`, `Winapi`, `Vcl`, `FMX`, `Anthropic`, and `WVPythia` to keep only my Demo units.* It displays the Mermaid diagram online and summarizes the most dependent units (top fan-in) as well as any cycles.

<p align="center">
  <img src="../../../docs/images/screenshots/skill-prompt.png?raw=true" width="500"/>
</p>

>[!NOTE]
>The skill is defined in the folder shown below and registered on the Anthropic cloud, making it accessible from the console. [delphi-uses-graph](../../../bin64/VCL_Anthropic/delphi-uses-graph)
>
>If it is not already registered, the Anthropic demo application handles the registration process. It also checks that the skill is available when the demo application starts.

<br>

# Discovering the agent cards

Companion to the **2026-05-27** changelog (version 0.9.5). Five cards ship with
the `VCL_Anthropic` demo. Run them in order — each one grants the agent a bit
more power.

| # | Card                       | What it shows                                  |
|---|----------------------------|------------------------------------------------|
| 1 | Research Analyst           | single agent, web tools, no project needed     |
| 2 | Local Project Review       | sub-agent, read-only on your project           |
| 3 | Supervised Exploration     | same, but **asks** before each tool call       |
| 4 | Safe Code Patch            | proposes a unified diff, writes nothing        |
| 5 | Sandbox To Local Code Edit | edits a sandbox copy, patches your disk after **your** confirmation |

## Where the cards live

- **Registry (UI side):**
  [`bin64/VCL_Anthropic/support/VCL_Anthropic-agent-cards.json`](../../../bin64/VCL_Anthropic/support/VCL_Anthropic-agent-cards.json)
- **Inline JSON** for cards 1–3 (compact, fits in `content`).
- **Markdown definitions** for cards 4–5 (richer, referenced via `md_path`):
  - [`safe-code-patch-agent.md`](../../../bin64/VCL_Anthropic/safe-code-patch-agent.md?plain=1)
  - [`sandbox-to-local-code-edit-agent.md`](../../../bin64/VCL_Anthropic/sandbox-to-local-code-edit-agent.md?plain=1)

> Both links use GitHub's `?plain=1` raw view so the YAML front matter — which
> declares the agent's topology, tools and policies — stays visible. Without
> it, the rendered Markdown hides that header.

<br>

<p align="center">
  <img src="../../../docs/images/screenshots/card-agent-selector.png?raw=true" width="500"/>
</p>

---

## Card 1 — Research Analyst

Single agent, `claude-opus-4-7`. `web_search` and `web_fetch` are
`always_allow`; nothing else.

**No project needed.**

**Try this:**
> Produce a short, sourced briefing on the public state of Anthropic's
> Managed Agents API as of today. Group findings by theme, cite every claim
> with a URL, and flag anything you could not verify.

You should see interleaved tool calls and assistant text, with URL citations
in the final answer. No confirmation pops up.

<p align="center">
  <img src="../../../docs/images/screenshots/Agent-prompt_1.png?raw=true" width="500"/>
</p>

---

## Card 2 — Local Project Review

Coordinator + sub-agent **Code Inspector**. Read-only: `read`, `glob`, `grep`
(`always_allow`). No write, no `bash`. Inspector reads at most 12 files.

**Setup:** click the **Project** button on the input bubble and pick a small
local folder. It is uploaded under `/mnt/session/uploads/workspace/project`.

**Try this:**
> Review the selected project. Identify up to five concrete issues (correctness,
> safety, clarity), citing the exact file path for each. Group your answer as
> Findings / Severity / Recommendations.

You get three sections, each finding tied to a real path. Nothing is written.

<p align="center">
  <img src="../../../docs/images/screenshots/Agent-prompt_2.png?raw=true" width="500"/>
</p>

---

## Card 3 — Supervised Exploration

Same shape as card 2, but the sub-agent's tools are `always_ask` — Pythia
prompts you before each call. The sub-agent has a tight budget: one `glob`,
up to three `read`, at most one `grep`.

**Setup:** same as card 2 (a small selected project).

**Try this:**
> Give me a one-paragraph summary of what this project is, plus a short list
> of its most notable files. Use the smallest number of tool calls.

The point here is to *experience* the confirmation dialogs (labels come from
[`Demo.Anthropic.Strs.pas`](Demo.Anthropic.Strs.pas)). Deny one to see the
clean *"Interrupted by the user."* path.

<p align="center">
  <img src="../../../docs/images/screenshots/Agent-prompt_3.png?raw=true" width="500"/>
</p>

---

## Card 4 — Safe Code Patch

Multi-agent (Markdown-defined): **Code Locator** finds the spot, **Patch
Author** drafts a diff. Neither has `edit`. Coordinator reviews and returns
the diff in a fixed format.

**Setup:** any small selected project.

**Try this:**
> In the selected project, propose the smallest safe patch that improves
> one specific user-visible string for clarity. Pick the string yourself,
> explain the choice, then return the unified diff between the
> `PYTHIA_UNIFIED_DIFF_BEGIN/END` markers. Do not modify any file.

**Required answer shape** (three sections, in this order):

1. **Patch Summary** — files affected, intent.
2. **Unified Diff** between `PYTHIA_UNIFIED_DIFF_BEGIN` / `…_END`, in
   standard unified diff syntax with local relative paths in the `---` /
   `+++` headers.
3. **Validation Notes** — why the patch is narrow, suggested test or
   manual check.

Your disk is untouched: this card *proposes*, nothing more.

<p align="center">
  <img src="../../../docs/images/screenshots/Agent-prompt_4.png?raw=true" width="500"/>
</p>

---

## Card 5 — Sandbox To Local Code Edit

The full round-trip. **Code Locator** finds, **Sandbox Editor** edits the
sandbox copy (its `edit` tool is `always_ask`), the coordinator returns
**two** machine-readable blocks. Pythia spots them and asks *you* before
touching your local file.

**The boundary the card teaches:**
1. Your folder is uploaded to the sandbox.
2. Agents edit only the sandbox copy.
3. The answer returns a manifest + a unified diff.
4. Pythia — not the agent — applies the diff locally, after your confirmation.

The coordinator must never claim your disk was modified.

### Validation test (patches the demo's own source)

The point of this test is to let the agent **find the work itself** — no file
hint, no symbol name, just an intent and a contract.

**Setup — choose one of these two options:**

> ⚠️ The local apply step really modifies the file on disk. There is no
> built-in undo.

- **Recommended — work on a copy.** Duplicate `demos\VCL\pythia-anthropic`
  somewhere outside the repo (e.g. `D:\sandbox\pythia-anthropic-copy`) and
  point the **Project** button at that copy. You can throw the copy away
  afterwards.
- **Direct — work on the demo source itself.** Pick
  `demos\VCL\pythia-anthropic` directly. Commit or back up the folder
  first; otherwise the change is permanent for your working tree.

**Try this:**
> In the selected project, find the error message shown when an agent card
> is missing or invalid (the one that mentions both *not found* and
> *invalid*).
>
> Goal:
> - modify only that message so it states the card can be defined either
>   via `content` or via `md_path`;
> - touch a single file;
> - do not change any business behavior;
> - do not reformat code.
>
> Expected work:
> 1. locate the relevant file;
> 2. modify only the sandbox copy with the `edit` tool if needed;
> 3. return the Local Apply Manifest between the
>    `PYTHIA_LOCAL_APPLY_MANIFEST_BEGIN` / `PYTHIA_LOCAL_APPLY_MANIFEST_END`
>    markers;
> 4. return the Unified Diff between the
>    `PYTHIA_UNIFIED_DIFF_BEGIN` / `PYTHIA_UNIFIED_DIFF_END` markers;
> 5. state the manual check to run after local application.

**Required answer shape** (four sections, in this order):

1. **Cloud Edit Summary** — sandbox files changed, intent, local files
   expected to change.
2. **Local Apply Manifest** between `PYTHIA_LOCAL_APPLY_MANIFEST_BEGIN` /
   `…_END`. Key-value text (not JSON) with at least `root_hint`, `files`,
   and for each file `sandbox_path`, `local_relative_path`, `change_type`,
   `requires_user_confirmation`.
3. **Unified Diff** between `PYTHIA_UNIFIED_DIFF_BEGIN` / `…_END`.
4. **Validation Notes** — why the edit is narrow, suggested local check.

> **Path gotcha:** `local_relative_path` is relative to `root_hint`. If the
> sandbox path is `/mnt/session/uploads/workspace/project/Foo.pas`, the
> local relative path is `Foo.pas`, **not** `project/Foo.pas`.

**What you should see, in order:**
1. `code-locator` globs/greps the project and reports back where the error
   message lives.
2. `sandbox-editor` asks before its `edit` call → you allow it.
3. The final answer contains both marker blocks above, with a real file
   path filled in and the new wording referencing `content` and `md_path`.
4. Pythia detects the markers and asks for a local-apply confirmation.
5. After you confirm, the matching `.pas` file on disk carries the new
   message; to see it live, temporarily break the cards registry (e.g.
   rename an agent `id` so it no longer matches the selection) and relaunch
   the demo — the new wording appears.

<p align="center">
  <img src="../../../docs/images/screenshots/Agent-prompt_5.png?raw=true" width="500"/>
</p>

---

## Demo architecture

The demo is wired around a single entry point, `Demo.Anthropic.Services` (the
`IVendorServices` implementation). The host form (`Main`) and the VCL glue
(`VCL.WVPythia.Services`) create it. Beyond the regular chat turn, its
distinctive part is the **Managed Agents** subsystem, orchestrated by
`Demo.Anthropic.Session.Flow`.

The tree below groups the demo units (`Demo.Anthropic.*`) under that entry
point. Indentation reads as *"is used by its parent"*. Only internal units are
shown — the Anthropic SDK and the `WVPythia.*` component units are left out.

```text
Demo.Anthropic.Services                        entry point — IVendorServices
│
├─ Managed Agents (orchestrated by Session.Flow)
│   ├─ Demo.Anthropic.Session.Flow             agent run orchestrator
│   ├─ Agent cards
│   │   ├─ Demo.Anthropic.Agent.Cards
│   │   ├─ Demo.Anthropic.Agent.Markdown
│   │   └─ Demo.Anthropic.Agent.Fingerprint
│   ├─ Cloud lifecycle
│   │   ├─ Demo.Anthropic.Agent.Registry
│   │   ├─ Demo.Anthropic.Agent.Provisioning
│   │   └─ Demo.Anthropic.Agent.Cleanup
│   ├─ Local project bridge
│   │   ├─ Demo.Anthropic.Agent.Folder
│   │   └─ Demo.Anthropic.Agent.LocalApply
│   └─ Session runtime
│       ├─ Demo.Anthropic.Session.Transport
│       ├─ Demo.Anthropic.Session.Events
│       └─ Demo.Anthropic.Agent.TurnDisplay
│
├─ Conversation
│   └─ Demo.Anthropic.Context                   continuity; reads Session.Events
│
├─ Vendor async services
│   └─ Demo.Anthropic.Upload                    file upload (Files API)
│
└─ Helpers / foundation                         shared across the demo
    ├─ Demo.Anthropic.AsyncUtils
    ├─ Demo.Anthropic.DisplayBlocks
    ├─ Demo.Anthropic.Finalize
    ├─ Demo.Anthropic.Helpers
    ├─ Demo.Anthropic.JsonResponse.Helper
    └─ Demo.Anthropic.Strs
```

The *Helpers / foundation* units are not exclusive to `Services`: the agent
subsystem reuses them too (rendering, finalization, parsing, strings). They are
listed once, at the bottom, to keep the tree flat.

### Unit responsibilities

| Unit | Role |
|------|------|
| `Demo.Anthropic.Services` | **Entry point.** `IVendorServices` implementation: drives the chat turn, wires the file-upload service, owns the API key and session lifecycle, and launches Managed Agents runs (`IAgentSessionFlow`). |
| `Demo.Anthropic.Session.Flow` | `IAgentSessionFlow` orchestrator: drives a complete Managed Agents round end to end. |
| `Demo.Anthropic.Session.Transport` | Cancelable SSE transport on a worker thread, via the Anthropic SDK. |
| `Demo.Anthropic.Session.Events` | Typed event parser (`TSessionEventKind`: assistant text, reasoning, tool use/result, custom tool use, confirmation request, outcome, thread, error, done). |
| `Demo.Anthropic.Agent.TurnDisplay` | `IPythiaTurnDisplay` adapter: translates the run into `TChatDisplayBlock` for the UI. |
| `Demo.Anthropic.Agent.Cards` | Typed agent-card model + JSON envelope loader. |
| `Demo.Anthropic.Agent.Markdown` | Markdown (YAML frontmatter) agent-card loader; complements `Agent.Cards`. |
| `Demo.Anthropic.Agent.Fingerprint` | Canonical card fingerprint used as the provisioning cache key. |
| `Demo.Anthropic.Agent.Registry` | Persistent registry of Managed Agents resources (environments, agents, sub-agents, sessions, statuses/versions). |
| `Demo.Anthropic.Agent.Provisioning` | `IAgentProvisioner`: resolves a card to live cloud IDs (with cache + session reuse). |
| `Demo.Anthropic.Agent.Cleanup` | Background TTL purge of sessions, environments and retired agents. |
| `Demo.Anthropic.Agent.Folder` | Uploads the selected project folder to the Files API (mounted under `/workspace/project`). |
| `Demo.Anthropic.Agent.LocalApply` | Extracts the `PYTHIA_*` manifest + unified diff and applies it to the local project. |
| `Demo.Anthropic.Context` | Conversation continuity; reads `Session.Events`. |
| `Demo.Anthropic.Upload` | `IFileUploadService` (`TDownloadService`): attachment upload to the Files API. |
| `Demo.Anthropic.AsyncUtils` | `IAnthropicClientUtils`: async client helpers. |
| `Demo.Anthropic.DisplayBlocks` | Centralized rendering of assistant / status / tool display blocks. |
| `Demo.Anthropic.Finalize` | End-of-round snapshot (`TFinalizeData`) and single-call emit guard. |
| `Demo.Anthropic.Helpers` | Shared payload helpers. |
| `Demo.Anthropic.JsonResponse.Helper` | JSON response parsing helpers. |
| `Demo.Anthropic.Strs` | Localized demo strings (confirmation labels, etc.). |

---

## Where to dig in the code

| Layer                  | Units                                                                              |
|------------------------|------------------------------------------------------------------------------------|
| Card model & loading   | `Agent.Cards`, `Agent.Markdown`, `Agent.Fingerprint`                               |
| Cloud lifecycle        | `Agent.Registry`, `Agent.Provisioning`, `Agent.Cleanup`                            |
| Local project bridge   | `Agent.Folder` (upload), `Agent.LocalApply` (apply manifest + diff)                |
| Run-time flow          | `Session.Transport`, `Session.Events`, `Session.Flow`, `Agent.TurnDisplay`         |

All units live under [`demos/VCL/pythia-anthropic`](.) with the
`Demo.Anthropic.` prefix.

---

## Caveats

> [!WARNING]
> **Occasional cloud-side `503` errors.** Anthropic's Managed Agents API is
> still in beta and the platform appears to be capacity-constrained at
> times. A run may fail with a `503` returned by the cloud. Unlike the
> regular Pythia error path, that failure is delivered *inside a tool
> result block* rather than as a top-level Pythia error notification, so
> it does not pop up the usual error dialog. What you will see instead is
> the turn ending early with the error embedded in the agent's trace —
> control is returned to you, the chip stays in place, and you can simply
> resend the prompt. This is a transient platform issue, not a bug in the
> card or in the demo.

<br>

> [!NOTE]
> **Scope of this document.** The five cards covered here exercise only
> the core Managed Agents surface: built-in tools (`web_search`,
> `web_fetch`, `read`, `glob`, `grep`, `edit`), single-agent and
> multi-agent topologies, sandbox uploads, and the local apply round-trip.
> MCP servers, skills, Vault and memories already work in Pythia outside
> the agent context and are documented separately. What is **not** covered
> here is their use *from inside an agent card* — wiring an MCP server or
> a skill into a managed agent's tool list, or letting an agent reach
> Vault and memories during a run. That integration will be the subject
> of a separate document.


