/* PDF Power Tools — real PDF operations through the local Print Helper PDF engine. */
(function () {
  "use strict";
  const API = "";               // same origin as the page (served by pdf_engine/server.py)
  const $ = (s, r = document) => r.querySelector(s);
  const el = (t, c, h) => { const e = document.createElement(t); if (c) e.className = c; if (h !== undefined) e.innerHTML = h; return e; };
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const toast = m => (window.showToast ? window.showToast(m) : alert(m));
  const fmtSize = b => b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB";

  const FILE_COLORS = [
    "#2563eb", "#059669", "#d97706", "#7c3aed",
    "#db2777", "#0891b2", "#ea580c", "#4f46e5"
  ];
  const genId = () => "p_" + Math.random().toString(36).slice(2, 10);

  const state = {
    files: [],
    selected: new Set(),
    tool: "merge",
    engine: null,
    ocrLangs: [],
    busy: false,
    org: [],
    orgHistory: [],
    orgRedo: [],
    orgInitial: null,
    orgThumbWidth: 200,
    orgLastFocus: 0,
    orgDropIndex: null,
    redact: { file: null, page: 1, regions: [] },
    results: []
  };

  const TOOLS = [
    { id: "merge", icon: "call_merge", name: "Merge", desc: "Combine PDFs in the order shown", need: "2+" },
    { id: "organize", icon: "dashboard_customize", name: "Organize Pages", desc: "Reorder, rotate, delete — mix pages from many PDFs", need: "1+" },
    { id: "split", icon: "call_split", name: "Split", desc: "By page count, ranges or every page", need: "1" },
    { id: "extract", icon: "content_cut", name: "Extract Pages", desc: "Keep only pages like 1-3,7,10-", need: "1" },
    { id: "delete", icon: "delete_sweep", name: "Delete Pages", desc: "Remove pages like 2,5-6", need: "1" },
    { id: "rotate", icon: "rotate_right", name: "Rotate", desc: "Rotate all, odd, even or chosen pages", need: "1" },
    { id: "crop", icon: "crop", name: "Crop Margins", desc: "Trim page margins", need: "1" },
    { id: "compress", icon: "compress", name: "Compress", desc: "Shrink size — image downsampling + stream optimisation", need: "1" },
    { id: "watermark", icon: "branding_watermark", name: "Watermark", desc: "Diagonal text stamp with opacity", need: "1" },
    { id: "pagenumbers", icon: "pin", name: "Page Numbers", desc: "Page 1 of N, any corner", need: "1" },
    { id: "protect", icon: "lock", name: "Protect (AES-256)", desc: "Open password + print/copy/edit permissions", need: "1" },
    { id: "unprotect", icon: "lock_open", name: "Remove Password", desc: "Save an unlocked copy", need: "1" },
    { id: "redact", icon: "ink_eraser", name: "Redact (permanent)", desc: "Draw boxes or auto-find words — text is truly removed", need: "1" },
    { id: "metadata", icon: "badge", name: "Metadata", desc: "Edit or wipe title, author, keywords", need: "1" },
    { id: "flatten", icon: "layers_clear", name: "Flatten", desc: "Convert pages to images (kills hidden layers/forms)", need: "1" },
    { id: "pdf_to_images", icon: "image", name: "PDF → Images", desc: "PNG/JPG per page in a ZIP", need: "1" },
    { id: "images_to_pdf", icon: "photo_library", name: "Images → PDF", desc: "Turn JPG/PNG files into one PDF", need: "images" },
    { id: "text", icon: "text_snippet", name: "Extract Text", desc: "Copy all text with layout, columns & tables", need: "1" },
    { id: "ocr", icon: "document_scanner", name: "OCR", desc: "Make scans searchable (Tesseract)", need: "1" },
    { id: "compare", icon: "compare", name: "Compare", desc: "Text differences between 2 PDFs", need: "2" },
  ];

  // ---------------------------------------------------------------- API
  async function api(path, opts) {
    const r = await fetch(API + path, opts);
    let j = null; try { j = await r.json(); } catch (e) { /* not json */ }
    if (!r.ok) throw new Error((j && j.error) || ("Server error " + r.status));
    return j;
  }
  const post = (path, obj) => api(path, { method: "POST", body: JSON.stringify(obj) });

  async function checkEngine() {
    const banner = $("#ptBanner");
    try {
      const h = await api("/api/health");
      state.engine = true; state.ocrLangs = h.ocr_langs || [];
      banner.className = "pt-banner ok";
      banner.innerHTML = `<span class="material-symbols-rounded">check_circle</span> PDF engine connected — all processing stays on this computer.` +
        (state.ocrLangs.length ? ` OCR languages: <b>${esc(state.ocrLangs.join(", "))}</b>` : ` OCR not installed (see README).`);
    } catch (e) {
      state.engine = false;
      banner.className = "pt-banner err";
      banner.innerHTML = `<span class="material-symbols-rounded">error</span><div><b>PDF engine is not running.</b> These tools need it to work on real files.<br>
        In Terminal: <code>pip3 install pikepdf pypdfium2 pillow reportlab</code> then <code>python3 pdf_engine/server.py</code> and open <code>http://localhost:8080</code>.</div>`;
    }
    renderOptions();
  }

  // ---------------------------------------------------------------- files
  async function addFiles(fileList) {
    if (!state.engine) { toast("Start the PDF engine first (see the red banner)."); return; }
    for (const f of Array.from(fileList)) {   // copy: the input is cleared right after this call
      try {
        const info = await api("/api/upload", { method: "POST", body: f, headers: { "X-Filename": encodeURIComponent(f.name) } });
        state.files.push(info); state.selected.add(info.id);
      } catch (e) { toast("❌ " + f.name + ": " + e.message); }
    }
    renderFiles(); renderOptions();
  }

  function renderFiles() {
    const box = $("#ptFileList"); box.innerHTML = "";
    if (!state.files.length) { box.innerHTML = `<div class="pt-empty">No files yet.<br>Drop PDFs (or images) here or click “Add files”.</div>`; return; }
    state.files.forEach((f, i) => {
      const row = el("div", "pt-file" + (state.selected.has(f.id) ? " sel" : ""));
      row.draggable = true; row.dataset.i = i;
      const enc = f.encrypted ? `<button class="btn btn-tonal btn-sm pt-unlock" title="Enter password">🔒 Unlock</button>` : "";
      row.innerHTML = `<input type="checkbox" ${state.selected.has(f.id) ? "checked" : ""}>
        <span class="material-symbols-rounded pt-ficon">${f.kind === "pdf" ? "picture_as_pdf" : "image"}</span>
        <div class="pt-fmeta"><b title="${esc(f.name)}">${esc(f.name)}</b><small>${f.kind === "pdf" ? (f.encrypted ? "Encrypted" : f.pages + " pages") : "Image"} • ${fmtSize(f.size)}</small></div>
        ${enc}
        <button class="btn-ghost pt-up" title="Move up">▲</button><button class="btn-ghost pt-down" title="Move down">▼</button>
        <button class="btn-ghost pt-view" title="Open">👁</button><button class="btn-ghost pt-rm" title="Remove">✕</button>`;
      $("input", row).onchange = e => { e.target.checked ? state.selected.add(f.id) : state.selected.delete(f.id); renderFiles(); renderOptions(); };
      $(".pt-rm", row).onclick = () => { state.files.splice(i, 1); state.selected.delete(f.id); post("/api/forget", { ids: [f.id] }); renderFiles(); renderOptions(); };
      $(".pt-up", row).onclick = () => { if (i > 0) { [state.files[i - 1], state.files[i]] = [state.files[i], state.files[i - 1]]; renderFiles(); renderOptions(); } };
      $(".pt-down", row).onclick = () => { if (i < state.files.length - 1) { [state.files[i + 1], state.files[i]] = [state.files[i], state.files[i + 1]]; renderFiles(); renderOptions(); } };
      $(".pt-view", row).onclick = () => window.open(`/api/file/${f.id}`, "_blank");
      const ul = $(".pt-unlock", row);
      if (ul) ul.onclick = async () => {
        const pw = prompt("Password for " + f.name); if (pw == null) return;
        try { Object.assign(f, await post("/api/unlock", { id: f.id, password: pw })); toast("🔓 Unlocked"); renderFiles(); renderOptions(); }
        catch (e) { toast("❌ " + e.message); }
      };
      row.ondragstart = e => e.dataTransfer.setData("text/pt-index", String(i));
      row.ondragover = e => { if (e.dataTransfer.types.includes("text/pt-index")) e.preventDefault(); };
      row.ondrop = e => { const from = e.dataTransfer.getData("text/pt-index"); if (from === "") return; e.preventDefault(); e.stopPropagation();
        const [m] = state.files.splice(+from, 1); state.files.splice(i, 0, m); renderFiles(); renderOptions(); };
      box.appendChild(row);
    });
  }
  const selectedFiles = () => state.files.filter(f => state.selected.has(f.id));
  const selectedPdfs = () => selectedFiles().filter(f => f.kind === "pdf");

  // ---------------------------------------------------------------- tool grid
  function renderTools() {
    const g = $("#ptToolGrid"); g.innerHTML = "";
    TOOLS.forEach(t => {
      const c = el("button", "pt-tool" + (state.tool === t.id ? " active" : ""),
        `<span class="material-symbols-rounded">${t.icon}</span><b>${t.name}</b><small>${t.desc}</small>`);
      c.dataset.tool = t.id;
      c.onclick = () => {
        state.tool = t.id;
        renderTools();
        renderOptions();
        const opt = $("#ptOptions");
        if (opt) opt.scrollIntoView({ behavior: "smooth", block: "start" });
      };
      g.appendChild(c);
    });
  }

  // ---------------------------------------------------------------- options per tool
  const field = (label, inner, hint) => `<div class="pt-field"><label>${label}</label>${inner}${hint ? `<small>${hint}</small>` : ""}</div>`;
  const pagesField = (id = "optPages", def = "all") => field("Pages", `<input id="${id}" class="form-input" value="${def}" placeholder="all, odd, even, 1-3,7,10-">`, "Examples: 1-3,7 • 5- (page 5 to end) • odd • even");

  function renderOptions() {
    const box = $("#ptOptions"); const t = TOOLS.find(x => x.id === state.tool); const pdfs = selectedPdfs();
    const work = $(".pt-work");
    if (work) {
      if (t.id === "organize") work.classList.add("pt-work-organize");
      else work.classList.remove("pt-work-organize");
    }

    if (t.id === "organize") {
      loadOrganizer();
      return;
    }

    let h = `<h3>${t.name}</h3><p class="pt-desc">${t.desc}</p>`;
    const needOne = pdfs.length < 1 ? `<div class="pt-warn">Select a PDF in the file list.</div>` : (pdfs.length > 1 && !["merge", "compare", "images_to_pdf"].includes(t.id) ? `<div class="pt-note">Using the first selected PDF: <b>${esc(pdfs[0].name)}</b></div>` : "");
    switch (t.id) {
      case "merge": h += field("Output name", `<input id="optName" class="form-input" value="merged.pdf">`, `Merges the ${pdfs.length} selected PDF(s) in list order.`) + (pdfs.length < 2 ? `<div class="pt-warn">Select at least 2 PDFs.</div>` : ""); break;
      case "split": h += needOne + field("Split mode", `<select id="optMode" class="form-select"><option value="every">Every N pages</option><option value="ranges">Custom ranges</option><option value="single">Every single page</option></select>`) +
        field("Value", `<input id="optValue" class="form-input" value="1" placeholder="N, or 1-3;4-6;7-">`, "N for 'every N pages'; ranges separated by semicolons."); break;
      case "extract": case "delete": h += needOne + pagesField("optPages", t.id === "delete" ? "1" : "1-3"); break;
      case "rotate": h += needOne + pagesField() + field("Rotation", `<select id="optDeg" class="form-select"><option value="90">90° clockwise</option><option value="180">180°</option><option value="270">90° counter-clockwise</option></select>`); break;
      case "crop": h += needOne + pagesField() + `<div class="pt-row">` + ["top", "right", "bottom", "left"].map(s => field(s[0].toUpperCase() + s.slice(1) + " (pt)", `<input id="crop_${s}" class="form-input" type="number" value="0" min="0">`)).join("") + `</div><small>72 points = 1 inch.</small>`; break;
      case "compress": h += needOne + field("Level", `<select id="optLevel" class="form-select"><option value="low">Low — best quality</option><option value="medium" selected>Medium — balanced</option><option value="high">High — smallest file</option></select>`, "Only images and structure are touched; text stays sharp and selectable."); break;
      case "watermark": h += needOne + field("Text", `<input id="optText" class="form-input" value="CONFIDENTIAL">`, "Latin letters only (Sinhala watermark needs the Flutter app).") + pagesField() +
        `<div class="pt-row">` + field("Opacity", `<input id="optOpacity" type="range" min="5" max="100" value="25">`) + field("Size", `<input id="optSize" class="form-input" type="number" value="64">`) + field("Angle", `<input id="optAngle" class="form-input" type="number" value="45">`) + field("Colour", `<input id="optColor" type="color" value="#888888">`) + `</div>`; break;
      case "pagenumbers": h += needOne + field("Format", `<input id="optFmt" class="form-input" value="Page {n} of {total}">`, "{n} = page number, {total} = page count") +
        field("Position", `<select id="optPos" class="form-select">${["bottom-center", "bottom-right", "bottom-left", "top-center", "top-right", "top-left"].map(p => `<option>${p}</option>`).join("")}</select>`) +
        `<div class="pt-row">` + field("Start at", `<input id="optStart" class="form-input" type="number" value="1">`) + field("Font size", `<input id="optPSize" class="form-input" type="number" value="10">`) + `</div>` + pagesField(); break;
      case "protect": h += needOne + field("Open password", `<input id="optUser" class="form-input" type="password" autocomplete="new-password">`) + field("Owner password (optional)", `<input id="optOwner" class="form-input" type="password" autocomplete="new-password">`) +
        `<label class="pt-check"><input type="checkbox" id="optAllowPrint" checked> Allow printing</label><label class="pt-check"><input type="checkbox" id="optAllowCopy" checked> Allow copying text</label><label class="pt-check"><input type="checkbox" id="optAllowEdit"> Allow editing</label>`; break;
      case "unprotect": h += needOne + field("Password", `<input id="optPw" class="form-input" type="password">`, "Leave blank if you already unlocked the file in the list."); break;
      case "metadata": { const f = pdfs[0]; const m = (f && f.meta) || {};
        h += needOne + ["Title", "Author", "Subject", "Keywords"].map(k => field(k, `<input id="meta_${k}" class="form-input" value="${esc(m[k] || "")}">`)).join("") + `<label class="pt-check"><input type="checkbox" id="optStrip"> Remove ALL metadata instead</label>`; break; }
      case "redact": h += needOne + field("Auto-find words (one per line)", `<textarea id="optTerms" class="form-input" rows="3" placeholder="e.g. 123-45-6789"></textarea>`, "Matches on every page are blacked out.") +
        `<p class="pt-note">Or draw boxes on a page:</p><div class="pt-row"><select id="redPage" class="form-select"></select><button class="btn btn-outline btn-sm" id="redClear">Clear boxes</button></div><div id="redStage" class="pt-redstage"></div><div class="pt-warn">Redacted pages are converted to images so the hidden text is gone for good. Keep your original.</div>`; break;
      case "flatten": h += needOne + field("Quality (DPI)", `<select id="optDpi" class="form-select"><option>100</option><option selected>150</option><option>200</option><option>300</option></select>`); break;
      case "pdf_to_images": h += needOne + pagesField() + field("Format", `<select id="optFmt" class="form-select"><option value="png">PNG</option><option value="jpg">JPG</option></select>`) + field("DPI", `<select id="optDpi" class="form-select"><option>72</option><option selected>150</option><option>200</option><option>300</option></select>`); break;
      case "images_to_pdf": { const im = selectedFiles().filter(f => f.kind !== "pdf"); h += `<p class="pt-note">${im.length} image(s) selected, in list order.</p>` + field("Output name", `<input id="optName" class="form-input" value="images.pdf">`) + (im.length ? "" : `<div class="pt-warn">Add and tick image files (JPG/PNG).</div>`); break; }
      case "text": {
        const langOpts = ["auto", ...(state.ocrLangs || [])].map(l => `<option value="${l}">${l}</option>`).join("");
        h += needOne +
          `<div class="pt-row">` +
            field("Extraction Mode", `<select id="optTextMode" class="form-select"><option value="auto" selected>Auto (Native PDF text, OCR if scanned)</option><option value="text">Text only (Fast, skips scanned images)</option><option value="ocr">Force OCR (Tesseract scan for all pages)</option></select>`) +
            field("Layout", `<select id="optTextLayout" class="form-select"><option value="smart" selected>Smart (Multi-column reading order & tables)</option><option value="raw">Raw (Physical top-to-bottom stream)</option></select>`) +
            field("Format", `<select id="optTextFmt" class="form-select"><option value="txt" selected>Plain Text (.txt)</option><option value="md">Markdown (.md)</option><option value="json">JSON (.json)</option></select>`) +
          `</div>` +
          `<div class="pt-row">` +
            pagesField("optPages", "all") +
            field("OCR Language", `<select id="optTextLang" class="form-select">${langOpts}</select>`, "Used when pages need OCR") +
          `</div>` +
          `<div class="pt-row" style="margin-top:4px">` +
            `<label class="pt-check"><input type="checkbox" id="optTextClean" checked> Remove headers, footers & page numbers</label>` +
            `<label class="pt-check"><input type="checkbox" id="optTextDehyphen" checked> Fix line-end hyphenation</label>` +
            `<label class="pt-check"><input type="checkbox" id="optTextMarkers" checked> Add page markers (--- Page N ---)</label>` +
          `</div>`;
        break;
      }
      case "ocr": { const opts = (state.ocrLangs.length ? state.ocrLangs : ["eng"]).map(l => `<option>${l}</option>`).join("");
        h += needOne + field("Language", `<select id="optLang" class="form-select">${opts}</select>`, state.ocrLangs.includes("sin") ? "Use eng+sin for mixed Sinhala/English." : "Sinhala: brew install tesseract-lang (Mac) then restart the engine.") + pagesField() +
          `<label class="pt-check"><input type="checkbox" id="optSearchable" checked> Also create a searchable PDF</label>`; break; }
      case "compare": h += (pdfs.length === 2 ? `<p class="pt-note">Comparing <b>${esc(pdfs[0].name)}</b> ↔ <b>${esc(pdfs[1].name)}</b></p>` : `<div class="pt-warn">Select exactly 2 PDFs.</div>`); break;
    }
    h += `<div class="pt-run"><button class="btn btn-primary" id="ptRun" ${state.engine ? "" : "disabled"}><span class="material-symbols-rounded">play_arrow</span><span>Run</span></button><span id="ptBusy" class="pt-busy hidden">Working…</span></div>`;
    box.innerHTML = h;
    $("#ptRun").onclick = run;
    if (t.id === "redact") initRedact();
  }

  // ---------------------------------------------------------------- organizer (Task 3)
  function bucketThumbWidth(w) {
    if (w <= 160) return 160;
    if (w <= 240) return 240;
    if (w <= 360) return 360;
    return 540;
  }

  function pushOrgState() {
    if (state.orgHistory.length > 50) state.orgHistory.shift();
    state.orgHistory.push(JSON.parse(JSON.stringify(state.org)));
    state.orgRedo = [];
    updateOrgHistoryButtons();
  }

  function undoOrg() {
    if (!state.orgHistory.length) return;
    state.orgRedo.push(JSON.parse(JSON.stringify(state.org)));
    state.org = state.orgHistory.pop();
    drawOrganizer(false);
  }

  function redoOrg() {
    if (!state.orgRedo.length) return;
    state.orgHistory.push(JSON.parse(JSON.stringify(state.org)));
    state.org = state.orgRedo.pop();
    drawOrganizer(false);
  }

  function resetOrg() {
    if (!state.orgInitial) return;
    pushOrgState();
    state.org = JSON.parse(JSON.stringify(state.orgInitial));
    drawOrganizer(false);
  }

  function updateOrgHistoryButtons() {
    const u = $("#ptOrgUndo"); if (u) u.disabled = (state.orgHistory.length === 0);
    const r = $("#ptOrgRedo"); if (r) r.disabled = (state.orgRedo.length === 0);
  }

  function loadOrganizer() {
    const pdfs = selectedPdfs();
    const items = [];
    pdfs.forEach(f => {
      const pageSizes = f.page_sizes || [];
      for (let p = 1; p <= f.pages; p++) {
        const ps = pageSizes[p - 1] || [595.28, 841.89];
        items.push({
          id: genId(),
          file: f.id,
          name: f.name,
          page: p,
          rotate: 0,
          width: ps[0] || 595.28,
          height: ps[1] || 841.89,
          blank: false,
          sel: false
        });
      }
    });
    state.org = items;
    state.orgInitial = JSON.parse(JSON.stringify(items));
    state.orgHistory = [];
    state.orgRedo = [];
    drawOrganizer(true);
  }

  let thumbObserver = null;
  function getThumbObserver() {
    if (thumbObserver) {
      thumbObserver.disconnect();
    }
    thumbObserver = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const wrap = entry.target;
          obs.unobserve(wrap);
          loadThumbImage(wrap);
        }
      });
    }, { root: $("#ptOrgGrid"), rootMargin: "150px" });
    return thumbObserver;
  }

  function loadThumbImage(wrap) {
    const img = wrap.querySelector(".pt-thumb-img");
    const shimmer = wrap.querySelector(".pt-thumb-placeholder");
    const retry = wrap.querySelector(".pt-thumb-retry");
    if (!img || !img.dataset.src) return;
    img.src = img.dataset.src;
    img.onload = () => {
      if (shimmer) shimmer.classList.add("hidden");
      img.classList.remove("hidden");
    };
    img.onerror = () => {
      if (shimmer) shimmer.classList.add("hidden");
      if (retry) {
        retry.classList.remove("hidden");
        retry.onclick = e => {
          e.stopPropagation();
          retry.classList.add("hidden");
          if (shimmer) shimmer.classList.remove("hidden");
          img.src = img.dataset.src + "&_t=" + Date.now();
        };
      }
    };
  }

  function updateOrgSelectionUI() {
    const g = $("#ptOrgGrid");
    if (!g) return;
    const cards = g.querySelectorAll(".pt-org-card");
    cards.forEach((c, idx) => {
      const it = state.org[idx];
      if (it) c.classList.toggle("sel", !!it.sel);
    });
    const cnt = $("#ptOrgCounter");
    if (cnt) {
      const total = state.org.length;
      const sel = state.org.filter(x => x.sel).length;
      cnt.textContent = `${total} pages • ${sel} selected`;
    }
    const btnBuild = $("#ptOrgBuild");
    if (btnBuild) {
      btnBuild.innerHTML = `<span class="material-symbols-rounded">picture_as_pdf</span> <span>Build PDF (${state.org.length} pages)</span>`;
    }
  }

  function drawOrganizer(fullRebuild = false) {
    const box = $("#ptOptions");
    const uniqueFiles = Array.from(new Set(state.org.filter(x => !x.blank).map(x => x.file)));
    const hasMultipleFiles = uniqueFiles.length > 1;

    let wrap = box.querySelector(".pt-org-wrap");
    if (!wrap || fullRebuild) {
      box.innerHTML = `
        <div class="pt-org-wrap">
          <div class="pt-org-toolbar">
            <div class="pt-org-row">
              <div class="pt-org-group">
                <button class="btn btn-tonal btn-sm" id="ptOrgRotL" title="Rotate selected left 90° (Shift+R)"><span class="material-symbols-rounded">rotate_left</span> <span>Rotate Left</span></button>
                <button class="btn btn-tonal btn-sm" id="ptOrgRotR" title="Rotate selected right 90° (R)"><span class="material-symbols-rounded">rotate_right</span> <span>Rotate Right</span></button>
                <button class="btn btn-tonal btn-sm" id="ptOrgDup" title="Duplicate selected pages"><span class="material-symbols-rounded">content_copy</span> <span>Duplicate</span></button>
                <button class="btn btn-tonal btn-sm" id="ptOrgDel" title="Delete selected pages (Del/Backspace)"><span class="material-symbols-rounded">delete</span> <span>Delete</span></button>
                <button class="btn btn-tonal btn-sm" id="ptOrgBlank" title="Insert blank page"><span class="material-symbols-rounded">note_add</span> <span>+ Blank Page</span></button>
                <button class="btn btn-tonal btn-sm" id="ptOrgToStart" title="Move selected to start"><span class="material-symbols-rounded">first_page</span> <span>To Start</span></button>
                <button class="btn btn-tonal btn-sm" id="ptOrgToEnd" title="Move selected to end"><span class="material-symbols-rounded">last_page</span> <span>To End</span></button>
              </div>
              <div class="pt-org-group">
                <button class="btn btn-ghost btn-sm" id="ptOrgUndo" title="Undo (Ctrl/Cmd+Z)"><span class="material-symbols-rounded">undo</span> <span>Undo</span></button>
                <button class="btn btn-ghost btn-sm" id="ptOrgRedo" title="Redo (Ctrl/Cmd+Shift+Z)"><span class="material-symbols-rounded">redo</span> <span>Redo</span></button>
                <button class="btn btn-ghost btn-sm" id="ptOrgReset" title="Reset all changes"><span class="material-symbols-rounded">restart_alt</span> <span>Reset</span></button>
              </div>
            </div>
            <div class="pt-org-row">
              <div class="pt-org-group">
                <span style="font-size:12px;color:var(--text-muted)">Select:</span>
                <button class="btn btn-outline btn-sm" id="ptOrgSelAll">All</button>
                <button class="btn btn-outline btn-sm" id="ptOrgSelNone">None</button>
                <button class="btn btn-outline btn-sm" id="ptOrgSelOdd">Odd</button>
                <button class="btn btn-outline btn-sm" id="ptOrgSelEven">Even</button>
                <button class="btn btn-outline btn-sm" id="ptOrgSelInv">Invert</button>
              </div>
              <div class="pt-org-group">
                <div class="pt-org-zoom">
                  <span class="material-symbols-rounded">zoom_in</span>
                  <input type="range" id="ptOrgZoom" min="120" max="360" value="${state.orgThumbWidth}" step="10">
                  <span id="ptOrgZoomLabel">${state.orgThumbWidth}px</span>
                </div>
                <div class="pt-org-counter" id="ptOrgCounter">0 pages • 0 selected</div>
              </div>
            </div>
          </div>
          <div id="ptOrgGrid" class="pt-orggrid" style="--org-card-w: ${state.orgThumbWidth}px"></div>
          <div class="pt-sticky-bar">
            <div style="font-size:12.5px;color:var(--text-muted)">
              Click to select • Shift-click range • Drag to reorder • R to rotate • Del to delete
            </div>
            <div class="pt-org-group">
              <button class="btn btn-primary" id="ptOrgBuild"><span class="material-symbols-rounded">picture_as_pdf</span> <span>Build PDF (${state.org.length} pages)</span></button>
              <span id="ptBusy" class="pt-busy hidden">Working…</span>
            </div>
          </div>
        </div>`;
      wrap = box.querySelector(".pt-org-wrap");
      bindOrgToolbar();
    }

    const g = $("#ptOrgGrid");
    g.innerHTML = "";
    if (!state.org.length) {
      g.innerHTML = `<div class="pt-empty">No pages to display. Select PDFs in the left panel to load their pages.</div>`;
      updateOrgSelectionUI();
      updateOrgHistoryButtons();
      return;
    }

    const obs = getThumbObserver();
    const dpr = window.devicePixelRatio || 1;
    const bucket = bucketThumbWidth(Math.round(state.orgThumbWidth * dpr));

    state.org.forEach((it, i) => {
      const card = el("div", "pt-org-card" + (it.sel ? " sel" : ""));
      card.dataset.id = it.id;
      card.dataset.idx = i;
      card.draggable = true;
      card.tabIndex = 0;

      const rot = (it.rotate || 0) % 360;
      const isSwapped = (rot === 90 || rot === 270);
      const w = it.width || 595.28;
      const h = it.height || 841.89;
      const effW = isSwapped ? h : w;
      const effH = isSwapped ? w : h;
      const fileColor = hasMultipleFiles ? FILE_COLORS[uniqueFiles.indexOf(it.file) % FILE_COLORS.length] : "";

      let thumbMarkup = "";
      if (it.blank) {
        thumbMarkup = `<div class="pt-org-blank"><span class="material-symbols-rounded">note_add</span><span>Blank Page</span></div>`;
      } else {
        const thumbUrl = `/api/thumb/${it.file}/${it.page}?w=${bucket}`;
        let imgStyle = "";
        if (!isSwapped) {
          imgStyle = `transform:rotate(${rot}deg);width:100%;height:100%;object-fit:contain;`;
        } else {
          imgStyle = `position:absolute;left:50%;top:50%;width:calc(100% * ${(w / h).toFixed(4)});height:calc(100% * ${(h / w).toFixed(4)});transform:translate(-50%,-50%) rotate(${rot}deg);object-fit:contain;`;
        }
        thumbMarkup = `
          <div class="pt-thumb-placeholder"><div class="pt-shimmer"></div></div>
          <img class="pt-thumb-img hidden" data-src="${thumbUrl}" style="${imgStyle}" alt="Page ${it.page}">
          <button class="pt-thumb-retry hidden" title="Retry"><span class="material-symbols-rounded">refresh</span><span>Retry</span></button>
        `;
      }

      card.innerHTML = `
        <div class="pt-org-card-header">
          <span class="pt-org-badge pt-org-page-num">${i + 1}</span>
          ${hasMultipleFiles && !it.blank ? `<span class="pt-org-file-tag" style="background:${fileColor}" title="${esc(it.name)}">${esc(it.name)}</span>` : ""}
          <div class="pt-org-check"><span class="material-symbols-rounded">check</span></div>
        </div>
        <div class="pt-org-thumbwrap" style="aspect-ratio:${effW}/${effH}">
          ${thumbMarkup}
        </div>
        <div class="pt-org-card-footer">
          ${it.blank ? "Blank" : `p.${it.page}`}${it.rotate ? ` • ↻${it.rotate}°` : ""}
        </div>
        <div class="pt-org-card-actions">
          <button type="button" class="pt-action-btn pt-act-rot-l" title="Rotate Left 90°"><span class="material-symbols-rounded">rotate_left</span></button>
          <button type="button" class="pt-action-btn pt-act-rot-r" title="Rotate Right 90°"><span class="material-symbols-rounded">rotate_right</span></button>
          <button type="button" class="pt-action-btn pt-act-dup" title="Duplicate"><span class="material-symbols-rounded">content_copy</span></button>
          <button type="button" class="pt-action-btn pt-act-del" title="Delete"><span class="material-symbols-rounded">delete</span></button>
        </div>
      `;

      // Click selection
      card.onclick = e => {
        if (e.target.closest(".pt-org-card-actions") || e.target.closest(".pt-thumb-retry")) return;
        if (e.metaKey || e.ctrlKey) {
          it.sel = !it.sel;
          state.orgLastFocus = i;
        } else if (e.shiftKey) {
          const from = state.orgLastFocus ?? 0;
          const min = Math.min(from, i), max = Math.max(from, i);
          state.org.forEach((x, idx) => { if (idx >= min && idx <= max) x.sel = true; });
        } else {
          state.org.forEach((x, idx) => { x.sel = (idx === i); });
          state.orgLastFocus = i;
        }
        updateOrgSelectionUI();
      };

      // Card hover action buttons
      $(".pt-act-rot-l", card).onclick = e => { e.stopPropagation(); pushOrgState(); it.rotate = (it.rotate + 270) % 360; drawOrganizer(); };
      $(".pt-act-rot-r", card).onclick = e => { e.stopPropagation(); pushOrgState(); it.rotate = (it.rotate + 90) % 360; drawOrganizer(); };
      $(".pt-act-dup", card).onclick = e => {
        e.stopPropagation();
        pushOrgState();
        const clone = { ...it, id: genId(), sel: false };
        state.org.splice(i + 1, 0, clone);
        drawOrganizer();
      };
      $(".pt-act-del", card).onclick = e => { e.stopPropagation(); pushOrgState(); state.org.splice(i, 1); drawOrganizer(); };

      // Drag and drop
      card.ondragstart = e => {
        e.stopPropagation();
        if (!it.sel) {
          state.org.forEach((x, idx) => { x.sel = (idx === i); });
          state.orgLastFocus = i;
          updateOrgSelectionUI();
        }
        const selIndices = state.org.map((x, idx) => x.sel ? idx : -1).filter(idx => idx !== -1);
        e.dataTransfer.setData("text/pt-org-drag", JSON.stringify(selIndices));
        e.dataTransfer.effectAllowed = "move";

        const ghost = el("div", "pt-drag-ghost");
        ghost.innerHTML = `<span class="material-symbols-rounded">filter_none</span> <span>${selIndices.length} page${selIndices.length > 1 ? "s" : ""}</span>`;
        document.body.appendChild(ghost);
        e.dataTransfer.setDragImage(ghost, 20, 20);
        setTimeout(() => ghost.remove(), 0);
      };

      card.ondragover = e => {
        if (!e.dataTransfer.types.includes("text/pt-org-drag")) return;
        e.preventDefault();
        e.stopPropagation();

        const scrollParent = $("#subviewPower") || g;
        const rect = scrollParent.getBoundingClientRect();
        if (e.clientY < rect.top + 60) scrollParent.scrollTop -= 14;
        else if (e.clientY > rect.bottom - 60) scrollParent.scrollTop += 14;

        if (it.sel) {
          card.classList.remove("drop-target-before", "drop-target-after");
          return;
        }

        const firstSel = state.org.findIndex(x => x.sel);
        if (i <= firstSel) {
          card.classList.add("drop-target-before");
          card.classList.remove("drop-target-after");
        } else {
          card.classList.add("drop-target-after");
          card.classList.remove("drop-target-before");
        }
      };

      card.ondragleave = e => {
        if (e.relatedTarget && card.contains(e.relatedTarget)) return;
        card.classList.remove("drop-target-before", "drop-target-after");
      };

      card.ondrop = e => {
        if (!e.dataTransfer.types.includes("text/pt-org-drag")) return;
        e.preventDefault();
        e.stopPropagation();
        card.classList.remove("drop-target-before", "drop-target-after");
        reorderOrganizerToCard(i);
      };

      card.ondragend = () => {
        g.querySelectorAll(".pt-org-card").forEach(c => {
          c.classList.remove("drop-target-before", "drop-target-after");
        });
      };

      g.appendChild(card);
      const wrapEl = card.querySelector(".pt-org-thumbwrap");
      if (wrapEl && !it.blank) obs.observe(wrapEl);
    });

    updateOrgSelectionUI();
    updateOrgHistoryButtons();
  }

  function reorderOrganizerToCard(targetIdx) {
    const selected = state.org.filter(x => x.sel);
    if (!selected.length) return;
    const targetItem = state.org[targetIdx];
    if (!targetItem || targetItem.sel) return;

    pushOrgState();
    const g = $("#ptOrgGrid");
    const firstPositions = new Map();
    if (g) {
      g.querySelectorAll(".pt-org-card").forEach(c => {
        firstPositions.set(c.dataset.id, c.getBoundingClientRect());
      });
    }

    const targetId = targetItem.id;
    const firstSel = state.org.findIndex(x => x.sel);

    // Remove selected items
    const remaining = state.org.filter(x => !x.sel);
    const newTargetIdx = remaining.findIndex(x => x.id === targetId);

    if (newTargetIdx !== -1) {
      if (targetIdx <= firstSel) {
        // Dragging backwards (e.g. Page 3 onto Page 1) -> Insert BEFORE target Page 1
        remaining.splice(newTargetIdx, 0, ...selected);
      } else {
        // Dragging forwards (e.g. Page 1 onto Page 3) -> Insert AFTER target Page 3
        remaining.splice(newTargetIdx + 1, 0, ...selected);
      }
      state.org = remaining;
      drawOrganizer();

      if (g) {
        requestAnimationFrame(() => {
          g.querySelectorAll(".pt-org-card").forEach(c => {
            const first = firstPositions.get(c.dataset.id);
            if (!first) return;
            const last = c.getBoundingClientRect();
            const dx = first.left - last.left;
            const dy = first.top - last.top;
            if (dx !== 0 || dy !== 0) {
              c.style.transform = `translate(${dx}px, ${dy}px)`;
              c.style.transition = "none";
              requestAnimationFrame(() => {
                c.style.transition = "transform 250ms cubic-bezier(0.2, 0, 0, 1)";
                c.style.transform = "";
              });
            }
          });
        });
      }
    }
  }

  function bindOrgToolbar() {
    const rotL = $("#ptOrgRotL"), rotR = $("#ptOrgRotR"), dup = $("#ptOrgDup"), del = $("#ptOrgDel");
    const blank = $("#ptOrgBlank"), start = $("#ptOrgToStart"), end = $("#ptOrgToEnd");
    const undo = $("#ptOrgUndo"), redo = $("#ptOrgRedo"), reset = $("#ptOrgReset");
    const selAll = $("#ptOrgSelAll"), selNone = $("#ptOrgSelNone"), selOdd = $("#ptOrgSelOdd"), selEven = $("#ptOrgSelEven"), selInv = $("#ptOrgSelInv");
    const zoom = $("#ptOrgZoom"), zoomLabel = $("#ptOrgZoomLabel"), build = $("#ptOrgBuild");

    if (rotL) rotL.onclick = () => {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      pushOrgState();
      sel.forEach(x => x.rotate = (x.rotate + 270) % 360);
      drawOrganizer();
    };
    if (rotR) rotR.onclick = () => {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      pushOrgState();
      sel.forEach(x => x.rotate = (x.rotate + 90) % 360);
      drawOrganizer();
    };
    if (dup) dup.onclick = () => {
      let sel = state.org.filter(x => x.sel);
      if (!sel.length && state.org.length) sel = [state.org[state.org.length - 1]];
      if (!sel.length) return;
      pushOrgState();
      const newItems = [];
      state.org.forEach(x => {
        newItems.push(x);
        if (x.sel) newItems.push({ ...x, id: genId(), sel: false });
      });
      state.org = newItems;
      drawOrganizer();
    };
    if (del) del.onclick = () => {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      pushOrgState();
      state.org = state.org.filter(x => !x.sel);
      drawOrganizer();
    };
    if (blank) blank.onclick = () => {
      pushOrgState();
      const blankItem = {
        id: genId(),
        file: null,
        name: "Blank Page",
        page: 1,
        rotate: 0,
        width: 595.28,
        height: 841.89,
        blank: true,
        sel: false
      };
      const lastSel = state.org.reduce((acc, x, idx) => x.sel ? idx : acc, -1);
      if (lastSel >= 0) {
        state.org.splice(lastSel + 1, 0, blankItem);
      } else {
        state.org.push(blankItem);
      }
      drawOrganizer();
    };
    if (start) start.onclick = () => {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      pushOrgState();
      const rest = state.org.filter(x => !x.sel);
      state.org = [...sel, ...rest];
      drawOrganizer();
    };
    if (end) end.onclick = () => {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      pushOrgState();
      const rest = state.org.filter(x => !x.sel);
      state.org = [...rest, ...sel];
      drawOrganizer();
    };
    if (undo) undo.onclick = undoOrg;
    if (redo) redo.onclick = redoOrg;
    if (reset) reset.onclick = resetOrg;

    if (selAll) selAll.onclick = () => { state.org.forEach(x => x.sel = true); updateOrgSelectionUI(); };
    if (selNone) selNone.onclick = () => { state.org.forEach(x => x.sel = false); updateOrgSelectionUI(); };
    if (selOdd) selOdd.onclick = () => { state.org.forEach((x, i) => x.sel = (i % 2 === 0)); updateOrgSelectionUI(); };
    if (selEven) selEven.onclick = () => { state.org.forEach((x, i) => x.sel = (i % 2 === 1)); updateOrgSelectionUI(); };
    if (selInv) selInv.onclick = () => { state.org.forEach(x => x.sel = !x.sel); updateOrgSelectionUI(); };

    if (zoom) zoom.oninput = () => {
      state.orgThumbWidth = +zoom.value;
      if (zoomLabel) zoomLabel.textContent = state.orgThumbWidth + "px";
      const g = $("#ptOrgGrid");
      if (g) g.style.setProperty("--org-card-w", state.orgThumbWidth + "px");
    };

    if (build) build.onclick = run;

    // Grid Drag & Drop and Marquee
    const g = $("#ptOrgGrid");
    if (!g) return;

    g.ondragover = e => {
      if (!e.dataTransfer.types.includes("text/pt-org-drag")) return;
      e.preventDefault();
      // Auto-scroll
      const scrollParent = $("#subviewPower") || g;
      const rect = scrollParent.getBoundingClientRect();
      if (e.clientY < rect.top + 60) scrollParent.scrollTop -= 14;
      else if (e.clientY > rect.bottom - 60) scrollParent.scrollTop += 14;
    };

    g.ondragleave = e => {
      if (e.relatedTarget && g.contains(e.relatedTarget)) return;
      g.querySelectorAll(".pt-org-card").forEach(c => {
        c.classList.remove("drop-target-before", "drop-target-after");
      });
    };

    g.ondrop = e => {
      if (!e.dataTransfer.types.includes("text/pt-org-drag")) return;
      // Triggered only when dropped on empty space of grid (outside cards)
      e.preventDefault();
      g.querySelectorAll(".pt-org-card").forEach(c => {
        c.classList.remove("drop-target-before", "drop-target-after");
      });

      const selected = state.org.filter(x => x.sel);
      if (!selected.length) return;

      pushOrgState();
      const firstPositions = new Map();
      g.querySelectorAll(".pt-org-card").forEach(c => {
        firstPositions.set(c.dataset.id, c.getBoundingClientRect());
      });

      // Append selected items to the end
      const remaining = state.org.filter(x => !x.sel);
      remaining.push(...selected);
      state.org = remaining;

      drawOrganizer();

      // Execute FLIP
      requestAnimationFrame(() => {
        g.querySelectorAll(".pt-org-card").forEach(c => {
          const first = firstPositions.get(c.dataset.id);
          if (!first) return;
          const last = c.getBoundingClientRect();
          const dx = first.left - last.left;
          const dy = first.top - last.top;
          if (dx !== 0 || dy !== 0) {
            c.style.transform = `translate(${dx}px, ${dy}px)`;
            c.style.transition = "none";
            requestAnimationFrame(() => {
              c.style.transition = "transform 240ms cubic-bezier(0.2, 0, 0, 1)";
              c.style.transform = "";
            });
          }
        });
      });
    };

    // Marquee selection on empty grid space
    g.onmousedown = e => {
      if (e.target.closest(".pt-org-card") || e.target.closest(".pt-org-toolbar") || e.target.closest(".pt-sticky-bar")) return;
      const gRect = g.getBoundingClientRect();
      const startX = e.clientX, startY = e.clientY;
      const marquee = el("div", "pt-marquee");
      g.appendChild(marquee);

      const onMouseMove = ev => {
        const x1 = Math.min(startX, ev.clientX), y1 = Math.min(startY, ev.clientY);
        const x2 = Math.max(startX, ev.clientX), y2 = Math.max(startY, ev.clientY);
        marquee.style.left = (x1 - gRect.left + g.scrollLeft) + "px";
        marquee.style.top = (y1 - gRect.top + g.scrollTop) + "px";
        marquee.style.width = (x2 - x1) + "px";
        marquee.style.height = (y2 - y1) + "px";

        const mRect = { left: x1, top: y1, right: x2, bottom: y2 };
        const cards = g.querySelectorAll(".pt-org-card");
        cards.forEach((c, idx) => {
          const it = state.org[idx];
          if (!it) return;
          const cRect = c.getBoundingClientRect();
          const hits = !(mRect.right < cRect.left || mRect.left > cRect.right || mRect.bottom < cRect.top || mRect.top > cRect.bottom);
          if (ev.metaKey || ev.ctrlKey) {
            if (hits) it.sel = true;
          } else {
            it.sel = hits;
          }
        });
        updateOrgSelectionUI();
      };

      const onMouseUp = () => {
        marquee.remove();
        window.removeEventListener("mousemove", onMouseMove);
        window.removeEventListener("mouseup", onMouseUp);
      };

      window.addEventListener("mousemove", onMouseMove);
      window.addEventListener("mouseup", onMouseUp);
    };
  }

  // Global Keyboard Shortcuts for Organizer
  window.addEventListener("keydown", e => {
    if (state.tool !== "organize") return;
    const active = document.activeElement;
    if (active && (active.tagName === "INPUT" || active.tagName === "TEXTAREA" || active.tagName === "SELECT")) return;

    // Delete / Backspace
    if (e.key === "Delete" || e.key === "Backspace") {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      e.preventDefault();
      pushOrgState();
      state.org = state.org.filter(x => !x.sel);
      drawOrganizer();
      return;
    }

    // Rotate: R (clockwise), Shift+R (counter-clockwise)
    if (e.key === "r" || e.key === "R") {
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      e.preventDefault();
      pushOrgState();
      const deg = e.shiftKey ? 270 : 90;
      sel.forEach(x => x.rotate = (x.rotate + deg) % 360);
      drawOrganizer();
      return;
    }

    // Undo / Redo
    if ((e.metaKey || e.ctrlKey) && (e.key === "z" || e.key === "Z")) {
      e.preventDefault();
      if (e.shiftKey) redoOrg();
      else undoOrg();
      return;
    }
    if ((e.metaKey || e.ctrlKey) && (e.key === "y" || e.key === "Y")) {
      e.preventDefault();
      redoOrg();
      return;
    }

    // Select all / clear
    if ((e.metaKey || e.ctrlKey) && (e.key === "a" || e.key === "A")) {
      e.preventDefault();
      state.org.forEach(x => x.sel = true);
      updateOrgSelectionUI();
      return;
    }
    if (e.key === "Escape") {
      state.org.forEach(x => x.sel = false);
      updateOrgSelectionUI();
      return;
    }

    // Alt + Left/Right arrow to shift selected items
    if (e.altKey && (e.key === "ArrowLeft" || e.key === "ArrowRight")) {
      e.preventDefault();
      const sel = state.org.filter(x => x.sel);
      if (!sel.length) return;
      pushOrgState();
      if (e.key === "ArrowLeft") {
        for (let i = 1; i < state.org.length; i++) {
          if (state.org[i].sel && !state.org[i - 1].sel) {
            [state.org[i - 1], state.org[i]] = [state.org[i], state.org[i - 1]];
          }
        }
      } else {
        for (let i = state.org.length - 2; i >= 0; i--) {
          if (state.org[i].sel && !state.org[i + 1].sel) {
            [state.org[i], state.org[i + 1]] = [state.org[i + 1], state.org[i]];
          }
        }
      }
      drawOrganizer();
      return;
    }

    // Normal Arrow keys to navigate focus
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      let cur = state.orgLastFocus ?? 0;
      if (e.key === "ArrowLeft") cur = Math.max(0, cur - 1);
      else cur = Math.min(state.org.length - 1, cur + 1);
      state.orgLastFocus = cur;
      if (!e.shiftKey) {
        state.org.forEach((x, idx) => { x.sel = (idx === cur); });
      } else {
        state.org[cur].sel = true;
      }
      updateOrgSelectionUI();
      const cards = document.querySelectorAll(".pt-org-card");
      if (cards[cur]) cards[cur].focus();
    }
  });

  // ---------------------------------------------------------------- redact stage
  function initRedact() {
    const f = selectedPdfs()[0]; const sel = $("#redPage"); const stage = $("#redStage");
    state.redact = { file: f ? f.id : null, page: 1, regions: [] };
    if (!f) { stage.innerHTML = ""; return; }
    sel.innerHTML = Array.from({ length: f.pages }, (_, i) => `<option value="${i + 1}">Page ${i + 1}</option>`).join("");
    sel.onchange = () => { state.redact.page = +sel.value; drawRedact(); };
    $("#redClear").onclick = () => { state.redact.regions = []; drawRedact(); };
    drawRedact();
  }
  function drawRedact() {
    const r = state.redact, stage = $("#redStage"); if (!r.file) return;
    stage.innerHTML = `<div class="pt-redwrap"><img id="redImg" src="/api/pagepng/${r.file}/${r.page}?zoom=1.2" draggable="false"></div><small>Drag on the page to add black boxes. ${r.regions.length} box(es) total.</small>`;
    const wrap = $(".pt-redwrap", stage), img = $("#redImg");
    const paint = () => { wrap.querySelectorAll(".pt-redbox").forEach(b => b.remove());
      r.regions.filter(b => b.page === r.page).forEach(b => { const d = el("div", "pt-redbox"); d.style.cssText = `left:${b.x * 100}%;top:${b.y * 100}%;width:${b.w * 100}%;height:${b.h * 100}%`;
        d.title = "Click to remove"; d.onclick = ev => { ev.stopPropagation(); r.regions.splice(r.regions.indexOf(b), 1); drawRedact(); }; wrap.appendChild(d); }); };
    let start = null, ghost = null;
    wrap.onmousedown = e => { if (e.target.classList.contains("pt-redbox")) return; const rc = img.getBoundingClientRect(); start = { x: (e.clientX - rc.left) / rc.width, y: (e.clientY - rc.top) / rc.height, rc };
      ghost = el("div", "pt-redbox ghost"); wrap.appendChild(ghost); e.preventDefault(); };
    window.onmousemove = e => { if (!start) return; const cx = Math.min(1, Math.max(0, (e.clientX - start.rc.left) / start.rc.width)), cy = Math.min(1, Math.max(0, (e.clientY - start.rc.top) / start.rc.height));
      ghost.style.cssText = `left:${Math.min(start.x, cx) * 100}%;top:${Math.min(start.y, cy) * 100}%;width:${Math.abs(cx - start.x) * 100}%;height:${Math.abs(cy - start.y) * 100}%`; };
    window.onmouseup = e => { if (!start) return; const cx = Math.min(1, Math.max(0, (e.clientX - start.rc.left) / start.rc.width)), cy = Math.min(1, Math.max(0, (e.clientY - start.rc.top) / start.rc.height));
      const b = { page: r.page, x: Math.min(start.x, cx), y: Math.min(start.y, cy), w: Math.abs(cx - start.x), h: Math.abs(cy - start.y) };
      if (b.w > 0.005 && b.h > 0.005) r.regions.push(b); start = null; ghost.remove(); drawRedact(); };
    paint();
  }

  // ---------------------------------------------------------------- run
  const v = id => { const e = $("#" + id); return e ? e.value : ""; };
  const chk = id => { const e = $("#" + id); return !!(e && e.checked); };

  function buildRequest() {
    const t = state.tool, pdfs = selectedPdfs(), f0 = pdfs[0] && pdfs[0].id, ids = pdfs.map(f => f.id);
    if (t === "images_to_pdf") {
      const im = selectedFiles().filter(f => f.kind !== "pdf");
      if (!im.length) throw new Error("Select at least one image");
      return { op: t, files: im.map(f => f.id), options: { name: v("optName") } };
    }
    if (!pdfs.length && t !== "organize") throw new Error("Select a PDF first");

    switch (t) {
      case "merge":
        if (ids.length < 2) throw new Error("Select at least 2 PDFs");
        return { op: t, files: ids, options: { name: v("optName") } };
      case "organize": {
        if (!state.org.length) throw new Error("No pages to build — select PDFs first (or you deleted every page)");
        const items = state.org.map(x => (x.blank ? { blank: true, width: x.width || 595.28, height: x.height || 841.89, rotate: x.rotate || 0 } : { file: x.file, page: x.page, rotate: x.rotate || 0 }));
        return { op: "assemble", files: [], options: { name: "organized.pdf", items } };
      }
      case "split": return { op: t, files: [f0], options: { mode: v("optMode"), value: v("optValue") } };
      case "extract": case "delete": return { op: t, files: [f0], options: { pages: v("optPages") } };
      case "rotate": return { op: t, files: [f0], options: { pages: v("optPages"), degrees: +v("optDeg") } };
      case "crop": return { op: t, files: [f0], options: { pages: v("optPages"), top: +v("crop_top"), right: +v("crop_right"), bottom: +v("crop_bottom"), left: +v("crop_left") } };
      case "compress": return { op: t, files: [f0], options: { level: v("optLevel") } };
      case "watermark": return { op: t, files: [f0], options: { text: v("optText"), pages: v("optPages"), opacity: +v("optOpacity") / 100, size: +v("optSize"), angle: +v("optAngle"), color: v("optColor") } };
      case "pagenumbers": return { op: t, files: [f0], options: { format: v("optFmt"), position: v("optPos"), start: +v("optStart"), size: +v("optPSize"), pages: v("optPages") } };
      case "protect": return { op: t, files: [f0], options: { user: v("optUser"), owner: v("optOwner"), allow_print: chk("optAllowPrint"), allow_copy: chk("optAllowCopy"), allow_edit: chk("optAllowEdit") } };
      case "unprotect": return { op: t, files: [f0], options: { password: v("optPw") || undefined } };
      case "metadata": return { op: t, files: [f0], options: { strip: chk("optStrip"), meta: Object.fromEntries(["Title", "Author", "Subject", "Keywords"].map(k => [k, v("meta_" + k)])) } };
      case "redact": return { op: t, files: [f0], options: { regions: state.redact.regions, terms: v("optTerms").split("\n").map(s => s.trim()).filter(Boolean) } };
      case "flatten": return { op: t, files: [f0], options: { dpi: +v("optDpi") } };
      case "pdf_to_images": return { op: t, files: [f0], options: { pages: v("optPages"), format: v("optFmt"), dpi: +v("optDpi") } };
      case "text":
        return {
          op: "text",
          files: [f0],
          options: {
            pages: v("optPages") || "all",
            mode: v("optTextMode") || "auto",
            layout: v("optTextLayout") || "smart",
            fmt: v("optTextFmt") || "txt",
            clean: chk("optTextClean"),
            dehyphenate: chk("optTextDehyphen"),
            markers: chk("optTextMarkers"),
            lang: v("optTextLang") || "auto"
          }
        };
      case "ocr": return { op: t, files: [f0], options: { lang: v("optLang"), pages: v("optPages"), searchable: chk("optSearchable") } };
      case "compare": if (ids.length !== 2) throw new Error("Select exactly 2 PDFs"); return { op: t, files: ids, options: {} };
    }
  }

  async function run() {
    if (state.busy) return;
    let req; try { req = buildRequest(); } catch (e) { toast("⚠️ " + e.message); return; }
    state.busy = true;
    const btn = $("#ptRun") || $("#ptOrgBuild");
    if (btn) btn.disabled = true;
    const busyEl = $("#ptBusy");
    if (busyEl) busyEl.classList.remove("hidden");

    try {
      const res = await post("/api/op", req);
      showResult(res);
      toast("✅ " + (res.message || "Done"));
      const resBox = $("#ptResults");
      if (resBox) resBox.scrollIntoView({ behavior: "smooth", block: "start" });
    } catch (e) {
      showResult({ error: e.message });
      toast("❌ " + e.message);
    } finally {
      state.busy = false;
      if (btn) btn.disabled = false;
      if (busyEl) busyEl.classList.add("hidden");
    }
  }

  function showResult(res) {
    const box = $("#ptResults"); box.innerHTML = "";
    if (res.error) {
      box.innerHTML = `<div class="pt-result err"><span class="material-symbols-rounded">error</span> ${esc(res.error)}</div>`;
      return;
    }
    box.appendChild(el("div", "pt-result ok", `<span class="material-symbols-rounded">check_circle</span> ${esc(res.message || "Done")}`));

    // Summary chips for text extraction
    if (res.summary) {
      const s = res.summary;
      const chips = el("div", "pt-summary-chips");
      chips.innerHTML = `
        <span class="pt-chip"><span class="material-symbols-rounded">article</span> ${s.pages} Page${s.pages > 1 ? "s" : ""}</span>
        <span class="pt-chip"><span class="material-symbols-rounded">notes</span> ${s.words} Words</span>
        <span class="pt-chip"><span class="material-symbols-rounded">text_format</span> ${s.chars} Characters</span>
        ${s.ocr_pages > 0 ? `<span class="pt-chip ocr"><span class="material-symbols-rounded">document_scanner</span> ${s.ocr_pages} OCR Page${s.ocr_pages > 1 ? "s" : ""}</span>` : ""}
      `;
      box.appendChild(chips);
    }

    // Per-page quality and method report table
    if (res.report && res.report.length > 1) {
      const wrap = el("div", "pt-report-table-wrap");
      const rows = res.report.map(r => `
        <tr>
          <td><b>Page ${r.page}</b></td>
          <td><span class="pt-badge method-${r.method}">${r.method}</span></td>
          <td>${r.words} words</td>
          <td>${r.confidence != null ? r.confidence + "%" : "—"}</td>
          <td>${(r.issues || []).map(iss => `<span class="pt-badge warn">${esc(iss)}</span>`).join("") || '<span style="color:var(--text-muted)">Clean</span>'}</td>
        </tr>
      `).join("");
      wrap.innerHTML = `<table class="pt-report-table">
        <thead><tr><th>Page</th><th>Method</th><th>Words</th><th>Confidence</th><th>Status</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>`;
      box.appendChild(wrap);
    }

    // Output files
    (res.results || []).forEach(r => {
      const row = el("div", "pt-outfile", `<span class="material-symbols-rounded">${r.name.endsWith(".zip") ? "folder_zip" : (r.name.endsWith(".txt") || r.name.endsWith(".md") || r.name.endsWith(".json")) ? "description" : "picture_as_pdf"}</span><div class="pt-fmeta"><b>${esc(r.name)}</b><small>${r.pages ? r.pages + " pages • " : ""}${fmtSize(r.size)}</small></div>
        <a class="btn btn-primary btn-sm" href="/api/file/${r.id}?download=1" download="${esc(r.name)}">Download</a>
        ${r.name.endsWith(".pdf") ? `<button class="btn btn-outline btn-sm pt-open">Open</button><button class="btn btn-tonal btn-sm pt-use">Use as input</button>` : ""}`);
      const op = $(".pt-open", row); if (op) op.onclick = () => window.open(`/api/file/${r.id}`, "_blank");
      const us = $(".pt-use", row); if (us) us.onclick = () => { if (!state.files.find(f => f.id === r.id)) state.files.push(r); state.selected = new Set([r.id]); renderFiles(); renderOptions(); toast("Added to file list"); };
      box.appendChild(row);
    });

    if ((res.results || []).length > 1) {
      const all = el("button", "btn btn-tonal btn-sm", "⬇ Download all");
      all.onclick = () => res.results.forEach((r, i) => setTimeout(() => {
        const a = document.createElement("a");
        a.href = `/api/file/${r.id}?download=1`;
        a.download = r.name;
        a.click();
      }, i * 350));
      box.appendChild(all);
    }

    // Extracted text preview
    if (res.text !== undefined) {
      const ta = el("textarea", "form-input pt-text");
      ta.value = res.text;
      ta.rows = 14;
      ta.readOnly = true;
      box.appendChild(ta);

      const actRow = el("div", "pt-actions-row");
      const cp = el("button", "btn btn-tonal btn-sm", `<span class="material-symbols-rounded">content_copy</span> <span>Copy text</span>`);
      cp.onclick = () => (window.copyTextSafe ? window.copyTextSafe(ta.value) : navigator.clipboard.writeText(ta.value)).then?.(() => toast("📋 Copied to clipboard"));
      actRow.appendChild(cp);

      if (res.results && res.results[0]) {
        const dl = el("a", "btn btn-primary btn-sm", `<span class="material-symbols-rounded">download</span> <span>Download ${res.results[0].name}</span>`);
        dl.href = `/api/file/${res.results[0].id}?download=1`;
        dl.download = res.results[0].name;
        actRow.appendChild(dl);
      }
      box.appendChild(actRow);
    }

    // Diff preview for compare
    if (res.compare) {
      const pre = el("pre", "pt-diff");
      pre.innerHTML = esc(res.compare.diff || "(no differences)").split("\n").map(l => l.startsWith("+") ? `<span class="add">${l}</span>` : l.startsWith("-") ? `<span class="del">${l}</span>` : l).join("\n");
      box.appendChild(pre);
    }
  }

  // ---------------------------------------------------------------- mount
  function init() {
    const pane = $("#subviewPower"); if (!pane) return;
    pane.innerHTML = `
      <div id="ptBanner" class="pt-banner">Checking PDF engine…</div>
      <div class="pt-layout">
        <aside class="pt-left">
          <div class="pt-dropzone" id="ptDrop"><span class="material-symbols-rounded">upload_file</span>
            <div><b>Add files</b><small>Drop PDFs / images or click</small></div><input type="file" id="ptPick" multiple accept=".pdf,image/*" hidden></div>
          <div id="ptFileList" class="pt-filelist"></div>
        </aside>
        <section class="pt-main">
          <div id="ptToolGrid" class="pt-toolgrid"></div>
          <div class="pt-work"><div id="ptOptions" class="pt-options"></div><div id="ptResults" class="pt-results"></div></div>
        </section>
      </div>`;
    const drop = $("#ptDrop"), pick = $("#ptPick");
    drop.onclick = () => pick.click();
    pick.onchange = () => { addFiles(pick.files); pick.value = ""; };
    ["dragenter", "dragover"].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); e.stopPropagation(); drop.classList.add("over"); }));
    ["dragleave", "drop"].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.remove("over"); }));
    drop.addEventListener("drop", e => { e.stopPropagation(); const ov = document.getElementById("globalDropOverlay"); if (ov) { ov.classList.add("hidden"); ov.classList.remove("visible"); } if (e.dataTransfer.files.length) addFiles(e.dataTransfer.files); });
    renderFiles(); renderTools(); renderOptions(); checkEngine();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
