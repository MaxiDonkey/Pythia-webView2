#### 2026 May 19 - version 0.9.4

- Switch the VCL_Anthropic stream flow to event callbacks

Refactored `demos\VCL\pythia-anthropic\Demo.Anthropic.Services.pas` so `TAnthropicServices.AsyncAwaitStreamChat` now uses typed stream event callbacks instead of a session callback. Assistant, reasoning, tool-use, and tool-result deltas now update the same state captured by finalization, which gives the demo a more suitable flow for building display blocks from the live Anthropic stream.

<br>

- Add Anthropic display block aggregation to the demo

Added `demos\VCL\pythia-anthropic\Demo.Anthropic.DisplayBlocks.pas` to translate Anthropic stream events into ordered Pythia display blocks. This block aggregation is the demo-level feature that ties together the new WebView2 `displayBlock` bridge and the persisted turn `DisplayBlocks` support described below, so live rendering, replay, and saved chat sessions all use the same structured representation.

<br>

- Update DelphiAnthropic dependency for typed stream events

Updated the embedded `dependencies\DelphiAnthropic` SDK dependency to version `1.3.1`. The VCL_Anthropic demo now relies on the SDK stream event callbacks and snapshots used by the display block aggregator.

<br>

- Add structured display block support to the chat bridge

Extended `assets\scripts\DisplayTemplate.js` with the new `displayBlock`, `displayBlockStream`, and `displayBlocks` helpers, then exposed the matching Delphi API through `source\WVPythia.Chat.Interfaces.pas`, `source\VCL.WVPythia.Chat.pas`, and `source\FMX.WVPythia.Chat.pas`. The chat bridge can now render assistant, reasoning, status, tool, source, citation, artifact, and media blocks through the same WebView2 display pipeline used for full and streamed responses.

<br>

- Persist display blocks in chat session turns

Updated the chat session turn model so structured display blocks are carried with the persisted session data. `TChatTurn` now owns cloned `TChatDisplayBlock` and `TChatDisplayItem` instances, exposes helpers for cloning, freeing, and JSON conversion, and `TOrchestratorEventHandler.CompleteTurn` now copies `AResult.DisplayBlocks` into the completed turn before saving the session.

<br>

#### 2026 May 17 - version 0.9.3

- Update DelphiAnthropic dependency for the VCL_Anthropic demo

Replaced the DelphiAnthropic dependency used by the `VCL_Anthropic` demo from version `1.2.0` to version `1.3.0`. The demo remains integrated as a Pythia vendor implementation and now targets the updated Anthropic SDK surface.

<br>

- Adapt Anthropic context replay and beta handling

Updated `demos\VCL\pythia-anthropic\Demo.Anthropic.Context.pas` for the newer Anthropic beta behavior, including replay support aligned with the SDK 1.3 code-execution result blocks. The demo now uses a hybrid beta mode: SDK auto-detection via `TBetaHeaderManager` is preserved, while the vendor layer adds only the extra beta tokens still needed for legacy replay, skills, or Files API scenarios.

<br>

- Route dropped media files to the image list

Updated the input bubble file handling so image files received through drag-and-drop or file selection are detected by MIME type and extension, then routed to the image attachment list instead of the generic file list. The UI now keeps documents and image media separated correctly.

- Fix Anthropic web search tool result replay (VCL_Anthropic demo)

Added support for replaying `web_search_tool_result` blocks in the Anthropic context builder. This preserves the required pairing between previous `web_search` tool calls and their results, preventing 400 errors when continuing conversations that used web search earlier.


#### 2026 May 11 - version 0.9.2

- Fix code block parsing with KaTeX protection

Fixed a rendering regression where Delphi code blocks containing `$` characters could be incorrectly merged when KaTeX protection was applied before Markdown parsing. Markdown code fences are now protected as complete opening/closing pairs before math detection, preserving each code container independently while keeping KaTeX rendering intact.

<br>

- Add dedicated knowledge indexing service support

Added a dedicated `IKnowledgeIndexingService` pipeline separate from file uploads, with VCL and FMX integration, event-handler routing for Knowledge files, aggregated send-button availability, and an `indexing` status reflected in the WebView2 UI. This prepares the chat bridge for vendor-specific vectorization workflows where files must be fully indexed before being used as knowledge sources.

<br>

- Fix KaTeX rendering inside Markdown responses

Protected LaTeX math blocks during Markdown parsing so KaTeX expressions remain intact before rendering. This prevents formulas containing delimiters, spacing commands, or comparison symbols from being partially interpreted as Markdown or displayed as raw KaTeX code.

<br>

#### 2026 May 9 - version 0.9.1

- Add controlled paste-from-clipboard handling

Added controlled clipboard paste handling from the input bubble. The JavaScript side now blocks the native paste, sends the current prompt and cursor selection to Delphi, and lets the platform-specific clipboard reader decide how to handle pasted text, files, paths, or images before updating the UI.

<br>

- Add file drop handling through the WebView2 bridge

Implemented clean file drop support by extracting dropped file paths from WebView2 additional objects in both VCL and FMX, then forwarding them through the existing event aggregation pipeline as a `file-drop-in` event. Dropped files are now handled by the shared input attachment flow, sent back to JavaScript for display, and routed through the upload service when required.

<br>

- Add drag-and-drop file attachment support

The UI now supports adding files by dragging and dropping them directly onto the WebView2 interface.

<br>

- Improve WebView2 streamed response rendering

Refactored the display bridge so full responses and streamed responses are handled separately. Streamed deltas are now buffered and rendered progressively in smaller chunks for smoother output, while media, footer, and spacer updates are deferred until the active stream has fully completed to prevent DOM insertions from interrupting the rendered text.

<br>

- Prevent redundant chat session reload

Added a selection guard in `ChatSessionSelection` to prevent the currently active chat session from being reloaded when its item is clicked again in the file drawer. 

<br>

- WebView2 Layout Fix

Fixed the layout between the main DOM area and the input bubble: the space occupied by the bubble at the bottom of the screen is now dynamically reserved, preventing content from appearing underneath it.

The DOM area remains in the normal page flow with the global WebView2 scroll. The bubble stays vertically centered when empty, moves correctly to the bottom once a conversation exists, and the layout remains responsive on window resize.
