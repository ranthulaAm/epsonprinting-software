/* Shop counter: real billing from the print queue, customer tickets, receipts and daily totals.
   No sample data - everything is built from the files the cashier adds. Tickets persist in localStorage. */
(function () {
  "use strict";
  const KEY = "ph_shop_tickets_v1";
  const $ = id => document.getElementById(id);
  const si = () => typeof currentLang !== "undefined" && currentLang === "si";
  const T = (en, sin) => (si() ? sin : en);
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const money = n => (typeof formatEnginePrice === "function" ? formatEnginePrice(n) : "Rs. " + n.toFixed(2));

  let tickets = [];
  try { tickets = JSON.parse(localStorage.getItem(KEY) || "[]"); } catch (e) { tickets = []; }
  const save = () => localStorage.setItem(KEY, JSON.stringify(tickets));
  const nextCode = () => "SHP-" + String(tickets.length + 1).padStart(4, "0");
  const isToday = t => new Date(t.at).toDateString() === new Date().toDateString();

  /* ---------- counter (left list + right bill) ---------- */
  function renderCounter() {
    const tb = $("shopBatchTbody");
    if (!tb) return;
    if (!queue.length) {
      tb.innerHTML = `<tr><td colspan="5" class="shop-empty">${esc(T("No files yet. Drop customer files above or use Browse Files.", "තවම ෆයිල් නැත. ඉහත ෆයිල් දමන්න හෝ Browse Files භාවිතා කරන්න."))}</td></tr>`;
    } else {
      tb.innerHTML = queue.map(f => `<tr><td>${esc(f.name)}</td><td>${f.pages}</td><td>${f.copies}</td>` +
        `<td>${f.colorMode === "color" ? T("Color", "වර්ණ") : T("B&W", "කළු-සුදු")}</td>` +
        `<td>${f.duplex === "one-sided" ? T("1-Sided", "එක් පැත්ත") : T("2-Sided", "දෙපැත්ත")}</td></tr>`).join("");
    }
    const q = calculateCurrentQueueQuote();
    const pages = queue.reduce((s, f) => s + f.pages * f.copies, 0);
    $("shopBillPages").textContent = T(`${pages} pages`, `පිටු ${pages}`);
    $("shopBillRows").innerHTML = q.lineSegments.map(s =>
      `<div class="bill-row"><span>${esc(s.desc)}</span><span>${money(s.subtotal)}</span></div>`).join("");
    $("shopCalculatedTotal").textContent = money(q.finalTotal);
    const c = $("shopBillCostLine");
    if (c) c.innerHTML = T("Estimated Ink &amp; Paper Supply Cost: ", "ඇස්තමේන්තුගත තීන්ත සහ කඩදාසි පිරිවැය: ") +
      `<strong>${money(q.totalCost)}</strong> (${T("Profit", "ලාභය")}: <span class="text-success">${money(q.netProfit)}</span>)`;
    const tag = $("shopJobTag");
    if (tag) tag.value = nextCode();
  }

  /* ---------- tickets ---------- */
  function statusLabel(s) {
    return { printing: T("Printing", "මුද්‍රණය වෙමින්"), ready: T("Ready for Pickup", "ලබාගැනීමට සූදානම්"), done: T("Handed Over", "භාර දෙන ලදී") }[s] || s;
  }
  function renderTickets() {
    const grid = $("customerJobsGrid");
    if (!grid) return;
    const q = ($("barcodeSearchInput")?.value || "").trim().toLowerCase();
    const list = tickets.filter(t => !q || t.code.toLowerCase().includes(q) || (t.customer || "").toLowerCase().includes(q)).slice().reverse();
    if (!list.length) {
      grid.innerHTML = `<div class="shop-empty-card"><span class="material-symbols-rounded">badge</span><p>${esc(
        tickets.length ? T("No ticket matches your search.", "සෙවුමට ගැළපෙන ටිකට්පතක් නැත.") :
          T("No customer tickets yet. Tickets appear here after you print a batch from the counter.", "තවම ගනුදෙනුකරු ටිකට් නැත. කවුන්ටරයෙන් මුද්‍රණය කළ පසු ටිකට් මෙහි පෙනේ."))}</p></div>`;
      return;
    }
    grid.innerHTML = list.map(t => `
      <div class="cust-job-card" data-code="${esc(t.code)}">
        <div class="cust-card-top">
          <div><h4>${esc(t.customer || T("Walk-in Customer", "සාමාන්‍ය ගනුදෙනුකරු"))}</h4><span class="ticket-code">#${esc(t.code)}</span></div>
          <span class="badge-status status-${t.status === "done" ? "done" : t.status === "ready" ? "done" : "printing"}">${esc(statusLabel(t.status))}</span>
        </div>
        <div class="cust-meta"><span>📄 ${T(`${t.files.length} file(s) • ${t.pages} pages`, `ෆයිල් ${t.files.length} • පිටු ${t.pages}`)}</span><strong>${money(t.total)}</strong></div>
        <div class="cust-card-actions">
          <button class="btn btn-tonal btn-sm" data-act="receipt">${T("Receipt", "රිසිට්පත")}</button>
          ${t.status === "printing" ? `<button class="btn btn-outline btn-sm" data-act="ready">${T("Mark Ready", "සූදානම් ලෙස සලකුණු කරන්න")}</button>` : ""}
          ${t.status === "ready" ? `<button class="btn btn-primary btn-sm" data-act="done">${T("Hand Over", "භාර දෙන්න")}</button>` : ""}
        </div>
      </div>`).join("");
  }
  function renderTotals() {
    const day = tickets.filter(isToday);
    const rev = day.reduce((s, t) => s + t.total, 0), cost = day.reduce((s, t) => s + t.cost, 0);
    const set = (id, v) => { const e = $(id); if (e) e.textContent = v; };
    set("lblAuditRevenue", money(rev));
    set("lblAuditCost", money(cost) + " (est.)");
    set("lblAuditProfit", money(Math.max(0, rev - cost)) + " (est.)");
  }
  function refresh() { renderCounter(); renderTickets(); renderTotals(); }

  /* ---------- receipt ---------- */
  function fillReceipt(t) {
    $("receiptDateTime").textContent = new Date(t.at).toLocaleString() + " • " + T("CASHIER", "කැෂියර්") + " #01";
    $("rcptCustomerName").textContent = T("Customer: ", "ගනුදෙනුකරු: ") + (t.customer || T("Walk-in", "සාමාන්‍ය"));
    $("rcptJobCode").textContent = T("Ticket: #", "ටිකට්: #") + t.code;
    $("rcptItemsList").innerHTML = t.lines.map(l => `<div class="r-item"><span>${esc(l.desc)}</span><span>${money(l.subtotal)}</span></div>`).join("");
    $("rcptSubtotal").textContent = money(t.gross);
    $("rcptDiscount").textContent = money(Math.max(0, t.gross - t.total));
    $("rcptGrandTotal").textContent = money(t.total);
    $("receiptModal").classList.remove("hidden");
    window.__currentReceipt = t;
  }
  function printReceiptWindow() {
    const paper = $("receiptPaper");
    if (!paper) return;
    const w = window.open("", "_blank", "width=380,height=640");
    if (!w) return showToast(T("Allow pop-ups to print the receipt.", "රිසිට්පත මුද්‍රණයට pop-ups ඉඩ දෙන්න."));
    w.document.write(`<html><head><meta charset="utf-8"><title>Receipt</title><style>body{font:13px monospace;width:300px;margin:12px auto}.r-item,.r-total-row,.receipt-customer-row{display:flex;justify-content:space-between;gap:8px}.grand{font-weight:bold}.receipt-header,.receipt-footer{text-align:center}</style></head><body>${paper.innerHTML}</body></html>`);
    w.document.close(); w.focus(); setTimeout(() => w.print(), 200);
  }

  /* ---------- actions ---------- */
  function printBatch() {
    if (!queue.length) return showToast(T("⚠️ Add customer files first.", "⚠️ මුලින් ගනුදෙනුකරුගේ ෆයිල් එක් කරන්න."));
    const q = calculateCurrentQueueQuote();
    const pages = queue.reduce((s, f) => s + f.pages * f.copies, 0);
    const t = {
      code: nextCode(), at: Date.now(), customer: ($("shopCustomerName")?.value || "").trim(),
      files: queue.map(f => f.name), pages, total: q.finalTotal, gross: q.grossSubtotal, cost: q.totalCost,
      lines: q.lineSegments.map(s => ({ desc: s.desc, subtotal: s.subtotal })), status: "printing"
    };
    tickets.push(t); save();
    const p = (printers.find(x => x.id === selectedPrinterId) || printers[0] || {}).name || "";
    jobs.unshift({ id: "JOB-" + t.code, doc: t.files.length === 1 ? t.files[0] : `${t.files.length} files`, printer: p,
      pages: String(pages), status: T("Sent to Spooler", "ස්පූලරයට යැවිණි"), time: new Date().toLocaleTimeString() });
    renderJobsTable();
    queue = []; selectedQueueIndex = 0; updateQueueUI(); updatePreviewCanvas();
    if ($("shopCustomerName")) $("shopCustomerName").value = "";
    refresh();
    fillReceipt(t);
    showToast(T(`🧾 Ticket #${t.code} created`, `🧾 ටිකට්පත #${t.code} සාදන ලදී`));
  }
  function init() {
    $("btnShopPrintAndReceipt")?.addEventListener("click", printBatch);
    $("btnOpenReceiptPreview")?.addEventListener("click", () => {
      const last = tickets[tickets.length - 1];
      last ? fillReceipt(last) : showToast(T("No receipt yet — print a batch first.", "තවම රිසිට්පතක් නැත — මුලින් මුද්‍රණය කරන්න."));
    });
    $("btnReprintLastJob")?.addEventListener("click", () => {
      const last = tickets[tickets.length - 1];
      showToast(last ? T(`🔁 Reprint sent for #${last.code}`, `🔁 #${last.code} නැවත මුද්‍රණයට යැවිණි`) : T("Nothing to reprint yet.", "නැවත මුද්‍රණයට කිසිවක් නැත."));
    });
    $("btnSaveReceiptPdf")?.addEventListener("click", printReceiptWindow);
    $("btnPrintReceiptThermal")?.addEventListener("click", printReceiptWindow);
    $("barcodeSearchInput")?.addEventListener("input", renderTickets);
    $("btnNewCustomerTicket")?.addEventListener("click", () => {
      document.querySelector('[data-shop-view="counter"]')?.click();
      $("shopCustomerName")?.focus();
    });
    $("customerJobsGrid")?.addEventListener("click", e => {
      const b = e.target.closest("[data-act]");
      const card = e.target.closest("[data-code]");
      if (!b || !card) return;
      const t = tickets.find(x => x.code === card.dataset.code);
      if (!t) return;
      if (b.dataset.act === "receipt") fillReceipt(t);
      else { t.status = b.dataset.act; save(); refresh(); }
    });
    const orig = window.updateQueueUI;
    if (typeof orig === "function") window.updateQueueUI = function () { const r = orig.apply(this, arguments); renderCounter(); return r; };
    const origUi = window.updateUIStrings;
    if (typeof origUi === "function") window.updateUIStrings = function () { const r = origUi.apply(this, arguments); refresh(); return r; };
    refresh();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(init, 0));
  else setTimeout(init, 0);
})();
