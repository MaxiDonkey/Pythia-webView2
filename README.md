# Pythia-Webview2 for Delphi
![Version](https://img.shields.io/badge/version-0.9-blue)
![Status](https://img.shields.io/badge/status-first%20public%20release-2ea44f)
![Delphi](https://img.shields.io/badge/Delphi-11%2F12%2F13-ffffba)
![Platform](https://img.shields.io/badge/platform-Windows%20only-0078D4?logo=windows&logoColor=white)
[![Requires](https://img.shields.io/badge/requires-WebView2-5C2D91)](https://developer.microsoft.com/microsoft-edge/webview2)
[![WebView4Delphi](https://img.shields.io/badge/dependency-WebView4Delphi-2ea44f?logo=github)](https://github.com/salvadordf/WebView4Delphi)

**A modern AI interaction layer for Delphi VCL and FMX desktop applications.**

**Pythia-Webview2** lets you embed a ChatGPT- or Claude-style chat workspace into a Delphi desktop application while keeping application logic, vendor integration, persistence, security, and business rules under Delphi control.

> **Platform note**  
> **Pythia-Webview2** is built on **Microsoft WebView2**.  
> In practice, this means the component targets **Windows desktop applications**.

## Table of Contents

- [Changelog](docs/changelog.md)
- [Get started in a few lines](#get-started-in-a-few-lines)
- [What Pythia-Webview2 is](#what-pythia-webview2-is)
- [Vendor-native by design](#vendor-native-by-design)
- [What Pythia-Webview2 is not](#what-pythia-webview2-is-not)
- [Demos](#demos)
- [Documentation](#documentation)
- [Recommended reading path](#recommended-reading-path)
- [Current feature scope](#current-feature-scope)
- [Integration model](#integration-model)
- [Architecture at a glance](#architecture-at-a-glance)
- [Repository structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Design principles](#design-principles)
- [Status](#status)
- [License](#license)

<br>

## Get started in a few lines

### VCL

```pascal
uses
  VCL.WVPythia.Chat, WVPythia.Types;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
  public
    Pythia: TVCLPythia;
  end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TVCLPythia.Create(Panel1);
  Pythia.Update;
end;
```

### FMX

```pascal
uses
  FMX.WVPythia.Chat, WVPythia.Types;

type
  TForm1 = class(TForm)
    Layout1: TLayout;
  public
    Pythia: TFMXPythia;
  end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Pythia := TFMXPythia.Create(Layout1);
  Pythia.AttachHost(Self);
  Pythia.Update;
end;
```

> [!IMPORTANT]
> **Note — WebView4Delphi**
>
> **Pythia-Webview2** relies heavily on [`WebView4Delphi`](https://github.com/salvadordf/WebView4Delphi), an open-source project maintained by [`salvadordf`](https://github.com/salvadordf) and released under the MIT license.
>
> The version included in `dependencies/` is not necessarily the latest one.
> For project use, it is recommended to clone the official `WebView4Delphi` repository and then add its source path to the `Browser` project options, under **Source**.
>
> The `dependencies/` directory provided here is mainly intended to make the examples quick to compile and to improve the discovery experience.
>
> If the `WebView4Delphi` code is included in this repository, the original project’s license and copyright notices must be preserved in the corresponding third-party files. (Please refer to those files.)

This is the smallest valid setup: it hosts the Pythia-Webview2 interface.

For a real integration, add a service adapter and vendor/plugin wiring.
If an action requires host-side services that are not connected yet, the
component reports a warning instead of failing silently or crashing.

In a real application, you will typically add a service adapter, a capabilities configuration, a model list, and one or more vendor services.

<br>

## What Pythia-Webview2 is

**Pythia-Webview2** provides the reusable desktop interaction layer around AI features:

- chat interface;
- input bar;
- streaming display;
- model selector;
- files and attachments;
- cards for functions, MCP, skills, agents, and custom integrations;
- slash commands;
- media rendering;
- sessions;
- themes and templates;
- Delphi event bridge.

**Pythia-Webview2** gives Delphi applications a modern AI workspace without forcing them into a web architecture.

The interface is embedded.  
> Control stays on the Delphi side.

<br>

### overview

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/images/screenshots/pythia-workspace-dark.png?raw=true" width="100%"/>
    </td>
    <td width="50%" align="center">
      <img src="docs/images/screenshots/pythia-workspace-light.png?raw=true" width="100%"/>
    </td>
  </tr>
</table>


> [!NOTE]
> Interface shown in French. **Pythia-Webview2** supports internationalization through dictionaries and currently offers 23 languages.

<br>

## Vendor-native by design

**Pythia-Webview2** is not an LLM SDK.

It does not replace the OpenAI, Anthropic, Gemini, Mistral, or any other vendor SDK.

Nor does it try to reduce all vendors to a minimal common API. Each provider has its own request model, its own streaming behavior, and its own feature surface. **Pythia-Webview2** lets each integration keep that native logic.

**Pythia-Webview2** standardizes the **interaction layer**, not the **vendor layer**.

Your application receives a structured prompt state and decides how to transform it into a native request for the selected vendor.

<br>

## What Pythia-Webview2 is not

**Pythia-Webview2** is deliberately not:

- a vendor SDK;
- a REST wrapper;
- a universal LLM abstraction;
- an agent orchestrator;
- a replacement for your business layer;
- a framework that decides how your application should call a model.

**Pythia-Webview2** handles the interaction surface.  
Your Delphi code handles the execution semantics.

<br>

## Demos

The repository ships seven runnable demos, grouped into three families.

### Starter projects

Minimal hosts to copy when starting a new application — no vendor wired, no plugin registered.

|Project|Folder|
|-|-|
|`NewVCLproject`|[`demos/VCL/new-projet`](demos/VCL/new-projet)|
|`NewFMXproject`|[`demos/FMX/new-projet`](demos/FMX/new-projet)|

### Showcase demos

|Project|Folder|Documentation|
|-|-|-|
|`PythiaSampleVCL`|[`demos/VCL/pythia-sample`](demos/VCL/pythia-sample)|[Discovery walkthrough](docs/PythiaSampleVCL.md) — UI tour and component capabilities|
|`VCL_Anthropic`|[`demos/VCL/pythia-anthropic`](demos/VCL/pythia-anthropic)|[Anthropic vendor integration](docs/VCL_Anthropic.md) — connects **Pythia-Webview2** to a real LLM via the Delphi Anthropic SDK with native async/await support|

### Plugin demos

Custom slash commands that extend the chat with host-side logic. Each plugin ships a dedicated developer document under `docs/`.

|Project|Folder|Command|Documentation|
|-|-|-|-|
|`PythiaSnippetDemo`|[`demos/FMX/plugin-snippet`](demos/FMX/plugin-snippet)|`/snippet`|[Local prompt library](demos/FMX/plugin-snippet/README.md)|
|`PythiaGitDemo`|[`demos/FMX/plugin-git`](demos/FMX/plugin-git)|`/git`|[Git context collector](demos/FMX/plugin-git/README.md)|
|`PythiaGrepDemo`|[`demos/FMX/plugin-grep`](demos/FMX/plugin-grep)|`/grep`|[Interactive code-context picker](demos/FMX/plugin-grep/README.md)|

These demos do not try to demonstrate a fake universal LLM API.

They show how **Pythia-Webview2** provides a common interaction workspace while letting each integration keep its native vendor logic.

<br>

## Documentation

- [Integrator guide](docs/integrator/index.md) — build a first application based on **Pythia-Webview2**.
- [Technical reference](docs/reference/index.md) — interfaces, events, templates, JSON files.
- [Complete single-file guide](docs/pythia-documentation.md) — exhaustive documentation in Markdown format.

The README intentionally focuses on quickly understanding the project.  
The detailed documentation is split into focused pages, while the complete guide remains available as a single Markdown file to serve as an exhaustive reference.

<br>

## Recommended reading path

For a first exploration:

1. Read this README.
2. Run `PythiaSampleVCL` to discover the chat surface and the component's capabilities.
3. Open one of the starter projects (`NewVCLproject` or `NewFMXproject`) to see a minimal host.
4. Read the integrator guide.
5. Study `VCL_Anthropic` to see how **Pythia-Webview2** connects to a real LLM SDK.
6. Explore the plugin demos (`/snippet`, `/git`, `/grep`) to understand the command layer and the JS↔Delphi bridge.
7. Use the technical reference for interfaces, events, JSON formats, and template details.

<br>

## Current feature scope

|Area|Status|Notes|
|-|-:|-|
|VCL component|Available|Desktop chat component for VCL applications|
|FMX component|Available|Desktop chat component for FireMonkey applications|
|WebView2-based UI|Available|HTML/JavaScript rendering hosted in Delphi; targets Windows|
|Delphi event bridge|Available|UI events are routed to Delphi handlers and services|
|Streaming display|Available|Vendor services can push text and reasoning deltas|
|Markdown rendering|Available|Chat content, code blocks, and final rendering pipeline|
|Chat sessions|Available|Persistence, restoration, and pagination|
|Model selector|Available|Model list and categories driven by JSON|
|Capabilities system|Available|Feature visibility controlled by JSON configuration|
|Slash commands|Available|Plugin-based command layer, with built-in API key commands|
|API key management|Available|Logical names, local secret storage, and update notifications|
|Card system|Available|Functions, MCP, skills, agents, and custom cards|
|Files and attachments|Available|Images, documents, knowledge files, and transcription-related entries|
|Media rendering|Available|Images, audio, video, and files returned by vendor services|
|Internationalization|Available|Dictionary loading and translation hooks|
|Theme and look & feel|Available|UI templates and synchronization hooks with the host application|
|Custom JavaScript templates|Available|Replaceable or extensible UI fragments|
|Vendor integration|Defined by the host|**Pythia-Webview2** exposes the state; the application chooses how to call vendors|
|Agent / MCP / skill semantics|Defined by the host|**Pythia-Webview2** transports selections; execution remains application-specific|

<br>

## Integration model

A **Pythia-Webview2** application generally follows this flow:

```
User interaction
    ↓
HTML / JavaScript template
    ↓
WebView2 message bridge
    ↓
Delphi event handler
    ↓
Service adapter
    ↓
Application logic
    ↓
Vendor SDK or internal backend
    ↓
Streamed response and final result
    ↓
Pythia-Webview2 UI rendering and session persistence
```

The key point is that **Pythia-Webview2** does not own the vendor call.

It provides the application with a structured interaction state and a rendering pipeline. The application decides how that state becomes an OpenAI, Anthropic, Gemini, Mistral, or internal request.

<br>

## Architecture at a glance

**Pythia-Webview2** is based on a clear separation:

|Layer|Responsibility|
|-|-|
|Embedded UI|Chat surface, input bar, panels, selectors, rendering, templates|
|WebView2 bridge|Communication between HTML/JavaScript and Delphi|
|Delphi event layer|Routing, validation, handlers, adapters|
|Host application|Vendor calls, business logic, security, persistence decisions|
|Vendor SDKs|Native access to OpenAI, Anthropic, Gemini, Mistral, or any other backend|

The component provides the application with a modern AI workspace without taking ownership of the vendor API.

<br>

## Repository structure

```
assets/                 Embedded HTML and JavaScript templates
source/                 Delphi source code
demos/                  VCL, FMX, vendor, and plugin examples
docs/                   Exhaustive guide, integrator docs, reference docs
dependencies/           Optional third-party dependencies for quickly compiling the demos
```

<br>

## Prerequisites

|Prerequisite|Notes|
|-|-|
|Delphi|Delphi 11, 12, or 13|
|UI framework|VCL and/or FMX|
|Platform|Windows|
|WebView2 Runtime|Microsoft Edge WebView2 Evergreen Runtime|
|WebView4Delphi|Used to host WebView2 from Delphi|

<br>

## Design principles

### Keep the desktop application in control

**Pythia-Webview2** is designed for real Delphi applications, where the host software owns the workflow, permissions, data, persistence, and vendor decisions.

### Do not flatten vendors

Each provider has its strengths and its API model. **Pythia-Webview2** lets integrations remain vendor-native instead of reducing them to a simplified common subset.

### Make the UI reusable

The chat interface, panels, selectors, rendering, commands, and sessions should not have to be rewritten for every application.

### Keep extension points explicit

**Pythia-Webview2** exposes clear contracts for adapters, commands, templates, capabilities, cards, models, and vendor services.

<br>

## Status

**Pythia-Webview2** is available as a first public release.

The component, documentation, and demos are ready for evaluation and integration
in Delphi VCL/FMX desktop applications.

The public API is intended to remain stable, although minor adjustments may
still occur before the first long-term stable release.

<br>

## License

This project is licensed under the [MIT](https://choosealicense.com/licenses/mit/) License.
