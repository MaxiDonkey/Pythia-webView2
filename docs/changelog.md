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