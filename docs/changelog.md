#### 2026 May 8 - version 0.9.1

- Improve streamed response rendering pipeline

Refactored the WebView2 display bridge so `display` and `displayStream` are now handled independently. Streamed responses are buffered and rendered progressively in smaller chunks for smoother output, while post-response elements such as media, footer, and spacer are deferred until the active stream has fully completed. This prevents DOM elements from being inserted between streamed text chunks.

<br>

- Prevent redundant chat session reload

Added a selection guard in `ChatSessionSelection` to prevent the currently active chat session from being reloaded when its item is clicked again in the file drawer. 

<br>

- WebView2 Layout Fix

Fixed the layout between the main DOM area and the input bubble: the space occupied by the bubble at the bottom of the screen is now dynamically reserved, preventing content from appearing underneath it.

The DOM area remains in the normal page flow with the global WebView2 scroll. The bubble stays vertically centered when empty, moves correctly to the bottom once a conversation exists, and the layout remains responsive on window resize.