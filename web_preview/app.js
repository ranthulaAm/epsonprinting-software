// Print Helper, Shop POS & PDF Studio - Interactive Web Preview

const strings = {
  en: {
    appTitle: "Print Helper",
    offlineBadge: "100% Offline",
    navPrint: "Print",
    navPrinters: "Printers",
    navJobs: "Jobs",
    navTools: "Tools",
    navShop: "Shop",
    navSettings: "Settings",
    dropTitle: "Drop files here to print",
    dropSub: "Supports PDF, Images (PNG, JPG, WebP), Plain Text (TXT) and Markdown (MD)",
    dropHeadline: "Drop files here",
    dropOverlaySub: "Files will be added to your print queue",
    queueHeader: "Files to Print",
    printAction: "Print",
    btnOpen: "Add Files",
    btnPaste: "Paste (Ctrl+V)",
    previewHeader: "Preview",
    printSettings: "Print Settings",
    copies: "Copies",
    color: "Color",
    colorOption: "Color",
    bwOption: "B&W",
    sides: "Sides",
    oneSided: "Single-sided",
    twoSided: "Two-sided (Long Edge)",
    twoSidedShort: "Two-sided (Short Edge)",
    paperSize: "Paper Size",
    pages: "pages",
    page: "page",
    printerStatusReady: "Ready",
    printerStatusOffline: "Printer is offline",
    inkLow: "Ink is low",
    save: "Save",
    cancel: "Cancel",
    settings: "Settings"
  },
  si: {
    appTitle: "Print Helper",
    offlineBadge: "100% නොබැඳිව (Offline)",
    navPrint: "ප්‍රින්ට්",
    navPrinters: "ප්‍රින්ටර්ස්",
    navJobs: "පෝලිම",
    navTools: "PDF මෙවලම්",
    navShop: "කඩේ මුද්‍රණ",
    navSettings: "සැකසුම්",
    dropTitle: "ෆයිල් මෙතනට දාන්න",
    dropSub: "PDF, පින්තූර (PNG, JPG, WebP), TXT සහ Markdown ෆයිල් දැමිය හැක",
    dropHeadline: "ෆයිල් මෙතනින් අතහරින්න",
    dropOverlaySub: "ප්‍රින්ට් කිරීමට ෆයිල් එකතු වේ",
    queueHeader: "ප්‍රින්ට් කරන ෆයිල්",
    printAction: "ප්‍රින්ට් කරන්න",
    btnOpen: "ෆයිල් එකතු කරන්න",
    btnPaste: "පේස්ට් කරන්න (Ctrl+V)",
    previewHeader: "පෙරදසුන",
    printSettings: "ප්‍රින්ට් සැකසුම්",
    copies: "කොපි ගණන",
    color: "පාට",
    colorOption: "පාටින්",
    bwOption: "කළු සුදු",
    sides: "මුද්‍රණය කරන පැත්ත",
    oneSided: "එක පැත්තකින්",
    twoSided: "දෙපැත්තෙන්ම (පොතක් වගේ)",
    twoSidedShort: "දෙපැත්තෙන්ම (දින දර්ශනයක් වගේ)",
    paperSize: "කඩදාසි ප්‍රමාණය",
    pages: "පිටු",
    page: "පිටුව",
    printerStatusReady: "සූදානම්",
    printerStatusOffline: "ප්‍රින්ටර් එක සම්බන්ධ වෙලා නැහැ",
    inkLow: "තීන්ත අඩුයි",
    save: "සුරකින්න",
    cancel: "අවලංගු කරන්න",
    settings: "සැකසුම්"
  }
};

let currentLang = 'en';
let currentTheme = 'dark';
let activeFilter = 'all';

// Active Queue & Preview state
let selectedQueueIndex = 0;
let previewCurrentPage = 1;
let previewZoom = 1.0;

// Mock Spooler Printers
let printers = [
  {
    id: "hp_m404dn",
    name: "HP LaserJet Pro M404dn",
    location: "Main Office (192.168.1.120)",
    status: "Ready",
    statusType: "online",
    type: "network",
    isDefault: true,
    isFavorite: true,
    toner: 84,
    tags: ["Network LAN", "Duplex", "A4 / Letter", "Default"]
  },
  {
    id: "canon_mf445dw",
    name: "Canon imageCLASS MF445dw",
    location: "Creative Dept (192.168.1.144)",
    status: "Ready",
    statusType: "online",
    type: "network",
    isDefault: false,
    isFavorite: true,
    toner: 65,
    tags: ["Color", "Network LAN", "High-DPI"]
  },
  {
    id: "epson_l3250",
    name: "Epson EcoTank L3250 Series",
    location: "Desk USB Port #2",
    status: "Ready • Low Ink (12%)",
    statusType: "warning",
    type: "usb",
    isDefault: false,
    isFavorite: false,
    toner: 12,
    tags: ["USB Direct", "Ink Tank", "Photo Quality"]
  },
  {
    id: "epson_wf4830",
    name: "Epson WorkForce Pro WF-4830",
    location: "Accounts Office LAN (192.168.1.182)",
    status: "Ready • Hardware Duplex Active",
    statusType: "online",
    type: "network",
    isDefault: false,
    isFavorite: true,
    toner: 78,
    tags: ["Network LAN", "Auto Duplex", "Heavy Duty Pigment"]
  },
  {
    id: "epson_l8050",
    name: "Epson EcoTank Photo L8050",
    location: "Photo Studio USB Port #1",
    status: "Ready • 6-Color Tank",
    statusType: "online",
    type: "usb",
    isDefault: false,
    isFavorite: false,
    toner: 90,
    tags: ["USB Direct", "6-Color Photo", "CD/DVD & ID Tray"]
  },
  {
    id: "pdf_virtual",
    name: "Microsoft Print to PDF",
    location: "Virtual Software Spooler",
    status: "Ready",
    statusType: "online",
    type: "virtual",
    isDefault: false,
    isFavorite: false,
    toner: 100,
    tags: ["Virtual", "Vector Output", "Zero Ink"]
  },
  {
    id: "brother_hl",
    name: "Brother HL-L2350DW",
    location: "Warehouse Spooler (192.168.1.205)",
    status: "Offline • Check Cable",
    statusType: "offline",
    type: "network",
    isDefault: false,
    isFavorite: false,
    toner: 0,
    tags: ["Network LAN", "Monochrome"]
  }
];

let selectedPrinterId = "hp_m404dn";

// Queue Items Store
let queue = [];

// Sample Demo Files
const sampleBatch = [
  {
    id: "f_1",
    name: "sinhala_orthography_test.pdf",
    ext: "PDF",
    sizeStr: "1.2 MB",
    pages: 4,
    type: "pdf",
    copies: 1,
    colorMode: "color",
    duplex: "two-sided",
    orientation: "portrait",
    paperSize: "A4",
    tray: "Auto",
    expanded: false
  },
  {
    id: "f_2",
    name: "Annual_Financial_Audit_2026.pdf",
    ext: "PDF",
    sizeStr: "2.4 MB",
    pages: 14,
    type: "pdf",
    copies: 1,
    colorMode: "bw",
    duplex: "two-sided",
    orientation: "portrait",
    paperSize: "A4",
    tray: "Auto",
    expanded: false
  },
  {
    id: "f_3",
    name: "Product_Packaging_Mockup_v4.png",
    ext: "PNG",
    sizeStr: "4.8 MB",
    pages: 1,
    type: "image",
    copies: 2,
    colorMode: "color",
    duplex: "one-sided",
    orientation: "landscape",
    paperSize: "A4",
    tray: "Tray 1",
    expanded: false
  }
];

// Jobs Log Store
let jobs = [
  {
    id: "JOB-4081",
    doc: "Client_NDA_Contract.pdf",
    printer: "HP LaserJet Pro M404dn",
    pages: "3 pages",
    status: "Completed",
    time: "10 mins ago"
  },
  {
    id: "JOB-4080",
    doc: "Shipping_Invoice_#992.pdf",
    printer: "HP LaserJet Pro M404dn",
    pages: "1 page",
    status: "Completed",
    time: "25 mins ago"
  }
];

// Organizer Pages State
let organizedPages = [
  { id: 1, label: "Page 1 (Cover)", rotated: 0, selected: false },
  { id: 2, label: "Page 2 (Agenda)", rotated: 0, selected: false },
  { id: 3, label: "Page 3 (Metrics)", rotated: 0, selected: false },
  { id: 4, label: "Page 4 (Signatures)", rotated: 0, selected: false }
];

// Command Palette Registry (all searchable actions & screens)
const commands = [
  { title: "Print Queue", sub: "View files and configure print batch", icon: "print", tab: "print" },
  { title: "Shop Mode POS & Billing", sub: "Cashier counter, price estimation, receipts, multi-printer fleet", icon: "point_of_sale", tab: "shop", subview: "counter" },
  { title: "Customer Jobs & Barcode Scanner", sub: "Scan tickets, customer grouping, job status", icon: "badge", tab: "shop", subview: "customers" },
  { title: "Multi-Printer Live Fleet Dashboard", sub: "Live ink/toner gauges, paper meters, auto-routing rules", icon: "hub", tab: "shop", subview: "fleet" },
  { title: "Price List & Profit Tracker", sub: "Editable page rates (LKR), daily cashier profit audit", icon: "payments", tab: "shop", subview: "pricing" },
  { title: "PDF Multi-Tab Viewer", sub: "Inspect pages, zoom, rotate, search text", icon: "menu_book", tab: "tools", subview: "viewer" },
  { title: "Page Organizer (Merge / Split / Rotate)", sub: "Reorder, extract, rotate 90°, delete pages", icon: "dashboard_customize", tab: "tools", subview: "organizer" },
  { title: "Annotate, Sign & AcroForms", sub: "Draw signature, sticky notes, approve stamp, fill forms", icon: "edit_document", tab: "tools", subview: "annotate" },
  { title: "Security & Redaction", sub: "256-bit AES password encryption, blackout text, visual compare", icon: "security", tab: "tools", subview: "security" },
  { title: "Convert & OCR (Sinhala + English)", sub: "Tesseract neural text extraction, PDF to PNG", icon: "transform", tab: "tools", subview: "ocr" },
  { title: "Manual Duplex Paper Turn Assistant", sub: "Visual instructions for flipping paper on single-sided printers", icon: "flip", action: "openDuplex" },
  { title: "Epson Diagnostics & Nozzle Check", sub: "Clean head, test nozzle pattern, ESC/P-R telemetry", icon: "precision_manufacturing", action: "openEpson" },
  { title: "Live Sheet Layout Preview (N-Up)", sub: "Open 1-Up, 2-Up, 4-Up imposition preview dialog", icon: "pageview", action: "openPreview" },
  { title: "Thermal Customer Receipt", sub: "Preview and print thermal ticket receipt", icon: "receipt_long", action: "openReceipt" },
  { title: "Printers & Spooler Management", sub: "Add network LAN printer, view toner levels, test print", icon: "router", tab: "printers" },
  { title: "Print Jobs Spooler History", sub: "Audit trail and reprint dispatched jobs", icon: "layers", tab: "jobs" },
  { title: "Print Presets", sub: "Eco Draft B&W, High-DPI Color, Booklet Duplex", icon: "bookmarks", tab: "presets" },
  { title: "Settings & AI Plugin", sub: "On-device AI document model, language and dark mode", icon: "settings", tab: "settings" }
];

// DOM Elements
const globalDropOverlay = document.getElementById("globalDropOverlay");
const toastEl = document.getElementById("toast");
const printerSelect = document.getElementById("printerSelect");
const railBadge = document.getElementById("railBadge");
const cardsList = document.getElementById("cardsList");
const queueSummaryText = document.getElementById("queueSummaryText");
const filePicker = document.getElementById("filePicker");
const cmdModal = document.getElementById("commandPaletteModal");
const cmdInput = document.getElementById("cmdInput");
const cmdResults = document.getElementById("cmdResults");
const livePreviewModal = document.getElementById("livePreviewModal");
const drawSigModal = document.getElementById("drawSigModal");
const manualDuplexModal = document.getElementById("manualDuplexModal");
const receiptModal = document.getElementById("receiptModal");
const epsonDiagModal = document.getElementById("epsonDiagModal");

// Init App
document.addEventListener("DOMContentLoaded", () => {
  const cfg = window.PREVIEW_CONFIG || {};
  const urlParams = new URLSearchParams(window.location.search);
  const theme = urlParams.get('theme') || cfg.theme;
  const lang = urlParams.get('lang') || cfg.lang;
  const tab = urlParams.get('tab') || cfg.tab;
  const sample = urlParams.get('sample') !== null ? (urlParams.get('sample') === 'true') : (cfg.sample !== undefined ? cfg.sample : true);

  if (theme) setTheme(theme);
  if (lang) {
    currentLang = lang;
  }

  renderPrinterDropdown();
  renderPrintersGrid();
  renderJobsTable();
  renderOrganizerPages();
  setupEventListeners();
  setupZoneControls();
  setupSignaturePad();
  setupCommandPalette();
  updateUIStrings();

  if (sample) {
    loadSampleBatch();
  } else {
    updateQueueUI();
  }

  updateLivePrinterPanel();
  initThreeTierPrintSettings();

  if (tab) {
    switchTab(tab);
  }
});

function switchTab(tabName) {
  if (!tabName) return;
  document.querySelectorAll(".nav-item").forEach(b => {
    b.classList.toggle("active", b.dataset.tab === tabName);
  });
  document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));
  const tabId = "tab" + tabName.charAt(0).toUpperCase() + tabName.slice(1);
  const targetPane = document.getElementById(tabId);
  if (targetPane) {
    targetPane.classList.add("active");
  }
}

function setupEventListeners() {
  // Navigation Tabs
  document.querySelectorAll(".nav-item").forEach(btn => {
    btn.addEventListener("click", () => {
      switchTab(btn.dataset.tab);
    });
  });

  // Shop Mode Sub-view Pills
  document.querySelectorAll("#shopSubbar .pill-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#shopSubbar .pill-btn").forEach(b => b.classList.remove("active"));
      document.querySelectorAll("#tabShop .subview-pane").forEach(p => p.classList.remove("active"));
      btn.classList.add("active");
      const sub = btn.dataset.shopView;
      const targetSub = document.getElementById("shopView" + sub.charAt(0).toUpperCase() + sub.slice(1));
      if (targetSub) targetSub.classList.add("active");
    });
  });

  // PDF Tools Sub-view Pills
  document.querySelectorAll("#pdfToolsSubbar .pill-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#pdfToolsSubbar .pill-btn").forEach(b => b.classList.remove("active"));
      document.querySelectorAll("#tabTools .subview-pane").forEach(p => p.classList.remove("active"));
      btn.classList.add("active");
      const sub = btn.dataset.subview;
      const targetSub = document.getElementById("subview" + sub.charAt(0).toUpperCase() + sub.slice(1));
      if (targetSub) targetSub.classList.add("active");
    });
  });

  // Theme Toggle
  document.getElementById("btnThemeToggle").addEventListener("click", toggleTheme);
  const themeSel = document.getElementById("settingThemeSelect");
  if (themeSel) {
    themeSel.addEventListener("change", (e) => setTheme(e.target.value));
  }

  // Language Toggle
  document.getElementById("btnLangToggle").addEventListener("click", toggleLang);
  const langSel = document.getElementById("settingLangSelect");
  if (langSel) {
    langSel.addEventListener("change", (e) => {
      currentLang = e.target.value;
      updateUIStrings();
      updateQueueUI();
    });
  }

  // File Pickers
  filePicker.addEventListener("change", handleFileSelect);
  const btnPickTop = document.getElementById("btnPickFilesTop");
  if (btnPickTop) btnPickTop.addEventListener("click", () => filePicker.click());
  const btnRespAdd = document.getElementById("btnResponsiveAddFiles");
  if (btnRespAdd) btnRespAdd.addEventListener("click", () => filePicker.click());
  const btnShopBrowse = document.getElementById("btnShopBrowseFiles");
  if (btnShopBrowse) btnShopBrowse.addEventListener("click", () => filePicker.click());

  // Pasting
  const btnPasteTop = document.getElementById("btnPasteFilesTop");
  if (btnPasteTop) btnPasteTop.addEventListener("click", pasteFromClipboard);

  // Load Demo Batch
  document.getElementById("btnLoadDemo").addEventListener("click", loadSampleBatch);

  // Clear Queue
  const btnClearAll = document.getElementById("btnClearAll");
  if (btnClearAll) {
    btnClearAll.addEventListener("click", () => {
      queue = [];
      selectedQueueIndex = 0;
      updateQueueUI();
      showToast(currentLang === 'si' ? "සියල්ල අයින් කරන ලදී" : "Queue cleared");
    });
  }

  // Printer Dropdown Change
  if (printerSelect) {
    printerSelect.addEventListener("change", (e) => {
      selectedPrinterId = e.target.value;
      const p = printers.find(x => x.id === selectedPrinterId) || printers[0];
      if (p) triggerHotPlugToast(p.name);
      updateLivePrinterPanel();
      validateDependenciesAndAutoFixes();
      updateLiveSummary();
    });
  }

  // Modal Closures
  document.querySelectorAll(".btn-close-modal").forEach(btn => {
    btn.addEventListener("click", () => {
      livePreviewModal.classList.add("hidden");
      drawSigModal.classList.add("hidden");
      manualDuplexModal.classList.add("hidden");
      receiptModal.classList.add("hidden");
      epsonDiagModal.classList.add("hidden");
      const pMod = document.getElementById("addPrinterModal");
      if (pMod) pMod.classList.add("hidden");
    });
  });

  // Duplex Assistant Trigger
  document.getElementById("btnResumeEvenDuplex").addEventListener("click", () => {
    manualDuplexModal.classList.add("hidden");
    showToast(currentLang === 'si' ? "📄 දෙවන පැත්ත මුද්‍රණය ආරම්භ විය!" : "📄 Resumed! Even pages sent to printer.");
  });

  // Shop Mode Print & Receipt
  document.getElementById("btnShopPrintAndReceipt").addEventListener("click", () => {
    receiptModal.classList.remove("hidden");
    showToast("🧾 Dispatched counter batch & generated Customer Receipt Ticket #SHP-4089");
  });

  document.getElementById("btnOpenReceiptPreview").addEventListener("click", () => {
    receiptModal.classList.remove("hidden");
  });

  document.getElementById("btnReprintLastJob").addEventListener("click", () => {
    showToast("🔁 1-Click Reprint dispatched for Ticket #SHP-4089");
  });

  document.querySelectorAll(".btn-view-rcpt").forEach(b => {
    b.addEventListener("click", () => receiptModal.classList.remove("hidden"));
  });

  document.getElementById("btnSaveReceiptPdf").addEventListener("click", () => {
    showToast("💾 Saved SHP-4089_Receipt.pdf");
    receiptModal.classList.add("hidden");
  });

  document.getElementById("btnPrintReceiptThermal").addEventListener("click", () => {
    showToast("🖨️ Sent to 80mm ESC/POS Thermal Receipt Printer");
    receiptModal.classList.add("hidden");
  });

  document.getElementById("btnExportDailyReport").addEventListener("click", () => {
    showToast("📊 Exported Daily_Cashier_Report_2026-10-27.csv");
  });

  // Drag and Drop (Global)
  window.addEventListener("dragenter", (e) => {
    e.preventDefault();
    globalDropOverlay.classList.remove("hidden");
    globalDropOverlay.classList.add("visible");
  });

  globalDropOverlay.addEventListener("dragover", (e) => e.preventDefault());

  globalDropOverlay.addEventListener("dragleave", (e) => {
    if (e.relatedTarget === null || e.clientX <= 0 || e.clientY <= 0) {
      globalDropOverlay.classList.add("hidden");
      globalDropOverlay.classList.remove("visible");
    }
  });

  globalDropOverlay.addEventListener("drop", (e) => {
    e.preventDefault();
    globalDropOverlay.classList.add("hidden");
    globalDropOverlay.classList.remove("visible");
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      addRealFiles(e.dataTransfer.files);
    }
  });

  // Organizer Buttons
  const btnRotAll = document.getElementById("btnOrgRotateAll");
  if (btnRotAll) {
    btnRotAll.addEventListener("click", () => {
      organizedPages.forEach(p => p.rotated = (p.rotated + 90) % 360);
      renderOrganizerPages();
      showToast(currentLang === 'si' ? "පිටු අංශක 90 කින් හරවන ලදී" : "Rotated all pages 90° clockwise");
    });
  }

  // OCR button
  const btnOcr = document.getElementById("btnRunOcr");
  if (btnOcr) {
    btnOcr.addEventListener("click", () => {
      const lang = document.getElementById("selOcrLang").value;
      document.getElementById("txtOcrOutput").value = 
`[Tesseract OCR Engine • Result (${lang})]
--------------------------------------------------------
ශ්‍රී ලංකා මුද්‍රණ සහායක — ලේඛන පරීක්ෂණ වාර්තාව
දිනය: 2026-10-27 • රහසිගතයි

විස්තරය (Description):
මෙම ලේඛනය ශ්‍රී ලාංකීය යතුරුලියන ප්‍රමිතීන් (Noto Sans Sinhala / Iskoola Pota)
සහ මුද්‍රණ පෙරදසුන් තාක්ෂණය පරීක්ෂා කිරීම සඳහා සකස් කරන ලද්දකි.
බැඳි අකුරු (Ligatures), කොම්බුව සහ ඇලපිල්ල නිවැරදිව මුද්‍රණය කෙරේ.

Status: Verified 100% On-Device Neural Recognition.`;
      showToast("✨ OCR text extraction complete!");
    });
  }

  // Signature Pad Modal Trigger
  const btnDrawSig = document.getElementById("btnOpenSignaturePad");
  if (btnDrawSig) btnDrawSig.addEventListener("click", () => drawSigModal.classList.remove("hidden"));
  const sigSlot = document.getElementById("sigSlotBox");
  if (sigSlot) sigSlot.addEventListener("click", () => drawSigModal.classList.remove("hidden"));

  // Presets "Apply to Queue" buttons
  document.querySelectorAll(".btn-apply-preset").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const card = e.target.closest(".preset-card");
      applyPresetToQueue(card.dataset.preset);
    });
  });

  // Filter Chips in Printers Tab
  document.querySelectorAll(".filter-chip").forEach(chip => {
    chip.addEventListener("click", () => {
      document.querySelectorAll(".filter-chip").forEach(c => c.classList.remove("active"));
      chip.classList.add("active");
      activeFilter = chip.dataset.filter;
      renderPrintersGrid();
    });
  });

  // Add Network Printer Modal
  const modal = document.getElementById("addPrinterModal");
  const btnAddNet = document.getElementById("btnAddNetworkPrinter");
  if (btnAddNet) btnAddNet.addEventListener("click", () => modal.classList.remove("hidden"));
  const btnSaveNet = document.getElementById("btnSaveNetworkPrinter");
  if (btnSaveNet) {
    btnSaveNet.addEventListener("click", () => {
      const name = document.getElementById("netPrinterName").value.trim() || "Network Printer";
      const host = document.getElementById("netPrinterHost").value.trim() || "192.168.1.199";
      const port = document.getElementById("netPrinterPort").value;

      printers.push({
        id: "net_" + Date.now(),
        name: name,
        location: `${host} (Port ${port})`,
        status: "Ready",
        statusType: "online",
        type: "network",
        isDefault: false,
        isFavorite: true,
        toner: 90,
        tags: ["Network LAN", "Port " + port]
      });

      modal.classList.add("hidden");
      renderPrinterDropdown();
      renderPrintersGrid();
      showToast(`✅ Connected to network printer "${name}" at ${host}`);
    });
  }

  // Refresh Spooler
  const btnRefP = document.getElementById("btnRefreshPrinters");
  if (btnRefP) {
    btnRefP.addEventListener("click", () => {
      showToast(currentLang === 'si' ? "🔄 ප්‍රින්ටර් ලැයිස්තුව යාවත්කාලීන විය" : "🔄 Spooler refreshed: 5 printers synced");
    });
  }

  // Clear Jobs
  const btnClrJobs = document.getElementById("btnClearHistory");
  if (btnClrJobs) {
    btnClrJobs.addEventListener("click", () => {
      jobs = [];
      renderJobsTable();
      showToast(currentLang === 'si' ? "පෝලිම පිරිසිදු කරන ලදී" : "Print history cleared");
    });
  }
}

function setupZoneControls() {
  // Mobile / Tablet Slide-over Queue Drawer Toggle
  const btnToggleDrawer = document.getElementById("btnToggleQueueDrawer");
  const leftQueue = document.getElementById("zoneLeftQueue");
  if (btnToggleDrawer && leftQueue) {
    btnToggleDrawer.addEventListener("click", () => {
      leftQueue.classList.toggle("drawer-open");
    });
  }

  // Zone 2 Preview Navigation & Zoom Controls
  const btnPrev = document.getElementById("btnPrevPage");
  const btnNext = document.getElementById("btnNextPage");
  if (btnPrev) {
    btnPrev.addEventListener("click", () => {
      if (previewCurrentPage > 1) {
        previewCurrentPage--;
        updatePreviewCanvas();
      }
    });
  }
  if (btnNext) {
    btnNext.addEventListener("click", () => {
      const activeItem = queue[selectedQueueIndex] || queue[0];
      const maxPages = activeItem ? activeItem.pages : 1;
      if (previewCurrentPage < maxPages) {
        previewCurrentPage++;
        updatePreviewCanvas();
      }
    });
  }

  const btnZIn = document.getElementById("btnZoomIn");
  const btnZOut = document.getElementById("btnZoomOut");
  const btnZFit = document.getElementById("btnFitPage");
  if (btnZIn) {
    btnZIn.addEventListener("click", () => {
      previewZoom = Math.min(1.8, Math.round((previewZoom + 0.2) * 10) / 10);
      updatePreviewCanvas();
    });
  }
  if (btnZOut) {
    btnZOut.addEventListener("click", () => {
      previewZoom = Math.max(0.6, Math.round((previewZoom - 0.2) * 10) / 10);
      updatePreviewCanvas();
    });
  }
  if (btnZFit) {
    btnZFit.addEventListener("click", () => {
      previewZoom = 1.0;
      updatePreviewCanvas();
    });
  }

  // Zone 3 Right Panel Controls
  const btnCopiesPlus = document.getElementById("btnCopiesPlus");
  const btnCopiesMinus = document.getElementById("btnCopiesMinus");
  if (btnCopiesPlus) {
    btnCopiesPlus.addEventListener("click", () => {
      if (queue.length > 0 && queue[selectedQueueIndex]) {
        queue[selectedQueueIndex].copies++;
        updateQueueUI();
        updateRightPanelSettings();
      }
    });
  }
  if (btnCopiesMinus) {
    btnCopiesMinus.addEventListener("click", () => {
      if (queue.length > 0 && queue[selectedQueueIndex] && queue[selectedQueueIndex].copies > 1) {
        queue[selectedQueueIndex].copies--;
        updateQueueUI();
        updateRightPanelSettings();
      }
    });
  }

  const btnColorColor = document.getElementById("btnColorColor");
  const btnColorBw = document.getElementById("btnColorBw");
  if (btnColorColor) {
    btnColorColor.addEventListener("click", () => {
      if (queue[selectedQueueIndex]) {
        queue[selectedQueueIndex].colorMode = 'color';
        updateQueueUI();
        updateRightPanelSettings();
      }
    });
  }
  if (btnColorBw) {
    btnColorBw.addEventListener("click", () => {
      if (queue[selectedQueueIndex]) {
        queue[selectedQueueIndex].colorMode = 'bw';
        updateQueueUI();
        updateRightPanelSettings();
      }
    });
  }

  const selSides = document.getElementById("selSides");
  if (selSides) {
    selSides.addEventListener("change", (e) => {
      if (queue[selectedQueueIndex]) {
        queue[selectedQueueIndex].duplex = e.target.value === 'single' ? 'one-sided' : 'two-sided';
        updateQueueUI();
      }
    });
  }

  // Pinned Bottom-Right Print Button
  const btnRightPrint = document.getElementById("btnRightPrint");
  if (btnRightPrint) {
    btnRightPrint.addEventListener("click", handlePrintAction);
  }

  // Expandable Printer Live Details Toggle
  const btnToggleDetails = document.getElementById("btnTogglePrinterDetails");
  const expDetails = document.getElementById("printerExpandedDetails");
  const iconDetails = document.getElementById("iconToggleDetails");
  if (btnToggleDetails && expDetails) {
    btnToggleDetails.addEventListener("click", () => {
      const isHidden = expDetails.classList.toggle("hidden");
      if (iconDetails) iconDetails.innerText = isHidden ? "expand_more" : "expand_less";
    });
  }

  const btnCopyDiag = document.getElementById("btnCopyDiag");
  if (btnCopyDiag) {
    btnCopyDiag.addEventListener("click", () => {
      showToast(currentLang === 'si' ? "ප්‍රින්ටර් විස්තර කොපි කරන ලදී" : "Copied printer diagnostics to clipboard");
    });
  }
}

function updatePreviewCanvas() {
  const simulatedPaper = document.getElementById("paperSheetSimulated");
  const lblDocInfo = document.getElementById("lblPreviewDocInfo");
  const lblCounter = document.getElementById("lblPageCounter");
  const lblZoom = document.getElementById("lblZoomLevel");

  if (lblZoom) lblZoom.innerText = `${Math.round(previewZoom * 100)}%`;

  if (!simulatedPaper) return;
  simulatedPaper.style.transform = `scale(${previewZoom})`;
  simulatedPaper.style.transformOrigin = "center center";

  const item = queue[selectedQueueIndex] || queue[0];
  if (!item) {
    if (lblDocInfo) lblDocInfo.innerText = "A4 • Ready";
    if (lblCounter) lblCounter.innerText = "Page 1 of 1";
    simulatedPaper.innerHTML = `
      <div style="height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; color:#888; text-align:center;">
        <span class="material-symbols-rounded" style="font-size:36px; opacity:0.4;">description</span>
        <p style="font-size:12px; margin-top:8px;">${currentLang === 'si' ? 'ෆයිල් එකක් තෝරන්න' : 'Select a document to preview'}</p>
      </div>
    `;
    return;
  }

  const totalPages = item.pages;
  if (previewCurrentPage > totalPages) previewCurrentPage = totalPages;
  if (previewCurrentPage < 1) previewCurrentPage = 1;

  if (lblCounter) {
    lblCounter.innerText = currentLang === 'si' 
      ? `පිටුව ${previewCurrentPage} / ${totalPages}`
      : `Page ${previewCurrentPage} of ${totalPages}`;
  }

  if (lblDocInfo) {
    const isColor = item.colorMode === 'color';
    const colorStr = currentLang === 'si' ? (isColor ? 'පාටින්' : 'කළු සුදු') : (isColor ? 'Color' : 'B&W');
    lblDocInfo.innerText = `${item.paperSize} • ${colorStr} • ${item.pages} ${item.pages === 1 ? 'pg' : 'pgs'}`;
  }

  // Dynamic high-fidelity simulated paper layout
  if (item.ext === 'PNG' || item.ext === 'JPG' || item.type === 'image') {
    simulatedPaper.innerHTML = `
      <div style="height:100%; display:flex; flex-direction:column; gap:8px;">
        <div style="display:flex; justify-content:space-between; font-size:10px; font-weight:700; color:#0b57d0; border-bottom:1px solid #ddd; padding-bottom:4px;">
          <span>${item.name}</span><span>${item.paperSize}</span>
        </div>
        <div style="flex:1; background:#e8ecf4; border-radius:4px; border:1px dashed #b0c4de; display:flex; align-items:center; justify-content:center; color:#0b57d0;">
          <span class="material-symbols-rounded" style="font-size:48px;">image</span>
        </div>
        <div style="font-size:9px; color:#777; text-align:center;">300 DPI High-Resolution Image Preview</div>
      </div>
    `;
  } else if (item.name.includes("sinhala")) {
    simulatedPaper.innerHTML = `
      <div style="height:100%; display:flex; flex-direction:column; font-family:'Noto Sans Sinhala', sans-serif;">
        <div style="border-bottom:2px solid #0b57d0; padding-bottom:6px; margin-bottom:10px; display:flex; justify-content:space-between; align-items:center;">
          <strong style="font-size:11px; color:#0b57d0;">ශ්‍රී ලංකා මුද්‍රණ සහායක</strong>
          <span style="font-size:9px; color:#666;">2026-10-27</span>
        </div>
        <h4 style="font-size:11.5px; margin-bottom:6px; color:#111;">ලේඛන පරීක්ෂණ වාර්තාව (Sinhala Orthography)</h4>
        <p style="font-size:9.5px; line-height:1.5; color:#333; margin-bottom:8px;">
          මෙම ලේඛනය සාමාන්‍ය කතාබස් කරන ශ්‍රී ලාංකීය සිංහල වචන (ප්‍රින්ටර්, ෆයිල්, කඩදාසි, කොපි) සහ යතුරුලියන ප්‍රමිතීන් නිවැරදිව පරීක්ෂා කිරීමට සකස් කර ඇත.
        </p>
        <div style="border:1px solid #e0e0e0; border-radius:3px; padding:6px; font-size:9px; background:#fafafa; margin-bottom:8px;">
          <div>• කඩදාසි ප්‍රමාණය: A4 Standard</div>
          <div>• මුද්‍රණ පැත්ත: දෙපැත්තෙන්ම (පොතක් වගේ)</div>
          <div>• තත්ත්වය: සම්පූර්ණයෙන්ම සූදානම්</div>
        </div>
        <div style="margin-top:auto; border-top:1px solid #eee; padding-top:6px; display:flex; justify-content:space-between; font-size:8.5px; color:#888;">
          <span>Print Helper Engine • 100% Offline</span>
          <span>පිටුව ${previewCurrentPage} / ${totalPages}</span>
        </div>
      </div>
    `;
  } else {
    simulatedPaper.innerHTML = `
      <div style="height:100%; display:flex; flex-direction:column;">
        <div style="border-bottom:2px solid #333; padding-bottom:6px; margin-bottom:10px; display:flex; justify-content:space-between;">
          <strong style="font-size:11px; text-transform:uppercase;">${item.name.replace(/\.[^/.]+$/, "")}</strong>
          <span style="font-size:9px; color:#777;">Page ${previewCurrentPage}/${totalPages}</span>
        </div>
        <div style="display:flex; flex-direction:column; gap:5px; margin-bottom:12px;">
          <div style="height:5px; background:#0b57d0; width:65%; border-radius:2px;"></div>
          <div style="height:4px; background:#ddd; width:95%; border-radius:2px;"></div>
          <div style="height:4px; background:#ddd; width:88%; border-radius:2px;"></div>
          <div style="height:4px; background:#ddd; width:92%; border-radius:2px;"></div>
        </div>
        <div style="display:flex; flex-direction:column; gap:5px; margin-bottom:12px;">
          <div style="height:4px; background:#ddd; width:100%; border-radius:2px;"></div>
          <div style="height:4px; background:#ddd; width:75%; border-radius:2px;"></div>
        </div>
        <div style="margin-top:auto; font-size:8.5px; color:#999; border-top:1px solid #eee; padding-top:4px; display:flex; justify-content:space-between;">
          <span>Print Helper Offline Imposition</span>
          <span>Sheet ${previewCurrentPage}</span>
        </div>
      </div>
    `;
  }
}

function updateRightPanelSettings() {
  const item = queue[selectedQueueIndex] || queue[0];
  if (!item) return;

  const lblCopiesVal = document.getElementById("lblCopiesValue");
  if (lblCopiesVal) lblCopiesVal.innerText = item.copies;

  const btnColor = document.getElementById("btnColorColor");
  const btnBw = document.getElementById("btnColorBw");
  if (btnColor && btnBw) {
    btnColor.classList.toggle("active", item.colorMode === 'color');
    btnBw.classList.toggle("active", item.colorMode === 'bw');
  }

  const selSides = document.getElementById("selSides");
  if (selSides) {
    selSides.value = item.duplex === 'one-sided' ? 'single' : (item.duplex === 'two-sided-short' ? 'double-short' : 'double-long');
  }
}

// --- THREE-TIER SETTINGS & CAPABILITY DISCOVERY DATABASE ---
let activeTier = localStorage.getItem("print_settings_tier") || "basic";
let onlyChangedFilterActive = false;

const printerProfilesDb = {
  "epson_l3250": {
    name: "Epson EcoTank L3250 Series",
    family: "Epson EcoTank L & ET Consumer Series",
    trait: "EcoTank",
    supplyTech: "Continuous Ink Tank",
    colorLayout: "CMYK Dye (003 Bottles)",
    hasDigitalInk: false,
    autoDuplex: false,
    borderless: true,
    borderlessMaxSize: "A4",
    opticalDpi: "5760x1440 DPI",
    paperSizes: ["A4", "Letter", "Legal", "A5", "A6", "Photo 4x6", "5x7 in", "Envelope #10", "DL"],
    mediaTypes: ["Plain Paper", "Epson Matte", "Epson Premium Glossy", "Photo Paper Glossy", "Envelope"],
    trays: ["Rear Paper Feed Slot (100 sheets)"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["Driver Managed", "sRGB IEC61966-2.1", "Adobe RGB (1998)", "Epson Standard RGB"],
    provenance: [
      { feature: "Duplex", source: "Win32 DeviceCapabilities", confidence: "Heuristic (Manual Only)" },
      { feature: "Paper Sizes & Media", source: "epson_profiles.json", confidence: "Verified (ESC/P-R specs)" },
      { feature: "Supply Levels", source: "IPP / SNMP Telemetry", confidence: "Live Telemetry (-3 OK)" },
      { feature: "Print Schema", source: "prntvpt.dll", confidence: "High" }
    ]
  },
  "epson_wf4830": {
    name: "Epson WorkForce Pro WF-4830",
    family: "Epson WorkForce Pro & RIPS Series",
    trait: "WorkForce Pro",
    supplyTech: "High-Yield Cartridge",
    colorLayout: "CMYK DURABrite All-Pigment",
    hasDigitalInk: true,
    autoDuplex: true,
    borderless: true,
    borderlessMaxSize: "A3+",
    opticalDpi: "4800x2400 DPI",
    paperSizes: ["A4", "A3", "Letter", "Legal", "Executive", "Photo 4x6"],
    mediaTypes: ["Plain Paper", "Bright White", "Presentation Matte", "Thick Cardstock"],
    trays: ["Cassette 1 (Lower 250)", "Cassette 2 (Upper 250)", "Rear Bypass (80)"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["Driver Managed", "sRGB IEC61966-2.1", "Adobe RGB (1998)", "Epson Matte Heavyweight"],
    provenance: [
      { feature: "Hardware Duplex", source: "Win32 DeviceCapabilities", confidence: "High (Hardware Auto)" },
      { feature: "Toner & Ink Level", source: "SNMP Printer MIB (RFC 3805)", confidence: "High (Chip %)" },
      { feature: "Paper Sizes", source: "epson_profiles.json", confidence: "Verified" }
    ]
  },
  "epson_l8050": {
    name: "Epson EcoTank Photo L8050",
    family: "Epson EcoTank Photo 6-Color Series",
    trait: "Stylus Photo",
    supplyTech: "Continuous Ink Tank",
    colorLayout: "Photo 6-Color Dye (C, M, Y, K, LC, LM)",
    hasDigitalInk: false,
    autoDuplex: true,
    borderless: true,
    borderlessMaxSize: "A4",
    opticalDpi: "5760x1440 DPI",
    paperSizes: ["A4", "Letter", "Photo 4x6", "5x7 in", "8x10 in", "PVC Card (CR80)"],
    mediaTypes: ["Plain Paper", "Epson Premium Glossy", "Epson Ultra Glossy", "Velvet Fine Art", "PVC ID Card"],
    trays: ["Front Cassette 1 (100)", "Rear Specialty Path", "CD/DVD & PVC Card Tray"],
    cdDvd: true,
    rollPaper: false,
    iccProfiles: ["Driver Managed", "sRGB IEC61966-2.1", "Adobe RGB (1998)", "Epson Premium Glossy"],
    provenance: [
      { feature: "Direct CD/DVD", source: "Win32 DeviceCapabilities", confidence: "High (Tray Guide Sensor)" },
      { feature: "Color Channels", source: "epson_profiles.json", confidence: "Verified (6-Color)" },
      { feature: "Trays", source: "IPP / SNMP Telemetry", confidence: "Live Telemetry" }
    ]
  },
  "hp_m404dn": {
    name: "HP LaserJet Pro M404dn",
    family: "HP LaserJet Enterprise Mono Series",
    trait: "Laser Mono",
    supplyTech: "Toner Cartridge",
    colorLayout: "Monochrome Laser",
    hasDigitalInk: true,
    autoDuplex: true,
    borderless: false,
    borderlessMaxSize: "None",
    opticalDpi: "1200x1200 DPI",
    paperSizes: ["A4", "Letter", "Legal", "A5", "Executive"],
    mediaTypes: ["Plain Paper", "Recycled Paper", "Labels", "Envelope"],
    trays: ["Tray 1 (Multipurpose 100)", "Tray 2 (250 sheets)"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["Driver Managed", "sRGB IEC61966-2.1"],
    provenance: [
      { feature: "Duplex", source: "Win32 DeviceCapabilities", confidence: "High (Hardware Auto)" },
      { feature: "Toner Level", source: "SNMP RFC 3805", confidence: "High (84%)" },
      { feature: "Paper Sizes", source: "IPP Everywhere", confidence: "High" }
    ]
  },
  "canon_mf445dw": {
    name: "Canon imageCLASS MF445dw",
    family: "Canon Color ImageClass Series",
    trait: "Color Laser",
    supplyTech: "All-in-One Toner",
    colorLayout: "CMYK Laser",
    hasDigitalInk: true,
    autoDuplex: true,
    borderless: false,
    borderlessMaxSize: "None",
    opticalDpi: "1200x1200 DPI",
    paperSizes: ["A4", "Letter", "Legal", "A5"],
    mediaTypes: ["Plain Paper", "Heavy Paper", "Recycled", "Envelope"],
    trays: ["Cassette 1 (250)", "Bypass Tray (50)"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["Driver Managed", "sRGB IEC61966-2.1"],
    provenance: [
      { feature: "Duplex", source: "Win32 DeviceCapabilities", confidence: "High (Hardware Auto)" },
      { feature: "Toner Levels", source: "SNMP RFC 3805", confidence: "High (65%)" }
    ]
  },
  "brother_hl": {
    name: "Brother HL-L2350DW",
    family: "Brother Compact Mono Laser",
    trait: "Laser Mono",
    supplyTech: "Toner & Drum",
    colorLayout: "Monochrome",
    hasDigitalInk: true,
    autoDuplex: true,
    borderless: false,
    borderlessMaxSize: "None",
    opticalDpi: "2400x600 DPI",
    paperSizes: ["A4", "Letter", "Legal"],
    mediaTypes: ["Plain Paper", "Thin Paper", "Recycled"],
    trays: ["Standard Paper Tray (250)"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["Driver Managed"],
    provenance: [
      { feature: "Duplex", source: "Win32 DeviceCapabilities", confidence: "High" }
    ]
  },
  "pdf_virtual": {
    name: "Microsoft Print to PDF",
    family: "Virtual PDF Spooler",
    trait: "Virtual",
    supplyTech: "Digital Vector",
    colorLayout: "Full RGB / CMYK Vector",
    hasDigitalInk: true,
    autoDuplex: true,
    borderless: true,
    borderlessMaxSize: "A3+",
    opticalDpi: "600x600 DPI",
    paperSizes: ["A4", "Letter", "Legal", "A3", "A5"],
    mediaTypes: ["Standard Digital Page"],
    trays: ["Virtual Spool Buffer"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["sRGB IEC61966-2.1"],
    provenance: [
      { feature: "Spooler", source: "Windows GDI / XPS Print Ticket", confidence: "High" }
    ]
  }
};

function initThreeTierPrintSettings() {
  // Tier Buttons
  const btnBasic = document.getElementById("btnTierBasic");
  const btnStandard = document.getElementById("btnTierStandard");
  const btnPro = document.getElementById("btnTierPro");

  if (btnBasic && btnStandard && btnPro) {
    btnBasic.addEventListener("click", () => switchSettingsTier("basic"));
    btnStandard.addEventListener("click", () => switchSettingsTier("standard"));
    btnPro.addEventListener("click", () => switchSettingsTier("professional"));
  }

  // Restore saved tier
  switchSettingsTier(activeTier);

  // Search Input
  const txtSearch = document.getElementById("txtSettingsSearch");
  if (txtSearch) {
    txtSearch.addEventListener("input", (e) => {
      filterSettingsBySearch(e.target.value.toLowerCase().trim());
    });
  }

  // "Only Changed" Filter Toggle
  const btnOnlyChanged = document.getElementById("btnToggleOnlyChanged");
  if (btnOnlyChanged) {
    btnOnlyChanged.addEventListener("click", () => {
      onlyChangedFilterActive = !onlyChangedFilterActive;
      btnOnlyChanged.classList.toggle("active", onlyChangedFilterActive);
      applyOnlyChangedFilter();
    });
  }

  // Open Abilities Modal
  const btnAbilities = document.getElementById("btnOpenAbilities");
  if (btnAbilities) {
    btnAbilities.addEventListener("click", () => {
      openPrinterAbilitiesModal(selectedPrinterId);
    });
  }

  // Close Abilities Modal
  const btnCloseAb = document.getElementById("btnCloseAbilitiesModal");
  const btnDoneAb = document.getElementById("btnDoneAbilitiesModal");
  const modalAb = document.getElementById("modalPrinterAbilities");
  if (btnCloseAb && modalAb) {
    btnCloseAb.addEventListener("click", () => modalAb.classList.add("hidden"));
  }
  if (btnDoneAb && modalAb) {
    btnDoneAb.addEventListener("click", () => modalAb.classList.add("hidden"));
  }

  // Driver Preferences Capture Button
  const btnCapturePrefs = document.getElementById("btnCaptureDriverPrefs");
  if (btnCapturePrefs) {
    btnCapturePrefs.addEventListener("click", () => {
      showToast(currentLang === 'si' ? "DocumentProperties() කවුළුව විවෘත වේ... DEVMODE සුරැකිණි!" : "DocumentProperties() invoked. Captured private DEVMODE preset!");
    });
  }

  // Copy Diagnostics
  const btnCopyDiag = document.getElementById("btnCopyAbilitiesDiag");
  if (btnCopyDiag) {
    btnCopyDiag.addEventListener("click", () => {
      const p = printerProfilesDb[selectedPrinterId] || printerProfilesDb["epson_l3250"];
      const text = `Printer: ${p.name}\nFamily: ${p.family}\nDuplex: ${p.autoDuplex ? 'Auto' : 'Manual'}\nBorderless: ${p.borderless}\nSizes: ${p.paperSizes.join(', ')}`;
      if (navigator.clipboard) navigator.clipboard.writeText(text);
      showToast(currentLang === 'si' ? "විස්තර පිටපත් විය!" : "Diagnostics copied to clipboard!");
    });
  }

  // Bleed slider
  const rangeBleed = document.getElementById("rangeBleed");
  const lblBleed = document.getElementById("lblBleedStep");
  if (rangeBleed && lblBleed) {
    const steps = ["Min", "Mid", "Max", "Full"];
    rangeBleed.addEventListener("input", (e) => {
      lblBleed.innerText = steps[e.target.value] || "Mid";
    });
  }

  // Advanced B&W checkbox toggle
  const chkAdvBw = document.getElementById("chkAdvBw");
  const selBwTone = document.getElementById("selBwTone");
  if (chkAdvBw && selBwTone) {
    chkAdvBw.addEventListener("change", (e) => {
      selBwTone.disabled = !e.target.checked;
      updateLiveSummary();
    });
  }

  // Passport photo checkbox toggle
  const chkPass = document.getElementById("chkPassportId");
  const selPass = document.getElementById("selPassportPreset");
  if (chkPass && selPass) {
    chkPass.addEventListener("change", (e) => {
      selPass.disabled = !e.target.checked;
      updateLiveSummary();
    });
  }

  // Color Mgmt change (show/hide ICC dropdown)
  const selColorMgmt = document.getElementById("selColorMgmtMode");
  const rowIcc = document.getElementById("rowIccProfile");
  if (selColorMgmt && rowIcc) {
    selColorMgmt.addEventListener("change", (e) => {
      rowIcc.classList.toggle("hidden", e.target.value !== "app");
    });
  }

  // Listen to inputs for Live Summary & Dependency Validation
  const watchedIds = [
    "selPaperSize", "selPaperType", "selSides", "chkBorderless",
    "selQuality", "selPagesPerSheet", "selStampOverlay"
  ];
  watchedIds.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener("change", () => {
        updateLiveSummary();
        validateDependenciesAndAutoFixes();
      });
    }
  });

  // Copies Stepper
  const btnMinus = document.getElementById("btnCopiesMinus");
  const btnPlus = document.getElementById("btnCopiesPlus");
  const lblCopies = document.getElementById("lblCopiesValue");
  if (btnMinus && btnPlus && lblCopies) {
    btnMinus.addEventListener("click", () => {
      let val = parseInt(lblCopies.innerText, 10) || 1;
      if (val > 1) {
        lblCopies.innerText = val - 1;
        updateLiveSummary();
      }
    });
    btnPlus.addEventListener("click", () => {
      let val = parseInt(lblCopies.innerText, 10) || 1;
      lblCopies.innerText = val + 1;
      updateLiveSummary();
    });
  }

  // Manual Duplex Assistant button in Sides row
  const btnDuplex = document.getElementById("btnOpenDuplexAssist");
  if (btnDuplex) {
    btnDuplex.addEventListener("click", () => {
      const mod = document.getElementById("manualDuplexModal");
      if (mod) mod.classList.remove("hidden");
    });
  }

  // Initial validation & summary
  updateLiveSummary();
  validateDependenciesAndAutoFixes();
}

function switchSettingsTier(tier) {
  activeTier = tier;
  localStorage.setItem("print_settings_tier", tier);

  const btnBasic = document.getElementById("btnTierBasic");
  const btnStandard = document.getElementById("btnTierStandard");
  const btnPro = document.getElementById("btnTierPro");

  if (btnBasic) btnBasic.classList.toggle("active", tier === "basic");
  if (btnStandard) btnStandard.classList.toggle("active", tier === "standard");
  if (btnPro) btnPro.classList.toggle("active", tier === "professional");

  const secStandard = document.getElementById("sectionStandardSettings");
  const secPro = document.getElementById("sectionProSettings");

  if (secStandard) {
    secStandard.classList.toggle("hidden", tier === "basic");
  }
  if (secPro) {
    secPro.classList.toggle("hidden", tier !== "professional");
  }

  updateLiveSummary();
}

function filterSettingsBySearch(query) {
  const items = document.querySelectorAll("#settingsScrollBody .setting-item");
  items.forEach(el => {
    if (!query) {
      el.style.display = "";
      return;
    }
    const keywords = (el.dataset.keywords || "").toLowerCase();
    const text = el.innerText.toLowerCase();
    const match = keywords.includes(query) || text.includes(query);
    el.style.display = match ? "" : "none";
  });
}

function applyOnlyChangedFilter() {
  const items = document.querySelectorAll("#settingsScrollBody .setting-item");
  if (!onlyChangedFilterActive) {
    items.forEach(el => el.style.display = "");
    return;
  }

  // Check which settings differ from defaults
  const copiesVal = parseInt(document.getElementById("lblCopiesValue")?.innerText || "1", 10);
  const sidesVal = document.getElementById("selSides")?.value || "single";
  const borderlessVal = document.getElementById("chkBorderless")?.checked || false;
  const paperTypeVal = document.getElementById("selPaperType")?.value || "Plain Paper";
  const qualityVal = document.getElementById("selQuality")?.value || "normal";
  const stampVal = document.getElementById("selStampOverlay")?.value || "none";

  items.forEach(el => {
    const kw = el.dataset.keywords || "";
    let isChanged = false;
    if (kw.includes("copies") && copiesVal > 1) isChanged = true;
    if (kw.includes("sides") && sidesVal !== "single") isChanged = true;
    if (kw.includes("borderless") && borderlessVal) isChanged = true;
    if (kw.includes("paper type") && paperTypeVal !== "Plain Paper") isChanged = true;
    if (kw.includes("quality") && qualityVal !== "normal") isChanged = true;
    if (kw.includes("stamp") && stampVal !== "none") isChanged = true;
    if (kw.includes("printer")) isChanged = true; // Always show printer selector

    el.style.display = isChanged ? "" : "none";
  });
}

function updateLiveSummary() {
  const lbl = document.getElementById("lblLiveSummaryText");
  if (!lbl) return;

  const isSi = currentLang === 'si';
  const paperSize = document.getElementById("selPaperSize")?.value || "A4";
  const paperType = document.getElementById("selPaperType")?.value || "Plain Paper";
  const isColor = document.getElementById("btnColorColor")?.classList.contains("active");
  const sides = document.getElementById("selSides")?.value || "single";
  const copies = document.getElementById("lblCopiesValue")?.innerText || "1";
  const isBorderless = document.getElementById("chkBorderless")?.checked || false;
  const stamp = document.getElementById("selStampOverlay")?.value || "none";

  const parts = [];
  parts.push(paperSize);

  // Paper type
  if (isSi) {
    if (paperType.includes("Plain")) parts.push("සාමාන්‍ය කඩදාසි");
    else if (paperType.includes("Glossy") || paperType.includes("Photo")) parts.push("ග්ලොසි ෆොටෝ කොළ");
    else if (paperType.includes("Matte")) parts.push("මැට් කඩදාසි");
    else parts.push(paperType);
  } else {
    parts.push(paperType);
  }

  // Color
  parts.push(isSi ? (isColor ? "පාටින්" : "කළු සුදු") : (isColor ? "Color" : "Black & White"));

  // Sides
  if (isSi) {
    parts.push(sides === "single" ? "තනි පැත්ත" : "දෙපැත්තෙන්ම");
  } else {
    parts.push(sides === "single" ? "Single-sided" : "Two-sided");
  }

  // Copies
  parts.push(isSi ? `කොපි ${copies}` : (copies === "1" ? "1 copy" : `${copies} copies`));

  if (isBorderless) {
    parts.push(isSi ? "දාර රහිත" : "Borderless");
  }

  if (activeTier === "professional" && stamp !== "none") {
    parts.push(isSi ? `මුද්‍රාව: ${stamp}` : `Stamp: ${stamp}`);
  }

  lbl.innerText = parts.join(", ");
}

function validateDependenciesAndAutoFixes() {
  const container = document.getElementById("validationAlertsBox");
  if (!container) return;

  const p = printerProfilesDb[selectedPrinterId] || printerProfilesDb["epson_l3250"];
  const paperType = document.getElementById("selPaperType")?.value || "Plain Paper";
  const sides = document.getElementById("selSides")?.value || "single";
  const isBorderless = document.getElementById("chkBorderless")?.checked || false;
  const isSi = currentLang === 'si';

  const alerts = [];

  // Conflict 1: Photo paper + duplex
  const isPhoto = paperType.includes("Glossy") || paperType.includes("Photo");
  if (isPhoto && sides !== "single") {
    alerts.push({
      blocking: false,
      title: isSi ? "ග්ලොසි ෆොටෝ කොළ සඳහා දෙපැත්තෙන්ම මුද්‍රණය කළ නොහැක" : "Glossy Photo Paper does not support 2-sided printing",
      sub: isSi ? "තීන්ත බොඳ වීම වැළැක්වීමට තනි පැත්ත තෝරන්න." : "Prevent ink smearing by printing single-sided.",
      fixLabel: isSi ? "තනි පැත්ත තෝරන්න" : "Switch to Single-Sided",
      action: () => {
        const selSides = document.getElementById("selSides");
        if (selSides) selSides.value = "single";
        updateLiveSummary();
        validateDependenciesAndAutoFixes();
      }
    });
  }

  // Conflict 2: Borderless unsupported on laser printers
  if (isBorderless && !p.borderless) {
    alerts.push({
      blocking: true,
      title: isSi ? "මෙම ප්‍රින්ටරයේ දාර රහිත (Borderless) පහසුකම නැත" : `${p.name} does not support borderless printing`,
      sub: isSi ? "ලේසර් ප්‍රින්ටර සඳහා 3mm හෝ 4mm මායිම් අවශ්‍ය වේ." : "Laser printers require at least 3-4mm hardware margins.",
      fixLabel: isSi ? "දාර රහිත ඉවත් කරන්න" : "Turn Off Borderless",
      action: () => {
        const chk = document.getElementById("chkBorderless");
        if (chk) chk.checked = false;
        updateLiveSummary();
        validateDependenciesAndAutoFixes();
      }
    });
  }

  // Conflict 3: Auto-duplex chosen on printer lacking auto-duplex hardware (e.g. Epson L3250)
  if (sides !== "single" && !p.autoDuplex) {
    alerts.push({
      blocking: false,
      title: isSi ? `${p.name} හි ස්වයංක්‍රීය දෙපැත්ත මුද්‍රණ දෘඪාංග නොමැත` : `${p.name} lacks hardware automatic duplex`,
      sub: isSi ? "Print Helper අත්පොත දෙපැත්ත සහායකය (Manual Duplex Assistant) භාවිතා කරන්න." : "Use Print Helper Manual Duplex Assistant to flip pages manually.",
      fixLabel: isSi ? "අත්පොත සහායකය අරින්න" : "Open Duplex Assistant",
      action: () => {
        const mod = document.getElementById("manualDuplexModal");
        if (mod) mod.classList.remove("hidden");
      }
    });
  }

  if (alerts.length === 0) {
    container.classList.add("hidden");
    container.innerHTML = "";
    return;
  }

  container.classList.remove("hidden");
  container.innerHTML = alerts.map((al, idx) => `
    <div class="validation-alert-item ${al.blocking ? 'blocking' : ''}">
      <div class="alert-title-row">
        <span class="material-symbols-rounded" style="font-size:16px;">${al.blocking ? 'error' : 'warning'}</span>
        <span>${al.title}</span>
      </div>
      <div style="font-size:11px; color:#555;">${al.sub}</div>
      <button class="alert-fix-btn" data-fix-idx="${idx}">
        <span class="material-symbols-rounded" style="font-size:13px;">auto_fix_high</span>
        <span>${al.fixLabel}</span>
      </button>
    </div>
  `).join('');

  container.querySelectorAll(".alert-fix-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const idx = parseInt(btn.dataset.fixIdx, 10);
      if (alerts[idx] && alerts[idx].action) {
        alerts[idx].action();
      }
    });
  });
}

function triggerHotPlugToast(printerName) {
  const toast = document.getElementById("hotPlugToast");
  const msg = document.getElementById("hotPlugToastMsg");
  if (!toast || !msg) return;

  const isSi = currentLang === 'si';
  msg.innerText = isSi
    ? `${printerName} සම්බන්ධ විය. ප්‍රින්ටර් හැකියාවන් කියවමින්...`
    : `${printerName} connected. Reading printer features...`;

  toast.classList.remove("hidden");
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => {
    toast.classList.add("hidden");
  }, 3500);
}

function openPrinterAbilitiesModal(printerId) {
  const p = printerProfilesDb[printerId] || printerProfilesDb["epson_l3250"];
  const modal = document.getElementById("modalPrinterAbilities");
  if (!modal) return;

  const isSi = currentLang === 'si';

  const titleEl = document.getElementById("abilitiesModalTitle");
  if (titleEl) {
    titleEl.innerText = isSi ? `${p.name} හැකියාවන්` : `${p.name} Abilities & Features`;
  }

  const subEl = document.getElementById("abilitiesModalSubtitle");
  if (subEl) {
    subEl.innerText = `${p.family} • ${isSi ? "තහවුරු කළ දෘඪාංග පැතිකඩ" : "Verified Hardware Profile"}`;
  }

  const techPills = document.getElementById("abilitiesTechPills");
  if (techPills) {
    techPills.innerHTML = `
      <span class="pill-badge accent">${p.supplyTech}</span>
      <span class="pill-badge muted">${p.colorLayout}</span>
      <span class="pill-badge ${p.hasDigitalInk ? 'teal' : 'warning'}">${p.hasDigitalInk ? (isSi ? 'ඩිජිටල් තීන්ත මට්ටම (%)' : 'Digital Percentage (%)') : (isSi ? 'දෘශ්‍ය ඇස්තමේන්තුව' : 'Visual / Estimated Levels')}</span>
    `;
  }

  const paperSizesEl = document.getElementById("abilitiesPaperSizes");
  if (paperSizesEl) {
    paperSizesEl.innerHTML = `<strong>${isSi ? 'ප්‍රමාණ' : 'Sizes'}:</strong> ${p.paperSizes.join(', ')}`;
  }

  const mediaTypesEl = document.getElementById("abilitiesMediaTypes");
  if (mediaTypesEl) {
    mediaTypesEl.innerHTML = `<strong>${isSi ? 'මාධ්‍ය වර්ග' : 'Media'}:</strong> ${p.mediaTypes.join(', ')}`;
  }

  const traysEl = document.getElementById("abilitiesTrays");
  if (traysEl) {
    traysEl.innerHTML = `<strong>${isSi ? 'තැටි' : 'Trays'}:</strong> ${p.trays.join(', ')}`;
  }

  const featurePills = document.getElementById("abilitiesFeaturePills");
  if (featurePills) {
    featurePills.innerHTML = `
      <span class="pill-badge ${p.autoDuplex ? 'teal' : 'warning'}">${p.autoDuplex ? (isSi ? 'ස්වයංක්‍රීය දෙපැත්ත (Auto-Duplex)' : 'Hardware Auto-Duplex') : (isSi ? 'අත්පොත දෙපැත්ත සහායකය' : 'Manual Duplex Assistant Only')}</span>
      <span class="pill-badge ${p.borderless ? 'accent' : 'muted'}">${p.borderless ? (isSi ? `දාර රහිත (${p.borderlessMaxSize})` : `Borderless (${p.borderlessMaxSize})`) : (isSi ? 'දාර රහිත නැත' : 'No Borderless')}</span>
      ${p.cdDvd ? `<span class="pill-badge teal">${isSi ? 'CD/DVD තැටි මුද්‍රණය' : 'Direct CD/DVD Print'}</span>` : ''}
      <span class="pill-badge muted">Max ${p.opticalDpi}</span>
    `;
  }

  const provList = document.getElementById("abilitiesProvenanceList");
  if (provList && p.provenance) {
    provList.innerHTML = p.provenance.map(item => `
      <div>• <strong>${item.feature}:</strong> ${item.source} (${item.confidence})</div>
    `).join('');
  }

  modal.classList.remove("hidden");
}


function setupCommandPalette() {
  document.getElementById("btnOpenCommandPalette").addEventListener("click", openCommandPalette);

  window.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      openCommandPalette();
    }
    if (e.key === "F1") { e.preventDefault(); switchTab("shop"); document.querySelector('[data-shop-view="counter"]').click(); }
    if (e.key === "F2") { e.preventDefault(); switchTab("shop"); document.querySelector('[data-shop-view="customers"]').click(); }
    if (e.key === "F3") { e.preventDefault(); switchTab("shop"); document.querySelector('[data-shop-view="fleet"]').click(); }
    if (e.key === "F4") { e.preventDefault(); switchTab("shop"); document.querySelector('[data-shop-view="pricing"]').click(); }
    if (e.key === "Escape") {
      cmdModal.classList.add("hidden");
      livePreviewModal.classList.add("hidden");
      drawSigModal.classList.add("hidden");
      manualDuplexModal.classList.add("hidden");
      receiptModal.classList.add("hidden");
      epsonDiagModal.classList.add("hidden");
    }
  });

  cmdInput.addEventListener("input", (e) => {
    renderCommandResults(e.target.value.toLowerCase().trim());
  });
}

function openCommandPalette() {
  cmdModal.classList.remove("hidden");
  cmdInput.value = "";
  renderCommandResults("");
  setTimeout(() => cmdInput.focus(), 50);
}

function renderCommandResults(query) {
  cmdResults.innerHTML = "";
  const filtered = commands.filter(c => 
    !query || c.title.toLowerCase().includes(query) || c.sub.toLowerCase().includes(query)
  );

  filtered.forEach(c => {
    const div = document.createElement("div");
    div.className = "cmd-item";
    div.innerHTML = `
      <span class="material-symbols-rounded">${c.icon}</span>
      <div class="cmd-item-info">
        <strong>${c.title}</strong>
        <span>${c.sub}</span>
      </div>
    `;
    div.addEventListener("click", () => {
      cmdModal.classList.add("hidden");
      if (c.action === 'loadSample') {
        loadSampleBatch();
      } else if (c.action === 'openPreview') {
        livePreviewModal.classList.remove("hidden");
      } else if (c.action === 'openDuplex') {
        manualDuplexModal.classList.remove("hidden");
      } else if (c.action === 'openReceipt') {
        receiptModal.classList.remove("hidden");
      } else if (c.action === 'openEpson') {
        epsonDiagModal.classList.remove("hidden");
      } else if (c.tab) {
        switchTab(c.tab);
        if (c.subview) {
          const pill = document.querySelector(`.pill-btn[data-subview="${c.subview}"], .pill-btn[data-shop-view="${c.subview}"]`);
          if (pill) pill.click();
        }
      }
    });
    cmdResults.appendChild(div);
  });
}

function setupSignaturePad() {
  const canvas = document.getElementById("sigPadCanvas");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  let drawing = false;

  ctx.lineWidth = 2.5;
  ctx.strokeStyle = "#042e6f";
  ctx.lineCap = "round";

  canvas.addEventListener("mousedown", (e) => {
    drawing = true;
    ctx.beginPath();
    ctx.moveTo(e.offsetX, e.offsetY);
  });

  canvas.addEventListener("mousemove", (e) => {
    if (!drawing) return;
    ctx.lineTo(e.offsetX, e.offsetY);
    ctx.stroke();
  });

  window.addEventListener("mouseup", () => drawing = false);

  const btnClr = document.getElementById("btnClearSigPad");
  if (btnClr) {
    btnClr.addEventListener("click", () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    });
  }

  const btnSaveSig = document.getElementById("btnSaveSigPad");
  if (btnSaveSig) {
    btnSaveSig.addEventListener("click", () => {
      const previewCanvas = document.getElementById("drawnSignaturePreview");
      const pCtx = previewCanvas.getContext("2d");
      previewCanvas.style.display = "block";
      document.getElementById("sigPlaceholder").style.display = "none";
      pCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
      pCtx.drawImage(canvas, 0, 0, 300, 90);
      drawSigModal.classList.add("hidden");
      showToast("✍️ Signature placed on document!");
    });
  }
}

function renderOrganizerPages() {
  const container = document.getElementById("pagesGridOrganizer");
  if (!container) return;
  container.innerHTML = "";

  organizedPages.forEach(p => {
    const tile = document.createElement("div");
    tile.className = "page-tile" + (p.selected ? " selected" : "");
    tile.innerHTML = `
      <div class="page-tile-paper" style="transform: rotate(${p.rotated}deg);">
        <div class="mline title" style="height:4px; margin-bottom:4px;"></div>
        <div class="mline" style="margin-bottom:3px;"></div>
        <div class="mline" style="margin-bottom:3px;"></div>
        <div class="mline short"></div>
      </div>
      <div class="page-tile-footer">
        <span>${p.label}</span>
        <span>${p.rotated}°</span>
      </div>
    `;
    tile.addEventListener("click", () => {
      p.selected = !p.selected;
      renderOrganizerPages();
    });
    container.appendChild(tile);
  });
}

function loadSampleBatch() {
  queue = JSON.parse(JSON.stringify(sampleBatch));
  selectedQueueIndex = 0;
  previewCurrentPage = 1;
  updateQueueUI();
  updatePreviewCanvas();
  updateRightPanelSettings();
  showToast(currentLang === 'si' ? "✨ සාම්පල ෆයිල් ප්‍රින්ට් පෝලිමට එක් කරන ලදී!" : "✨ Sample batch loaded into print queue!");
}

function handleFileSelect(e) {
  if (e.target.files && e.target.files.length > 0) {
    addRealFiles(e.target.files);
    e.target.value = "";
  }
}

function addRealFiles(files) {
  for (let i = 0; i < files.length; i++) {
    const f = files[i];
    const ext = f.name.split('.').pop().toUpperCase();
    const isPdf = ext === 'PDF';
    const isTxt = ext === 'TXT' || ext === 'MD';
    const isImg = ['PNG', 'JPG', 'JPEG', 'WEBP', 'BMP'].includes(ext);

    let docType = 'text';
    if (isPdf) docType = 'pdf';
    else if (isImg) docType = 'image';

    let estPages = 1;
    if (isPdf) estPages = Math.max(1, Math.min(60, Math.round(f.size / 150000) || 3));
    else if (isTxt) estPages = Math.max(1, Math.round(f.size / 4000) || 1);

    queue.push({
      id: "file_" + Date.now() + "_" + i,
      name: f.name,
      ext: ext,
      sizeStr: formatBytes(f.size),
      pages: estPages,
      type: docType,
      copies: 1,
      colorMode: isPdf || isImg ? "color" : "bw",
      duplex: estPages > 1 ? "two-sided" : "one-sided",
      orientation: "portrait",
      paperSize: "A4",
      tray: "Auto",
      expanded: false
    });
  }

  selectedQueueIndex = queue.length - 1;
  previewCurrentPage = 1;
  switchTab("print");
  updateQueueUI();
  updatePreviewCanvas();
  updateRightPanelSettings();
  showToast(currentLang === 'si' ? `ෆයිල් ${files.length} ක් එක් කරන ලදී` : `Added ${files.length} file(s) to queue`);
}

function pasteFromClipboard() {
  queue.push({
    id: "clip_" + Date.now(),
    name: "Clipboard_Snippet_" + new Date().toLocaleTimeString().replace(/:/g, '-') + ".txt",
    ext: "TXT",
    sizeStr: "4.2 KB",
    pages: 1,
    type: "text",
    copies: 1,
    colorMode: "bw",
    duplex: "one-sided",
    orientation: "portrait",
    paperSize: "A4",
    tray: "Auto",
    expanded: false
  });
  selectedQueueIndex = queue.length - 1;
  previewCurrentPage = 1;
  updateQueueUI();
  updatePreviewCanvas();
  updateRightPanelSettings();
  showToast(currentLang === 'si' ? "📋 පේස්ට් කරන ලද ෆයිල් එකතු විය" : "📋 Pasted text from clipboard into queue");
}

function updateQueueUI() {
  const hasFiles = queue.length > 0;
  const t = strings[currentLang] || strings.en;

  if (railBadge) {
    railBadge.innerText = queue.length;
    railBadge.classList.toggle("hidden", !hasFiles);
  }

  const totalPages = queue.reduce((sum, item) => sum + (item.pages * item.copies), 0);

  const lblCount = document.getElementById("lblQueueCount");
  if (lblCount) {
    lblCount.innerText = currentLang === 'si' 
      ? (hasFiles ? `${queue.length} ෆයිල්` : 'ෆයිල් නැත')
      : (hasFiles ? `${queue.length} file${queue.length > 1 ? 's' : ''}` : '0 files');
  }

  const lblToggleDrawer = document.getElementById("lblToggleQueueDrawer");
  if (lblToggleDrawer) {
    lblToggleDrawer.innerText = currentLang === 'si' ? `ෆයිල් (${queue.length})` : `Files (${queue.length})`;
  }

  const lblRespPages = document.getElementById("lblResponsiveTotalPages");
  if (lblRespPages) {
    lblRespPages.innerText = currentLang === 'si' ? `පිටු ${totalPages}` : `${totalPages} pages`;
  }

  if (queueSummaryText) {
    queueSummaryText.innerText = currentLang === 'si' ? `පිටු ${totalPages}` : `${totalPages} pages`;
  }

  const emptyMsg = document.getElementById("emptyQueueMsg");
  if (emptyMsg) emptyMsg.classList.toggle("hidden", hasFiles);

  const btnRightPrint = document.getElementById("btnRightPrint");
  if (btnRightPrint) {
    btnRightPrint.disabled = !hasFiles;
    btnRightPrint.innerHTML = `<span class="material-symbols-rounded">print</span> <span>${t.printAction} (${totalPages} ${t.pages})</span>`;
  }

  if (hasFiles) {
    renderQueueCards();
    updatePreviewCanvas();
    updateRightPanelSettings();
  } else {
    cardsList.innerHTML = "";
    updatePreviewCanvas();
  }
}

function renderQueueCards() {
  cardsList.innerHTML = "";
  const t = strings[currentLang];

  queue.forEach((item, index) => {
    const card = document.createElement("div");
    card.className = "queue-card" + (index === selectedQueueIndex ? " selected-card" : "");
    card.dataset.id = item.id;
    card.dataset.index = index;

    const thumbClass = item.type === 'pdf' ? 'is-pdf' : (item.type === 'image' ? 'is-img' : 'is-txt');
    const thumbIcon = item.type === 'pdf' ? 'picture_as_pdf' : (item.type === 'image' ? 'image' : 'article');

    card.innerHTML = `
      <div class="card-main-row">
        <span class="material-symbols-rounded drag-handle" title="Drag to reorder">drag_indicator</span>
        <div class="doc-thumb ${thumbClass}">
          <span class="material-symbols-rounded">${thumbIcon}</span>
        </div>
        <div class="doc-info">
          <div class="doc-name" title="${item.name}">${item.name}</div>
          <div class="doc-meta">
            <span class="meta-pill type-pdf">${item.ext}</span>
            <span class="meta-pill">${item.pages} ${item.pages === 1 ? t.page : t.pages}</span>
            <span class="meta-pill">${item.sizeStr}</span>
          </div>
        </div>

        <div class="card-controls">
          <div class="stepper" title="Copies">
            <button class="btn-step-minus" data-id="${item.id}">-</button>
            <span class="stepper-value">${item.copies}</span>
            <button class="btn-step-plus" data-id="${item.id}">+</button>
          </div>

          <div class="segmented-toggle">
            <button class="seg-btn ${item.colorMode === 'bw' ? 'active' : ''}" data-action="set-bw" data-id="${item.id}">${t.bwOption || 'B&W'}</button>
            <button class="seg-btn ${item.colorMode === 'color' ? 'active' : ''}" data-action="set-color" data-id="${item.id}">${t.colorOption || 'Color'}</button>
          </div>

          <button class="card-remove-btn" data-id="${item.id}" title="Remove file">
            <span class="material-symbols-rounded">close</span>
          </button>
        </div>
      </div>
    `;

    // Click card to select & preview
    card.addEventListener("click", (e) => {
      if (e.target.closest("button")) return;
      selectedQueueIndex = index;
      previewCurrentPage = 1;
      document.querySelectorAll(".queue-card").forEach(c => c.classList.remove("selected-card"));
      card.classList.add("selected-card");
      updatePreviewCanvas();
      updateRightPanelSettings();
    });

    cardsList.appendChild(card);
  });

  cardsList.querySelectorAll(".btn-step-plus").forEach(b => {
    b.addEventListener("click", (e) => {
      const item = queue.find(q => q.id === e.target.dataset.id);
      if (item) { item.copies++; updateQueueUI(); }
    });
  });

  cardsList.querySelectorAll(".btn-step-minus").forEach(b => {
    b.addEventListener("click", (e) => {
      const item = queue.find(q => q.id === e.target.dataset.id);
      if (item && item.copies > 1) { item.copies--; updateQueueUI(); }
    });
  });

  cardsList.querySelectorAll('[data-action="set-bw"]').forEach(b => {
    b.addEventListener("click", (e) => {
      const item = queue.find(q => q.id === e.target.dataset.id);
      if (item) { item.colorMode = 'bw'; updateQueueUI(); }
    });
  });

  cardsList.querySelectorAll('[data-action="set-color"]').forEach(b => {
    b.addEventListener("click", (e) => {
      const item = queue.find(q => q.id === e.target.dataset.id);
      if (item) { item.colorMode = 'color'; updateQueueUI(); }
    });
  });

  cardsList.querySelectorAll(".card-remove-btn").forEach(b => {
    b.addEventListener("click", (e) => {
      const id = b.dataset.id;
      queue = queue.filter(q => q.id !== id);
      if (selectedQueueIndex >= queue.length) selectedQueueIndex = Math.max(0, queue.length - 1);
      updateQueueUI();
    });
  });
}

function renderPrinterDropdown() {
  if (!printerSelect) return;
  printerSelect.innerHTML = "";
  printers.forEach(p => {
    const opt = document.createElement("option");
    opt.value = p.id;
    opt.innerText = (p.isFavorite ? "⭐ " : "") + p.name;
    if (p.id === selectedPrinterId) opt.selected = true;
    printerSelect.appendChild(opt);
  });
}

function renderPrintersGrid() {
  const container = document.getElementById("printersGrid");
  if (!container) return;
  container.innerHTML = "";

  const filtered = printers.filter(p => {
    if (activeFilter === 'all') return true;
    if (activeFilter === 'favorites') return p.isFavorite;
    return p.type === activeFilter;
  });

  filtered.forEach(p => {
    const card = document.createElement("div");
    card.className = "printer-card";

    card.innerHTML = `
      <div class="printer-top">
        <div class="printer-name-col">
          <div class="printer-icon-wrap">
            <span class="material-symbols-rounded">print</span>
          </div>
          <div class="printer-headings">
            <h4>${p.name}</h4>
            <span>${p.location}</span>
          </div>
        </div>
        <button class="star-btn ${p.isFavorite ? 'active' : ''}" data-id="${p.id}" title="Toggle favorite">
          <span class="material-symbols-rounded">${p.isFavorite ? 'star' : 'star_border'}</span>
        </button>
      </div>

      <div class="printer-status-bar">
        <span class="printer-status-dot ${p.statusType}"></span>
        <span>${p.status}</span>
      </div>

      <div class="printer-tags">
        ${p.tags.map(t => `<span class="tag">${t}</span>`).join('')}
      </div>

      <div class="printer-actions">
        <button class="btn btn-tonal btn-sm btn-test-print" data-name="${p.name}">
          <span class="material-symbols-rounded">receipt_long</span>
          <span>Test Page</span>
        </button>
        <button class="btn btn-outline btn-sm btn-set-default" data-id="${p.id}">
          <span>${selectedPrinterId === p.id ? 'Selected' : 'Use as Target'}</span>
        </button>
      </div>
    `;

    container.appendChild(card);
  });

  container.querySelectorAll(".star-btn").forEach(b => {
    b.addEventListener("click", () => {
      const p = printers.find(x => x.id === b.dataset.id);
      if (p) {
        p.isFavorite = !p.isFavorite;
        renderPrinterDropdown();
        renderPrintersGrid();
      }
    });
  });

  container.querySelectorAll(".btn-test-print").forEach(b => {
    b.addEventListener("click", () => {
      showToast(`🖨️ Sent diagnostic test page to ${b.dataset.name}`);
    });
  });

  container.querySelectorAll(".btn-set-default").forEach(b => {
    b.addEventListener("click", () => {
      selectedPrinterId = b.dataset.id;
      renderPrinterDropdown();
      renderPrintersGrid();
      updateLivePrinterPanel();
      validateDependenciesAndAutoFixes();
      updateLiveSummary();
      showToast(`Selected "${printers.find(p=>p.id===selectedPrinterId).name}" as target printer`);
    });
  });
}

function renderJobsTable() {
  const tbody = document.getElementById("jobsTableBody");
  if (!tbody) return;
  tbody.innerHTML = "";

  if (jobs.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; padding:32px; color:var(--text-muted)">No active or historical print jobs recorded yet.</td></tr>`;
    return;
  }

  jobs.forEach(j => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${j.id}</strong></td>
      <td>${j.doc}</td>
      <td>${j.printer}</td>
      <td>${j.pages}</td>
      <td><span class="badge-active">${j.status}</span></td>
      <td>${j.time}</td>
      <td>
        <button class="btn-ghost btn-sm" onclick="showToast('Reprint requested for ${j.id}')">Reprint</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function handlePrintAction() {
  if (queue.length === 0) return;
  const p = printers.find(x => x.id === selectedPrinterId) || printers[0];
  const totalPages = queue.reduce((sum, item) => sum + (item.pages * item.copies), 0);

  const newJobId = "JOB-" + Math.floor(1000 + Math.random() * 9000);
  jobs.unshift({
    id: newJobId,
    doc: queue.length === 1 ? queue[0].name : `Batch (${queue.length} files)`,
    printer: p.name,
    pages: `${totalPages} page${totalPages > 1 ? 's' : ''}`,
    status: "Sent to Spooler",
    time: "Just now"
  });

  renderJobsTable();
  showToast(currentLang === 'si'
    ? `🚀 "${p.name}" වෙත ගොනු ${queue.length} ක් (පිටු ${totalPages}) යොමු කරන ලදී`
    : `🚀 Dispatched ${queue.length} file(s) (${totalPages} pages) to "${p.name}"`
  );

  const autoClear = document.getElementById("chkAutoClear");
  if (autoClear && autoClear.checked) {
    queue = [];
    selectedQueueIndex = 0;
    updateQueueUI();
  }
}

function applyPresetToQueue(preset) {
  if (queue.length === 0) {
    showToast("⚠️ Add files to the queue first or load the Sample Batch!");
    return;
  }

  queue.forEach(item => {
    if (preset === 'draft') {
      item.colorMode = 'bw';
      item.duplex = 'two-sided';
    } else if (preset === 'report') {
      item.colorMode = 'color';
      item.duplex = 'two-sided';
      item.paperSize = 'A4';
    } else if (preset === 'presentation') {
      item.colorMode = 'color';
      item.duplex = 'one-sided';
      item.tray = 'Tray 1';
    } else if (preset === 'labels') {
      item.colorMode = 'bw';
      item.duplex = 'one-sided';
      item.tray = 'Tray 2';
    }
  });

  updateQueueUI();
  switchTab("print");
  showToast(`Applied preset to all ${queue.length} document(s) in queue!`);
}

function toggleTheme() {
  setTheme(currentTheme === 'dark' ? 'light' : 'dark');
}

function setTheme(theme) {
  currentTheme = theme;
  document.documentElement.setAttribute("data-theme", theme);
  const icon = document.getElementById("themeIcon");
  if (icon) icon.innerText = theme === 'dark' ? 'light_mode' : 'dark_mode';
  const sel = document.getElementById("settingThemeSelect");
  if (sel) sel.value = theme;
}

function toggleLang() {
  currentLang = currentLang === 'en' ? 'si' : 'en';
  const lbl = document.getElementById("currentLangLabel");
  if (lbl) lbl.innerText = currentLang === 'en' ? 'සිංහල' : 'English';
  const sel = document.getElementById("settingLangSelect");
  if (sel) sel.value = currentLang;
  updateUIStrings();
  updateQueueUI();
}

function updateUIStrings() {
  const t = strings[currentLang];
  const setTxt = (id, txt) => {
    const el = document.getElementById(id);
    if (el) el.innerText = txt;
  };

  setTxt("lblAppTitle", t.appTitle);
  setTxt("lblOffline", t.offlineBadge);
  setTxt("lblNavPrint", t.navPrint);
  setTxt("lblNavPrinters", t.navPrinters);
  setTxt("lblNavJobs", t.navJobs);
  setTxt("lblNavTools", t.navTools);
  setTxt("lblNavShop", t.navShop);
  setTxt("lblNavSettings", t.navSettings);

  setTxt("lblDropZoneTitle", t.dropTitle);
  setTxt("dropHeadline", t.dropHeadline);
  setTxt("dropSub", t.dropOverlaySub);
  setTxt("lblQueueHeader", t.queueHeader);
  setTxt("lblBtnClearQueue", currentLang === 'si' ? "සියල්ල අයින් කරන්න" : "Clear All");
  setTxt("lblBtnAddTop", t.btnOpen);
  setTxt("lblResponsiveAdd", t.btnOpen);

  setTxt("lblPreviewHeader", t.previewHeader);
  setTxt("lblPrevPage", currentLang === 'si' ? "කලින් පිටුව" : "Previous");
  setTxt("lblNextPage", currentLang === 'si' ? "ඊළඟ පිටුව" : "Next");

  setTxt("lblPrintSettingsHeader", t.printSettings);
  setTxt("lblPrinterSelect", currentLang === 'si' ? "ප්‍රින්ටර් එක" : "Printer");
  setTxt("lblCopies", t.copies);
  setTxt("lblColor", t.color);
  setTxt("btnColorColor", t.colorOption);
  setTxt("btnColorBw", t.bwOption);
  setTxt("lblSides", t.sides);
  setTxt("lblPaperSize", t.paperSize);
  setTxt("lblAdvTitle", currentLang === 'si' ? "වැඩිදුර සැකසුම්" : "Advanced Settings");
  setTxt("lblBtnRightPrint", t.printAction);

  setTxt("currentLangLabel", currentLang === 'si' ? "English" : "සිංහල");
}

function showToast(msg) {
  toastEl.innerText = msg;
  toastEl.classList.remove("hidden");
  clearTimeout(toastEl._timer);
  toastEl._timer = setTimeout(() => {
    toastEl.classList.add("hidden");
  }, 3200);
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}
