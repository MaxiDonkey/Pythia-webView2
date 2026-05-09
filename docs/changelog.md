#### 2026 May 8 - version 0.9.1

- Prevent redundant chat session reload

Added a selection guard in `ChatSessionSelection` to prevent the currently active chat session from being reloaded when its item is clicked again in the file drawer. 

<br>

- WebView2 Layout Fix

Fixed the layout between the main DOM area and the input bubble: the space occupied by the bubble at the bottom of the screen is now dynamically reserved, preventing content from appearing underneath it.

The DOM area remains in the normal page flow with the global WebView2 scroll. The bubble stays vertically centered when empty, moves correctly to the bottom once a conversation exists, and the layout remains responsive on window resize.