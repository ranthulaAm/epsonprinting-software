/* PDF Power Tools — real PDF operations through the local Print Helper PDF engine. */
(function () {
  "use strict";
  const API = "";               // same origin as the page (served by pdf_engine/server.py)
  const $ = (s, r = document) => r.querySelector(s);
  const el = (t, c, h) => { const e = document.createElement(t); if (c) e.className = c; if (h !== undefined) e.innerHTML = h; return e; };
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const toast = m => (window.showToast ? window.showToast(m) : alert(m));
  const fmtSize = b => b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB";

  const state = { files: [], selected: new Set(), tool: "merge", engine: null, ocrLangs: [], busy: false,
                  org: [], redact: { file: null, page: 1, regions: [] }, results: [] };

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
    { id: "text", icon: "text_snippet", name: "Extract Text", desc: "Copy all text from a PDF", need: "1" },
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
      $(".pt-up", row).onclick = () => { if (i > 0) { [state.files[i - 1], state.files[i]] = [state.files[i], state.files[i - 1]]; renderFiles(); } };
      $(".pt-down", row).onclick = () => { if (i < state.files.length - 1) { [state.files[i + 1], state.files[i]] = [state.files[i], state.files[i + 1]]; renderFiles(); } };
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
        const [m] = state.files.splice(+from, 1); state.files.splice(i, 0, m); renderFiles(); };
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
      c.onclick = () => { state.tool = t.id; renderTools(); renderOptions(); };
      g.appendChild(c);
    });
  }

  // ---------------------------------------------------------------- options per tool
  const field = (label, inner, hint) => `<div class="pt-field"><label>${label}</label>${inner}${hint ? `<small>${hint}</small>` : ""}</div>`;
  const pagesField = (id = "optPages", def = "all") => field("Pages", `<input id="${id}" class="form-input" value="${def}" placeholder="all, odd, even, 1-3,7,10-">`, "Examples: 1-3,7 • 5- (page 5 to end) • odd • even");

  function renderOptions() {
    const box = $("#ptOptions"); const t = TOOLS.find(x => x.id === state.tool); const pdfs = selectedPdfs();
    let h = `<h3>${t.name}</h3><p class="pt-desc">${t.desc}</p>`;
    const needOne = pdfs.length < 1 ? `<div class="pt-warn">Select a PDF in the file list.</div>` : (pdfs.length > 1 && !["merge", "organize", "compare", "images_to_pdf"].includes(t.id) ? `<div class="pt-note">Using the first selected PDF: <b>${esc(pdfs[0].name)}</b></div>` : "");
    switch (t.id) {
      case "merge": h += field("Output name", `<input id="optName" class="form-input" value="merged.pdf">`, `Merges the ${pdfs.length} selected PDF(s) in list order.`) + (pdfs.length < 2 ? `<div class="pt-warn">Select at least 2 PDFs.</div>` : ""); break;
      case "organize": h += `<p class="pt-note">Pages of the selected PDFs appear below. Click to select, then rotate/delete; drag to reorder.</p>`; break;
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
      case "text": h += needOne + pagesField(); break;
      case "ocr": { const opts = (state.ocrLangs.length ? state.ocrLangs : ["eng"]).map(l => `<option>${l}</option>`).join("");
        h += needOne + field("Language", `<select id="optLang" class="form-select">${opts}</select>`, state.ocrLangs.includes("sin") ? "Use eng+sin for mixed Sinhala/English." : "Sinhala: brew install tesseract-lang (Mac) then restart the engine.") + pagesField() +
          `<label class="pt-check"><input type="checkbox" id="optSearchable" checked> Also create a searchable PDF</label>`; break; }
      case "compare": h += (pdfs.length === 2 ? `<p class="pt-note">Comparing <b>${esc(pdfs[0].name)}</b> ↔ <b>${esc(pdfs[1].name)}</b></p>` : `<div class="pt-warn">Select exactly 2 PDFs.</div>`); break;
    }
    h += `<div class="pt-run"><button class="btn btn-primary" id="ptRun" ${state.engine ? "" : "disabled"}><span class="material-symbols-rounded">play_arrow</span><span>${t.id === "organize" ? "Build PDF" : "Run"}</span></button><span id="ptBusy" class="pt-busy hidden">Working…</span></div>`;
    box.innerHTML = h;
    $("#ptRun").onclick = run;
    if (t.id === "organize") loadOrganizer();
    if (t.id === "redact") initRedact();
  }

  // ---------------------------------------------------------------- organizer
  async function loadOrganizer() {
    const items = [];
    selectedPdfs().forEach(f => { for (let p = 1; p <= f.pages; p++) items.push({ file: f.id, name: f.name, page: p, rotate: 0, sel: false, del: false }); });
    state.org = items; drawOrganizer();
  }
  function drawOrganizer() {
    let g = $("#ptOrgGrid"); if (!g) { g = el("div", "pt-orggrid"); g.id = "ptOrgGrid"; $("#ptOptions").insertBefore(g, $(".pt-run")); const bar = el("div", "pt-orgbar",
      `<button class="btn btn-tonal btn-sm" data-a="l">⟲ Rotate left</button><button class="btn btn-tonal btn-sm" data-a="r">⟳ Rotate right</button><button class="btn btn-tonal btn-sm" data-a="d">🗑 Delete</button><button class="btn btn-outline btn-sm" data-a="all">Select all</button><button class="btn btn-outline btn-sm" data-a="odd">Select odd</button>`);
      bar.onclick = e => { const a = e.target.dataset.a; if (!a) return; const sel = state.org.filter(x => x.sel);
        if (a === "l") sel.forEach(x => x.rotate = (x.rotate + 270) % 360);
        if (a === "r") sel.forEach(x => x.rotate = (x.rotate + 90) % 360);
        if (a === "d") state.org = state.org.filter(x => !x.sel);
        if (a === "all") { const all = state.org.every(x => x.sel); state.org.forEach(x => x.sel = !all); }
        if (a === "odd") state.org.forEach((x, i) => x.sel = i % 2 === 0);
        drawOrganizer(); }; $("#ptOptions").insertBefore(bar, g); }
    g.innerHTML = "";
    if (!state.org.length) g.innerHTML = `<div class="pt-empty">Select PDFs on the left to see their pages.</div>`;
    state.org.forEach((x, i) => {
      const t = el("div", "pt-page" + (x.sel ? " sel" : ""));
      t.draggable = true;
      t.innerHTML = `<div class="pt-thumbwrap"><img loading="lazy" src="/api/thumb/${x.file}/${x.page}?w=160" style="transform:rotate(${x.rotate}deg)"></div><small>${i + 1} · ${esc(x.name.slice(0, 14))} p${x.page}${x.rotate ? " ↻" + x.rotate : ""}</small>`;
      t.onclick = () => { x.sel = !x.sel; t.classList.toggle("sel", x.sel); };
      t.ondragstart = e => e.dataTransfer.setData("text/pt-page", String(i));
      t.ondragover = e => { if (e.dataTransfer.types.includes("text/pt-page")) e.preventDefault(); };
      t.ondrop = e => { const from = e.dataTransfer.getData("text/pt-page"); if (from === "") return; e.preventDefault(); const [m] = state.org.splice(+from, 1); state.org.splice(i, 0, m); drawOrganizer(); };
      g.appendChild(t);
    });
  }

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
    if (t === "images_to_pdf") { const im = selectedFiles().filter(f => f.kind !== "pdf"); if (!im.length) throw new Error("Select at least one image"); return { op: t, files: im.map(f => f.id), options: { name: v("optName") } }; }
    if (!pdfs.length && t !== "organize") throw new Error("Select a PDF first");
    switch (t) {
      case "merge": if (ids.length < 2) throw new Error("Select at least 2 PDFs"); return { op: t, files: ids, options: { name: v("optName") } };
      case "organize": { if (!state.org.length) throw new Error("No pages to build — select PDFs first (or you deleted every page)"); return { op: "assemble", files: [], options: { name: "organized.pdf", items: state.org.map(x => ({ file: x.file, page: x.page, rotate: x.rotate })) } }; }
      case "split": return { op: t, files: [f0], options: { mode: v("optMode"), value: v("optValue") } };
      case "extract": case "delete": case "text": return { op: t, files: [f0], options: { pages: v("optPages") } };
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
      case "ocr": return { op: t, files: [f0], options: { lang: v("optLang"), pages: v("optPages"), searchable: chk("optSearchable") } };
      case "compare": if (ids.length !== 2) throw new Error("Select exactly 2 PDFs"); return { op: t, files: ids, options: {} };
    }
  }

  async function run() {
    if (state.busy) return;
    let req; try { req = buildRequest(); } catch (e) { toast("⚠️ " + e.message); return; }
    state.busy = true; $("#ptRun").disabled = true; $("#ptBusy").classList.remove("hidden");
    try {
      const res = await post("/api/op", req);
      showResult(res);
      toast("✅ " + (res.message || "Done"));
    } catch (e) { showResult({ error: e.message }); toast("❌ " + e.message); }
    finally { state.busy = false; const b = $("#ptRun"); if (b) b.disabled = false; const bb = $("#ptBusy"); if (bb) bb.classList.add("hidden"); }
  }

  function showResult(res) {
    const box = $("#ptResults"); box.innerHTML = "";
    if (res.error) { box.innerHTML = `<div class="pt-result err"><span class="material-symbols-rounded">error</span> ${esc(res.error)}</div>`; return; }
    box.appendChild(el("div", "pt-result ok", `<span class="material-symbols-rounded">check_circle</span> ${esc(res.message || "Done")}`));
    (res.results || []).forEach(r => {
      const row = el("div", "pt-outfile", `<span class="material-symbols-rounded">${r.name.endsWith(".zip") ? "folder_zip" : "picture_as_pdf"}</span><div class="pt-fmeta"><b>${esc(r.name)}</b><small>${r.pages ? r.pages + " pages • " : ""}${fmtSize(r.size)}</small></div>
        <a class="btn btn-primary btn-sm" href="/api/file/${r.id}?download=1" download="${esc(r.name)}">Download</a>
        ${r.name.endsWith(".pdf") ? `<button class="btn btn-outline btn-sm pt-open">Open</button><button class="btn btn-tonal btn-sm pt-use">Use as input</button>` : ""}`);
      const op = $(".pt-open", row); if (op) op.onclick = () => window.open(`/api/file/${r.id}`, "_blank");
      const us = $(".pt-use", row); if (us) us.onclick = () => { if (!state.files.find(f => f.id === r.id)) state.files.push(r); state.selected = new Set([r.id]); renderFiles(); renderOptions(); toast("Added to file list"); };
      box.appendChild(row);
    });
    if ((res.results || []).length > 1) { const all = el("button", "btn btn-tonal btn-sm", "⬇ Download all"); all.onclick = () => res.results.forEach((r, i) => setTimeout(() => { const a = document.createElement("a"); a.href = `/api/file/${r.id}?download=1`; a.download = r.name; a.click(); }, i * 350)); box.appendChild(all); }
    if (res.text !== undefined) { const ta = el("textarea", "form-input pt-text"); ta.value = res.text; ta.rows = 12; box.appendChild(ta);
      const cp = el("button", "btn btn-tonal btn-sm", "Copy text"); cp.onclick = () => (window.copyTextSafe ? window.copyTextSafe(ta.value) : navigator.clipboard.writeText(ta.value)).then?.(() => toast("📋 Copied")); box.appendChild(cp); }
    if (res.compare) { const pre = el("pre", "pt-diff"); pre.innerHTML = esc(res.compare.diff || "(no differences)").split("\n").map(l => l.startsWith("+") ? `<span class="add">${l}</span>` : l.startsWith("-") ? `<span class="del">${l}</span>` : l).join("\n"); box.appendChild(pre); }
    (res.results || []).forEach(r => { if (!state.files.find(f => f.id === r.id) && false) state.files.push(r); });
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
