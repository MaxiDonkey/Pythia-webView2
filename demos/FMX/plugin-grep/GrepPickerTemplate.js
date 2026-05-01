/* =================================================================
   Grep picker template
   --------------------------------------------------------------
   Self-contained IIFE injected by Demo.Grep.Plugin.Service.

   Contract with the Delphi side
     window.__grepPickerPayload__   base64-encoded JSON:
       {
         pattern, root, count, truncated,
         matches: [{ id, file, line, snippet }, ...]
       }

     The picker decodes this payload once, builds a modal overlay,
     and lets the user tick the matches that should land in the
     prompt. On confirm it emits 'grep.pick'; on cancel it emits
     'grep.cancel'. Both events go through the standard custom-event
     channel:

       window.chrome.webview.postMessage({
         event:  "custom-event",
         name:   "grep.pick" | "grep.cancel",
         payload: { ... }
       });

     The picker carries the full match data back in the 'pick'
     payload (file, line, snippet) so the Delphi side does not need
     to re-correlate by id.

   Why no LoadCustomTemplate
     The picker is transient: it is created on demand by the plugin
     and removed once the user has answered. Wiring it through
     ITemplateProvider would tie its lifecycle to the WebView load
     cycle. ExecuteScript injection keeps it under the plugin's
     control.
   ================================================================= */

(() => {
  const OVERLAY_ID = "__grep_picker_overlay__";
  const STYLE_ID   = "__grep_picker_style__";
  const EVENT_NAME = "custom-event";

  /* ---------------- payload bootstrap ---------------- */

  function decodePayload() {
    try {
      const b64 = window.__grepPickerPayload__ || "";
      const raw = atob(b64);
      const utf8 = decodeURIComponent(escape(raw));
      const obj = JSON.parse(utf8);

      if (!obj || !Array.isArray(obj.matches)) {
        return null;
      }

      return obj;
    } catch (e) {
      console.warn("[grep-picker] payload decode failed:", e);
      return null;
    }
  }

  const data = decodePayload();
  if (!data) {
    return;
  }

  /* ---------------- DOM cleanup ---------------- */

  function removeExisting() {
    const previous = document.getElementById(OVERLAY_ID);
    if (previous && previous.parentNode) {
      previous.parentNode.removeChild(previous);
    }
  }

  /* ---------------- styles ---------------- */

  function ensureStyles() {
    if (document.getElementById(STYLE_ID)) {
      return;
    }

    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      #${OVERLAY_ID} {
        position: fixed; inset: 0; z-index: 99999;
        background: rgba(0, 0, 0, 0.55);
        display: flex; align-items: center; justify-content: center;
        font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI",
                      Roboto, sans-serif;
      }
      #${OVERLAY_ID} .grep-modal {
        background: var(--surface, #1f1f24);
        color: var(--text, #e6e6e6);
        width: min(820px, 92vw);
        max-height: 86vh;
        border-radius: 12px;
        box-shadow: 0 18px 48px rgba(0, 0, 0, 0.45);
        display: flex; flex-direction: column;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.08);
      }
      #${OVERLAY_ID} .grep-head {
        padding: 14px 18px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.07);
        display: flex; flex-direction: column; gap: 4px;
      }
      #${OVERLAY_ID} .grep-head .title {
        font-weight: 600; font-size: 15px;
      }
      #${OVERLAY_ID} .grep-head .meta {
        font-size: 12px; opacity: 0.7;
        word-break: break-all;
      }
      #${OVERLAY_ID} .grep-toolbar {
        display: flex; align-items: center; gap: 12px;
        padding: 8px 18px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.07);
        font-size: 12px;
      }
      #${OVERLAY_ID} .grep-toolbar input[type="search"] {
        flex: 1; padding: 6px 9px;
        background: rgba(255, 255, 255, 0.05);
        color: inherit;
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 6px;
        outline: none;
      }
      #${OVERLAY_ID} .grep-toolbar .grep-counter {
        opacity: 0.7;
        white-space: nowrap;
      }
      #${OVERLAY_ID} .grep-list {
        overflow-y: auto;
        padding: 6px 4px 6px 12px;
        flex: 1;
      }
      #${OVERLAY_ID} .grep-file {
        margin: 8px 4px;
      }
      #${OVERLAY_ID} .grep-file-head {
        display: flex; align-items: center; gap: 8px;
        padding: 6px 4px;
        font-size: 13px; font-weight: 600;
        cursor: pointer; user-select: none;
      }
      #${OVERLAY_ID} .grep-file-head .grep-path {
        color: var(--accent, #7aa6ff);
        font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas,
                      monospace;
        font-size: 12.5px;
        word-break: break-all;
      }
      #${OVERLAY_ID} .grep-file-head .grep-fcount {
        opacity: 0.5; font-weight: 400; font-size: 11.5px;
      }
      #${OVERLAY_ID} .grep-row {
        display: flex; align-items: flex-start; gap: 10px;
        padding: 5px 8px 5px 26px;
        border-radius: 6px;
        font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas,
                      monospace;
        font-size: 12px;
        line-height: 1.5;
      }
      #${OVERLAY_ID} .grep-row:hover {
        background: rgba(255, 255, 255, 0.04);
      }
      #${OVERLAY_ID} .grep-row .grep-line {
        opacity: 0.5; min-width: 44px; text-align: right;
        user-select: none;
      }
      #${OVERLAY_ID} .grep-row .grep-snippet {
        flex: 1;
        white-space: pre-wrap;
        word-break: break-word;
      }
      #${OVERLAY_ID} .grep-row .grep-hl {
        background: rgba(255, 230, 100, 0.25);
        border-radius: 2px;
        padding: 0 1px;
      }
      #${OVERLAY_ID} .grep-foot {
        display: flex; align-items: center; justify-content: space-between;
        gap: 12px;
        padding: 12px 18px;
        border-top: 1px solid rgba(255, 255, 255, 0.07);
        font-size: 13px;
      }
      #${OVERLAY_ID} .grep-foot .grep-summary { opacity: 0.7; }
      #${OVERLAY_ID} .grep-foot .grep-actions {
        display: flex; gap: 8px;
      }
      #${OVERLAY_ID} button {
        padding: 7px 14px;
        border-radius: 8px; border: 1px solid transparent;
        font: inherit; cursor: pointer;
        background: rgba(255, 255, 255, 0.06);
        color: inherit;
      }
      #${OVERLAY_ID} button:hover { background: rgba(255, 255, 255, 0.10); }
      #${OVERLAY_ID} button.primary {
        background: var(--accent, #4f7cff);
        color: white;
      }
      #${OVERLAY_ID} button.primary:disabled {
        background: rgba(120, 120, 140, 0.4);
        color: rgba(255, 255, 255, 0.55);
        cursor: not-allowed;
      }
      #${OVERLAY_ID} input[type="checkbox"] { cursor: pointer; }
      #${OVERLAY_ID} .grep-truncated {
        margin: 6px 12px;
        padding: 6px 10px;
        border-radius: 6px;
        background: rgba(255, 200, 80, 0.12);
        color: rgba(255, 200, 80, 0.95);
        font-size: 12px;
      }
      [data-theme="light"] #${OVERLAY_ID} .grep-modal {
        background: #ffffff; color: #1f1f24;
        border: 1px solid rgba(0, 0, 0, 0.08);
      }
      [data-theme="light"] #${OVERLAY_ID} .grep-toolbar input[type="search"] {
        background: #f6f6f8; border-color: rgba(0, 0, 0, 0.1);
      }
      [data-theme="light"] #${OVERLAY_ID} .grep-row:hover {
        background: rgba(0, 0, 0, 0.04);
      }
      [data-theme="light"] #${OVERLAY_ID} button {
        background: rgba(0, 0, 0, 0.05);
      }
      [data-theme="light"] #${OVERLAY_ID} button:hover {
        background: rgba(0, 0, 0, 0.10);
      }
    `;
    document.head.appendChild(style);
  }

  /* ---------------- helpers ---------------- */

  function escapeHtml(s) {
    const text = String(s == null ? "" : s);
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function highlightSnippet(snippet, pattern) {
    const safe = escapeHtml(snippet);
    if (!pattern) {
      return safe;
    }

    const lowerSafe = safe.toLowerCase();
    const lowerPat = pattern.toLowerCase();

    const out = [];
    let cursor = 0;

    while (true) {
      const found = lowerSafe.indexOf(lowerPat, cursor);
      if (found < 0) {
        out.push(safe.substring(cursor));
        break;
      }
      out.push(safe.substring(cursor, found));
      out.push(
        '<span class="grep-hl">' +
        safe.substring(found, found + lowerPat.length) +
        "</span>"
      );
      cursor = found + lowerPat.length;
    }

    return out.join("");
  }

  function postEvent(name, payload) {
    try {
      window.chrome.webview.postMessage({
        event:   EVENT_NAME,
        name:    name,
        payload: payload || {}
      });
    } catch (e) {
      console.warn("[grep-picker] postMessage failed:", e);
    }
  }

  /* ---------------- rendering ---------------- */

  function groupByFile(matches) {
    const groups = new Map();
    matches.forEach((m) => {
      if (!groups.has(m.file)) {
        groups.set(m.file, []);
      }
      groups.get(m.file).push(m);
    });
    return groups;
  }

  function build(matches) {
    const overlay = document.createElement("div");
    overlay.id = OVERLAY_ID;

    const modal = document.createElement("div");
    modal.className = "grep-modal";
    overlay.appendChild(modal);

    /* head */
    const head = document.createElement("div");
    head.className = "grep-head";
    head.innerHTML = `
      <div class="title">Grep — pick the matches you want as context</div>
      <div class="meta">
        Pattern <code>${escapeHtml(data.pattern)}</code>
        &middot; ${matches.length} match${matches.length === 1 ? "" : "es"}
        &middot; <span title="${escapeHtml(data.root)}">${escapeHtml(
          data.root)}</span>
      </div>
    `;
    modal.appendChild(head);

    /* toolbar */
    const toolbar = document.createElement("div");
    toolbar.className = "grep-toolbar";
    toolbar.innerHTML = `
      <input type="search" placeholder="Filter by file or text…"
             aria-label="Filter matches" />
      <span class="grep-counter">0 selected</span>
    `;
    modal.appendChild(toolbar);

    /* truncated banner */
    if (data.truncated) {
      const banner = document.createElement("div");
      banner.className = "grep-truncated";
      banner.textContent =
        "Result set was truncated. Narrow the pattern or use a sub-path.";
      modal.appendChild(banner);
    }

    /* list */
    const list = document.createElement("div");
    list.className = "grep-list";
    modal.appendChild(list);

    const groups = groupByFile(matches);
    groups.forEach((group, fileName) => {
      const fileBlock = document.createElement("div");
      fileBlock.className = "grep-file";
      fileBlock.dataset.file = fileName;

      const fileHead = document.createElement("div");
      fileHead.className = "grep-file-head";
      fileHead.innerHTML = `
        <input type="checkbox" class="grep-file-toggle"
               aria-label="Toggle all matches in ${escapeHtml(fileName)}">
        <span class="grep-path">${escapeHtml(fileName)}</span>
        <span class="grep-fcount">${group.length}</span>
      `;
      fileBlock.appendChild(fileHead);

      const rowsHost = document.createElement("div");
      rowsHost.className = "grep-rows";
      fileBlock.appendChild(rowsHost);

      group.forEach((m) => {
        const row = document.createElement("label");
        row.className = "grep-row";
        row.dataset.matchId = String(m.id);
        row.innerHTML = `
          <input type="checkbox" class="grep-row-cb" data-id="${m.id}">
          <span class="grep-line">L${m.line}</span>
          <span class="grep-snippet">${highlightSnippet(m.snippet,
            data.pattern)}</span>
        `;
        rowsHost.appendChild(row);
      });

      list.appendChild(fileBlock);
    });

    /* foot */
    const foot = document.createElement("div");
    foot.className = "grep-foot";
    foot.innerHTML = `
      <span class="grep-summary">Esc cancels &middot;
        Ctrl+Enter injects</span>
      <span class="grep-actions">
        <button class="grep-cancel">Cancel</button>
        <button class="grep-confirm primary" disabled>Inject as context</button>
      </span>
    `;
    modal.appendChild(foot);

    return { overlay, toolbar, list, foot };
  }

  /* ---------------- behaviour ---------------- */

  function activate(parts, matches) {
    const filterInput = parts.toolbar.querySelector('input[type="search"]');
    const counter     = parts.toolbar.querySelector(".grep-counter");
    const confirmBtn  = parts.foot.querySelector(".grep-confirm");
    const cancelBtn   = parts.foot.querySelector(".grep-cancel");

    const matchById = new Map();
    matches.forEach((m) => matchById.set(m.id, m));

    function rowCheckboxes() {
      return parts.list.querySelectorAll(".grep-row-cb");
    }

    function selectedIds() {
      const ids = [];
      rowCheckboxes().forEach((cb) => {
        if (cb.checked) {
          const visibleRow = cb.closest(".grep-row");
          if (visibleRow && visibleRow.style.display !== "none") {
            ids.push(parseInt(cb.dataset.id, 10));
          }
        }
      });
      return ids;
    }

    function refreshCounter() {
      const n = selectedIds().length;
      counter.textContent =
        n + " selected";
      confirmBtn.disabled = n === 0;
    }

    /* per-row toggle */
    parts.list.addEventListener("change", (ev) => {
      const target = ev.target;
      if (!(target instanceof HTMLInputElement)) {
        return;
      }
      if (target.classList.contains("grep-row-cb")) {
        refreshCounter();

        /* sync the per-file toggle */
        const fileBlock = target.closest(".grep-file");
        if (fileBlock) {
          const fileToggle = fileBlock.querySelector(".grep-file-toggle");
          const rows = fileBlock.querySelectorAll(".grep-row-cb");
          const all = Array.from(rows).every((r) => r.checked);
          const none = Array.from(rows).every((r) => !r.checked);
          fileToggle.checked = all;
          fileToggle.indeterminate = !all && !none;
        }
        return;
      }

      if (target.classList.contains("grep-file-toggle")) {
        const fileBlock = target.closest(".grep-file");
        if (!fileBlock) return;
        const rows = fileBlock.querySelectorAll(".grep-row-cb");
        rows.forEach((r) => { r.checked = target.checked; });
        target.indeterminate = false;
        refreshCounter();
      }
    });

    /* filter */
    filterInput.addEventListener("input", () => {
      const q = filterInput.value.trim().toLowerCase();
      parts.list.querySelectorAll(".grep-file").forEach((fb) => {
        const fileName = (fb.dataset.file || "").toLowerCase();
        let visibleCount = 0;
        fb.querySelectorAll(".grep-row").forEach((row) => {
          if (q.length === 0) {
            row.style.display = "";
            visibleCount++;
            return;
          }
          const text = row.textContent.toLowerCase();
          const matches =
            text.indexOf(q) >= 0 ||
            fileName.indexOf(q) >= 0;
          row.style.display = matches ? "" : "none";
          if (matches) visibleCount++;
        });
        fb.style.display = visibleCount === 0 ? "none" : "";
      });
      refreshCounter();
    });

    /* confirm */
    function confirm() {
      const ids = selectedIds();
      if (ids.length === 0) return;

      const picked = ids.map((id) => {
        const m = matchById.get(id);
        return m
          ? { file: m.file, line: m.line, snippet: m.snippet }
          : null;
      }).filter(Boolean);

      postEvent("grep.pick", {
        pattern:  data.pattern,
        root:     data.root,
        selected: picked
      });

      teardown();
    }

    /* cancel */
    function cancel() {
      postEvent("grep.cancel", { pattern: data.pattern });
      teardown();
    }

    confirmBtn.addEventListener("click", confirm);
    cancelBtn.addEventListener("click", cancel);
    parts.overlay.addEventListener("click", (ev) => {
      if (ev.target === parts.overlay) cancel();
    });

    function onKey(e) {
      if (e.key === "Escape") {
        e.preventDefault();
        cancel();
      } else if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        if (!confirmBtn.disabled) confirm();
      }
    }
    document.addEventListener("keydown", onKey, true);

    function teardown() {
      document.removeEventListener("keydown", onKey, true);
      window.__grepPickerPayload__ = "";
      removeExisting();
    }

    refreshCounter();
    setTimeout(() => filterInput.focus(), 0);
  }

  /* ---------------- mount ---------------- */

  removeExisting();
  ensureStyles();
  const parts = build(data.matches);
  document.body.appendChild(parts.overlay);
  activate(parts, data.matches);
})();
