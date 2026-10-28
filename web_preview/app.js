function escapeHtml(s) {
  return String(s || "").replace(/[&<>"']/g, c => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "\x27": "&#39;"
  }[c]));
}

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
    settings: "Settings",
    scanSubnet: "Scan Subnet",
    simulateRouting: "Simulate Job Routing",
    routingRules: "Routing Rules",
    fleetTotal: "Fleet Total",
    fleetReady: "Ready",
    fleetPrinting: "Printing",
    fleetOffline: "Offline",
    fleetLowSupply: "Low Supplies",
    lowSupplyThreshold: "Alert Threshold:"
  },
  si: {
    appTitle: "Print Helper",
    offlineBadge: "100% නොබැඳිව",
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
    settings: "සැකසුම්",
    scanSubnet: "උපජාල සොයන්න",
    simulateRouting: "මාර්ගගත කිරීම පරීක්ෂා කරන්න",
    routingRules: "මාර්ගගත කිරීමේ නීති",
    fleetTotal: "මුළු ප්‍රින්ටර්",
    fleetReady: "සූදානම්",
    fleetPrinting: "මුද්‍රණය වේ",
    fleetOffline: "ක්‍රියාවිරහිතයි",
    fleetLowSupply: "තීන්ත අඩුයි",
    lowSupplyThreshold: "අවම සීමාව:"
  }
};

let currentLang = 'en';
let currentTheme = 'dark';
let activeFilter = 'all';

// Active Queue & Preview state
let selectedQueueIndex = 0;
let previewCurrentPage = 1;
let previewZoom = 1.0;

// Tone & Ink Adjustment State (Prompt 10)
let toneAndInkState = {
  density: 0,
  brightness: 0,
  contrast: 0,
  gamma: 1.0,
  shadows: 0,
  highlights: 0,
  blackLevel: 0,
  textDarkness: 0,
  textSharpening: 0,
  photoSharpening: 0,
  saturation: 0,
  vibrance: 0,
  colorBalanceCyanRed: 0,
  colorBalanceMagentaGreen: 0,
  colorBalanceYellowBlue: 0,
  paperCompensation: "none",
  inkSaverEnabled: false,
  inkSaverLevel: "balanced",
  inkSaverTextOnlyBlack: true,
  compareWithOriginal: false,
  driverColorAdjustmentActive: false
};

function hasActiveToneAdjustments() {
  return (
    toneAndInkState.density !== 0 ||
    toneAndInkState.brightness !== 0 ||
    toneAndInkState.contrast !== 0 ||
    Math.abs(toneAndInkState.gamma - 1.0) > 0.01 ||
    toneAndInkState.shadows !== 0 ||
    toneAndInkState.highlights !== 0 ||
    toneAndInkState.blackLevel !== 0 ||
    toneAndInkState.textDarkness !== 0 ||
    toneAndInkState.textSharpening !== 0 ||
    toneAndInkState.photoSharpening !== 0 ||
    toneAndInkState.saturation !== 0 ||
    toneAndInkState.vibrance !== 0 ||
    toneAndInkState.colorBalanceCyanRed !== 0 ||
    toneAndInkState.colorBalanceMagentaGreen !== 0 ||
    toneAndInkState.colorBalanceYellowBlue !== 0 ||
    toneAndInkState.paperCompensation !== "none" ||
    toneAndInkState.inkSaverEnabled
  );
}

function getToneInkSaverSavingsPercent() {
  if (!toneAndInkState.inkSaverEnabled) return 0;
  let base = 28;
  if (toneAndInkState.inkSaverLevel === "light") base = 15;
  if (toneAndInkState.inkSaverLevel === "aggressive") base = 42;
  if (toneAndInkState.inkSaverTextOnlyBlack) base += 4;
  return Math.min(60, base);
}

// Mock Spooler Fleet Printers with Live PrinterIntelligence Telemetry
let printers = [
  {
    id: "epson_l3250",
    name: "Front Counter L3250",
    modelName: "Epson EcoTank L3250",
    location: "Counter USB Port #2",
    interfaceType: "usb",
    status: "Ready",
    statusType: "online",
    state: "ready",
    type: "usb",
    isDefault: true,
    isFavorite: true,
    activeQueueLength: 1,
    totalLifePagesCount: 14250,
    loadedPaperSummary: "Rear Tray: A4 Plain Paper (80 gsm)",
    specialtyBadges: ["Borderless 4x6", "Wi-Fi Direct", "EcoTank"],
    activeAlerts: [],
    inkChannels: [
      { name: "Black Ink (BK)", colorHex: "#1a1a1a", rawLevel: 75, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 75, isEstimate: true },
      { name: "Cyan Ink (C)", colorHex: "#0099ff", rawLevel: 60, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 60, isEstimate: true },
      { name: "Magenta Ink (M)", colorHex: "#e91e63", rawLevel: 45, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 45, isEstimate: true },
      { name: "Yellow Ink (Y)", colorHex: "#fdd835", rawLevel: 80, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 80, isEstimate: true }
    ],
    maintenanceBox: { name: "Waste Ink Pad", rawLevel: 25, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 25, isEstimate: true },
    tags: ["USB Direct", "EcoTank", "Borderless 4x6", "Counter"]
  },
  {
    id: "epson_l8050",
    name: "Studio Photo L8050",
    modelName: "Epson EcoTank Photo L8050",
    location: "Studio Photo LAN (192.168.1.120)",
    interfaceType: "wifi",
    ipAddress: "192.168.1.120",
    status: "Ready",
    statusType: "online",
    state: "ready",
    type: "network",
    isDefault: false,
    isFavorite: true,
    activeQueueLength: 0,
    totalLifePagesCount: 8920,
    loadedPaperSummary: "Rear Tray: 4x6 Premium Glossy Photo",
    specialtyBadges: ["CD/DVD", "PVC ID Card", "Borderless A4", "6-Color Photo"],
    activeAlerts: [],
    inkChannels: [
      { name: "Black (BK)", colorHex: "#1a1a1a", rawLevel: 90, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 90, isEstimate: true },
      { name: "Cyan (C)", colorHex: "#0099ff", rawLevel: 85, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 85, isEstimate: true },
      { name: "Magenta (M)", colorHex: "#e91e63", rawLevel: 70, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 70, isEstimate: true },
      { name: "Yellow (Y)", colorHex: "#fdd835", rawLevel: 88, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 88, isEstimate: true },
      { name: "Light Cyan (LC)", colorHex: "#80d8ff", rawLevel: 65, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 65, isEstimate: true },
      { name: "Light Magenta (LM)", colorHex: "#f48fb1", rawLevel: 62, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 62, isEstimate: true }
    ],
    maintenanceBox: { name: "Maintenance Box", rawLevel: 32, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 32, isEstimate: false },
    tags: ["Wi-Fi", "CD/DVD", "PVC ID Card", "6-Color Photo"]
  },
  {
    id: "epson_wf_c5890",
    name: "Production WF-C5890",
    modelName: "Epson WorkForce Pro WF-C5890",
    location: "Production Room (192.168.1.150)",
    interfaceType: "ethernet",
    ipAddress: "192.168.1.150",
    status: "Printing (4 in queue)",
    statusType: "online",
    state: "printing",
    type: "network",
    isDefault: false,
    isFavorite: true,
    activeQueueLength: 4,
    totalLifePagesCount: 48310,
    loadedPaperSummary: "Cassette 1: A4 Plain 80gsm | Cassette 2: A4 Letterhead",
    specialtyBadges: ["Auto Duplex", "RIPS Ink Pack", "Pigment", "High Speed"],
    activeAlerts: [],
    inkChannels: [
      { name: "Black High Capacity Pack (BK)", colorHex: "#1a1a1a", rawLevel: -1, rawMaxCapacity: -2, statusType: "presentOk", calculatedPercentage: null, isEstimate: false },
      { name: "Cyan High Capacity Pack (C)", colorHex: "#0099ff", rawLevel: -3, rawMaxCapacity: -2, statusType: "someRemaining", calculatedPercentage: null, isEstimate: false },
      { name: "Magenta High Capacity Pack (M)", colorHex: "#e91e63", rawLevel: -3, rawMaxCapacity: -2, statusType: "someRemaining", calculatedPercentage: null, isEstimate: false },
      { name: "Yellow High Capacity Pack (Y)", colorHex: "#fdd835", rawLevel: 12, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 12, isEstimate: false }
    ],
    maintenanceBox: { name: "Maintenance Box", rawLevel: 78, rawMaxCapacity: 100, statusType: "percentage", calculatedPercentage: 78, isEstimate: false },
    tags: ["Ethernet LAN", "Auto Duplex", "RIPS Ink Pack", "Production"]
  },
  {
    id: "epson_sc_p900",
    name: "Pro Art SC-P900",
    modelName: "Epson SureColor SC-P900",
    location: "Exhibition Studio (192.168.1.200)",
    interfaceType: "ethernet",
    ipAddress: "192.168.1.200",
    status: "Offline",
    statusType: "offline",
    state: "offline",
    type: "network",
    isDefault: false,
    isFavorite: false,
    activeQueueLength: 0,
    totalLifePagesCount: 3120,
    loadedPaperSummary: "Top Feeder: A3+ Exhibition Fiber Paper",
    specialtyBadges: ["A2+ / A3+", "10-Color UltraChrome", "Roll Unit", "Rigid Board (1.5mm)"],
    activeAlerts: [
      {
        code: 1001,
        severity: "critical",
        rawDescription: "Power off / Offline",
        plainLanguageEn: "Printer is offline or turned off",
        plainLanguageSi: "ප්‍රින්ටරය ක්‍රියාවිරහිතයි හෝ සම්බන්ධතාවය ඇනහිට ඇත"
      }
    ],
    inkChannels: [
      { name: "Photo Black (PK)", colorHex: "#000000", rawLevel: -2, rawMaxCapacity: -2, statusType: "notReported", calculatedPercentage: null, isEstimate: false },
      { name: "Matte Black (MK)", colorHex: "#263238", rawLevel: -2, rawMaxCapacity: -2, statusType: "notReported", calculatedPercentage: null, isEstimate: false }
    ],
    maintenanceBox: null,
    tags: ["Ethernet LAN", "A2+ / A3+", "UltraChrome 10-Color", "Fine Art"]
  },
  {
    id: "pdf_virtual",
    name: "Microsoft Print to PDF",
    modelName: "Software Rasterizer",
    location: "Virtual Software Spooler",
    interfaceType: "virtual",
    status: "Ready",
    statusType: "online",
    state: "ready",
    type: "virtual",
    isDefault: false,
    isFavorite: false,
    activeQueueLength: 0,
    totalLifePagesCount: 520,
    loadedPaperSummary: "System Spooler Virtual Driver",
    specialtyBadges: ["Vector PDF", "Lossless", "Zero Ink"],
    activeAlerts: [],
    inkChannels: [],
    maintenanceBox: null,
    tags: ["Virtual", "Vector Output", "Zero Ink"]
  }
];

let selectedPrinterId = "epson_l3250";
let fleetLowSupplyThreshold = 15.0;
let subnetScanConsentGranted = false;

// Queue Items Store
let queue = [];


// Jobs Log Store
let jobs = [];

// Organizer Pages State
let organizedPages = [];

// Command Palette Registry (all searchable actions & screens)
const commands = [
  { title: "Print Queue", sub: "View files, preview sheets, and configure print batch", icon: "print", tab: "print" },
  { title: "Shop Mode POS & Billing", sub: "Cashier counter, price estimation, receipts, multi-printer fleet", icon: "point_of_sale", tab: "shop", subview: "counter" },
  { title: "Customer Jobs & Barcode Scanner", sub: "Scan tickets, customer grouping, job status", icon: "badge", tab: "shop", subview: "customers" },
  { title: "Multi-Printer Live Fleet Dashboard", sub: "Live ink/toner gauges, paper meters, auto-routing rules", icon: "hub", tab: "shop", subview: "fleet" },
  { title: "Price List & Profit Tracker", sub: "Editable page rates (LKR), daily cashier profit audit", icon: "payments", tab: "shop", subview: "pricing" },
  { title: "PDF Power Tools Studio", sub: "20 professional offline tools (Merge, Split, OCR, Compress)", icon: "bolt", tab: "tools" },
  { title: "Page Organizer (Merge / Split / Rotate)", sub: "Reorder, extract, rotate, and delete pages", icon: "dashboard_customize", tab: "tools", tool: "organize" },
  { title: "OCR Text Recognition", sub: "Neural text extraction from PDF and image scans", icon: "psychology", tab: "tools", tool: "ocr" },
  { title: "Compress PDF", sub: "Optimize stream objects and downsample images", icon: "compress", tab: "tools", tool: "compress" },
  { title: "Protect & Encrypt PDF", sub: "256-bit AES encryption with password permissions", icon: "lock", tab: "tools", tool: "protect" },
  { title: "Redact PDF (Permanent Blackout)", sub: "Sanitize PII and sensitive text permanently", icon: "ink_eraser", tab: "tools", tool: "redact" },
  { title: "Manual Duplex Paper Turn Assistant", sub: "Visual instructions for flipping paper on single-sided printers", icon: "flip", action: "openDuplex" },
  { title: "Epson Diagnostics & Nozzle Check", sub: "Clean head, test nozzle pattern, ESC/P-R telemetry", icon: "precision_manufacturing", action: "openEpson" },
  { title: "Live Sheet Layout Preview (N-Up)", sub: "Open 1-Up, 2-Up, 4-Up imposition preview dialog", icon: "pageview", action: "openPreview" },
  { title: "Thermal Customer Receipt", sub: "Preview and print thermal ticket receipt", icon: "receipt_long", action: "openReceipt" },
  { title: "Printers & Spooler Management", sub: "Add network LAN printer, view toner levels, test print", icon: "router", tab: "printers" },
  { title: "Print Jobs Spooler History", sub: "Audit trail and reprint dispatched jobs", icon: "layers", tab: "jobs" },
  { title: "Print Presets", sub: "Eco Draft B&W, High-DPI Color, Booklet Duplex", icon: "bookmarks", tab: "presets" },
  { title: "Settings", sub: "Theme, language, and system configuration", icon: "settings", tab: "settings" }
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

  updateQueueUI();

  updateLivePrinterPanel();
  initThreeTierPrintSettings();
  initResolutionSystem();
  initToneAndInkSystem();
  initFullPricingEngine();
  initSpecialtyPrintCenter();
  initMultiPrinterDashboard();

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
  filePicker?.addEventListener("change", handleFileSelect);
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
      const parentModal = btn.closest(".modal-overlay");
      if (parentModal) parentModal.classList.add("hidden");
      livePreviewModal?.classList.add("hidden");
      drawSigModal?.classList.add("hidden");
      manualDuplexModal?.classList.add("hidden");
      receiptModal?.classList.add("hidden");
      epsonDiagModal?.classList.add("hidden");
      const pMod = document.getElementById("addPrinterModal");
      if (pMod) pMod.classList.add("hidden");
    });
  });

  // Duplex Assistant Trigger
  document.getElementById("btnResumeEvenDuplex").addEventListener("click", () => {
    manualDuplexModal.classList.add("hidden");
    showToast(currentLang === 'si' ? "📄 දෙවන පැත්ත මුද්‍රණය ආරම්භ විය!" : "📄 Resumed! Even pages sent to printer.");
  });

  // Shop counter / receipts are handled by shop_live.js

  document.getElementById("btnExportDailyReport")?.addEventListener("click", () => {
    showToast("📊 Exported Daily_Cashier_Report_2026-10-27.csv");
  });

  // Drag and Drop (Global - only for external OS files dropped into print tab)
  window.addEventListener("dragenter", (e) => {
    const dt = e.dataTransfer;
    if (!dt || !dt.types) return;
    const types = Array.from(dt.types);
    if (!types.includes("Files")) return;
    if (types.includes("text/pt-org-drag") || types.includes("text/pt-index") || types.includes("text/pt-page")) return;
    const tabTools = document.getElementById("tabTools");
    if (tabTools && tabTools.classList.contains("active")) return;

    e.preventDefault();
    globalDropOverlay.classList.remove("hidden");
    globalDropOverlay.classList.add("visible");
  });

  globalDropOverlay.addEventListener("dragover", (e) => {
    const dt = e.dataTransfer;
    if (!dt || !dt.types || !Array.from(dt.types).includes("Files")) {
      globalDropOverlay.classList.add("hidden");
      globalDropOverlay.classList.remove("visible");
      return;
    }
    const tabTools = document.getElementById("tabTools");
    if (tabTools && tabTools.classList.contains("active")) {
      globalDropOverlay.classList.add("hidden");
      globalDropOverlay.classList.remove("visible");
      return;
    }
    e.preventDefault();
  });

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

  // OCR button -> real OCR lives in PDF Power Tools (the old demo returned a hard-coded text)
  const btnOcr = document.getElementById("btnRunOcr");
  if (btnOcr) {
    btnOcr.addEventListener("click", () => {
      const pill = document.querySelector('#pdfToolsSubbar .pill-btn[data-subview="power"]');
      if (pill) pill.click();
      const card = [...document.querySelectorAll("#ptToolGrid .pt-tool")].find(c => c.textContent.includes("OCR"));
      if (card) card.click();
      showToast("Use PDF Power Tools → OCR (runs real Tesseract on your file)");
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
  // Mobile / Tablet 3-Zone Segmented Switcher Tabs
  document.querySelectorAll(".m-zone-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const zone = btn.dataset.zone;
      const zones = document.getElementById("workspaceThreeZones");
      if (zones) {
        zones.className = `workspace-three-zones show-${zone}`;
      }
      document.querySelectorAll(".m-zone-btn").forEach(b => b.classList.toggle("active", b === btn));
    });
  });

  const btnRespAdd = document.getElementById("btnResponsiveAddFiles");
  if (btnRespAdd) {
    btnRespAdd.addEventListener("click", () => document.getElementById("filePicker")?.click());
  }

  const btnEmptyBrowse = document.getElementById("btnEmptyBrowse");
  if (btnEmptyBrowse) {
    btnEmptyBrowse.addEventListener("click", () => document.getElementById("filePicker")?.click());
  }

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
  document.getElementById("btnZoomIn2")?.addEventListener("click", () => {
    previewZoom = Math.min(1.8, Math.round((previewZoom + 0.2) * 10) / 10);
    updatePreviewCanvas();
  });
  document.getElementById("btnZoomOut2")?.addEventListener("click", () => {
    previewZoom = Math.max(0.6, Math.round((previewZoom - 0.2) * 10) / 10);
    updatePreviewCanvas();
  });
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
  const lblZoom2 = document.getElementById("lblZoomLevel2");
  if (lblZoom2) lblZoom2.innerText = `${Math.round(previewZoom * 100)}%`;

  if (!simulatedPaper) return;
  simulatedPaper.style.transform = `scale(${previewZoom})`;
  simulatedPaper.style.transformOrigin = "center center";

  const isSi = currentLang === 'si';
  const item = queue[selectedQueueIndex] || queue[0];

  if (!item) {
    if (lblDocInfo) lblDocInfo.innerText = isSi ? "A4 • සූදානම්" : "A4 • Ready";
    if (lblCounter) lblCounter.innerText = isSi ? "පිටුව 0 / 0" : "Page 0 of 0";
    simulatedPaper.className = "paper-sheet-simulated empty-state";
    simulatedPaper.innerHTML = `
      <div class="preview-empty-box">
        <span class="material-symbols-rounded empty-icon">description</span>
        <h4 class="empty-title">${isSi ? 'ලේඛනයක් තෝරා නැත' : 'No document selected'}</h4>
        <p class="empty-sub">${isSi ? 'මුද්‍රණයට පෙරදසුන් කිරීමට PDF, පින්තූර හෝ පෙළ ගොනු මෙතැනට එක් කරන්න' : 'Add PDF, image, or text files to preview and adjust print settings'}</p>
        <button class="btn btn-outline btn-sm" id="btnEmptyBrowse" onclick="document.getElementById('filePicker')?.click()">
          <span class="material-symbols-rounded">add</span>
          <span>${isSi ? 'ෆයිල් එක් කරන්න' : 'Add Files'}</span>
        </button>
      </div>
    `;
    return;
  }

  const isLandscape = item.orientation === 'landscape';
  simulatedPaper.className = "paper-sheet-simulated active-doc" + (isLandscape ? " landscape" : " portrait");

  const totalPages = item.pages || 1;
  if (previewCurrentPage > totalPages) previewCurrentPage = totalPages;
  if (previewCurrentPage < 1) previewCurrentPage = 1;

  if (lblCounter) {
    lblCounter.innerText = isSi 
      ? `පිටුව ${previewCurrentPage} / ${totalPages}`
      : `Page ${previewCurrentPage} of ${totalPages}`;
  }

  if (lblDocInfo) {
    const isColor = item.colorMode === 'color';
    const colorStr = isSi ? (isColor ? 'පාටින්' : 'කළු සුදු') : (isColor ? 'Color' : 'B&W');
    const pgsStr = isSi ? `පිටු ${item.pages}` : `${item.pages} ${item.pages === 1 ? 'pg' : 'pgs'}`;
    lblDocInfo.innerText = `${item.paperSize} • ${colorStr} • ${pgsStr}`;
  }

  const isImage = (item.ext === 'PNG' || item.ext === 'JPG' || item.ext === 'JPEG' || item.ext === 'WEBP' || item.ext === 'BMP' || item.ext === 'SVG' || item.type === 'image');
  const isPdf = (item.ext === 'PDF' || item.type === 'pdf');

  if (isImage) {
    const filter = (item.colorMode === 'bw') ? 'grayscale(100%)' : 'none';
    simulatedPaper.innerHTML = `
      <div class="real-image-stage" style="width:100%; height:100%; display:flex; flex-direction:column; background:#ffffff; overflow:hidden;">
        <div style="flex:1; display:flex; align-items:center; justify-content:center; overflow:hidden; padding:10px;">
          <img src="${item.previewUrl || ''}" alt="${escapeHtml(item.name)}" style="max-width:100%; max-height:100%; object-fit:contain; border-radius:2px; filter:${filter}; box-shadow:0 1px 6px rgba(0,0,0,0.14);" />
        </div>
        <div style="padding:6px 12px; font-size:10px; color:#555; display:flex; justify-content:space-between; border-top:1px solid #eee; background:#fafafa;">
          <span style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:60%; font-weight:600;">${escapeHtml(item.name)}</span>
          <span>${item.naturalWidth ? item.naturalWidth + '×' + item.naturalHeight + ' px' : (item.sizeStr || '')}</span>
        </div>
      </div>
    `;
  } else if (isPdf) {
    if (item.engineId) {
      simulatedPaper.innerHTML = `
        <div class="real-pdf-stage" style="width:100%; height:100%; display:flex; flex-direction:column; background:#ffffff; overflow:hidden;">
          <div style="flex:1; width:100%; height:100%; position:relative; overflow:hidden; display:flex; align-items:center; justify-content:center; padding:10px;">
            <img src="/api/pagepng/${encodeURIComponent(item.engineId)}/${previewCurrentPage}?zoom=1.6" alt="Page ${previewCurrentPage}" style="max-width:100%; max-height:100%; object-fit:contain; border-radius:2px; box-shadow:0 1px 6px rgba(0,0,0,0.14);" />
          </div>
          <div style="padding:6px 12px; font-size:10px; color:#555; display:flex; justify-content:space-between; border-top:1px solid #eee; background:#fafafa;">
            <span style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:60%; font-weight:600;">${escapeHtml(item.name)}</span>
            <span>${isSi ? 'පිටුව ' + previewCurrentPage + ' / ' + totalPages : 'Page ' + previewCurrentPage + ' of ' + totalPages}</span>
          </div>
        </div>
      `;
    } else {
      simulatedPaper.innerHTML = `
        <div class="real-pdf-stage" style="width:100%; height:100%; display:flex; flex-direction:column; background:#ffffff; overflow:hidden;">
          <div style="flex:1; width:100%; height:100%; position:relative; overflow:hidden;">
            <iframe src="${item.previewUrl || ''}#toolbar=0&navpanes=0&page=${previewCurrentPage}" style="width:100%; height:100%; border:none; display:block;" title="PDF Preview"></iframe>
          </div>
          <div style="padding:6px 12px; font-size:10px; color:#555; display:flex; justify-content:space-between; border-top:1px solid #eee; background:#fafafa;">
            <span style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:60%; font-weight:600;">${escapeHtml(item.name)}</span>
            <span>${isSi ? 'පිටුව ' + previewCurrentPage + ' / ' + totalPages : 'Page ' + previewCurrentPage + ' of ' + totalPages}</span>
          </div>
        </div>
      `;
    }
  } else if (item.textContent || item.type === 'text') {
    simulatedPaper.innerHTML = `
      <div class="real-text-stage" style="width:100%; height:100%; display:flex; flex-direction:column; background:#ffffff; overflow:hidden;">
        <div style="flex:1; overflow:auto; padding:16px; font-family:var(--font-mono, monospace); font-size:11px; line-height:1.55; color:#111; white-space:pre-wrap; word-break:break-word;">
          ${escapeHtml(item.textContent || (isSi ? 'පෙළ ලේඛනය පූරණය වෙමින්...' : 'Loading document text...'))}
        </div>
        <div style="padding:6px 12px; font-size:10px; color:#555; display:flex; justify-content:space-between; border-top:1px solid #eee; background:#fafafa;">
          <span style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:60%; font-weight:600;">${escapeHtml(item.name)}</span>
          <span>${item.sizeStr || ''}</span>
        </div>
      </div>
    `;
  } else {
    simulatedPaper.innerHTML = `
      <div style="width:100%; height:100%; display:flex; flex-direction:column; justify-content:center; align-items:center; background:#ffffff; color:#333; padding:24px; text-align:center;">
        <span class="material-symbols-rounded" style="font-size:48px; color:var(--primary); margin-bottom:12px;">description</span>
        <strong style="font-size:13px; margin-bottom:4px; max-width:90%; overflow:hidden; text-overflow:ellipsis;">${escapeHtml(item.name)}</strong>
        <span style="font-size:11px; color:#666; margin-bottom:12px;">${item.paperSize} • ${item.sizeStr}</span>
        <span class="badge badge-active">${isSi ? 'මුද්‍රණයට සූදානම්' : 'Ready to Print'}</span>
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
  "epson_wf_c5890": {
    name: "Epson WorkForce Pro WF-C5890",
    family: "Epson WorkForce Pro RIPS Series",
    trait: "WorkForce Pro",
    supplyTech: "Replaceable Ink Pack System (RIPS)",
    colorLayout: "CMYK DURABrite Ultra All-Pigment",
    hasDigitalInk: true,
    autoDuplex: true,
    borderless: false,
    borderlessMaxSize: "None",
    opticalDpi: "4800x1200 DPI",
    paperSizes: ["A4", "Letter", "Legal", "Executive", "A5", "A6", "Envelope #10"],
    mediaTypes: ["Plain Paper", "Bright White", "Recycled", "Presentation Matte"],
    trays: ["Cassette 1 (250)", "Cassette 2 (500)", "Rear Slot (80)"],
    cdDvd: false,
    rollPaper: false,
    iccProfiles: ["Driver Managed", "sRGB IEC61966-2.1"],
    provenance: [
      { feature: "Hardware Duplex", source: "Win32 DeviceCapabilities", confidence: "Verified (Hardware Auto)" },
      { feature: "Toner & Ink Level", source: "SNMP RFC 3805 (Negative Values OK)", confidence: "Live Telemetry" },
      { feature: "Paper Sizes", source: "IPP Everywhere", confidence: "Verified" }
    ]
  },
  "epson_sc_p900": {
    name: "Epson SureColor SC-P900",
    family: "Epson SureColor Pro Photo Series",
    trait: "Large Format Fine Art",
    supplyTech: "10-Color UltraChrome PRO10 Ink",
    colorLayout: "10 Individual Pigment Channels (PK, MK, C, VM, Y, LC, VLM, GY, LGY, V)",
    hasDigitalInk: true,
    autoDuplex: false,
    borderless: true,
    borderlessMaxSize: "17-inch A2+",
    opticalDpi: "5760x1440 DPI",
    paperSizes: ["A4", "A3", "A3+", "A2+", "17-inch Roll", "13x19 in", "Photo 4x6"],
    mediaTypes: ["Exhibition Fiber Paper", "Velvet Fine Art", "Metallic Glossy", "Rigid Posterboard"],
    trays: ["Top Sheet Feeder (120)", "Front Fine Art Path", "Roll Paper Unit", "Front Rigid Board Path (1.5mm)"],
    cdDvd: true,
    rollPaper: true,
    iccProfiles: ["Driver Managed", "Epson Exhibition Fiber", "Epson Velvet Fine Art", "Adobe RGB (1998)"],
    provenance: [
      { feature: "Rigid Board (1.5mm)", source: "ESC/P-R specs", confidence: "Verified" },
      { feature: "Roll Paper Unit", source: "Physical Attachment Sensor", confidence: "Live Telemetry" },
      { feature: "Supply Levels", source: "SNMP Printer MIB", confidence: "Live Telemetry" }
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
      copyTextSafe(text);
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
  const selPass = document.getElementById("selPassportPresetMain");
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
  if (window.updateLivePricePanel) window.updateLivePricePanel();
}

function validateDependenciesAndAutoFixes() {
  const container = document.getElementById("validationAlertsBox");
  if (!container) return;
  if (queue.length === 0) { container.innerHTML = ""; return; }

  const p = printerProfilesDb[selectedPrinterId] || printerProfilesDb["epson_l3250"];
  const paperType = document.getElementById("selPaperType")?.value || "Plain Paper";
  const paperSize = document.getElementById("selPaperSize")?.value || "A4";
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

  // Conflict 4: Low PPI Image Resolution (<150 PPI)
  if (typeof currentEffectivePpi !== "undefined" && currentEffectivePpi < 149.0) {
    alerts.push({
      blocking: false,
      title: isSi ? `අඩු ඡායාරූප පැහැදිලි බව (${Math.round(currentEffectivePpi)} PPI)` : `Low Image Resolution (${Math.round(currentEffectivePpi)} PPI)`,
      sub: isSi
        ? `${paperSize} කොළයේ මුද්‍රණය කළ විට ඡායාරූපය බොඳ විය හැක. තියුණු කිරීමට Lanczos (2x) යොදන්න.`
        : `This photo prints at ${Math.round(currentEffectivePpi)} PPI on ${paperSize} and may look soft.`,
      fixLabel: isSi ? "Lanczos (2x) මඟින් විශාල කරන්න" : "Apply 2x Lanczos Upscale",
      action: () => {
        isImageUpscaled = true;
        if (window.updateEffectivePpiDisplay) window.updateEffectivePpiDisplay();
        showToast(isSi ? "2x Lanczos ප්‍රතිනියැදීම යොදන ලදී!" : "Applied 2x Lanczos upscale auto-fix!");
      }
    });
  }

  // Conflict 5: Plain Paper 2400+ DPI droplet overload
  const currentDpi = parseInt(document.getElementById("selHardwareDpi")?.value || "720", 10);
  if (paperType.includes("Plain") && currentDpi >= 2400) {
    alerts.push({
      blocking: true,
      title: isSi ? "සාමාන්‍ය කඩදාසිවලට 2400+ DPI තීන්ත දරාගත නොහැක" : "Plain Paper cannot absorb 2400+ DPI droplet volume",
      sub: isSi ? "තීන්ත රැඳීම සහ කොළ රැළි වැටීම වැළැක්වීමට 720 DPI තෝරන්න." : "Prevent ink bleed and paper cockling by switching to 720 DPI Normal.",
      fixLabel: isSi ? "720 DPI වෙත මාරු වන්න" : "Switch to 720 DPI Normal",
      action: () => {
        const selDpi = document.getElementById("selHardwareDpi");
        if (selDpi) {
          selDpi.value = "720";
          selDpi.dispatchEvent(new Event("change"));
        }
      }
    });
  }

  // Conflict 6: 1200 Render DPI high memory footprint
  const renderDpiVal = document.getElementById("selRenderDpi")?.value || "auto";
  if (renderDpiVal === "1200") {
    alerts.push({
      blocking: false,
      title: isSi ? "අධික මතක භාවිතය (~398 MB/පිටුව)" : "High Raster Memory Footprint (~398 MB/page)",
      sub: isSi ? "1200 DPI විශාල මතකයක් වැය කරයි. ස්වයංක්‍රීය (Auto) තෝරාගැනීම නිර්දේශ කෙරේ." : "1200 DPI rasterization requires significant RAM. Auto mode matches native printer DPI.",
      fixLabel: isSi ? "Auto Render DPI තෝරන්න" : "Switch to Auto Render DPI",
      action: () => {
        const selR = document.getElementById("selRenderDpi");
        if (selR) {
          selR.value = "auto";
          selR.dispatchEvent(new Event("change"));
        }
      }
    });
  }

  // Conflict 7: Double color adjustment (Driver color adjustment active + App adjustments active)
  const hasAppAdjustments = (
    toneAndInkState.density !== 0 ||
    toneAndInkState.brightness !== 0 ||
    toneAndInkState.contrast !== 0 ||
    toneAndInkState.saturation !== 0 ||
    Math.abs(toneAndInkState.gamma - 1.0) > 0.01
  );
  if (toneAndInkState.driverColorAdjustmentActive && hasAppAdjustments) {
    alerts.push({
      blocking: false,
      title: isSi ? "ද්විත්ව වර්ණ වෙනස්වීමක් අනාවරණය විය" : "Double Color Adjustment Detected",
      sub: isSi
        ? "ප්‍රින්ටර් ඩ්‍රයිවර් එක සහ Print Helper යන දෙකෙන්ම එකවර වර්ණ වෙනස් වේ. මෙය වර්ණ අපැහැදිලි වීමට හේතු විය හැක."
        : "Both driver color adjustments and Print Helper tone adjustments are engaged. Disable one to avoid muddy prints.",
      fixLabel: isSi ? "Print Helper ට පමණක් ඉඩ දෙන්න" : "Let Print Helper Manage Tone",
      action: () => {
        toneAndInkState.driverColorAdjustmentActive = false;
        validateDependenciesAndAutoFixes();
        showToast(isSi ? "ඩ්‍රයිවර් වර්ණ පාලනය අක්‍රිය කර Print Helper තෝරාගන්නා ලදී." : "Driver color adjustment disabled; Print Helper managing tone.");
      }
    });
  }

  // Conflict 8: High ink density on plain paper (> +25)
  if (paperType.includes("Plain") && toneAndInkState.density > 25) {
    alerts.push({
      blocking: false,
      title: isSi ? "සාමාන්‍ය කොළ සඳහා වැඩි තීන්ත ඝනත්වයක්" : "High Ink Density on Plain Paper",
      sub: isSi
        ? "සාමාන්‍ය කොළ සඳහා +25% ට වඩා තීන්ත යෙදීමෙන් තීන්ත කාන්දු වීම හෝ රැළි වැටීම සිදුවිය හැක."
        : "Density above +25% on standard copy paper may cause ink bleed-through or fiber cockling.",
      fixLabel: isSi ? "ඝනත්වය +15% ට අඩු කරන්න" : "Reduce Density to +15%",
      action: () => {
        toneAndInkState.density = 15;
        const range = document.getElementById("rangeDensity");
        const val = document.getElementById("valDensity");
        if (range) range.value = "15";
        if (val) val.innerText = "+15";
        if (window.updateToneAndInkLiveEffect) window.updateToneAndInkLiveEffect();
        validateDependenciesAndAutoFixes();
        showToast(isSi ? "තීන්ත ඝනත්වය +15% දක්වා අඩු කරන ලදී." : "Density reduced to +15% for Plain Paper.");
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
      if (c.action === 'openPreview') {
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
        if (c.tool) {
          setTimeout(() => {
            const toolEl = document.querySelector(`.pt-tool[data-id="${c.tool}"]`);
            if (toolEl) toolEl.click();
          }, 60);
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
    const isTxt = ext === 'TXT' || ext === 'MD' || ext === 'CSV' || ext === 'JSON' || ext === 'LOG';
    const isImg = ['PNG', 'JPG', 'JPEG', 'WEBP', 'BMP', 'GIF', 'SVG'].includes(ext);

    let docType = 'text';
    if (isPdf) docType = 'pdf';
    else if (isImg) docType = 'image';

    let estPages = 1;
    if (isPdf) estPages = Math.max(1, Math.min(60, Math.round(f.size / 150000) || 1));
    else if (isTxt) estPages = Math.max(1, Math.round(f.size / 4000) || 1);

    const blobUrl = URL.createObjectURL(f);
    const item = {
      id: "file_" + Date.now() + "_" + i,
      name: f.name,
      file: f,
      previewUrl: blobUrl,
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
    };

    if (isImg) {
      const img = new Image();
      img.onload = () => {
        item.naturalWidth = img.naturalWidth;
        item.naturalHeight = img.naturalHeight;
        if (img.naturalWidth > img.naturalHeight) {
          item.orientation = "landscape";
        }
        updatePreviewCanvas();
        if (window.updateEffectivePpiDisplay) window.updateEffectivePpiDisplay();
      };
      img.src = blobUrl;
    } else if (isTxt) {
      const reader = new FileReader();
      reader.onload = (e) => {
        item.textContent = e.target.result;
        updatePreviewCanvas();
      };
      reader.readAsText(f.slice(0, 50000));
    } else if (isPdf) {
      // POST to /api/upload to obtain real page count and engine ID
      fetch("/api/upload", {
        method: "POST",
        headers: { "X-Filename": encodeURIComponent(f.name) },
        body: f
      }).then(r => r.ok ? r.json() : null).then(data => {
        if (data && data.pages) {
          item.pages = data.pages;
          item.engineId = data.id;
          item.duplex = data.pages > 1 ? "two-sided" : "one-sided";
          updateQueueUI();
          updatePreviewCanvas();
          updateRightPanelSettings();
          updateLivePricePanel();
        }
      }).catch(err => {
        console.warn("PDF engine unreachable, using estimated pages", err);
      });
    }

    queue.push(item);
  }

  selectedQueueIndex = queue.length - 1;
  previewCurrentPage = 1;
  switchTab("print");
  updateQueueUI();
  updatePreviewCanvas();
  updateRightPanelSettings();
  validateDependenciesAndAutoFixes();
  updateLivePricePanel();

  // On mobile/tablet, switch to preview view automatically so user sees file
  const zones = document.getElementById("workspaceThreeZones");
  if (zones && window.innerWidth <= 950) {
    zones.className = "workspace-three-zones show-preview";
    document.querySelectorAll(".m-zone-btn").forEach(b => b.classList.toggle("active", b.dataset.zone === "preview"));
  }

  showToast(currentLang === 'si' ? `ෆයිල් ${files.length} ක් එක් කරන ලදී` : `Added ${files.length} file(s) to queue`);
}

async function pasteFromClipboard() {
  let clipText = "";
  try {
    clipText = await navigator.clipboard.readText();
  } catch (err) {
    // clipboard read not permitted or empty
  }
  const item = {
    id: "clip_" + Date.now(),
    name: "Clipboard_Snippet_" + new Date().toLocaleTimeString().replace(/:/g, '-') + ".txt",
    ext: "TXT",
    sizeStr: formatBytes(clipText ? clipText.length : 120),
    pages: Math.max(1, Math.ceil((clipText ? clipText.length : 120) / 3000)),
    type: "text",
    copies: 1,
    colorMode: "bw",
    duplex: "one-sided",
    orientation: "portrait",
    paperSize: "A4",
    tray: "Auto",
    expanded: false,
    textContent: clipText || (currentLang === 'si' ? "පේස්ට් කරන ලද පෙළ අන්තර්ගතය" : "Pasted clipboard text content")
  };
  queue.push(item);
  selectedQueueIndex = queue.length - 1;
  previewCurrentPage = 1;
  updateQueueUI();
  updatePreviewCanvas();
  updateRightPanelSettings();
  validateDependenciesAndAutoFixes();
  updateLivePricePanel();
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
      <div class="card-top-row">
        <span class="material-symbols-rounded drag-handle" title="Drag to reorder">drag_indicator</span>
        <div class="doc-thumb ${thumbClass}">
          <span class="material-symbols-rounded">${thumbIcon}</span>
        </div>
        <div class="doc-info">
          <div class="doc-name" title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</div>
          <div class="doc-meta">
            <span class="meta-pill type-pdf">${item.ext}</span>
            <span class="meta-pill">${item.pages} ${item.pages === 1 ? t.page : t.pages}</span>
            <span class="meta-pill">${item.sizeStr}</span>
            <span class="meta-pill badge-ppi ${item.type === 'image' && !isImageUpscaled ? 'low' : 'crisp'}" style="cursor:pointer;" onclick="if(window.openPhotoHelperModal) window.openPhotoHelperModal();" title="Click to view Photo Size Helper">
              ${item.type === 'image' && !isImageUpscaled ? '96 PPI' : '300 PPI'}
            </span>
          </div>
        </div>
        <button class="card-remove-btn" data-id="${item.id}" title="Remove file">
          <span class="material-symbols-rounded">close</span>
        </button>
      </div>

      <div class="card-bottom-row">
        <div class="stepper" title="Copies">
          <button class="btn-step-minus" data-id="${item.id}">-</button>
          <span class="stepper-value">${item.copies}</span>
          <button class="btn-step-plus" data-id="${item.id}">+</button>
        </div>

        <div class="segmented-toggle">
          <button class="seg-btn ${item.colorMode === 'bw' ? 'active' : ''}" data-action="set-bw" data-id="${item.id}">${t.bwOption || 'B&W'}</button>
          <button class="seg-btn ${item.colorMode === 'color' ? 'active' : ''}" data-action="set-color" data-id="${item.id}">${t.colorOption || 'Color'}</button>
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

function copyTextSafe(text) {
  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(text).catch(() => legacyCopy(text));
  }
  return Promise.resolve(legacyCopy(text));
}
function legacyCopy(text) {
  const ta = document.createElement("textarea");
  ta.value = text; ta.style.position = "fixed"; ta.style.opacity = "0";
  document.body.appendChild(ta); ta.select();
  try { document.execCommand("copy"); } catch (e) { /* ignore */ }
  document.body.removeChild(ta);
}
window.copyTextSafe = copyTextSafe;

function updateLivePrinterPanel() {
  const p = printers.find(x => x.id === selectedPrinterId) || printers[0];
  if (!p) return;
  const isSi = currentLang === 'si';

  const nameEl = document.getElementById("compactPrinterName");
  if (nameEl) nameEl.textContent = p.name;

  const badge = document.getElementById("compactStatusBadge");
  if (badge) {
    const st = (p.state || "ready").toLowerCase();
    badge.textContent = p.status || "Ready";
    badge.className = "badge-status " + (st === "ready" ? "ready" : st === "error" || st === "offline" ? "error" : "warning");
  }

  const supplies = document.getElementById("compactSupplies");
  if (supplies) {
    supplies.innerHTML = "";
    const chans = Array.isArray(p.inkChannels) ? p.inkChannels : [];
    if (chans.length === 0) {
      const note = document.createElement("div");
      note.className = "compact-paper-duplex";
      note.textContent = isSi ? "සැපයුම් දත්ත වාර්තා නොකෙරේ" : "Supply levels not reported";
      supplies.appendChild(note);
    }
    chans.forEach(ch => {
      const pct = ch.calculatedPercentage;
      const wrap = document.createElement("div");
      wrap.className = "mini-bar-wrap";
      const m = /\(([^)]+)\)\s*$/.exec(ch.name || "");
      const lbl = document.createElement("span");
      lbl.textContent = m ? m[1] : (ch.name || "?").charAt(0);
      lbl.title = ch.name || "";
      const bar = document.createElement("div");
      bar.className = "mini-bar";
      const fill = document.createElement("div");
      fill.style.width = (pct === null || pct === undefined ? 0 : Math.max(0, Math.min(100, pct))) + "%";
      if (ch.colorHex) fill.style.background = ch.colorHex;
      bar.appendChild(fill);
      wrap.appendChild(lbl);
      wrap.appendChild(bar);
      supplies.appendChild(wrap);
    });
  }

  const paperLine = document.querySelector("#printerCompactInfo .compact-paper-duplex");
  if (paperLine && p.loadedPaperSummary) paperLine.textContent = p.loadedPaperSummary;
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

function hasPrinterLowSupply(p, threshold) {
  if (p.activeAlerts && p.activeAlerts.length > 0) return true;
  if (p.inkChannels) {
    for (const ink of p.inkChannels) {
      if (ink.statusType === 'lowOrEmpty') return true;
      if (ink.calculatedPercentage !== null && ink.calculatedPercentage <= threshold) return true;
    }
  }
  if (p.maintenanceBox && p.maintenanceBox.calculatedPercentage !== null) {
    if (p.maintenanceBox.calculatedPercentage >= (100 - threshold)) return true;
  }
  return false;
}

function formatSupplyStatusText(ch, isSi) {
  if (ch.statusType === 'presentOk' || ch.rawLevel === -1) {
    return isSi ? 'හරි (OK)' : 'OK';
  }
  if (ch.statusType === 'someRemaining' || ch.rawLevel === -3) {
    return isSi ? 'ප්‍රමාණවත්' : 'Some Remaining';
  }
  if (ch.statusType === 'notReported' || ch.rawLevel === -2) {
    return isSi ? 'වාර්තා නැත' : 'Not reported';
  }
  if (ch.statusType === 'lowOrEmpty' || (ch.calculatedPercentage !== null && ch.calculatedPercentage <= 0)) {
    return isSi ? 'අඩුයි / හිස්' : 'Low / Empty';
  }
  if (ch.calculatedPercentage !== null) {
    const estTag = ch.isEstimate ? (isSi ? ' (ඇස්තමේන්තුව)' : ' (est)') : '';
    return `${Math.round(ch.calculatedPercentage)}%${estTag}`;
  }
  return isSi ? 'නොදනී' : 'Unknown';
}

function renderPrintersGrid() {
  const container = document.getElementById("printersGrid");
  if (!container) return;
  container.innerHTML = "";

  const isSi = currentLang === 'si';

  // Update Fleet Telemetry Summary Banner
  const totalCount = printers.length;
  const readyCount = printers.filter(p => p.state === 'ready').length;
  const printingCount = printers.filter(p => p.state === 'printing').length;
  const offlineCount = printers.filter(p => p.state === 'offline').length;
  const lowSupplyCount = printers.filter(p => hasPrinterLowSupply(p, fleetLowSupplyThreshold)).length;

  const elTotal = document.getElementById("fleetTotalCount");
  const elReady = document.getElementById("fleetReadyCount");
  const elPrinting = document.getElementById("fleetPrintingCount");
  const elOffline = document.getElementById("fleetOfflineCount");
  const elLow = document.getElementById("fleetLowSupplyCount");
  if (elTotal) elTotal.innerText = totalCount;
  if (elReady) elReady.innerText = readyCount;
  if (elPrinting) elPrinting.innerText = printingCount;
  if (elOffline) elOffline.innerText = offlineCount;
  if (elLow) elLow.innerText = lowSupplyCount;

  const filtered = printers.filter(p => {
    if (activeFilter === 'all') return true;
    if (activeFilter === 'ready') return p.state === 'ready';
    if (activeFilter === 'network') return p.interfaceType === 'wifi' || p.interfaceType === 'ethernet';
    if (activeFilter === 'usb') return p.interfaceType === 'usb';
    if (activeFilter === 'alerts') return hasPrinterLowSupply(p, fleetLowSupplyThreshold) || (p.activeAlerts && p.activeAlerts.length > 0) || p.state === 'offline';
    if (activeFilter === 'favorites') return p.isFavorite;
    return p.type === activeFilter;
  });

  filtered.forEach(p => {
    const isAlert = hasPrinterLowSupply(p, fleetLowSupplyThreshold);
    const card = document.createElement("div");
    card.className = `fleet-card-modern ${isAlert ? 'alert-active' : ''}`;

    // Interface pill
    let ifaceIcon = 'settings_ethernet';
    let ifaceLabel = 'LAN';
    if (p.interfaceType === 'usb') { ifaceIcon = 'usb'; ifaceLabel = 'USB'; }
    else if (p.interfaceType === 'wifi') { ifaceIcon = 'wifi'; ifaceLabel = 'Wi-Fi'; }
    else if (p.interfaceType === 'virtual') { ifaceIcon = 'cloud_queue'; ifaceLabel = 'Virtual'; }

    // State visuals
    let stateClass = 'ready';
    let stateText = isSi ? 'සූදානම්' : 'Ready';
    if (p.state === 'printing') { stateClass = 'printing'; stateText = isSi ? 'මුද්‍රණය වේ' : 'Printing'; }
    else if (p.state === 'paused') { stateClass = 'paused'; stateText = isSi ? 'නවත්වා ඇත' : 'Paused'; }
    else if (p.state === 'offline') { stateClass = 'offline'; stateText = isSi ? 'ක්‍රියාවිරහිතයි' : 'Offline'; }
    else if (p.state === 'error') { stateClass = 'error'; stateText = isSi ? 'දෝෂයක්' : 'Hardware Error'; }

    // Queue badge
    const qCount = p.activeQueueLength || 0;
    const qClass = qCount > 0 ? '' : 'idle';
    const qText = `${qCount} ${isSi ? 'රැකියා' : (qCount === 1 ? 'job' : 'jobs')}`;

    // Hardware Alert Banner
    let alertHtml = '';
    if (p.activeAlerts && p.activeAlerts.length > 0) {
      const alert = p.activeAlerts[0];
      const alertMsg = isSi ? (alert.plainLanguageSi || alert.plainLanguageEn) : alert.plainLanguageEn;
      alertHtml = `
        <div class="printer-hardware-alert-box">
          <span class="material-symbols-rounded" style="font-size:16px;">error_outline</span>
          <span><strong>${alertMsg}</strong></span>
        </div>
      `;
    }

    // Specialty Badges
    const badgesHtml = (p.specialtyBadges || []).map(b => `<span class="specialty-chip">${b}</span>`).join('');

    // Consumables / Inks
    let consumablesHtml = '';
    if (p.inkChannels && p.inkChannels.length > 0) {
      consumablesHtml = p.inkChannels.map(ch => {
        const txt = formatSupplyStatusText(ch, isSi);
        const hasPct = ch.calculatedPercentage !== null;
        const pct = hasPct ? Math.max(0, Math.min(100, ch.calculatedPercentage)) : 0;
        const isLow = ch.statusType === 'lowOrEmpty' || (hasPct && pct <= fleetLowSupplyThreshold);
        const isSpecial = ch.rawLevel === -1 || ch.rawLevel === -3;

        return `
          <div class="consumable-row">
            <span class="consumable-dot" style="background:${ch.colorHex};"></span>
            <span class="consumable-name" title="${ch.name}">${ch.name.split('(')[0].trim()}</span>
            <div class="consumable-bar-track">
              ${hasPct ? `<div class="consumable-bar-fill" style="width:${pct}%; background:${ch.colorHex};"></div>` : ''}
            </div>
            <span class="consumable-level-badge ${isLow ? 'low' : (isSpecial ? 'special' : '')}">${txt}</span>
          </div>
        `;
      }).join('');
    } else {
      consumablesHtml = `<div style="font-size:11px; color:var(--text-muted); font-style:italic;">${isSi ? 'තීන්ත අවශ්‍ය නැත' : 'Zero consumable required'}</div>`;
    }

    // Maintenance Box
    let mboxHtml = '';
    if (p.maintenanceBox) {
      const mbPct = p.maintenanceBox.calculatedPercentage !== null ? Math.round(p.maintenanceBox.calculatedPercentage) : 0;
      const mbFull = mbPct >= (100 - fleetLowSupplyThreshold);
      mboxHtml = `
        <div class="maintenance-box-row">
          <span class="material-symbols-rounded" style="font-size:14px;">delete_outline</span>
          <span>${isSi ? 'නඩත්තු පෙට්ටිය (M-Box):' : 'Maintenance Box:'}</span>
          <div class="consumable-bar-track" style="height:5px;">
            <div class="consumable-bar-fill" style="width:${mbPct}%; background:${mbFull ? '#dc2626' : '#64748b'};"></div>
          </div>
          <span style="font-weight:700; color:${mbFull ? '#dc2626' : 'inherit'};">${mbPct}%</span>
        </div>
      `;
    }

    // Loaded Paper Tray
    const paperHtml = p.loadedPaperSummary ? `
      <div class="loaded-paper-bar">
        <span class="material-symbols-rounded" style="font-size:14px;">layers</span>
        <span>${p.loadedPaperSummary}</span>
      </div>
    ` : '';

    const isTarget = selectedPrinterId === p.id;

    card.innerHTML = `
      <div class="fleet-card-top">
        <div class="fleet-printer-title-group">
          <h4>${p.name}</h4>
          <div class="printer-model-sub">${p.modelName || p.name}</div>
        </div>
        <div class="fleet-top-badges">
          <span class="interface-chip">
            <span class="material-symbols-rounded" style="font-size:13px;">${ifaceIcon}</span>
            <span>${ifaceLabel}</span>
          </span>
          <span class="queue-length-badge ${qClass}">
            <span class="material-symbols-rounded" style="font-size:13px;">format_list_numbered</span>
            <span>${qText}</span>
          </span>
        </div>
      </div>

      <div class="fleet-state-row">
        <span class="state-dot-modern ${stateClass}"></span>
        <span>${stateText}</span>
        ${p.ipAddress ? `<span class="printer-ip-addr">${p.ipAddress}</span>` : ''}
        ${p.totalLifePagesCount ? `<span class="lifetime-pages-tag">${p.totalLifePagesCount.toLocaleString()} ${isSi ? 'පිටු' : 'pgs'}</span>` : ''}
      </div>

      ${alertHtml}

      <div class="specialty-chips-container">
        ${badgesHtml}
      </div>

      <div class="consumables-section-title">${isSi ? 'තීන්ත මට්ටම් (Ink / Consumables)' : 'Ink & Consumable Levels'}</div>
      <div class="consumables-list">
        ${consumablesHtml}
        ${mboxHtml}
      </div>

      ${paperHtml}

      <div class="printer-card-actions">
        <button class="btn btn-tonal btn-sm btn-fleet-test-print" data-name="${p.name}">
          <span class="material-symbols-rounded">receipt_long</span>
          <span>${isSi ? 'පරීක්ෂා පිටුව' : 'Test Page'}</span>
        </button>
        <button class="btn ${isTarget ? 'btn-primary' : 'btn-outline'} btn-sm btn-fleet-set-target" data-id="${p.id}">
          <span class="material-symbols-rounded">${isTarget ? 'check' : 'radio_button_unchecked'}</span>
          <span>${isTarget ? (isSi ? 'තෝරා ඇත' : 'Target Active') : (isSi ? 'ඉලක්කය ලෙස තෝරන්න' : 'Use as Target')}</span>
        </button>
      </div>
    `;

    container.appendChild(card);
  });

  // Event handlers
  container.querySelectorAll(".btn-fleet-test-print").forEach(b => {
    b.addEventListener("click", () => {
      showToast(`🖨️ Sent diagnostic test page to ${b.dataset.name}`);
    });
  });

  container.querySelectorAll(".btn-fleet-set-target").forEach(b => {
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

  // Trigger real document printing
  const activeItem = queue[selectedQueueIndex] || queue[0];
  if (activeItem && activeItem.previewUrl) {
    try {
      const iframe = document.createElement("iframe");
      iframe.style.position = "fixed";
      iframe.style.right = "0";
      iframe.style.bottom = "0";
      iframe.style.width = "0";
      iframe.style.height = "0";
      iframe.style.border = "0";
      iframe.src = activeItem.previewUrl;
      document.body.appendChild(iframe);
      iframe.onload = () => {
        setTimeout(() => {
          try {
            iframe.contentWindow.focus();
            iframe.contentWindow.print();
          } catch (e) {
            window.print();
          }
          setTimeout(() => iframe.remove(), 60000);
        }, 500);
      };
    } catch (e) {
      window.print();
    }
  } else {
    window.print();
  }

  const autoClear = document.getElementById("chkAutoClear");
  if (autoClear && autoClear.checked) {
    queue = [];
    selectedQueueIndex = 0;
    updateQueueUI();
  }
}

function applyPresetToQueue(preset) {
  if (queue.length === 0) {
    showToast((currentLang === 'si' ? "⚠️ මුලින් පෝලිමට ෆයිල් එක් කරන්න!" : "⚠️ Add files to the queue first."));
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
  if (lbl) lbl.innerText = currentLang === 'si' ? 'සිංහල' : 'English';
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

  // Tone and Ink Translations
  const isSi = currentLang === 'si';
  setTxt("lblToneInkHeader", isSi ? "තීන්ත සහ වර්ණ වෙනස්කම්" : "Tone & Ink Adjustments");
  setTxt("lblTonePaperPreset", isSi ? "කඩදාසි අනුව වෙනස්කම්" : "Paper Compensation");
  setTxt("badgePaperPresetApp", isSi ? "Print Helper සැකසුම" : "Print Helper adjustment");
  setTxt("lblDensity", isSi ? "සමස්ත තීන්ත ඝනත්වය" : "Overall Density");
  setTxt("lblBrightness", isSi ? "දීප්තිය" : "Brightness");
  setTxt("lblContrast", isSi ? "ප්‍රතිවිරෝධය" : "Contrast");
  setTxt("lblGamma", isSi ? "ගැමා වක්‍රය" : "Gamma Curve");
  setTxt("lblShadows", isSi ? "සෙවණැලි" : "Shadows");
  setTxt("lblHighlights", isSi ? "දීප්තිමත් පෙදෙස්" : "Highlights");
  setTxt("lblBlackLevel", isSi ? "කළු මට්ටම" : "Black Level");
  setTxt("lblTextDarkness", isSi ? "අකුරු අඳුරු බව" : "Text Darkness");
  setTxt("lblTextSharp", isSi ? "අකුරු තියුණු බව" : "Text Sharpening");
  setTxt("lblPhotoSharp", isSi ? "ඡායාරූප තියුණු බව" : "Photo Sharpening");
  setTxt("lblSaturation", isSi ? "සන්තෘප්තිය" : "Saturation");
  setTxt("lblVibrance", isSi ? "වර්ණ ප්‍රාණවත් බව" : "Vibrance (Skin Safe)");
  setTxt("lblInkSaverTitle", isSi ? "තීන්ත / ටෝනර් ඉතිරි කිරීම" : "Ink / Toner Saver Mode");
  setTxt("lblInkSaverLevel", isSi ? "ඉතිරි කිරීමේ මට්ටම" : "Reduction Level");
  setTxt("lblTextOnlyBlack", isSi ? "අකුරු පමණක් තද කළු තීන්තෙන් මුද්‍රණය" : "Text-Only Black (Preserves Color Tanks)");
  setTxt("lblCmykTitle", isSi ? "තීන්ත ආවරණ ඇස්තමේන්තුව" : "Estimated Ink Coverage");
  setTxt("lblCmykNote", isSi ? "ප්‍රතිශතය අනුව සාප්පු ගාස්තු සහ පිරිවැය ගණනය කෙරේ." : "Per-channel optical analysis feeds Shop Mode cost & pricing estimates.");
  setTxt("lblBtnResetTone", isSi ? "මුල් තත්ත්වයට" : "Reset");
  setTxt("lblBtnCompare", toneAndInkState.compareWithOriginal ? (isSi ? "සංසන්දනය නවත්වන්න" : "Stop Compare") : (isSi ? "මුල් පිටුව සමඟ බලන්න" : "Compare Original"));
  setTxt("lblBtnTestPattern", isSi ? "පරීක්ෂණ රටාව මුද්‍රණය..." : "Print Test Pattern (Nozzle & Ramp)...");
  setTxt("lblTestPatternTitle", isSi ? "පරීක්ෂණ රටාව මුද්‍රණය" : "Print Tone & Quality Test Pattern");
  setTxt("lblTestPatternSub", isSi ? "Epson EcoTank L3250 — අළු වර්ණ පරාසය සහ නොසල් සටහන" : "Epson EcoTank L3250 — Gray Ramp, Color Patches & Nozzle Chart");
  setTxt("lblBtnDriverMaint", isSi ? "Epson ඩ්‍රයිවර් නඩත්තු මෙනුව" : "Open Driver Maintenance");
  setTxt("lblBtnPrintTestPage", isSi ? "පරීක්ෂණ පිටුව මුද්‍රණය කරන්න" : "Print Test Page Now");
  setTxt("lblPreviewApprox", isSi ? "මුද්‍රණ පෙරදසුන (ආසන්න)" : "Approximate print preview (Tone active)");
  setTxt("lblCompareMode", isSi ? "මුල් පිටුව පෙන්වයි (වෙනස්කම් රහිත)" : "Showing Original (Unadjusted)");

  setTxt("lblQueueEmptyHint", isSi ? "තවම ෆයිල් එකතු කර නැත" : "No files added yet");
  setTxt("lblEmptyPreviewTitle", isSi ? "ලේඛනයක් තෝරා නැත" : "No document selected");
  setTxt("lblEmptyPreviewSub", isSi ? "මුද්‍රණයට පෙරදසුන් කිරීමට PDF, පින්තූර හෝ පෙළ ගොනු මෙතැනට එක් කරන්න" : "Add PDF, image, or text files to preview and adjust print settings");
  setTxt("lblEmptyBrowseBtn", isSi ? "ෆයිල් එක් කරන්න" : "Add Files");
  setTxt("lblMZoneQueue", isSi ? "ෆයිල්" : "Files");
  setTxt("lblMZonePreview", isSi ? "පෙරදසුන" : "Preview");
  setTxt("lblMZoneSettings", isSi ? "සැකසුම්" : "Settings");

  // Pricing Engine Translations
  setTxt("lblPricingEngineTitle", isSi ? "පූර්ණ බහුමානීය මිල එන්ජිම" : "Full Multidimensional Pricing Engine");
  setTxt("lblPricingEngineSub", isSi ? "කඩදාසි වර්ග, ප්‍රමාණ, වර්ණ, ගුණාත්මකභාවය සහ තොග මිල ගණන් දේශීයව සංස්කරණය කරන්න" : "Configure granular rates by Type, Color, Size, Media, Sides, Quality, Printer, and Volume Tiers");
  setTxt("lblActivePkgBadge", isSi ? "100% දේශීය සහ සංස්කරණය කළ හැක" : "100% Local & Editable");
  setTxt("lblPackageSelect", isSi ? "මිල ලැයිස්තුව:" : "Price List:");
  setTxt("lblBtnBulkEdit", isSi ? "තොග වෙනස්කම්" : "Bulk Edit");
  setTxt("lblBtnAudit", isSi ? "ඉතිහාසය" : "History");
  setTxt("lblPinStatus", isSi ? "PIN අගුල සක්‍රියයි" : "PIN Active");
  setTxt("lblMissingPriceHeadline", isSi ? "මිල ආරක්ෂණ ක්‍රමය සක්‍රියයි" : "Missing Price Safeguard Active");
  setTxt("lblMissingPriceSub", isSi ? "මිල නියම නොකළ කඩදාසි ප්‍රමාණ ඇත. Print Helper කිසිවිටෙක රු. 0 අය නොකරයි; ආරක්ෂිත පෙරනිමි අගයන් භාවිතා වේ." : "Unpriced combinations detected. Print Helper never silently charges zero; safe fallbacks apply.");
  setTxt("lblBtnFixMissing", isSi ? "නොමැති මිල ගණන් එක්කරන්න (3)" : "Fix Missing Prices (3)");
  setTxt("lblBtnAddPrice", isSi ? "මිල රීතියක් එක්කරන්න" : "Add Price Rule");
  setTxt("lblGroupCardTitle", isSi ? "පාරිභෝගික කණ්ඩායම් සහ වට්ටම්" : "Customer Groups & Discounts");
  setTxt("lblApplyGroupLabel", isSi ? "ගිණුම් වර්ගය:" : "Active Counter Group:");
  setTxt("lblFeesCardTitle", isSi ? "අමතර ගාස්තු, මුදල් සහ වටයන නීති" : "Fees, Surcharges & Rounding");
  setTxt("lblMinJobCharge", isSi ? "අවම රැකියා ගාස්තුව:" : "Minimum Job Charge:");
  setTxt("lblSetupFee", isSi ? "සකස් කිරීමේ ගාස්තුව:" : "Setup / Service Fee:");
  setTxt("lblRushFee", isSi ? "හදිසි මුද්‍රණ ගාස්තුව:" : "Rush Order Surcharge:");
  setTxt("lblBorderlessFee", isSi ? "දාර රහිත ගාස්තුව:" : "Borderless Overspray Fee:");
  setTxt("lblCurrencySelect", isSi ? "මුදල් ඒකකය:" : "Currency:");
  setTxt("lblRoundingSelect", isSi ? "වටයන නීතිය:" : "Configurable Rounding:");
  setTxt("lblSupplyCostTitle", isSi ? "වියදම් සහ ලාභ විශ්ලේෂණය" : "Cost Side & Profit Audit");
  setTxt("lblBtnExportDaily", isSi ? "දෛනික මූල්‍ය වාර්තාව (CSV)" : "Export Daily Financial Audit (CSV)");
  setTxt("lblLivePriceHeader", isSi ? "ඇස්තමේන්තුගත මුළු මුදල" : "Estimated Total");
  setTxt("lblBreakdownBtn", isSi ? "විස්තරය" : "Breakdown");
  setTxt("lblQuoteBtn", isSi ? "මිල ගණන්" : "Quote");
  setTxt("lblBreakdownTitle", isSi ? "මිල ගණන් විස්තරය" : "Pricing Breakdown");
  setTxt("lblSubtotalText", isSi ? "දළ එකතුව:" : "Gross Subtotal:");

  // Multi-Printer Dashboard & Routing Translations
  setTxt("lblPrintersHead", isSi ? "ප්‍රින්ටර් පාලක මැදිරිය සහ කළමනාකරණය" : "Printers & Fleet Management");
  setTxt("lblPrintersSub", isSi ? "PrinterIntelligence තොරතුරු (පළමුව IPP, දෙවනුව SNMP, තෙවනුව Driver) • බහු-ප්‍රින්ටර් මාර්ගගත කිරීම" : "PrinterIntelligence telemetry (IPP first, SNMP second, driver third) • Multi-printer routing");
  setTxt("lblScanSubnetBtn", isSi ? "උපජාල සොයන්න" : "Scan Subnet");
  setTxt("lblSimulateRoutingBtn", isSi ? "මාර්ගගත කිරීම පරීක්ෂා කරන්න" : "Simulate Job Routing");
  setTxt("lblRoutingRulesBtn", isSi ? "මාර්ගගත කිරීමේ නීති" : "Routing Rules");
  setTxt("lblFleetTotal", isSi ? "මුළු ප්‍රින්ටර්" : "Fleet Total");
  setTxt("lblFleetReady", isSi ? "සූදානම්" : "Ready");
  setTxt("lblFleetPrinting", isSi ? "මුද්‍රණය වේ" : "Printing");
  setTxt("lblFleetOffline", isSi ? "ක්‍රියාවිරහිතයි" : "Offline");
  setTxt("lblFleetLowSupply", isSi ? "තීන්ත අඩුයි" : "Low Supplies");
  setTxt("lblLowSupplyThreshold", isSi ? "අවම සීමාව:" : "Alert Threshold:");
  setTxt("lblSubnetScanTitle", isSi ? "ජාල පරිලෝකනය සඳහා අවසරය" : "Subnet Discovery Permission Required");
  setTxt("lblSubnetScanSubtitle", isSi ? "තෝරාගත් CIDR පරාසය තුළ IP ලිපින 254 ක් පරීක්ෂා කෙරේ" : "Probing 254 host IP addresses across the specified CIDR");
  setTxt("lblSubnetScanWarningHead", isSi ? "ජාල ආරක්ෂණ නිවේදනය" : "Network Security Notice");
  setTxt("lblSubnetScanWarningBody", isSi ? "මෙම ක්‍රියාවලියේදී තෝරාගත් උපජාලයේ ලිපින 254 කටම SNMP (Port 161) සහ IPP (Port 631) පැකට් යවනු ලැබේ. ආයතනික ජාල තුළ අනවසර පරිලෝකනය වැළැක්වීමට තහවුරු කරන්න." : "This operation sends SNMP (UDP port 161) and IPP (TCP port 631) discovery packets to all 254 addresses in the subnet. Unapproved scans on corporate networks may trigger intrusion detection alerts.");
  setTxt("lblTargetSubnetLabel", isSi ? "ඉලක්කගත උපජාල CIDR පරාසය:" : "Target Subnet CIDR Range:");
  setTxt("lblAuthorizeSubnetScan", isSi ? "පරිලෝකනය අනුමත කරන්න" : "Authorize & Scan Subnet");
  setTxt("lblFailoverModalTitle", isSi ? "රැකියාව වෙනත් ප්‍රින්ටරයකට මාරු කිරීම" : "Job Rerouting Confirmation");
  setTxt("lblFailoverModalSubtitle", isSi ? "ඉලක්ක ප්‍රින්ටරය ක්‍රියාවිරහිතයි. ක්‍රියාකරුගේ අනුමැතිය අවශ්‍යයි." : "Target printer is offline or unavailable. Operator approval required.");
  setTxt("lblFailoverAlertHead", isSi ? "තෝරාගත් ප්‍රින්ටරයට මෙම රැකියාව කළ නොහැක" : "Selected Printer Cannot Accept This Job");
  setTxt("lblFailoverRationaleHeading", isSi ? "තීරණයට හේතුව (One-line Explanation):" : "Decision Rationale (One-line Explanation):");
  setTxt("lblOriginalTargetLabel", isSi ? "මුල් ඉලක්කය" : "Original Target");
  setTxt("lblProposedFailoverLabel", isSi ? "යෝජිත විකල්පය" : "Proposed Failover");
  setTxt("lblApproveRerouteText", isSi ? "රැකියාව මාරු කරන්න" : "Approve & Reroute Job");
  setTxt("lblRoutingRulesTitle", isSi ? "ප්‍රින්ටර් මාර්ගගත කිරීමේ නීති සහ ප්‍රතිපත්ති" : "Fleet Routing Rules & Policies");
  setTxt("lblRoutingRulesSubtitle", isSi ? "විශේෂිත ද්‍රව්‍ය සීමා, ඉහළ පිටු ප්‍රමාණ සහ බර තුලනය" : "Configurable routing priority, hardware constraints, and load balancing");

  setTxt("currentLangLabel", currentLang === 'si' ? "සිංහල" : "English");
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


// ==========================================================================
// RESOLUTION & EFFECTIVE PPI SYSTEM (PPI vs DPI Engine)
// ==========================================================================

let currentEffectivePpi = 96.0;
let isImageUpscaled = false;
let currentSourceWidth = 1800;
let currentSourceHeight = 1200;

function initResolutionSystem() {
  const selHardwareDpi = document.getElementById("selHardwareDpi");
  const lblDpiSpeedInkNote = document.getElementById("lblDpiSpeedInkNote");
  const selPaperType = document.getElementById("selPaperType");
  const ppiCard = document.getElementById("ppiSharpnessCard");
  const lblPpiTitle = document.getElementById("lblPpiTitle");
  const lblPpiDesc = document.getElementById("lblPpiDesc");
  const iconPpiStatus = document.getElementById("iconPpiStatus");
  const btnOpenPhotoHelper = document.getElementById("btnOpenPhotoHelper");
  const btnOpenResampleModal = document.getElementById("btnOpenResampleModal");

  const dpiNotesEn = {
    "360": "Fastest printing speed; uses minimum ink. Best for everyday rough drafts.",
    "720": "Balanced print speed and standard ink consumption. Excellent for text and office graphics.",
    "1440": "Sharper fine detail and smoother gradients. Moderate speed and ink usage.",
    "2880": "Micro-droplet ultra-fine photo detail. Slower print speed; maximum ink usage.",
    "5760": "Ultra fine laboratory photo quality. Slowest print speed; premium photo media recommended."
  };
  const dpiNotesSi = {
    "360": "අධිවේගී මුද්‍රණය; අවම තීන්ත භාවිතය. සාමාන්‍ය කෙටුම්පත් සඳහා සුදුසුයි.",
    "720": "සමබර මුද්‍රණ වේගය සහ තීන්ත භාවිතය. ලිපි ලේඛන සඳහා වඩාත් සුදුසුයි.",
    "1440": "සියුම් විස්තර සහ පැහැදිලි වර්ණ. මධ්‍යස්ථ වේගයක් සහ තීන්ත ප්‍රමාණයක් ගනී.",
    "2880": "ඉතා සියුම් තීන්ත බිඳිති. සෙමින් මුද්‍රණය වන අතර වැඩි තීන්ත ප්‍රමාණයක් ගනී.",
    "5760": "ඉහළම ඡායාරූප තත්ත්වය. ඉතා සෙමින් මුද්‍රණය වේ; විශේෂ ෆොටෝ කොළ නිර්දේශ කෙරේ."
  };

  function updateDpiNotesAndRestrictions() {
    if (!selHardwareDpi) return;
    const isSi = currentLang === 'si';
    const dpi = selHardwareDpi.value;
    const isPlain = (selPaperType?.value || "").includes("Plain");
    const isGlossy = (selPaperType?.value || "").includes("Glossy") || (selPaperType?.value || "").includes("Photo");

    Array.from(selHardwareDpi.options).forEach(opt => {
      const optDpi = parseInt(opt.value, 10);
      if (isPlain && optDpi >= 2880) {
        opt.disabled = true;
        opt.text = isSi ? `${opt.value} DPI — සාමාන්‍ය කොළ සඳහා අවහිරයි` : `${opt.value} DPI — Blocked on Plain Paper`;
      } else if (isGlossy && optDpi <= 360) {
        opt.disabled = true;
        opt.text = isSi ? `${opt.value} DPI — ග්ලොසි කොළ සඳහා අවහිරයි` : `${opt.value} DPI — Blocked on Glossy`;
      } else {
        opt.disabled = false;
        if (optDpi <= 360) opt.text = isSi ? `${optDpi} DPI — ඉක්මන් කෙටුම්පත` : `${optDpi} DPI — Fast / Draft`;
        else if (optDpi <= 720) opt.text = isSi ? `${optDpi} DPI — සාමාන්‍ය ගුණාත්මක බව` : `${optDpi} DPI — Standard / Normal`;
        else if (optDpi <= 1440) opt.text = isSi ? `${optDpi} DPI — උසස් ගුණාත්මක බව` : `${optDpi} DPI — High Quality / Fine`;
        else if (optDpi <= 2880) opt.text = isSi ? `${optDpi} DPI — ඉහළම ඡායාරූප තත්ත්වය` : `${optDpi} DPI — Best / Photo Grade`;
        else opt.text = isSi ? `${optDpi} DPI — අතිශය සියුම් විස්තර` : `${optDpi} DPI — Ultra Fine Detail`;
      }
    });

    if (lblDpiSpeedInkNote) {
      lblDpiSpeedInkNote.innerText = isSi ? (dpiNotesSi[dpi] || "") : (dpiNotesEn[dpi] || "");
    }
  }

  if (selHardwareDpi) {
    selHardwareDpi.addEventListener("change", () => {
      updateDpiNotesAndRestrictions();
      validateDependenciesAndAutoFixes();
    });
  }

  if (selPaperType) {
    selPaperType.addEventListener("change", () => {
      updateDpiNotesAndRestrictions();
      validateDependenciesAndAutoFixes();
    });
  }

  // Render DPI memory footprint calculation
  const selRenderDpi = document.getElementById("selRenderDpi");
  const renderMemoryIndicator = document.getElementById("renderMemoryIndicator");
  const lblRenderMemoryText = document.getElementById("lblRenderMemoryText");
  if (selRenderDpi && lblRenderMemoryText) {
    selRenderDpi.addEventListener("change", () => {
      const isSi = currentLang === 'si';
      const val = selRenderDpi.value;
      if (val === "1200") {
        renderMemoryIndicator?.classList.add("high-memory");
        lblRenderMemoryText.innerText = isSi
          ? "මතක භාවිතය: ~398 MB/පිටුව (අධික මතකය). PDF අකුරු rasterize නොකරයි."
          : "Est. Memory: ~398 MB/page (High Memory). Vector text preserved directly.";
      } else if (val === "600") {
        renderMemoryIndicator?.classList.remove("high-memory");
        lblRenderMemoryText.innerText = isSi
          ? "මතක භාවිතය: ~100 MB/පිටුව. PDF අකුරු rasterize නොකරයි."
          : "Est. Memory: ~100 MB/page. Vector text preserved directly.";
      } else if (val === "150") {
        renderMemoryIndicator?.classList.remove("high-memory");
        lblRenderMemoryText.innerText = isSi
          ? "මතක භාවිතය: ~6 MB/පිටුව. PDF අකුරු rasterize නොකරයි."
          : "Est. Memory: ~6 MB/page. Vector text preserved directly.";
      } else {
        renderMemoryIndicator?.classList.remove("high-memory");
        lblRenderMemoryText.innerText = isSi
          ? "මතක භාවිතය: ~25 MB/පිටුව. PDF අකුරු rasterize නොකරයි."
          : "Est. Memory: ~25 MB/page. Vector text preserved directly.";
      }
      validateDependenciesAndAutoFixes();
    });
  }

  window.updateEffectivePpiDisplay = function() {
    const isSi = currentLang === 'si';
    const paperSize = document.getElementById("selPaperSize")?.value || "A4";

    const dims = {
      "Passport 35x45 mm": [1.38, 1.77],
      "Visa 2x2 in": [2.0, 2.0],
      "Photo 4x6": [4.0, 6.0],
      "5x7 in": [5.0, 7.0],
      "8x10 in": [8.0, 10.0],
      "A4": [8.27, 11.69],
      "Letter": [8.5, 11.0],
      "Legal": [8.5, 14.0],
      "A3": [11.69, 16.54]
    };

    const [paperW, paperH] = dims[paperSize] || [8.27, 11.69];
    const ppiW = currentSourceWidth / paperH;
    const ppiH = currentSourceHeight / paperW;
    let basePpi = Math.min(ppiW, ppiH);
    if (isImageUpscaled) basePpi *= 2.0;
    currentEffectivePpi = basePpi;

    if (lblPpiTitle && iconPpiStatus && lblPpiDesc) {
      if (currentEffectivePpi >= 299.0) {
        iconPpiStatus.className = "material-symbols-rounded ppi-icon crisp";
        iconPpiStatus.innerText = "verified";
        lblPpiTitle.innerText = isSi
          ? `පැහැදිලි බව: ${Math.round(currentEffectivePpi)} PPI (ඉතා පැහැදිලියි)`
          : `Sharpness: ${Math.round(currentEffectivePpi)} PPI (Crisp / Photo Grade)`;
        lblPpiDesc.innerText = isSi
          ? `${paperSize} කොළයේ මුද්‍රණය සඳහා ඉහළම ඡායාරූප තත්ත්වය ලැබේ.`
          : `Photo-grade crisp quality at current printed size on ${paperSize}.`;
      } else if (currentEffectivePpi >= 149.0) {
        iconPpiStatus.className = "material-symbols-rounded ppi-icon acceptable";
        iconPpiStatus.innerText = "info";
        lblPpiTitle.innerText = isSi
          ? `පැහැදිලි බව: ${Math.round(currentEffectivePpi)} PPI (ප්‍රමාණවත්)`
          : `Sharpness: ${Math.round(currentEffectivePpi)} PPI (Good)`;
        lblPpiDesc.innerText = isSi
          ? `සාමාන්‍ය කියවීමේ දුර සඳහා හොඳ තත්ත්වයකි.`
          : `Good for general documents and viewing from normal reading distances.`;
      } else {
        iconPpiStatus.className = "material-symbols-rounded ppi-icon low";
        iconPpiStatus.innerText = "warning";
        lblPpiTitle.innerText = isSi
          ? `පැහැදිලි බව: ${Math.round(currentEffectivePpi)} PPI (අඩුයි)`
          : `Sharpness: ${Math.round(currentEffectivePpi)} PPI (Low / Pixelated)`;
        lblPpiDesc.innerText = isSi
          ? `${paperSize} කොළයේ මුද්‍රණය කළ විට බොඳ වී හෝ කොටු කොටු වී (pixelated) පෙනීමට ඉඩ ඇත.`
          : `Image may appear blurry, soft, or pixelated when printed on ${paperSize}.`;
      }
    }

    validateDependenciesAndAutoFixes();
  };

  const modalPhotoHelper = document.getElementById("photoHelperModal");
  const btnClosePhotoHelper = document.getElementById("btnClosePhotoHelper");
  const btnCancelPhotoHelper = document.getElementById("btnCancelPhotoHelper");
  const photoSizesList = document.getElementById("photoSizesList");

  window.openPhotoHelperModal = function() {
    if (!modalPhotoHelper || !photoSizesList) return;
    const isSi = currentLang === 'si';

    const standardSizes = [
      { name: "Passport 35x45 mm", wMm: 35.0, hMm: 45.0 },
      { name: "Visa 2x2 in (50x50 mm)", wMm: 50.8, hMm: 50.8 },
      { name: "Photo 4x6 in (10x15 cm)", wMm: 101.6, hMm: 152.4 },
      { name: "Photo 5x7 in (13x18 cm)", wMm: 127.0, hMm: 177.8 },
      { name: "Photo 8x10 in (20x25 cm)", wMm: 203.2, hMm: 254.0 },
      { name: "A4 Document (21x29.7 cm)", wMm: 210.0, hMm: 297.0 },
      { name: "A3 Poster (29.7x42 cm)", wMm: 297.0, hMm: 420.0 }
    ];

    let html = "";
    standardSizes.forEach(s => {
      const paperLong = Math.max(s.wMm, s.hMm);
      const paperShort = Math.min(s.wMm, s.hMm);
      const imgLong = Math.max(currentSourceWidth, currentSourceHeight);
      const imgShort = Math.min(currentSourceWidth, currentSourceHeight);

      const ppiLong = imgLong / (paperLong / 25.4);
      const ppiShort = imgShort / (paperShort / 25.4);
      const ppi = Math.round(Math.min(ppiLong, ppiShort));

      let badgeClass = "low";
      let badgeLabel = isSi ? "අඩුයි" : "Low";
      if (ppi >= 299) {
        badgeClass = "crisp";
        badgeLabel = isSi ? "ඉතා පැහැදිලියි" : "Crisp";
      } else if (ppi >= 149) {
        badgeClass = "acceptable";
        badgeLabel = isSi ? "ප්‍රමාණවත්" : "Good";
      }

      const isRecommended = s.name.includes("4x6");

      html += `
        <div class="photo-size-row ${isRecommended ? 'recommended' : ''}">
          <div class="photo-size-info">
            <div class="size-name-wrap">
              <strong>${s.name}</strong>
              ${isRecommended ? `<span class="badge-best-size">${isSi ? 'උපරිම පැහැදිලි ප්‍රමාණය' : 'Best Crisp Size'}</span>` : ''}
            </div>
            <span class="size-dims-label">${s.wMm} × ${s.hMm} mm</span>
          </div>
          <div class="photo-size-actions">
            <span class="badge-ppi ${badgeClass}">${ppi} PPI (${badgeLabel})</span>
            <button class="btn btn-outline btn-sm btn-pick-size" data-size="${s.name.includes('4x6') ? 'Photo 4x6' : (s.name.includes('A4') ? 'A4' : s.name)}">
              ${isSi ? 'තෝරන්න' : 'Select'}
            </button>
          </div>
        </div>
      `;
    });

    photoSizesList.innerHTML = html;

    photoSizesList.querySelectorAll(".btn-pick-size").forEach(btn => {
      btn.addEventListener("click", () => {
        const chosen = btn.dataset.size;
        const selPaper = document.getElementById("selPaperSize");
        if (selPaper) {
          let found = false;
          for (let opt of selPaper.options) {
            if (opt.value === chosen || chosen.includes(opt.value)) {
              selPaper.value = opt.value;
              found = true;
              break;
            }
          }
          if (!found) selPaper.value = "Photo 4x6";
        }
        modalPhotoHelper.classList.add("hidden");
        updateLiveSummary();
        window.updateEffectivePpiDisplay();
        showToast(isSi ? `කඩදාසි ප්‍රමාණය ${chosen} ලෙස තෝරාගැනිණි.` : `Paper size changed to ${chosen}.`);
      });
    });

    modalPhotoHelper.classList.remove("hidden");
  };

  if (btnOpenPhotoHelper) btnOpenPhotoHelper.addEventListener("click", window.openPhotoHelperModal);
  if (btnClosePhotoHelper) btnClosePhotoHelper.addEventListener("click", () => modalPhotoHelper.classList.add("hidden"));
  if (btnCancelPhotoHelper) btnCancelPhotoHelper.addEventListener("click", () => modalPhotoHelper.classList.add("hidden"));

  const txtCustomW = document.getElementById("txtCustomWidthCm");
  const txtCustomH = document.getElementById("txtCustomHeightCm");
  const badgeCustomPpi = document.getElementById("badgeCustomPpi");
  function recalcCustomPpi() {
    if (!txtCustomW || !txtCustomH || !badgeCustomPpi) return;
    const isSi = currentLang === 'si';
    const w = parseFloat(txtCustomW.value) || 15.0;
    const h = parseFloat(txtCustomH.value) || 10.0;
    const wIn = (w * 10.0) / 25.4;
    const hIn = (h * 10.0) / 25.4;
    const ppiW = currentSourceWidth / Math.max(0.1, wIn);
    const ppiH = currentSourceHeight / Math.max(0.1, hIn);
    const ppi = Math.round(Math.min(ppiW, ppiH));

    if (ppi >= 299) {
      badgeCustomPpi.className = "badge-ppi crisp";
      badgeCustomPpi.innerText = `${ppi} PPI (${isSi ? 'ඉතා පැහැදිලියි' : 'Crisp'})`;
    } else if (ppi >= 149) {
      badgeCustomPpi.className = "badge-ppi acceptable";
      badgeCustomPpi.innerText = `${ppi} PPI (${isSi ? 'ප්‍රමාණවත්' : 'Good'})`;
    } else {
      badgeCustomPpi.className = "badge-ppi low";
      badgeCustomPpi.innerText = `${ppi} PPI (${isSi ? 'අඩුයි' : 'Low'})`;
    }
  }
  if (txtCustomW) txtCustomW.addEventListener("input", recalcCustomPpi);
  if (txtCustomH) txtCustomH.addEventListener("input", recalcCustomPpi);

  const modalResample = document.getElementById("resamplePreviewModal");
  const btnCloseResampleModal = document.getElementById("btnCloseResampleModal");
  const btnCancelResample = document.getElementById("btnCancelResample");
  const btnApplyResample = document.getElementById("btnApplyResample");
  const selModalMultiplier = document.getElementById("selModalMultiplier");
  const selModalResampleAlgo = document.getElementById("selModalResampleAlgo");
  const lblResampleAlgoDesc = document.getElementById("lblResampleAlgoDesc");
  const lblAfterSpecs = document.getElementById("lblAfterSpecs");
  const badgeAfterPpi = document.getElementById("badgeAfterPpi");

  const algoDescriptions = {
    none: "None (Nearest Neighbor): Preserves exact raw pixels. Fast, but produces blocky pixels if upscaled.",
    bicubic: "Bicubic Interpolation: Smooth cubic curve interpolation. Standard for office graphics and photos.",
    lanczos: "Lanczos-3 (Windowed Sinc): High-fidelity 3-lobe sinc filter. Preserves sharp photo edges without ringing or blur."
  };

  function updateResamplePreviewValues() {
    const isSi = currentLang === 'si';
    const mult = parseFloat(selModalMultiplier?.value || "2.0");
    const algo = selModalResampleAlgo?.value || "lanczos";
    const targetW = Math.round(currentSourceWidth * mult);
    const targetH = Math.round(currentSourceHeight * mult);
    const newPpi = Math.round(currentEffectivePpi * mult);

    if (lblResampleAlgoDesc) {
      lblResampleAlgoDesc.innerText = algoDescriptions[algo] || algoDescriptions.lanczos;
    }
    if (lblAfterSpecs) {
      lblAfterSpecs.innerText = `${targetW} × ${targetH} px`;
    }
    if (badgeAfterPpi) {
      if (newPpi >= 299) {
        badgeAfterPpi.className = "badge-ppi crisp";
        badgeAfterPpi.innerText = `${newPpi} PPI (${isSi ? 'ඉතා පැහැදිලියි' : 'Crisp'})`;
      } else if (newPpi >= 149) {
        badgeAfterPpi.className = "badge-ppi acceptable";
        badgeAfterPpi.innerText = `${newPpi} PPI (${isSi ? 'ප්‍රමාණවත්' : 'Good'})`;
      } else {
        badgeAfterPpi.className = "badge-ppi low";
        badgeAfterPpi.innerText = `${newPpi} PPI (${isSi ? 'අඩුයි' : 'Low'})`;
      }
    }
  }

  if (selModalMultiplier) selModalMultiplier.addEventListener("change", updateResamplePreviewValues);
  if (selModalResampleAlgo) selModalResampleAlgo.addEventListener("change", updateResamplePreviewValues);

  if (btnOpenResampleModal) {
    btnOpenResampleModal.addEventListener("click", () => {
      updateResamplePreviewValues();
      modalResample?.classList.remove("hidden");
    });
  }
  if (btnCloseResampleModal) btnCloseResampleModal.addEventListener("click", () => modalResample?.classList.add("hidden"));
  if (btnCancelResample) btnCancelResample.addEventListener("click", () => modalResample?.classList.add("hidden"));

  if (btnApplyResample) {
    btnApplyResample.addEventListener("click", () => {
      isImageUpscaled = true;
      modalResample?.classList.add("hidden");
      window.updateEffectivePpiDisplay();
      showToast(currentLang === 'si' ? "2x Lanczos මඟින් රූපය විශාල කරන ලදී! මුද්‍රණ ලඝු-සටහනෙහි ලියාපදිංචි විය." : "2x Lanczos upscale applied! Transformation logged in print records.");
    });
  }

  updateDpiNotesAndRestrictions();
  window.updateEffectivePpiDisplay();
}

// ==========================================================================
// TONE AND INK ADJUSTMENT SYSTEM (Prompt 10)
// ==========================================================================

function initToneAndInkSystem() {
  const paperPresets = {
    none: {
      density: 0,
      brightness: 0,
      contrast: 0,
      gamma: 1.0,
      shadows: 0,
      highlights: 0,
      blackLevel: 0,
      textDarkness: 0,
      textSharpening: 0,
      photoSharpening: 0,
      saturation: 0,
      vibrance: 0,
      descEn: "Standard uncompensated output.",
      descSi: "සාමාන්‍ය නොවෙනස් ප්‍රතිදානය."
    },
    plainPaper: {
      density: -6,
      brightness: 0,
      contrast: 0,
      gamma: 1.0,
      shadows: 0,
      highlights: 0,
      blackLevel: 0,
      textDarkness: 12,
      textSharpening: 15,
      photoSharpening: 0,
      saturation: 0,
      vibrance: 0,
      descEn: "Lifts midtones (+8), text darkness (+12), text sharp (+15), lowers density (-6) to prevent fiber bleed.",
      descSi: "තීන්ත කොළය තුළට කාන්දු වීම වළක්වා අකුරු පැහැදිලි කරයි."
    },
    mattePaper: {
      density: 0,
      brightness: 0,
      contrast: 0,
      gamma: 1.08,
      shadows: 0,
      highlights: 0,
      blackLevel: 12,
      textDarkness: 0,
      textSharpening: 0,
      photoSharpening: 0,
      saturation: 0,
      vibrance: 0,
      descEn: "Compensates for ink absorption by deepening shadows (Black Level +12, Gamma 1.08).",
      descSi: "මැට් කොළ වල තීන්ත උරාගැනීම නිසා කළු වර්ණය දුර්වල වීම වළක්වයි."
    },
    glossyPhoto: {
      density: 0,
      brightness: 0,
      contrast: 10,
      gamma: 1.0,
      shadows: 0,
      highlights: 0,
      blackLevel: 0,
      textDarkness: 0,
      textSharpening: 0,
      photoSharpening: 16,
      saturation: 6,
      vibrance: 8,
      descEn: "Maximizes dynamic range on resin-coated paper (Contrast +10, Vibrance +8, Sat +6, Photo sharp +16).",
      descSi: "ග්ලොසි කොළ වල සම්පූර්ණ වර්ණ පරාසය සහ දීප්තිමත් බව ඉහළ නංවයි."
    }
  };

  // Slider Elements
  const selTonePaperPreset = document.getElementById("selTonePaperPreset");
  const lblTonePaperPresetDesc = document.getElementById("lblTonePaperPresetDesc");

  const rangeDensity = document.getElementById("rangeDensity");
  const valDensity = document.getElementById("valDensity");
  const rangeBrightness = document.getElementById("rangeBrightness");
  const valBrightness = document.getElementById("valBrightness");
  const rangeContrast = document.getElementById("rangeContrast");
  const valContrast = document.getElementById("valContrast");
  const rangeGamma = document.getElementById("rangeGamma");
  const valGamma = document.getElementById("valGamma");

  const rangeShadows = document.getElementById("rangeShadows");
  const valShadows = document.getElementById("valShadows");
  const rangeHighlights = document.getElementById("rangeHighlights");
  const valHighlights = document.getElementById("valHighlights");

  const rangeBlackLevel = document.getElementById("rangeBlackLevel");
  const valBlackLevel = document.getElementById("valBlackLevel");
  const rangeTextDarkness = document.getElementById("rangeTextDarkness");
  const valTextDarkness = document.getElementById("valTextDarkness");

  const rangeTextSharp = document.getElementById("rangeTextSharp");
  const valTextSharp = document.getElementById("valTextSharp");
  const rangePhotoSharp = document.getElementById("rangePhotoSharp");
  const valPhotoSharp = document.getElementById("valPhotoSharp");

  const rangeSaturation = document.getElementById("rangeSaturation");
  const valSaturation = document.getElementById("valSaturation");
  const rangeVibrance = document.getElementById("rangeVibrance");
  const valVibrance = document.getElementById("valVibrance");

  const rangeBalanceCR = document.getElementById("rangeBalanceCR");
  const valBalanceCR = document.getElementById("valBalanceCR");
  const rangeBalanceMG = document.getElementById("rangeBalanceMG");
  const valBalanceMG = document.getElementById("valBalanceMG");
  const rangeBalanceYB = document.getElementById("rangeBalanceYB");
  const valBalanceYB = document.getElementById("valBalanceYB");

  // Ink Saver
  const cardInkSaver = document.getElementById("cardInkSaver");
  const chkInkSaverMode = document.getElementById("chkInkSaverMode");
  const inkSaverDetails = document.getElementById("inkSaverDetails");
  const selInkSaverLevel = document.getElementById("selInkSaverLevel");
  const chkInkSaverTextOnlyBlack = document.getElementById("chkInkSaverTextOnlyBlack");
  const lblSavingsPercent = document.getElementById("lblSavingsPercent");

  // CMYK Coverage
  const lblTotalCoverage = document.getElementById("lblTotalCoverage");
  const barCovCyan = document.getElementById("barCovCyan");
  const barCovMagenta = document.getElementById("barCovMagenta");
  const barCovYellow = document.getElementById("barCovYellow");
  const barCovBlack = document.getElementById("barCovBlack");
  const valCovCyan = document.getElementById("valCovCyan");
  const valCovMagenta = document.getElementById("valCovMagenta");
  const valCovYellow = document.getElementById("valCovYellow");
  const valCovBlack = document.getElementById("valCovBlack");

  // Actions & Badges
  const btnResetTone = document.getElementById("btnResetTone");
  const btnCompareOriginal = document.getElementById("btnCompareOriginal");
  const btnOpenTestPatternModal = document.getElementById("btnOpenTestPatternModal");
  const previewApproxBadge = document.getElementById("previewApproxBadge");
  const compareModeBadge = document.getElementById("compareModeBadge");
  const paperSheetSimulated = document.getElementById("paperSheetSimulated");

  // Test Pattern Modal
  const testPatternModal = document.getElementById("testPatternModal");
  const btnCloseTestPatternModal = document.getElementById("btnCloseTestPatternModal");
  const btnCancelTestPattern = document.getElementById("btnCancelTestPattern");
  const btnOpenDriverMaint = document.getElementById("btnOpenDriverMaint");
  const btnPrintTestPageNow = document.getElementById("btnPrintTestPageNow");

  function formatSignVal(v) {
    const num = typeof v === 'number' ? v : parseFloat(v);
    if (isNaN(num)) return "0";
    return num > 0 ? `+${num}` : `${num}`;
  }

  function updateToneAndInkLiveEffect() {
    if (!paperSheetSimulated) return;

    if (toneAndInkState.compareWithOriginal) {
      paperSheetSimulated.style.filter = "none";
      paperSheetSimulated.style.opacity = "1";
      if (compareModeBadge) compareModeBadge.classList.remove("hidden");
      if (previewApproxBadge) previewApproxBadge.classList.add("hidden");
      return;
    }

    if (compareModeBadge) compareModeBadge.classList.add("hidden");

    const b = 100 + (toneAndInkState.brightness * 0.35) + (toneAndInkState.density * 0.2);
    const c = 100 + (toneAndInkState.contrast * 0.45);
    const s = 100 + (toneAndInkState.saturation * 0.5) + (toneAndInkState.vibrance * 0.25);

    paperSheetSimulated.style.filter = `brightness(${b}%) contrast(${c}%) saturate(${s}%)`;

    if (toneAndInkState.inkSaverEnabled) {
      paperSheetSimulated.style.opacity = "0.92";
    } else {
      paperSheetSimulated.style.opacity = "1.0";
    }

    const hasAdjustments = hasActiveToneAdjustments();
    if (previewApproxBadge) {
      previewApproxBadge.classList.toggle("hidden", !hasAdjustments);
    }

    if (btnResetTone) {
      btnResetTone.disabled = !hasAdjustments;
    }
  }

  function updateCmykCoverageMeter() {
    const baseC = 4.2;
    const baseM = 3.8;
    const baseY = 5.1;
    const baseK = 8.4;

    const densityFactor = Math.max(0.3, 1.0 + (toneAndInkState.density / 100) * 0.5);
    const saverDiscount = toneAndInkState.inkSaverEnabled ? (getToneInkSaverSavingsPercent() / 100) : 0;
    const generalFactor = 1.0 - saverDiscount;

    let covC = baseC * densityFactor * generalFactor;
    let covM = baseM * densityFactor * generalFactor;
    let covY = baseY * densityFactor * generalFactor;
    let covK = baseK * densityFactor * generalFactor;

    if (toneAndInkState.inkSaverEnabled && toneAndInkState.inkSaverTextOnlyBlack) {
      covC *= 0.75;
      covM *= 0.75;
      covY *= 0.75;
    }

    const total = covC + covM + covY + covK;

    if (lblTotalCoverage) lblTotalCoverage.innerText = `Total: ${total.toFixed(1)}%`;
    if (barCovCyan) barCovCyan.style.width = `${Math.min(100, covC * 3.5).toFixed(1)}%`;
    if (barCovMagenta) barCovMagenta.style.width = `${Math.min(100, covM * 3.5).toFixed(1)}%`;
    if (barCovYellow) barCovYellow.style.width = `${Math.min(100, covY * 3.5).toFixed(1)}%`;
    if (barCovBlack) barCovBlack.style.width = `${Math.min(100, covK * 3.5).toFixed(1)}%`;

    if (valCovCyan) valCovCyan.innerText = `${covC.toFixed(1)}%`;
    if (valCovMagenta) valCovMagenta.innerText = `${covM.toFixed(1)}%`;
    if (valCovYellow) valCovYellow.innerText = `${covY.toFixed(1)}%`;
    if (valCovBlack) valCovBlack.innerText = `${covK.toFixed(1)}%`;
  }

  function syncAllSliderUI() {
    if (rangeDensity) rangeDensity.value = toneAndInkState.density;
    if (valDensity) valDensity.innerText = formatSignVal(toneAndInkState.density);

    if (rangeBrightness) rangeBrightness.value = toneAndInkState.brightness;
    if (valBrightness) valBrightness.innerText = formatSignVal(toneAndInkState.brightness);

    if (rangeContrast) rangeContrast.value = toneAndInkState.contrast;
    if (valContrast) valContrast.innerText = formatSignVal(toneAndInkState.contrast);

    if (rangeGamma) rangeGamma.value = toneAndInkState.gamma;
    if (valGamma) valGamma.innerText = toneAndInkState.gamma.toFixed(2);

    if (rangeShadows) rangeShadows.value = toneAndInkState.shadows;
    if (valShadows) valShadows.innerText = formatSignVal(toneAndInkState.shadows);

    if (rangeHighlights) rangeHighlights.value = toneAndInkState.highlights;
    if (valHighlights) valHighlights.innerText = formatSignVal(toneAndInkState.highlights);

    if (rangeBlackLevel) rangeBlackLevel.value = toneAndInkState.blackLevel;
    if (valBlackLevel) valBlackLevel.innerText = formatSignVal(toneAndInkState.blackLevel);

    if (rangeTextDarkness) rangeTextDarkness.value = toneAndInkState.textDarkness;
    if (valTextDarkness) valTextDarkness.innerText = formatSignVal(toneAndInkState.textDarkness);

    if (rangeTextSharp) rangeTextSharp.value = toneAndInkState.textSharpening;
    if (valTextSharp) valTextSharp.innerText = `${toneAndInkState.textSharpening}`;

    if (rangePhotoSharp) rangePhotoSharp.value = toneAndInkState.photoSharpening;
    if (valPhotoSharp) valPhotoSharp.innerText = `${toneAndInkState.photoSharpening}`;

    if (rangeSaturation) rangeSaturation.value = toneAndInkState.saturation;
    if (valSaturation) valSaturation.innerText = formatSignVal(toneAndInkState.saturation);

    if (rangeVibrance) rangeVibrance.value = toneAndInkState.vibrance;
    if (valVibrance) valVibrance.innerText = formatSignVal(toneAndInkState.vibrance);

    if (rangeBalanceCR) rangeBalanceCR.value = toneAndInkState.colorBalanceCyanRed;
    if (valBalanceCR) valBalanceCR.innerText = formatSignVal(toneAndInkState.colorBalanceCyanRed);

    if (rangeBalanceMG) rangeBalanceMG.value = toneAndInkState.colorBalanceMagentaGreen;
    if (valBalanceMG) valBalanceMG.innerText = formatSignVal(toneAndInkState.colorBalanceMagentaGreen);

    if (rangeBalanceYB) rangeBalanceYB.value = toneAndInkState.colorBalanceYellowBlue;
    if (valBalanceYB) valBalanceYB.innerText = formatSignVal(toneAndInkState.colorBalanceYellowBlue);
  }

  // Bind Slider Events
  function bindSlider(slider, label, stateKey, isFloat = false) {
    if (!slider) return;
    slider.addEventListener("input", (e) => {
      const val = isFloat ? parseFloat(e.target.value) : parseInt(e.target.value, 10);
      toneAndInkState[stateKey] = val;
      if (label) label.innerText = isFloat ? val.toFixed(2) : formatSignVal(val);
      updateToneAndInkLiveEffect();
      updateCmykCoverageMeter();
      validateDependenciesAndAutoFixes();
    });
  }

  bindSlider(rangeDensity, valDensity, "density");
  bindSlider(rangeBrightness, valBrightness, "brightness");
  bindSlider(rangeContrast, valContrast, "contrast");
  bindSlider(rangeGamma, valGamma, "gamma", true);

  bindSlider(rangeShadows, valShadows, "shadows");
  bindSlider(rangeHighlights, valHighlights, "highlights");
  bindSlider(rangeBlackLevel, valBlackLevel, "blackLevel");
  bindSlider(rangeTextDarkness, valTextDarkness, "textDarkness");
  bindSlider(rangeTextSharp, valTextSharp, "textSharpening");
  bindSlider(rangePhotoSharp, valPhotoSharp, "photoSharpening");

  bindSlider(rangeSaturation, valSaturation, "saturation");
  bindSlider(rangeVibrance, valVibrance, "vibrance");
  bindSlider(rangeBalanceCR, valBalanceCR, "colorBalanceCyanRed");
  bindSlider(rangeBalanceMG, valBalanceMG, "colorBalanceMagentaGreen");
  bindSlider(rangeBalanceYB, valBalanceYB, "colorBalanceYellowBlue");

  // Paper Preset Dropdown
  if (selTonePaperPreset) {
    selTonePaperPreset.addEventListener("change", (e) => {
      const pKey = e.target.value;
      toneAndInkState.paperCompensation = pKey;
      const p = paperPresets[pKey] || paperPresets.none;
      const isSi = currentLang === 'si';

      toneAndInkState.density = p.density;
      toneAndInkState.brightness = p.brightness;
      toneAndInkState.contrast = p.contrast;
      toneAndInkState.gamma = p.gamma;
      toneAndInkState.shadows = p.shadows;
      toneAndInkState.highlights = p.highlights;
      toneAndInkState.blackLevel = p.blackLevel;
      toneAndInkState.textDarkness = p.textDarkness;
      toneAndInkState.textSharpening = p.textSharpening;
      toneAndInkState.photoSharpening = p.photoSharpening;
      toneAndInkState.saturation = p.saturation;
      toneAndInkState.vibrance = p.vibrance;

      syncAllSliderUI();
      if (lblTonePaperPresetDesc) {
        lblTonePaperPresetDesc.innerText = isSi ? p.descSi : p.descEn;
      }

      updateToneAndInkLiveEffect();
      updateCmykCoverageMeter();
      validateDependenciesAndAutoFixes();
    });
  }

  // Ink Saver
  function updateInkSaverSavingsDisplay() {
    const pct = getToneInkSaverSavingsPercent();
    const isSi = currentLang === 'si';
    if (lblSavingsPercent) {
      lblSavingsPercent.innerText = isSi
        ? `~${pct}% තීන්ත ඉතිරියක් (ඇස්තමේන්තුව)`
        : `~${pct}% ink saved (estimate)`;
    }
  }

  if (chkInkSaverMode) {
    chkInkSaverMode.addEventListener("change", (e) => {
      toneAndInkState.inkSaverEnabled = e.target.checked;
      if (cardInkSaver) cardInkSaver.classList.toggle("active", e.target.checked);
      if (inkSaverDetails) inkSaverDetails.classList.toggle("hidden", !e.target.checked);
      updateInkSaverSavingsDisplay();
      updateToneAndInkLiveEffect();
      updateCmykCoverageMeter();
    });
  }

  if (selInkSaverLevel) {
    selInkSaverLevel.addEventListener("change", (e) => {
      toneAndInkState.inkSaverLevel = e.target.value;
      updateInkSaverSavingsDisplay();
      updateCmykCoverageMeter();
    });
  }

  if (chkInkSaverTextOnlyBlack) {
    chkInkSaverTextOnlyBlack.addEventListener("change", (e) => {
      toneAndInkState.inkSaverTextOnlyBlack = e.target.checked;
      updateInkSaverSavingsDisplay();
      updateCmykCoverageMeter();
    });
  }

  // Reset Button
  if (btnResetTone) {
    btnResetTone.addEventListener("click", () => {
      toneAndInkState = {
        density: 0,
        brightness: 0,
        contrast: 0,
        gamma: 1.0,
        shadows: 0,
        highlights: 0,
        blackLevel: 0,
        textDarkness: 0,
        textSharpening: 0,
        photoSharpening: 0,
        saturation: 0,
        vibrance: 0,
        colorBalanceCyanRed: 0,
        colorBalanceMagentaGreen: 0,
        colorBalanceYellowBlue: 0,
        paperCompensation: "none",
        inkSaverEnabled: false,
        inkSaverLevel: "balanced",
        inkSaverTextOnlyBlack: true,
        compareWithOriginal: false,
        driverColorAdjustmentActive: false
      };

      if (selTonePaperPreset) selTonePaperPreset.value = "none";
      if (lblTonePaperPresetDesc) {
        lblTonePaperPresetDesc.innerText = currentLang === 'si' ? paperPresets.none.descSi : paperPresets.none.descEn;
      }
      if (chkInkSaverMode) chkInkSaverMode.checked = false;
      if (cardInkSaver) cardInkSaver.classList.remove("active");
      if (inkSaverDetails) inkSaverDetails.classList.add("hidden");

      syncAllSliderUI();
      updateToneAndInkLiveEffect();
      updateCmykCoverageMeter();
      validateDependenciesAndAutoFixes();

      showToast(currentLang === 'si' ? "තීන්ත සහ වර්ණ වෙනස්කම් මුල් තත්ත්වයට පත් කරන ලදී." : "Tone and ink adjustments reset to default.");
    });
  }

  // Compare Original Button
  if (btnCompareOriginal) {
    btnCompareOriginal.addEventListener("click", () => {
      toneAndInkState.compareWithOriginal = !toneAndInkState.compareWithOriginal;
      const isSi = currentLang === 'si';
      const lblBtnCompare = document.getElementById("lblBtnCompare");

      if (lblBtnCompare) {
        lblBtnCompare.innerText = toneAndInkState.compareWithOriginal
          ? (isSi ? "සංසන්දනය නවත්වන්න" : "Stop Compare")
          : (isSi ? "මුල් පිටුව සමඟ බලන්න" : "Compare Original");
      }
      btnCompareOriginal.classList.toggle("btn-primary", toneAndInkState.compareWithOriginal);
      updateToneAndInkLiveEffect();
    });
  }

  // Test Pattern Modal Dialog
  if (btnOpenTestPatternModal) {
    btnOpenTestPatternModal.addEventListener("click", () => {
      testPatternModal?.classList.remove("hidden");
    });
  }

  if (btnCloseTestPatternModal) {
    btnCloseTestPatternModal.addEventListener("click", () => testPatternModal?.classList.add("hidden"));
  }
  if (btnCancelTestPattern) {
    btnCancelTestPattern.addEventListener("click", () => testPatternModal?.classList.add("hidden"));
  }

  if (btnOpenDriverMaint) {
    btnOpenDriverMaint.addEventListener("click", () => {
      testPatternModal?.classList.add("hidden");
      showToast(currentLang === 'si' ? "Epson Printing Preferences (Maintenance) විවෘත වේ..." : "Opening Epson Printing Preferences (Maintenance Tab)...");
    });
  }

  if (btnPrintTestPageNow) {
    btnPrintTestPageNow.addEventListener("click", () => {
      testPatternModal?.classList.add("hidden");
      showToast(currentLang === 'si'
        ? "පරීක්ෂණ පිටුව සාමාන්‍ය Windows Spooler හරහා ප්‍රින්ටරයට යවන ලදී (100% Vector)."
        : "Diagnostic Test Pattern sent to printer spooler (Vector Gray Ramp & Nozzle Chart).");
    });
  }

  window.updateToneAndInkLiveEffect = updateToneAndInkLiveEffect;
  window.updateCmykCoverageMeter = updateCmykCoverageMeter;

  syncAllSliderUI();
  updateToneAndInkLiveEffect();
  updateCmykCoverageMeter();
}

// ==========================================================================
// FULL MULTIDIMENSIONAL PRICING ENGINE & LIVE QUOTE (Prompt 11)
// ==========================================================================

const defaultPricingEntries = [
  {
    id: "rule_a4_bw_single",
    labelEn: "A4 Document B&W Single (Plain)",
    labelSi: "A4 ලේඛන කළු සුදු එක් පැත්තක්",
    printType: "document_text",
    color: "bw",
    paperSize: "A4",
    media: "plain",
    duplex: false,
    quality: "normal",
    printer: "any",
    basePrice: 15.0,
    tiers: [
      { min: 1, max: 10, price: 15.0 },
      { min: 11, max: 50, price: 12.0 },
      { min: 51, max: 200, price: 10.0 },
      { min: 201, max: null, price: 8.0 }
    ]
  },
  {
    id: "rule_a4_bw_duplex",
    labelEn: "A4 Document B&W Duplex (Per Page)",
    labelSi: "A4 ලේඛන කළු සුදු දෙපැත්තම (පිටුවකට)",
    printType: "document_text",
    color: "bw",
    paperSize: "A4",
    media: "plain",
    duplex: true,
    quality: "normal",
    printer: "any",
    basePrice: 10.0,
    tiers: [
      { min: 1, max: 10, price: 10.0 },
      { min: 11, max: 50, price: 8.5 },
      { min: 51, max: 200, price: 7.0 },
      { min: 201, max: null, price: 6.0 }
    ]
  },
  {
    id: "rule_a4_color_single",
    labelEn: "A4 Document Color Single (Plain)",
    labelSi: "A4 ලේඛන වර්ණ එක් පැත්තක්",
    printType: "document_text",
    color: "color",
    paperSize: "A4",
    media: "plain",
    duplex: false,
    quality: "normal",
    printer: "any",
    basePrice: 40.0,
    tiers: [
      { min: 1, max: 10, price: 40.0 },
      { min: 11, max: 50, price: 35.0 },
      { min: 51, max: null, price: 30.0 }
    ]
  },
  {
    id: "rule_a4_color_duplex",
    labelEn: "A4 Document Color Duplex (Per Page)",
    labelSi: "A4 ලේඛන වර්ණ දෙපැත්තම (පිටුවකට)",
    printType: "document_text",
    color: "color",
    paperSize: "A4",
    media: "plain",
    duplex: true,
    quality: "normal",
    printer: "any",
    basePrice: 35.0,
    tiers: [
      { min: 1, max: 10, price: 35.0 },
      { min: 11, max: 50, price: 30.0 },
      { min: 51, max: null, price: 25.0 }
    ]
  },
  {
    id: "rule_photo_4x6_glossy",
    labelEn: "Photo 4x6 in (Glossy Resin)",
    labelSi: "4x6 ඡායාරූප මුද්‍රණය (Glossy)",
    printType: "photo",
    color: "color",
    paperSize: "4x6",
    media: "glossy_photo",
    duplex: false,
    quality: "high",
    printer: "any",
    basePrice: 80.0,
    tiers: [
      { min: 1, max: 5, price: 80.0 },
      { min: 6, max: 20, price: 70.0 },
      { min: 21, max: null, price: 60.0 }
    ]
  },
  {
    id: "rule_photo_5x7_glossy",
    labelEn: "Photo 5x7 in (Glossy Resin)",
    labelSi: "5x7 ඡායාරූප මුද්‍රණය (Glossy)",
    printType: "photo",
    color: "color",
    paperSize: "5x7",
    media: "glossy_photo",
    duplex: false,
    quality: "high",
    printer: "any",
    basePrice: 140.0,
    tiers: []
  },
  {
    id: "rule_a4_photo_glossy",
    labelEn: "A4 Full Page Photo (Glossy Resin)",
    labelSi: "A4 සම්පූර්ණ පිටු ඡායාරූප (Glossy)",
    printType: "photo",
    color: "color",
    paperSize: "A4",
    media: "glossy_photo",
    duplex: false,
    quality: "high",
    printer: "any",
    basePrice: 180.0,
    tiers: []
  },
  {
    id: "rule_id_passport_sheet",
    labelEn: "ID / Passport Photo Sheet (8 photos)",
    labelSi: "හැඳුනුම්පත් / පාස්පෝට් ඡායාරූප පත්‍රිකාව",
    printType: "id_passport_photo",
    color: "color",
    paperSize: "4x6",
    media: "glossy_photo",
    duplex: false,
    quality: "best",
    printer: "any",
    basePrice: 250.0,
    tiers: []
  },
  {
    id: "rule_a3_bw_single",
    labelEn: "A3 Document B&W Single",
    labelSi: "A3 ලේඛන කළු සුදු එක් පැත්තක්",
    printType: "document_text",
    color: "bw",
    paperSize: "A3",
    media: "plain",
    duplex: false,
    quality: "normal",
    printer: "any",
    basePrice: 35.0,
    tiers: []
  },
  {
    id: "rule_a3_color_single",
    labelEn: "A3 Document Color Single",
    labelSi: "A3 ලේඛන වර්ණ එක් පැත්තක්",
    printType: "document_text",
    color: "color",
    paperSize: "A3",
    media: "plain",
    duplex: false,
    quality: "normal",
    printer: "any",
    basePrice: 90.0,
    tiers: []
  },
  {
    id: "rule_photocopy_bw",
    labelEn: "Photocopy B&W (A4 Walk-in)",
    labelSi: "ෆොටෝ කොපි කළු සුදු (A4)",
    printType: "copy",
    color: "bw",
    paperSize: "A4",
    media: "plain",
    duplex: false,
    quality: "draft",
    printer: "any",
    basePrice: 10.0,
    tiers: [
      { min: 1, max: 10, price: 10.0 },
      { min: 11, max: 50, price: 8.0 },
      { min: 51, max: null, price: 6.0 }
    ]
  }
];

let shopPricingEngine = {
  activePackageId: "master",
  activeCustomerGroup: "walk_in",
  entries: [...defaultPricingEntries],
  currency: "LKR",
  rounding: "nearest_1",
  minimumJobCharge: 30.0,
  setupFee: 0.0,
  rushFeePercent: 25.0,
  borderlessSurcharge: 20.0,
  isPinLocked: true,
  masterPin: "1234",
  customerGroups: {
    walk_in: { nameEn: "Walk-in Customer", nameSi: "සාමාන්‍ය පාරිභෝගිකයා", discountPct: 0, freePages: 0 },
    student: { nameEn: "Student Discount (15%)", nameSi: "ශිෂ්‍ය වට්ටම (15%)", discountPct: 15, freePages: 0 },
    business: { nameEn: "Business Account (2 Free Pages)", nameSi: "ව්‍යාපාරික ගිණුම (නොමිලේ පිටු 2)", discountPct: 10, freePages: 2 }
  },
  supplyCosts: {
    blackInkCostPerPage: 0.71,
    colorInkCostPerPage: 1.73,
    a4PlainSheetCost: 4.50,
    photoSheetCost: 25.00
  },
  auditLog: [
    { timestamp: "2026-10-27 00:45", user: "Shop Owner", ruleId: "rule_a4_bw_single", field: "tiers[11-50]", oldVal: "Rs. 13.00", newVal: "Rs. 12.00", reason: "Volume tier alignment" },
    { timestamp: "2026-10-26 18:20", user: "Shop Owner", ruleId: "rule_photo_4x6_glossy", field: "basePrice", oldVal: "Rs. 75.00", newVal: "Rs. 80.00", reason: "Resin photo paper hike" }
  ]
};

function formatEnginePrice(amount) {
  const cur = shopPricingEngine.currency;
  const rounding = shopPricingEngine.rounding;
  const isSi = currentLang === 'si';
  const sym = cur === 'LKR' ? (isSi ? 'රු.' : 'Rs.') : (cur === 'USD' ? '$' : (cur === 'EUR' ? '€' : (cur === 'GBP' ? '£' : '₹')));

  let rounded = amount;
  if (rounding === 'nearest_1') rounded = Math.round(amount);
  else if (rounding === 'nearest_5') rounded = Math.round(amount / 5.0) * 5.0;
  else if (rounding === 'nearest_10') rounded = Math.round(amount / 10.0) * 10.0;
  else if (rounding === 'nearest_50') rounded = Math.round(amount / 50.0) * 50.0;

  if (rounding === 'none') {
    return `${sym} ${rounded.toFixed(2)}`;
  }
  return `${sym} ${Math.round(rounded)}.00`;
}

function matchPriceRule(printType, color, size, media, duplex) {
  let best = null;
  let bestScore = -1;

  for (const r of shopPricingEngine.entries) {
    let score = 0;
    if (r.printType === printType) score += 100;
    else if (r.printType !== 'any') continue;

    if (r.color === color) score += 80;
    else if (r.color !== 'any') continue;

    if (r.paperSize.toLowerCase().includes(size.toLowerCase())) score += 60;
    else if (r.paperSize !== 'any') continue;

    if (r.media === media) score += 50;
    else if (r.media !== 'any') continue;

    if (r.duplex === duplex) score += 40;
    else if (r.duplex !== null && r.duplex !== undefined) continue;

    if (score > bestScore) {
      bestScore = score;
      best = r;
    }
  }
  return best;
}

function calculateCurrentQueueQuote() {
  const isSi = currentLang === 'si';
  const group = shopPricingEngine.customerGroups[shopPricingEngine.activeCustomerGroup] || shopPricingEngine.customerGroups.walk_in;

  let totalImpressions = 0;
  let totalGross = 0;
  let totalCost = 0;
  let lineSegments = [];

  const items = queue.map(q => ({
    name: q.name,
    pageCount: q.pages,
    copies: q.copies,
    paperSize: q.paperSize,
    isColor: q.colorMode === 'color',
    sides: q.duplex === 'one-sided' ? 'single' : 'double-long'
  }));

  let remainingFreePages = group.freePages;
  let freePagesDeducted = 0;

  items.forEach(file => {
    const pageCount = file.pageCount || 1;
    const copies = file.copies || parseInt(document.getElementById("lblCopiesValue")?.innerText || "1", 10);
    const paperSize = file.paperSize || document.getElementById("selPaperSize")?.value || "A4";
    const paperType = file.paperType || document.getElementById("selPaperType")?.value || "Plain Paper";
    const isColor = (file.isColor !== undefined) ? file.isColor : document.getElementById("btnColorColor")?.classList.contains("active");
    const sides = file.sides || document.getElementById("selSides")?.value || "single";
    const isDuplex = sides !== "single";
    const isBorderless = file.isBorderless || document.getElementById("chkBorderless")?.checked || false;

    const mediaKey = paperType.includes("Glossy") || paperType.includes("Photo") ? "glossy_photo" : (paperType.includes("Matte") ? "matte" : "plain");
    const isPhoto = mediaKey === "glossy_photo" || paperSize.includes("4x6") || paperSize.includes("5x7");

    let bwPages = 0;
    let colorPages = 0;
    let photoPages = 0;

    if (isPhoto) {
      photoPages = pageCount;
    } else if (isColor) {
      if (pageCount > 3) {
        colorPages = Math.max(1, Math.round(pageCount * 0.15));
        bwPages = pageCount - colorPages;
      } else {
        colorPages = pageCount;
      }
    } else {
      bwPages = pageCount;
    }

    const fileImpressions = pageCount * copies;
    totalImpressions += fileImpressions;

    // Segment 1: B&W pages
    if (bwPages > 0) {
      const segImpr = bwPages * copies;
      const rule = matchPriceRule("document_text", "bw", paperSize, mediaKey, isDuplex);
      let unitRate = rule ? rule.basePrice : 15.0;
      if (rule && rule.tiers && rule.tiers.length > 0) {
        for (const t of rule.tiers) {
          if (segImpr >= t.min && (t.max === null || segImpr <= t.max)) {
            unitRate = t.price;
            break;
          }
        }
      }
      const segSubtotal = segImpr * unitRate;
      totalGross += segSubtotal;
      lineSegments.push({
        fileName: file.name,
        desc: isSi ? `B&W පෙළ (${bwPages}p × ${copies})` : `B&W Text (${bwPages}p × ${copies})`,
        rate: unitRate,
        subtotal: segSubtotal
      });
      totalCost += (segImpr * shopPricingEngine.supplyCosts.blackInkCostPerPage) + (segImpr * shopPricingEngine.supplyCosts.a4PlainSheetCost);
    }

    // Segment 2: Color pages
    if (colorPages > 0) {
      const segImpr = colorPages * copies;
      const rule = matchPriceRule("document_text", "color", paperSize, mediaKey, isDuplex);
      let unitRate = rule ? rule.basePrice : 40.0;
      if (rule && rule.tiers && rule.tiers.length > 0) {
        for (const t of rule.tiers) {
          if (segImpr >= t.min && (t.max === null || segImpr <= t.max)) {
            unitRate = t.price;
            break;
          }
        }
      }
      const segSubtotal = segImpr * unitRate;
      totalGross += segSubtotal;
      lineSegments.push({
        fileName: file.name,
        desc: isSi ? `වර්ණ පිටු (${colorPages}p × ${copies})` : `Color Pages (${colorPages}p × ${copies})`,
        rate: unitRate,
        subtotal: segSubtotal
      });
      totalCost += (segImpr * shopPricingEngine.supplyCosts.colorInkCostPerPage) + (segImpr * shopPricingEngine.supplyCosts.a4PlainSheetCost);
    }

    // Segment 3: Photo pages
    if (photoPages > 0) {
      const segImpr = photoPages * copies;
      const rule = matchPriceRule("photo", "color", paperSize, mediaKey, false);
      let unitRate = rule ? rule.basePrice : 80.0;
      if (rule && rule.tiers && rule.tiers.length > 0) {
        for (const t of rule.tiers) {
          if (segImpr >= t.min && (t.max === null || segImpr <= t.max)) {
            unitRate = t.price;
            break;
          }
        }
      }
      const segSubtotal = segImpr * unitRate;
      totalGross += segSubtotal;
      lineSegments.push({
        fileName: file.name,
        desc: isSi ? `ඡායාරූප (${photoPages}p × ${copies})` : `Photo Print (${photoPages}p × ${copies})`,
        rate: unitRate,
        subtotal: segSubtotal
      });
      totalCost += (segImpr * shopPricingEngine.supplyCosts.colorInkCostPerPage * 1.5) + (segImpr * shopPricingEngine.supplyCosts.photoSheetCost);
    }

    if (isBorderless) {
      const bFee = shopPricingEngine.borderlessSurcharge * fileImpressions;
      totalGross += bFee;
      lineSegments.push({
        fileName: file.name,
        desc: isSi ? "දාර රහිත ගාස්තුව" : "Borderless Finishing Surcharge",
        rate: shopPricingEngine.borderlessSurcharge,
        subtotal: bFee
      });
    }
  });

  if (remainingFreePages > 0 && lineSegments.length > 0) {
    const freeRate = lineSegments[0].rate;
    freePagesDeducted = remainingFreePages * freeRate;
  }

  const afterFreeGross = Math.max(0, totalGross - freePagesDeducted);
  const groupDiscount = afterFreeGross * (group.discountPct / 100.0);
  const discountedSubtotal = Math.max(0, afterFreeGross - groupDiscount);

  let minAdjustment = 0;
  if (discountedSubtotal < shopPricingEngine.minimumJobCharge && totalImpressions > 0) {
    minAdjustment = shopPricingEngine.minimumJobCharge - discountedSubtotal;
  }

  const finalTotal = totalImpressions > 0 ? discountedSubtotal + minAdjustment + shopPricingEngine.setupFee : 0;
  const netProfit = Math.max(0, finalTotal - totalCost);

  return {
    totalImpressions,
    grossSubtotal: totalGross,
    freePagesDeducted,
    groupDiscount,
    minAdjustment,
    finalTotal,
    totalCost,
    netProfit,
    lineSegments,
    groupName: isSi ? group.nameSi : group.nameEn
  };
}

function updateLivePricePanel() {
  const quote = calculateCurrentQueueQuote();
  const lblAmount = document.getElementById("lblLivePriceAmount");
  const lblSubtotal = document.getElementById("lblGrossSubtotalVal");
  const lblProfit = document.getElementById("lblProfitEstimateText");
  const breakdownList = document.getElementById("breakdownItemsList");
  const groupTag = document.getElementById("lblCustomerGroupTag");

  if (lblAmount) lblAmount.innerText = formatEnginePrice(quote.finalTotal);
  if (lblSubtotal) lblSubtotal.innerText = formatEnginePrice(quote.grossSubtotal);
  if (lblProfit) {
    lblProfit.innerText = `Cost: ${formatEnginePrice(quote.totalCost)} (est.) • Profit: ${formatEnginePrice(quote.netProfit)} (est.)`;
  }
  if (groupTag) groupTag.innerText = quote.groupName;

  if (breakdownList) {
    breakdownList.innerHTML = quote.lineSegments.map(seg => `
      <div class="breakdown-line">
        <span class="item-name">${seg.desc}</span>
        <span class="item-rate">@ ${formatEnginePrice(seg.rate)}</span>
        <span class="item-total">${formatEnginePrice(seg.subtotal)}</span>
      </div>
    `).join("");
  }
}

function initFullPricingEngine() {
  const btnToggleBreakdown = document.getElementById("btnTogglePriceBreakdown");
  const breakdownCard = document.getElementById("livePriceBreakdownCard");
  const btnQuoteMode = document.getElementById("btnQuoteMode");
  const quoteModal = document.getElementById("quoteModal");
  const btnCloseQuoteModal = document.getElementById("btnCloseQuoteModal");
  const btnCancelQuote = document.getElementById("btnCancelQuote");
  const btnQuoteDispatchPrint = document.getElementById("btnQuoteDispatchPrint");
  const btnPrintQuotePdf = document.getElementById("btnPrintQuotePdf");

  // Toggle Breakdown Card in Print Panel
  if (btnToggleBreakdown && breakdownCard) {
    btnToggleBreakdown.addEventListener("click", () => {
      breakdownCard.classList.toggle("hidden");
    });
  }

  // Quote Mode Modal Dialog
  if (btnQuoteMode && quoteModal) {
    btnQuoteMode.addEventListener("click", () => {
      const q = calculateCurrentQueueQuote();
      const tbody = document.getElementById("quoteItemsTbody");
      if (tbody) {
        tbody.innerHTML = q.lineSegments.map(s => `
          <tr>
            <td><strong>${s.fileName || "Document"}</strong></td>
            <td><span class="customer-tag-pill">${s.desc}</span></td>
            <td>${s.desc}</td>
            <td>${formatEnginePrice(s.rate)}</td>
            <td style="text-align:right;"><strong>${formatEnginePrice(s.subtotal)}</strong></td>
          </tr>
        `).join("");
      }

      const grossEl = document.getElementById("lblQuoteGrossSubtotal");
      const grandEl = document.getElementById("lblQuoteGrandTotal");
      const discEl = document.getElementById("lblQuoteGroupDiscount");
      const freeEl = document.getElementById("lblQuoteFreePagesDeduction");
      const minEl = document.getElementById("lblQuoteMinCharge");
      const profitEl = document.getElementById("lblQuoteProfitAudit");

      if (grossEl) grossEl.innerText = formatEnginePrice(q.grossSubtotal);
      if (grandEl) grandEl.innerText = formatEnginePrice(q.finalTotal);
      if (discEl) discEl.innerText = `- ${formatEnginePrice(q.groupDiscount)}`;
      if (freeEl) freeEl.innerText = `- ${formatEnginePrice(q.freePagesDeducted)}`;
      if (minEl) minEl.innerText = formatEnginePrice(q.minAdjustment);
      if (profitEl) {
        profitEl.innerHTML = `<span class="material-symbols-rounded">trending_up</span><span>Estimated Supplies Cost: <strong>${formatEnginePrice(q.totalCost)}</strong> • Estimated Net Profit: <strong>${formatEnginePrice(q.netProfit)}</strong> (labeled estimate)</span>`;
      }

      quoteModal.classList.remove("hidden");
    });
  }

  if (btnCloseQuoteModal) btnCloseQuoteModal.addEventListener("click", () => quoteModal?.classList.add("hidden"));
  if (btnCancelQuote) btnCancelQuote.addEventListener("click", () => quoteModal?.classList.add("hidden"));

  if (btnPrintQuotePdf) {
    btnPrintQuotePdf.addEventListener("click", () => {
      quoteModal?.classList.add("hidden");
      showToast(currentLang === 'si' ? "PDF මිල ගණන් පත්‍රිකාව (Quote Invoice) සාර්ථකව උත්පාදනය කරන ලදී!" : "PDF Quotation Invoice generated with mixed page itemization!");
    });
  }

  if (btnQuoteDispatchPrint) {
    btnQuoteDispatchPrint.addEventListener("click", () => {
      quoteModal?.classList.add("hidden");
      const btnPrint = document.getElementById("btnRightPrint");
      if (btnPrint) btnPrint.click();
    });
  }

  // Price Table Renderer in Shop View
  function renderPricingTable() {
    const tbody = document.getElementById("pricingTableTbody");
    if (!tbody) return;

    const searchInput = document.getElementById("inputSearchPrices");
    const q = (searchInput?.value || "").toLowerCase().trim();
    const typeFilter = document.getElementById("filterPrintType")?.value || "all";
    const colorFilter = document.getElementById("filterColorMode")?.value || "all";
    const sizeFilter = document.getElementById("filterPaperSize")?.value || "all";
    const isSi = currentLang === 'si';

    const filtered = shopPricingEngine.entries.filter(r => {
      if (q && !r.labelEn.toLowerCase().includes(q) && !r.labelSi.toLowerCase().includes(q) && !r.paperSize.toLowerCase().includes(q)) {
        return false;
      }
      if (typeFilter !== "all" && r.printType !== typeFilter) return false;
      if (colorFilter !== "all" && r.color !== colorFilter) return false;
      if (sizeFilter !== "all" && !r.paperSize.toLowerCase().includes(sizeFilter)) return false;
      return true;
    });

    tbody.innerHTML = filtered.map(r => `
      <tr>
        <td>
          <div style="display:flex; align-items:center; gap:6px;">
            <span class="material-symbols-rounded" style="font-size:15px; color:var(--accent);">
              ${r.printType === 'photo' ? 'photo_camera' : (r.printType === 'copy' ? 'copy_all' : 'description')}
            </span>
            <strong>${isSi ? r.labelSi : r.labelEn}</strong>
          </div>
        </td>
        <td>${r.paperSize} (${r.media})</td>
        <td>${r.duplex ? 'Duplex (2-Sided)' : 'Single (1-Sided)'}</td>
        <td><span class="badge" style="font-size:9.5px;">${r.quality}</span></td>
        <td>
          <span class="source-badge ${r.color === 'color' ? 'app' : 'driver'}">
            ${r.color === 'color' ? 'Color' : 'B&W'}
          </span>
        </td>
        <td><strong>${formatEnginePrice(r.basePrice)}</strong></td>
        <td>
          ${r.tiers && r.tiers.length > 0
            ? `<span class="tier-badge" title="${r.tiers.map(t => `${t.min}-${t.max || '+'}: ${formatEnginePrice(t.price)}`).join(', ')}">${r.tiers.length} Tiers (from ${formatEnginePrice(r.tiers[r.tiers.length-1].price)})</span>`
            : '<span style="color:var(--text-muted); font-size:10px;">Fixed</span>'}
        </td>
        <td style="text-align:right;">
          <button class="btn btn-ghost btn-sm btn-icon-rule" data-copy-id="${r.id}" title="Copy from Row">
            <span class="material-symbols-rounded" style="font-size:14px;">content_copy</span>
          </button>
          <button class="btn btn-ghost btn-sm btn-icon-rule" data-edit-id="${r.id}" title="Edit Rate">
            <span class="material-symbols-rounded" style="font-size:14px;">edit</span>
          </button>
          <button class="btn btn-ghost btn-sm btn-icon-rule text-danger" data-del-id="${r.id}" title="Delete">
            <span class="material-symbols-rounded" style="font-size:14px;">delete</span>
          </button>
        </td>
      </tr>
    `).join("");

    // Wire table row action buttons
    tbody.querySelectorAll("[data-copy-id]").forEach(btn => {
      btn.addEventListener("click", () => {
        const id = btn.dataset.copyId;
        const source = shopPricingEngine.entries.find(e => e.id === id);
        if (source) {
          const clone = JSON.parse(JSON.stringify(source));
          clone.id = `rule_${Date.now()}`;
          clone.labelEn += " (Copy)";
          clone.labelSi += " (පිටපත)";
          shopPricingEngine.entries.push(clone);
          renderPricingTable();
          showToast(currentLang === 'si' ? "පේළිය පිටපත් කර අලුත් මිල රීතියක් සාදන ලදී!" : "Row duplicated into a new price rule!");
        }
      });
    });

    tbody.querySelectorAll("[data-del-id]").forEach(btn => {
      btn.addEventListener("click", () => {
        const id = btn.dataset.delId;
        shopPricingEngine.entries = shopPricingEngine.entries.filter(e => e.id !== id);
        renderPricingTable();
        showToast(currentLang === 'si' ? "මිල රීතිය ඉවත් කරන ලදී." : "Price rule deleted.");
      });
    });
  }

  // Filter input listeners
  ["inputSearchPrices", "filterPrintType", "filterColorMode", "filterPaperSize", "filterMediaType"].forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener("input", renderPricingTable);
      el.addEventListener("change", renderPricingTable);
    }
  });

  // Missing prices safeguard tool
  const btnFixMissing = document.getElementById("btnFixMissingPrices");
  const missingBanner = document.getElementById("missingPriceBanner");
  if (btnFixMissing) {
    btnFixMissing.addEventListener("click", () => {
      shopPricingEngine.entries.push(
        {
          id: `rule_a3_photo_${Date.now()}`,
          labelEn: "A3 Glossy Photo Print",
          labelSi: "A3 ග්ලොසි ඡායාරූප මුද්‍රණය",
          printType: "photo",
          color: "color",
          paperSize: "A3",
          media: "glossy_photo",
          duplex: false,
          quality: "high",
          printer: "any",
          basePrice: 280.0,
          tiers: []
        },
        {
          id: `rule_4x6_bw_${Date.now()}`,
          labelEn: "Photo 4x6 in B&W Monochrome",
          labelSi: "4x6 කළු සුදු ඡායාරූප මුද්‍රණය",
          printType: "photo",
          color: "bw",
          paperSize: "4x6",
          media: "glossy_photo",
          duplex: false,
          quality: "high",
          printer: "any",
          basePrice: 50.0,
          tiers: []
        }
      );
      if (missingBanner) missingBanner.classList.add("hidden");
      renderPricingTable();
      showToast(currentLang === 'si' ? "නොමැති සියලු මිල රීති ආරක්ෂිතව එකතු කරන ලදී!" : "Missing price combinations fixed! Safe rates assigned.");
    });
  }

  // Bulk Edit Modal
  const btnOpenBulkEdit = document.getElementById("btnOpenBulkEdit");
  const bulkModal = document.getElementById("bulkEditModal");
  const btnCloseBulkModal = document.getElementById("btnCloseBulkEditModal");
  const btnCancelBulk = document.getElementById("btnCancelBulkEdit");
  const btnApplyBulk = document.getElementById("btnApplyBulkEdit");

  if (btnOpenBulkEdit) btnOpenBulkEdit.addEventListener("click", () => bulkModal?.classList.remove("hidden"));
  if (btnCloseBulkModal) btnCloseBulkModal.addEventListener("click", () => bulkModal?.classList.add("hidden"));
  if (btnCancelBulk) btnCancelBulk.addEventListener("click", () => bulkModal?.classList.add("hidden"));

  if (btnApplyBulk) {
    btnApplyBulk.addEventListener("click", () => {
      const scope = document.getElementById("selBulkScope")?.value || "all";
      const op = document.getElementById("selBulkOperation")?.value || "pct_increase";
      const val = parseFloat(document.getElementById("inputBulkValue")?.value || "10");

      shopPricingEngine.entries.forEach(r => {
        if (scope === "a4_only" && !r.paperSize.includes("A4")) return;
        if (scope === "a3_only" && !r.paperSize.includes("A3")) return;
        if (scope === "color_only" && r.color !== "color") return;
        if (scope === "photo_only" && r.printType !== "photo") return;

        if (op === "pct_increase") r.basePrice *= (1.0 + (val / 100.0));
        else if (op === "pct_decrease") r.basePrice *= Math.max(0.1, (1.0 - (val / 100.0)));
        else if (op === "fixed_add") r.basePrice += val;
        else if (op === "fixed_sub") r.basePrice = Math.max(1.0, r.basePrice - val);

        r.basePrice = Math.round(r.basePrice * 100.0) / 100.0;
      });

      shopPricingEngine.auditLog.unshift({
        timestamp: new Date().toISOString().substring(0, 16).replace("T", " "),
        user: "Shop Owner",
        ruleId: scope.toUpperCase(),
        field: "basePrice",
        oldVal: "Batch",
        newVal: `${op} (${val})`,
        reason: "Bulk rate adjustment via wizard"
      });

      bulkModal?.classList.add("hidden");
      renderPricingTable();
      updateLivePricePanel();
      showToast(currentLang === 'si' ? "තොග මිල වෙනස්කම් සාර්ථකව යොදන ලදී!" : "Bulk price adjustment applied and logged to history!");
    });
  }

  // Audit Log Modal
  const btnAudit = document.getElementById("btnAuditLog");
  const auditModal = document.getElementById("auditLogModal");
  const btnCloseAuditModal = document.getElementById("btnCloseAuditLogModal");
  const btnCloseAudit = document.getElementById("btnCloseAudit");

  if (btnAudit) {
    btnAudit.addEventListener("click", () => {
      const tbody = document.getElementById("auditLogTbody");
      if (tbody) {
        tbody.innerHTML = shopPricingEngine.auditLog.map(l => `
          <tr>
            <td>${l.timestamp}</td>
            <td><strong>${l.user}</strong></td>
            <td><code>${l.ruleId}</code></td>
            <td>${l.field}</td>
            <td>${l.oldVal}</td>
            <td><strong>${l.newVal}</strong></td>
            <td>${l.reason}</td>
          </tr>
        `).join("");
      }
      auditModal?.classList.remove("hidden");
    });
  }
  if (btnCloseAuditModal) btnCloseAuditModal.addEventListener("click", () => auditModal?.classList.add("hidden"));
  if (btnCloseAudit) btnCloseAudit.addEventListener("click", () => auditModal?.classList.add("hidden"));

  // PIN Lock Verification
  const btnPin = document.getElementById("btnPinLock");
  const pinModal = document.getElementById("pricePinModal");
  const btnClosePinModal = document.getElementById("btnClosePinModal");
  const btnCancelPin = document.getElementById("btnCancelPin");
  const btnVerifyPin = document.getElementById("btnVerifyPin");

  if (btnPin) {
    btnPin.addEventListener("click", () => {
      if (shopPricingEngine.isPinLocked) {
        pinModal?.classList.remove("hidden");
      } else {
        shopPricingEngine.isPinLocked = true;
        document.getElementById("lblPinStatus").innerText = currentLang === 'si' ? "PIN අගුල සක්‍රියයි" : "PIN Active";
        showToast(currentLang === 'si' ? "මිල සංස්කාරකය අගුලු ලන ලදී (Locked)." : "Price editor locked with PIN protection.");
      }
    });
  }
  if (btnClosePinModal) btnClosePinModal.addEventListener("click", () => pinModal?.classList.add("hidden"));
  if (btnCancelPin) btnCancelPin.addEventListener("click", () => pinModal?.classList.add("hidden"));

  if (btnVerifyPin) {
    btnVerifyPin.addEventListener("click", () => {
      const pinField = document.getElementById("inputMasterPin");
      if (pinField?.value === shopPricingEngine.masterPin) {
        shopPricingEngine.isPinLocked = false;
        document.getElementById("lblPinStatus").innerText = currentLang === 'si' ? "අගුල ඉවත් විය" : "Unlocked";
        pinModal?.classList.add("hidden");
        showToast(currentLang === 'si' ? "PIN නිවැරදියි! මිල සංස්කරණයට ඉඩ ලබා දෙන ලදී." : "Master PIN verified! Price editing unlocked.");
      } else {
        showToast(currentLang === 'si' ? "වැරදි PIN අංකයකි! නැවත උත්සාහ කරන්න." : "Invalid PIN code! Try default 1234.");
      }
    });
  }

  // Fees, Rounding & Currency Listeners
  const selCurr = document.getElementById("selEngineCurrency");
  if (selCurr) {
    selCurr.addEventListener("change", (e) => {
      shopPricingEngine.currency = e.target.value;
      renderPricingTable();
      updateLivePricePanel();
    });
  }

  const selRound = document.getElementById("selEngineRounding");
  if (selRound) {
    selRound.addEventListener("change", (e) => {
      shopPricingEngine.rounding = e.target.value;
      renderPricingTable();
      updateLivePricePanel();
    });
  }

  const selGroup = document.getElementById("selActiveCounterGroup");
  if (selGroup) {
    selGroup.addEventListener("change", (e) => {
      shopPricingEngine.activeCustomerGroup = e.target.value;
      updateLivePricePanel();
      showToast(currentLang === 'si' ? `පාරිභෝගික ගිණුම මාරු කරන ලදී: ${e.target.value}` : `Switched customer account tier: ${e.target.value}`);
    });
  }

  // CSV Export Buttons
  ["btnExportCsv", "btnExportDailyCsv"].forEach(id => {
    const btn = document.getElementById(id);
    if (btn) {
      btn.addEventListener("click", () => {
        showToast(currentLang === 'si' ? "මිල ගණන් සහ මූල්‍ය වාර්තාව CSV ලෙස බාගත විය!" : "Exported Price Matrix & Daily Audit to CSV!");
      });
    }
  });

  window.updateLivePricePanel = updateLivePricePanel;
  renderPricingTable();
  updateLivePricePanel();
}

// ============================================================================
// Specialty Print Media Center (8 Hardware-Native Modules)
// ============================================================================
function initSpecialtyPrintCenter() {
  const modal = document.getElementById("specialtyPrintModal");
  const btnOpen = document.getElementById("btnOpenSpecialtyCenter");
  const btnClose = document.getElementById("btnCloseSpecialtyModal");
  const btnCancel = document.getElementById("btnCancelSpecialty");
  const btnPrintSpooler = document.getElementById("btnPrintSpecialtySpooler");
  const tabStrip = document.getElementById("specialtyTabStrip");
  const activePrinterBadge = document.getElementById("badgeSpecialtyActivePrinter");

  if (!modal || !btnOpen) return;

  // Specialty state
  const specialtyState = {
    activeModule: "cdDvd",
    cd: {
      profile: "standard12cm",
      outerDiameterMm: 116.0,
      innerDiameterMm: 43.0,
      text: "PRINT HELPER WEDDING ARCHIVE 2026",
      testPrintDone: false,
    },
    pvc: {
      slots: 2,
      inkjetConfirmed: false,
      aftermarketTray: false,
      offsetX: 0.0,
      offsetY: 0.0,
      cardholder: "KASUN PERERA",
      title: "CHIEF ENGINEER",
      id: "EMP-00948",
    },
    passport: {
      preset: "35x45",
      photoWidthMm: 35.0,
      photoHeightMm: 45.0,
      paper: "4x6",
      guides: "dashed",
    },
    rigid: {
      thicknessMm: 0.8,
    },
    roll: {
      widthInches: 24,
      autoCut: "page",
      borderless: false,
    },
    sublimation: {
      item: "mug11",
      widthMm: 200,
      heightMm: 95,
      autoMirror: true,
    },
    labels: {
      shape: "diecut",
      barcode: "LBL-2026-9482",
      dispense: "cut",
    },
    receipt: {
      width: "80mm",
      autoCut: true,
      cashDrawer: false,
    }
  };

  // Helper: evaluate supported modules from active printer string
  function getActivePrinterSupport() {
    const printerSelect = document.getElementById("printerSelect");
    const printerName = printerSelect ? printerSelect.value : "EPSON L8050 Series";

    const nameUpper = printerName.toUpperCase();
    const isL8050 = nameUpper.includes("L8050") || nameUpper.includes("L18050") || nameUpper.includes("ET-18100");
    const isL8180 = nameUpper.includes("L8180") || nameUpper.includes("ET-8550") || nameUpper.includes("L8160");
    const isScP = nameUpper.includes("SC-P") || nameUpper.includes("P900") || nameUpper.includes("P700");
    const isScF = nameUpper.includes("SC-F") || nameUpper.includes("F100") || nameUpper.includes("F500");
    const isColorWorks = nameUpper.includes("COLORWORKS") || nameUpper.includes("CW-C");
    const isTm = nameUpper.includes("TM-") || nameUpper.includes("RECEIPT");

    let maxThickness = 0.3;
    if (isL8180) maxThickness = 1.3;
    if (isScP) maxThickness = 1.5;

    return {
      printerName,
      cdDvd: isL8050 || isL8180 || isScP || nameUpper.includes("L805") || nameUpper.includes("XP-15000"),
      pvc: isL8050 || (nameUpper.includes("L805") && specialtyState.pvc.aftermarketTray),
      passport: true, // Universal
      rigid: maxThickness >= 0.6,
      roll: isScP || isScF || nameUpper.includes("SC-T") || nameUpper.includes("SL-D"),
      sublimation: isScF,
      labels: isColorWorks,
      receipt: isTm || true, // Also available in Shop Mode
      maxThicknessLimit: maxThickness,
    };
  }

  // Update tabs availability
  function updateTabsState() {
    const support = getActivePrinterSupport();
    if (activePrinterBadge) {
      activePrinterBadge.textContent = support.printerName;
    }

    const tabs = tabStrip?.querySelectorAll(".specialty-tab");
    tabs?.forEach(tab => {
      const mod = tab.getAttribute("data-mod");
      const isSupported = support[mod] === true;
      if (isSupported) {
        tab.classList.remove("disabled");
        tab.removeAttribute("title");
      } else {
        tab.classList.add("disabled");
        tab.setAttribute("title", currentLang === 'si' 
          ? `මෙම ප්‍රින්ටරයේ (${support.printerName}) මෙම හැකියාව නොමැත` 
          : `Not supported on ${support.printerName}`);
      }
    });

    // If active module is disabled, switch to first available
    if (!support[specialtyState.activeModule]) {
      const firstValid = ["passport", "cdDvd", "pvc", "rigid", "roll", "sublimation", "labels", "receipt"].find(m => support[m]);
      if (firstValid) {
        switchModuleTab(firstValid);
      }
    }
  }

  // Switch Module Tab
  function switchModuleTab(modName) {
    specialtyState.activeModule = modName;
    const tabs = tabStrip?.querySelectorAll(".specialty-tab");
    tabs?.forEach(t => {
      t.classList.toggle("active", t.getAttribute("data-mod") === modName);
    });

    // Hide all panels, show active
    document.querySelectorAll(".specialty-panel").forEach(p => p.classList.add("hidden"));
    const activePanel = document.getElementById(`panelSpecialty${modName.charAt(0).toUpperCase() + modName.slice(1)}`);
    if (activePanel) {
      activePanel.classList.remove("hidden");
    }

    renderActivePreview();
  }

  // Render Interactive Preview Graphic
  function renderActivePreview() {
    const container = document.getElementById("specialtyCanvasInner");
    const badgeDims = document.getElementById("badgePreviewDimensions");
    const statFooter = document.getElementById("lblSpecialtyPreviewStat");
    if (!container) return;

    const mod = specialtyState.activeModule;

    if (mod === "cdDvd") {
      const outerD = specialtyState.cd.outerDiameterMm;
      const innerD = specialtyState.cd.innerDiameterMm;
      const rOuter = outerD / 2;
      const rInner = innerD / 2;
      const area = Math.PI * (rOuter * rOuter - rInner * rInner);

      if (badgeDims) badgeDims.textContent = `${outerD.toFixed(1)} mm Ring`;
      if (statFooter) statFooter.textContent = `Printable Area: ${area.toFixed(1)} mm² • Outer: ${outerD}mm • Inner: ${innerD}mm`;

      const scale = 230 / outerD;
      const innerPx = innerD * scale;

      container.innerHTML = `
        <div class="cd-disc-wrap">
          <div class="cd-disc-outer">
            <div class="cd-disc-art">
              <div class="cd-curved-text">${specialtyState.cd.text || "PRINT HELPER DISC ARTWORK"}</div>
              <div class="material-symbols-rounded" style="font-size:36px; color:#00796b; opacity:0.35;">album</div>
              <div style="font-size:9px; color:#004d40; letter-spacing:1px;">AUDIO & DATA ARCHIVE</div>
            </div>
          </div>
          <div class="cd-center-hub" style="width:${innerPx}px; height:${innerPx}px;">
            <span>HUB</span>
          </div>
        </div>
      `;
    } else if (mod === "pvc") {
      if (badgeDims) badgeDims.textContent = "CR80 (85.60 x 53.98 mm)";
      if (statFooter) statFooter.textContent = `Offset: (${specialtyState.pvc.offsetX.toFixed(1)}mm, ${specialtyState.pvc.offsetY.toFixed(1)}mm) • 0.76mm Thickness`;

      container.innerHTML = `
        <div class="pvc-tray-canvas">
          <div class="pvc-card-slot">
            <div class="pvc-card-photo-box">
              <span class="material-symbols-rounded" style="font-size:36px; color:#bdbdbd;">person</span>
            </div>
            <div class="pvc-card-info-col">
              <span class="pvc-card-name">${specialtyState.pvc.cardholder}</span>
              <span class="pvc-card-title">${specialtyState.pvc.title}</span>
              <span class="pvc-card-meta">ID: ${specialtyState.pvc.id}</span>
              <span class="pvc-card-meta">COLOMBO TECH ENTERPRISE</span>
              <div style="margin-top:4px; font-family:monospace; font-size:8px; color:#757575;">||| | ||||| || |||| |||</div>
            </div>
          </div>
          ${specialtyState.pvc.slots === 2 ? `
            <div class="pvc-card-slot" style="opacity:0.85;">
              <div class="pvc-card-photo-box">
                <span class="material-symbols-rounded" style="font-size:36px; color:#bdbdbd;">person</span>
              </div>
              <div class="pvc-card-info-col">
                <span class="pvc-card-name">NIMALI SILVA</span>
                <span class="pvc-card-title">SYSTEM ARCHITECT</span>
                <span class="pvc-card-meta">ID: EMP-00949</span>
                <span class="pvc-card-meta">COLOMBO TECH ENTERPRISE</span>
                <div style="margin-top:4px; font-family:monospace; font-size:8px; color:#757575;">||| | ||||| || |||| |||</div>
              </div>
            </div>
          ` : ""}
        </div>
      `;
    } else if (mod === "passport") {
      const isA4 = specialtyState.passport.paper === "A4";
      const sheetW = isA4 ? 210 : 101.6;
      const sheetH = isA4 ? 297 : 152.4;
      const pW = specialtyState.passport.photoWidthMm;
      const pH = specialtyState.passport.photoHeightMm;
      const gap = 2;
      const margin = 5;

      const cols = Math.floor((sheetW - margin * 2 + gap) / (pW + gap));
      const rows = Math.floor((sheetH - margin * 2 + gap) / (pH + gap));
      const totalFit = Math.max(1, cols * rows);

      if (badgeDims) badgeDims.textContent = `${pW}x${pH} mm on ${isA4 ? "A4" : "4x6\""}`;
      if (statFooter) statFooter.textContent = `Yield: ${totalFit} photos (${cols} cols x ${rows} rows) • Crop Guides: ${specialtyState.passport.guides}`;

      const cells = Array.from({ length: Math.min(totalFit, isA4 ? 24 : 8) }).map(() => `
        <div class="passport-cell" style="width:40px; height:50px;">
          <span class="material-symbols-rounded" style="font-size:18px; color:#64b5f6;">person</span>
        </div>
      `).join("");

      container.innerHTML = `
        <div class="passport-sheet-canvas" style="grid-template-columns: repeat(${Math.min(cols, 4)}, 40px);">
          ${cells}
        </div>
      `;
    } else if (mod === "rigid") {
      const support = getActivePrinterSupport();
      const thick = specialtyState.rigid.thicknessMm;
      const limit = support.maxThicknessLimit;
      const exceeds = thick > limit;

      if (badgeDims) badgeDims.textContent = `${thick.toFixed(2)} mm Thickness`;
      if (statFooter) statFooter.textContent = `Hardware Limit: ${limit.toFixed(2)} mm • ${exceeds ? "EXCEEDED" : "SAFE"}`;

      // Update validation alert box
      const banner = document.getElementById("bannerRigidValidation");
      const icon = document.getElementById("iconRigidValidation");
      const title = document.getElementById("titleRigidValidation");
      const desc = document.getElementById("descRigidValidation");

      if (banner && title && desc) {
        if (exceeds) {
          banner.className = "alert-box alert-danger";
          if (icon) icon.textContent = "error";
          title.textContent = currentLang === 'si' ? "යාන්ත්‍රික අනතුරක් (Head-Strike Risk)" : "Mechanical Strike Hazard!";
          desc.textContent = currentLang === 'si'
            ? `කඩදාසියේ ඝනකම (${thick.toFixed(2)} mm) ප්‍රින්ටරයේ සීමාවට (${limit.toFixed(2)} mm) වඩා වැඩිය. ප්‍රින්ට් නොකරන්න.`
            : `Selected thickness (${thick.toFixed(2)} mm) exceeds limit (${limit.toFixed(2)} mm) by ${(thick - limit).toFixed(2)} mm. Printing will cause head strike.`;
        } else {
          banner.className = "alert-box alert-success";
          if (icon) icon.textContent = "check_circle";
          title.textContent = currentLang === 'si' ? "ආරක්ෂිත ඝනකම (Safe Thickness)" : "Safe Media Thickness";
          desc.textContent = currentLang === 'si'
            ? `ඝනකම ආරක්ෂිත සීමාවේ පවතී. පසුපස සෘජු මාර්ගය (Rear straight pass) භාවිතා කරන්න.`
            : `Thickness is within safe limits for straight-through rear manual feeder (up to ${limit.toFixed(2)} mm).`;
        }
      }

      container.innerHTML = `
        <div style="display:flex; flex-direction:column; align-items:center; gap:12px;">
          <div style="width:240px; height:${Math.min(160, Math.max(20, thick * 80))}px; background:#e0e0e0; border:2px solid ${exceeds ? '#d32f2f' : '#388e3c'}; border-radius:4px; display:flex; align-items:center; justify-content:center; font-weight:bold; color:#424242;">
            ${thick.toFixed(2)} mm Board
          </div>
          <div class="diagram-pill">${thick >= 0.5 ? "Rear Straight-Through Slot" : "Standard Friction Feed"}</div>
        </div>
      `;
    } else if (mod === "roll") {
      if (badgeDims) badgeDims.textContent = `${specialtyState.roll.widthInches}" Roll Width`;
      if (statFooter) statFooter.textContent = `Auto-cut: ${specialtyState.roll.autoCut} • Borderless: ${specialtyState.roll.borderless}`;

      container.innerHTML = `
        <div style="display:flex; flex-direction:column; align-items:center; gap:10px;">
          <div style="width:220px; height:280px; background:#fafafa; border:2px solid #009688; border-radius:4px; display:flex; flex-direction:column; align-items:center; justify-content:center; box-shadow:0 4px 10px rgba(0,0,0,0.06);">
            <span class="material-symbols-rounded" style="font-size:48px; color:#009688; opacity:0.5;">panorama_horizontal</span>
            <span style="font-size:12px; font-weight:bold; margin-top:8px;">CONTINUOUS ROLL</span>
            <span style="font-size:10px; color:#757575;">Width: ${specialtyState.roll.widthInches}" • Rotary Blade Ready</span>
          </div>
        </div>
      `;
    } else if (mod === "sublimation") {
      if (badgeDims) badgeDims.textContent = "Auto-Mirror Locked ON";
      if (statFooter) statFooter.textContent = `Template: ${specialtyState.sublimation.widthMm} x ${specialtyState.sublimation.heightMm} mm`;

      container.innerHTML = `
        <div class="sublimation-preview-grid">
          <div class="sublimation-col">
            <span style="font-size:11px; font-weight:600;">Original Artwork</span>
            <div class="sublimation-box">
              <span class="material-symbols-rounded" style="font-size:32px; color:#00796b;">coffee</span>
              <span>SRI LANKA</span>
              <span style="font-size:9px; color:#616161;">2026 EDITION</span>
            </div>
          </div>
          <span class="material-symbols-rounded" style="color:#009688; font-size:28px;">arrow_forward</span>
          <div class="sublimation-col">
            <span style="font-size:11px; font-weight:600; color:#009688;">Mirrored Transfer (Face-Down)</span>
            <div class="sublimation-box mirrored">
              <span class="material-symbols-rounded" style="font-size:32px; color:#00796b;">coffee</span>
              <span>SRI LANKA</span>
              <span style="font-size:9px; color:#616161;">2026 EDITION</span>
            </div>
          </div>
        </div>
      `;
    } else if (mod === "labels") {
      if (badgeDims) badgeDims.textContent = "Die-Cut 4x3\" Label";
      if (statFooter) statFooter.textContent = `Barcode: ${specialtyState.labels.barcode} • Action: ${specialtyState.labels.dispense}`;

      container.innerHTML = `
        <div style="width:200px; height:150px; background:#ffffff; border:2px solid #009688; border-radius:6px; padding:12px; display:flex; flex-direction:column; justify-content:space-between; box-shadow:0 2px 6px rgba(0,0,0,0.08);">
          <div style="font-size:11px; font-weight:bold;">CHEMICAL SAFETY LABEL</div>
          <div style="display:flex; justify-content:center; align-items:center; gap:8px;">
            <div style="width:30px; height:30px; border:2px solid #d32f2f; transform:rotate(45deg); display:flex; align-items:center; justify-content:center;">
              <span class="material-symbols-rounded" style="transform:rotate(-45deg); font-size:16px; color:#d32f2f;">local_fire_department</span>
            </div>
          </div>
          <div style="text-align:center;">
            <div style="font-family:monospace; font-size:10px; letter-spacing:2px;">||| | |||| || |||</div>
            <div style="font-size:9px; font-family:monospace;">${specialtyState.labels.barcode}</div>
          </div>
        </div>
      `;
    } else if (mod === "receipt") {
      const is80 = specialtyState.receipt.width === "80mm";
      if (badgeDims) badgeDims.textContent = `${is80 ? "80mm (48 cols)" : "58mm (32 cols)"} Thermal`;
      if (statFooter) statFooter.textContent = `Auto-cut: ${specialtyState.receipt.autoCut} • ESC/POS GS V 0`;

      container.innerHTML = `
        <div class="receipt-paper-box" style="width:${is80 ? '240px' : '190px'};">
          <div style="text-align:center; font-weight:bold;">PRINT HELPER COPY CENTER</div>
          <div style="text-align:center; font-size:8.5px;">142 High Level Rd, Nugegoda</div>
          <div style="text-align:center; font-size:8.5px;">Tel: +94 11 282 5590</div>
          <div>--------------------------------</div>
          <div>INV: INV-2026-1049  2026-10-27</div>
          <div>CASHIER: SUNIL    CUST: WALK-IN</div>
          <div>--------------------------------</div>
          <div>A4 B&W Copies x25     Rs. 300.00</div>
          <div>Glossy Photo 4x6" x4   Rs. 200.00</div>
          <div>--------------------------------</div>
          <div>SUBTOTAL:             Rs. 500.00</div>
          <div>DISCOUNT:            -Rs.  25.00</div>
          <div style="font-weight:bold;">TOTAL PAID (CASH):   Rs. 475.00</div>
          <div>================================</div>
          <div style="text-align:center; margin-top:8px;">THANK YOU FOR YOUR BUSINESS!</div>
          <div style="text-align:center; font-size:8px; color:#757575;">[ PAPER CUT COMMAND ]</div>
        </div>
      `;
    }
  }

  // Bind Event Listeners
  btnOpen.addEventListener("click", () => {
    updateTabsState();
    modal.classList.remove("hidden");
    renderActivePreview();
  });

  [btnClose, btnCancel].forEach(b => {
    if (b) b.addEventListener("click", () => modal.classList.add("hidden"));
  });

  btnPrintSpooler?.addEventListener("click", () => {
    modal.classList.add("hidden");
    showToast(currentLang === 'si' 
      ? `🖨️ විශේෂිත මුද්‍රණ කාර්යය Windows Spooler වෙත යවන ලදී!` 
      : `🖨️ Specialty print job dispatched to Windows Spooler safely!`);
  });

  // Tab switching clicks
  tabStrip?.querySelectorAll(".specialty-tab").forEach(tab => {
    tab.addEventListener("click", () => {
      if (tab.classList.contains("disabled")) {
        const support = getActivePrinterSupport();
        showToast(currentLang === 'si' 
          ? `මෙම විකල්පය සක්‍රිය ප්‍රින්ටරයේ (${support.printerName}) සහාය නොදක්වයි` 
          : `This feature is not supported on ${support.printerName}`);
        return;
      }
      const mod = tab.getAttribute("data-mod");
      if (mod) switchModuleTab(mod);
    });
  });

  // CD/DVD Event Listeners
  const rngOuter = document.getElementById("rngOuterDia");
  const valOuter = document.getElementById("valOuterDia");
  if (rngOuter && valOuter) {
    rngOuter.addEventListener("input", (e) => {
      const val = parseFloat(e.target.value);
      specialtyState.cd.outerDiameterMm = val;
      valOuter.textContent = `${val.toFixed(1)} mm`;
      renderActivePreview();
    });
  }

  const rngInner = document.getElementById("rngInnerDia");
  const valInner = document.getElementById("valInnerDia");
  if (rngInner && valInner) {
    rngInner.addEventListener("input", (e) => {
      const val = parseFloat(e.target.value);
      specialtyState.cd.innerDiameterMm = val;
      valInner.textContent = `${val.toFixed(1)} mm`;
      renderActivePreview();
    });
  }

  const btnDisc12 = document.getElementById("btnDisc12cm");
  const btnDisc8 = document.getElementById("btnDisc8cm");
  btnDisc12?.addEventListener("click", () => {
    btnDisc12.classList.add("active");
    btnDisc8?.classList.remove("active");
    specialtyState.cd.outerDiameterMm = 116.0;
    specialtyState.cd.innerDiameterMm = 43.0;
    if (rngOuter) rngOuter.value = "116";
    if (rngInner) rngInner.value = "43";
    if (valOuter) valOuter.textContent = "116.0 mm";
    if (valInner) valInner.textContent = "43.0 mm";
    renderActivePreview();
  });
  btnDisc8?.addEventListener("click", () => {
    btnDisc8.classList.add("active");
    btnDisc12?.classList.remove("active");
    specialtyState.cd.outerDiameterMm = 80.0;
    specialtyState.cd.innerDiameterMm = 18.0;
    if (rngOuter) rngOuter.value = "80";
    if (rngInner) rngInner.value = "18";
    if (valOuter) valOuter.textContent = "80.0 mm";
    if (valInner) valInner.textContent = "18.0 mm";
    renderActivePreview();
  });

  const inputCdText = document.getElementById("inputCircularText");
  inputCdText?.addEventListener("input", (e) => {
    specialtyState.cd.text = e.target.value;
    renderActivePreview();
  });

  const btnPrintCdTest = document.getElementById("btnPrintCdTestPattern");
  const badgeCdVerified = document.getElementById("badgeCdTestVerified");
  const iconCdCheck = document.getElementById("iconCdTestCheck");
  const guardrailCd = document.getElementById("guardrailCdDvd");
  btnPrintCdTest?.addEventListener("click", () => {
    specialtyState.cd.testPrintDone = true;
    badgeCdVerified?.classList.remove("hidden");
    if (iconCdCheck) {
      iconCdCheck.textContent = "check_circle";
      iconCdCheck.style.color = "#2e7d32";
    }
    guardrailCd?.classList.add("verified");
    showToast(currentLang === 'si' 
      ? "📄 1:1 පෙර-පරීක්ෂණ සැකිල්ල සාමාන්‍ය කොළයේ මුද්‍රණය විය!" 
      : "📄 1:1 Plain paper alignment test target sent to spooler!");
  });

  // PVC Event Listeners
  const btnPvc2 = document.getElementById("btnPvc2Slots");
  const btnPvc1 = document.getElementById("btnPvc1Slot");
  btnPvc2?.addEventListener("click", () => {
    btnPvc2.classList.add("active");
    btnPvc1?.classList.remove("active");
    specialtyState.pvc.slots = 2;
    renderActivePreview();
  });
  btnPvc1?.addEventListener("click", () => {
    btnPvc1.classList.add("active");
    btnPvc2?.classList.remove("active");
    specialtyState.pvc.slots = 1;
    renderActivePreview();
  });

  document.getElementById("chkConfirmInkjetPvc")?.addEventListener("change", (e) => {
    specialtyState.pvc.inkjetConfirmed = e.target.checked;
  });

  document.getElementById("chkAftermarketTray")?.addEventListener("change", (e) => {
    specialtyState.pvc.aftermarketTray = e.target.checked;
    updateTabsState();
  });

  const rngPvcX = document.getElementById("rngPvcOffsetX");
  const valPvcX = document.getElementById("valPvcOffsetX");
  rngPvcX?.addEventListener("input", (e) => {
    specialtyState.pvc.offsetX = parseFloat(e.target.value);
    if (valPvcX) valPvcX.textContent = `${specialtyState.pvc.offsetX.toFixed(1)} mm`;
    renderActivePreview();
  });

  const rngPvcY = document.getElementById("rngPvcOffsetY");
  const valPvcY = document.getElementById("valPvcOffsetY");
  rngPvcY?.addEventListener("input", (e) => {
    specialtyState.pvc.offsetY = parseFloat(e.target.value);
    if (valPvcY) valPvcY.textContent = `${specialtyState.pvc.offsetY.toFixed(1)} mm`;
    renderActivePreview();
  });

  document.getElementById("btnImportPvcCsv")?.addEventListener("click", () => {
    showToast(currentLang === 'si' ? "📁 CSV කාඩ්පත් ලැයිස්තුව සාර්ථකව පූරණය විය (කාඩ්පත් 12)" : "📁 Loaded 12 cardholder records from CSV batch!");
  });

  // Passport Event Listeners
  document.getElementById("selPassportPreset")?.addEventListener("change", (e) => {
    specialtyState.passport.preset = e.target.value;
    if (e.target.value === "35x45") { specialtyState.passport.photoWidthMm = 35; specialtyState.passport.photoHeightMm = 45; }
    if (e.target.value === "51x51") { specialtyState.passport.photoWidthMm = 51; specialtyState.passport.photoHeightMm = 51; }
    if (e.target.value === "30x40") { specialtyState.passport.photoWidthMm = 30; specialtyState.passport.photoHeightMm = 40; }
    if (e.target.value === "35x35") { specialtyState.passport.photoWidthMm = 35; specialtyState.passport.photoHeightMm = 35; }
    renderActivePreview();
  });

  const btnP4x6 = document.getElementById("btnPaper4x6");
  const btnPA4 = document.getElementById("btnPaperA4");
  btnP4x6?.addEventListener("click", () => {
    btnP4x6.classList.add("active");
    btnPA4?.classList.remove("active");
    specialtyState.passport.paper = "4x6";
    renderActivePreview();
  });
  btnPA4?.addEventListener("click", () => {
    btnPA4.classList.add("active");
    btnP4x6?.classList.remove("active");
    specialtyState.passport.paper = "A4";
    renderActivePreview();
  });

  document.getElementById("selCropGuides")?.addEventListener("change", (e) => {
    specialtyState.passport.guides = e.target.value;
    renderActivePreview();
  });

  // Rigid Event Listeners
  const rngThick = document.getElementById("rngMediaThickness");
  const valThick = document.getElementById("valMediaThickness");
  rngThick?.addEventListener("input", (e) => {
    const val = parseFloat(e.target.value);
    specialtyState.rigid.thicknessMm = val;
    if (valThick) valThick.textContent = `${val.toFixed(2)} mm`;
    renderActivePreview();
  });

  // Roll Event Listeners
  document.getElementById("selRollWidth")?.addEventListener("change", (e) => {
    specialtyState.roll.widthInches = parseFloat(e.target.value);
    renderActivePreview();
  });

  document.getElementById("selAutoCutMode")?.addEventListener("change", (e) => {
    specialtyState.roll.autoCut = e.target.value;
    renderActivePreview();
  });

  // Sublimation Event Listeners
  document.getElementById("selSublimationItem")?.addEventListener("change", (e) => {
    specialtyState.sublimation.item = e.target.value;
    if (e.target.value === "mug11") { specialtyState.sublimation.widthMm = 200; specialtyState.sublimation.heightMm = 95; }
    if (e.target.value === "mug15") { specialtyState.sublimation.widthMm = 220; specialtyState.sublimation.heightMm = 105; }
    if (e.target.value === "tshirtA4") { specialtyState.sublimation.widthMm = 210; specialtyState.sublimation.heightMm = 297; }
    if (e.target.value === "lanyard") { specialtyState.sublimation.widthMm = 900; specialtyState.sublimation.heightMm = 20; }
    if (e.target.value === "mousepad") { specialtyState.sublimation.widthMm = 230; specialtyState.sublimation.heightMm = 190; }
    renderActivePreview();
  });

  // Receipt Event Listeners
  const btnRcpt80 = document.getElementById("btnReceipt80mm");
  const btnRcpt58 = document.getElementById("btnReceipt58mm");
  btnRcpt80?.addEventListener("click", () => {
    btnRcpt80.classList.add("active");
    btnRcpt58?.classList.remove("active");
    specialtyState.receipt.width = "80mm";
    renderActivePreview();
  });
  btnRcpt58?.addEventListener("click", () => {
    btnRcpt58.classList.add("active");
    btnRcpt80?.classList.remove("active");
    specialtyState.receipt.width = "58mm";
    renderActivePreview();
  });

  // Watch for printer changes in the main window
  const selPrinter = document.getElementById("printerSelect");
  selPrinter?.addEventListener("change", () => {
    updateTabsState();
    renderActivePreview();
  });

  // Initial render
  updateTabsState();
  renderActivePreview();
}

// ============================================================================
// Multi-Printer Fleet Dashboard & Intelligent Routing Engine
// ============================================================================
function initMultiPrinterDashboard() {
  // 1. Subnet Scan Modal
  const modalSubnet = document.getElementById("subnetScanModal");
  const btnTriggerSubnet = document.getElementById("btnTriggerSubnetScan");
  const btnCloseSubnet = document.getElementById("btnCloseSubnetScanModal");
  const btnCancelSubnet = document.getElementById("btnCancelSubnetScan");
  const btnAuthSubnet = document.getElementById("btnAuthorizeSubnetScan");
  const inputCidr = document.getElementById("inputTargetSubnetCidr");

  btnTriggerSubnet?.addEventListener("click", () => {
    modalSubnet?.classList.remove("hidden");
  });

  const hideSubnetModal = () => modalSubnet?.classList.add("hidden");
  btnCloseSubnet?.addEventListener("click", hideSubnetModal);
  btnCancelSubnet?.addEventListener("click", hideSubnetModal);

  btnAuthSubnet?.addEventListener("click", () => {
    const cidr = inputCidr ? inputCidr.value.trim() : "192.168.1.0/24";
    subnetScanConsentGranted = true;
    hideSubnetModal();
    const isSi = currentLang === "si";
    const msg = isSi
      ? `📡 ${cidr} ජාලයේ IP 254 ක් SNMP සහ IPP මඟින් පරීක්ෂා කර ප්‍රින්ටර් 4 ක් සොයා ගන්නා ලදී.`
      : `📡 Scanned 254 hosts on ${cidr} via IPP & SNMP. Discovered 4 network printers.`;
    showToast(msg);
    renderPrintersGrid();
  });

  // 2. Simulation Trigger Dropdown
  const btnSimTrigger = document.getElementById("btnSimulateRoutingTrigger");
  const simMenu = document.getElementById("simulateRoutingDropdown");

  btnSimTrigger?.addEventListener("click", (e) => {
    e.stopPropagation();
    simMenu?.classList.toggle("hidden");
  });

  document.addEventListener("click", (e) => {
    if (!btnSimTrigger?.contains(e.target) && !simMenu?.contains(e.target)) {
      simMenu?.classList.add("hidden");
    }
  });

  // 3. Routing Simulation Options & Failover Modal
  const modalFailover = document.getElementById("routingFailoverModal");
  const btnCloseFailover = document.getElementById("btnCloseFailoverModal");
  const btnKeepQueue = document.getElementById("btnKeepInQueue");
  const btnApproveReroute = document.getElementById("btnApproveReroute");

  const hideFailoverModal = () => modalFailover?.classList.add("hidden");
  btnCloseFailover?.addEventListener("click", hideFailoverModal);
  btnKeepQueue?.addEventListener("click", hideFailoverModal);

  btnApproveReroute?.addEventListener("click", () => {
    hideFailoverModal();
    selectedPrinterId = "epson_l8050";
    renderPrinterDropdown();
    renderPrintersGrid();
    updateLivePrinterPanel();
    validateDependenciesAndAutoFixes();
    updateLiveSummary();
    const isSi = currentLang === "si";
    showToast(
      isSi
        ? "🔀 ක්‍රියාවිරහිත SC-P900 වෙනුවට Studio Photo L8050 වෙත රැකියාව මාරු කරන ලදී."
        : "🔀 Job approved & rerouted from SC-P900 to Studio Photo L8050."
    );
  });

  simMenu?.querySelectorAll(".dropdown-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      simMenu.classList.add("hidden");
      const simType = btn.dataset.sim;
      const isSi = currentLang === "si";

      if (simType === "pvc") {
        const msg = isSi
          ? "PVC ID කාඩ්පත් මුද්‍රණය සඳහා විශේෂිත තැටි මාර්ගෝපදේශයක් අවශ්‍ය බැවින් Studio Photo L8050 වෙත යොමු කරන ලදී."
          : "Routed to Studio Photo L8050 because PVC ID card printing requires a dedicated card tray guide.";
        showToast(`🖨️ ${msg}`);
      } else if (simType === "cd") {
        const msg = isSi
          ? "CD/DVD තැටි මුද්‍රණය සඳහා විශේෂිත තැටි මාර්ගෝපදේශයක් අවශ්‍ය බැවින් Studio Photo L8050 වෙත යොමු කරන ලදී."
          : "Routed to Studio Photo L8050 because optical disc label printing requires a direct CD/DVD tray guide.";
        showToast(`🖨️ ${msg}`);
      } else if (simType === "heavy_doc") {
        const msg = isSi
          ? "පිටු 150 ක විශාල ලේඛනයක් බැවින් අධිවේගී ද්විත්ව මුද්‍රණය සහ අඩු පිරිවැය සහිත RIPS තීන්ත ඇසුරුම් ඇති WF-C5890 වෙත යොමු කරන ලදී."
          : "Routed 150-page document to Production WF-C5890 for high-speed hardware duplex and low cost-per-page RIPS ink packs.";
        showToast(`🖨️ ${msg}`);
      } else if (simType === "offline_reroute") {
        modalFailover?.classList.remove("hidden");
      }
    });
  });

  // 4. Fleet Routing Rules Modal
  const modalRules = document.getElementById("fleetRoutingRulesModal");
  const btnOpenRules = document.getElementById("btnOpenFleetRoutingRules");
  const btnCloseRules = document.getElementById("btnCloseRoutingRulesModal");
  const btnSaveRules = document.getElementById("btnSaveRoutingRules");

  btnOpenRules?.addEventListener("click", () => {
    modalRules?.classList.remove("hidden");
  });

  const hideRulesModal = () => modalRules?.classList.add("hidden");
  btnCloseRules?.addEventListener("click", hideRulesModal);
  btnSaveRules?.addEventListener("click", () => {
    hideRulesModal();
    const isSi = currentLang === "si";
    showToast(isSi ? "✅ මාර්ගගත කිරීමේ නීති සාර්ථකව සුරකින ලදී." : "✅ Fleet routing policies saved and applied.");
  });

  // 5. Low Supply Threshold Select
  const selThreshold = document.getElementById("fleetLowSupplyThresholdSelect");
  selThreshold?.addEventListener("change", (e) => {
    fleetLowSupplyThreshold = parseFloat(e.target.value);
    renderPrintersGrid();
  });

  // 6. Filter Chips
  const filterChips = document.querySelectorAll("#tabPrinters .filter-chips-row .filter-chip");
  filterChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      filterChips.forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");
      activeFilter = chip.dataset.filter || "all";
      renderPrintersGrid();
    });
  });
}


