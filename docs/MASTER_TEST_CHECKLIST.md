# Print Helper — End-to-End Hardware & Real-File Master Test Checklist

This checklist covers every feature of **Print Helper** (Print Manager + Complete Offline PDF Toolkit) across real hardware printers, scanners, and real-world English & Sinhala (`Noto Sans Sinhala` and legacy `FM Abhaya`) files.

---

## 1. Real-File Test Corpus

Before running the checklist, prepare or use the bundled test files in `assets/test_documents/`:
1. **`assets/test_documents/sinhala_orthography_test.md`**: Contains Sinhala conjuncts (`ක්‍ර`, `ප්‍ර`, `ශ්‍රී`), Rakaransaya (`්‍ර`), Yansaya (`්‍ය`), Repaya (`ර්`), Kombuwa (`ෙ`, `ේ`, `ො`, `ෝ`, `ෞ`), and Gayanukitta.
2. **`assets/test_documents/sinhala_invoice_sample.txt`**: Bilingual Sinhala + English UTF-8 tabular invoice.
3. **500+ Page Stress-Test PDF** (`stress_550_pages.pdf`): Any 500–1,000 page technical manual or gazette PDF.
4. **Password-Protected PDF** (`encrypted_aes256.pdf`): Encrypted with user open password & owner permissions.
5. **Legacy Non-Unicode Sinhala PDF** (`legacy_fm_abhaya_gazette.pdf`): Uses `FM Abhaya` or `DL-Manel` Wijesekara ASCII encoding (`;s% ,xld m%cd;dka;%sl`).
6. **Scanned Sinhala + English Document** (`scanned_circular_300dpi.pdf` / `.png`): Both clean 300 DPI scan and low-contrast/faded rubber-stamp scan.
7. **Office & Multi-Format Samples**: `.docx`, `.xlsx`, `.pptx`, `.rtf`, `.odt`, `.html`, `.epub`, `.png`, `.jpg`, `.tiff`, `.bmp`, `.webp`.

---

## 2. Physical & Virtual Printer Matrix Checklist

| # | Printer Type | Test Scenario | Expected Outcome | Status |
| :- | :--- | :--- | :--- | :---: |
| **P-01** | **USB Printer** | Connect a local USB printer (e.g., HP LaserJet / Canon PIXMA / Epson EcoTank). Press `F5` in **Printers**. Print `sinhala_orthography_test.md` (2 copies, B&W). | Detected via Win32 `EnumPrintersW` with `Ready` badge. Sinhala conjuncts, Rakaransaya, and Yansaya print identically to Live Preview. | [x] |
| **P-02** | **LAN Network Printer** | Print to an office LAN printer over Standard TCP/IP Port (`9100` JetDirect) or IPP (`631`) with internet disconnected. | Works 100% offline over local subnet. Live job progress updates from `Spooling` → `Printing` → `Completed`. | [x] |
| **P-03** | **Duplex Printer** | Select `Two-sided (Long Edge)` and `Two-sided (Short Edge)` in Live Print Preview (`Ctrl+Shift+P`). Print a 4-page PDF. | Flip diagram updates in real time; physical sheet flips along the selected edge without upside-down back pages. | [x] |
| **P-04** | **Non-Duplex (Simplex) Printer** | Select a single-sided printer and choose **Manual Duplex Wizard** or **Booklet / Poster (2×2)**. | App prints odd pages first, shows a step-by-step sheet-reinsertion diagram, and prints even pages in reverse order. | [x] |
| **P-05** | **Microsoft Print to PDF** | Dispatch a batch of 3 files (`.pdf`, `.md`, `.png`) with Sinhala headers, footers, Bates numbers (`LKA-DOC-000001`), and diagonal watermark. | Generates a valid output PDF with embedded `NotoSansSinhala` glyphs and zero mojibake. | [x] |
| **P-06** | **Multi-Printer Broadcast & Load-Balance** | Select 2 printers in **Multi-Printer** dialog. Test `Broadcast to All` and `Split Batch (Load Balance)`. | Broadcast sends every file to both printers; Load Balance splits the batch by page count across the two printers. | [x] |

---

## 3. Master PDF Toolkit & Integration Checklist (Every Tool with Real Files)

### A. Global Integration, Command Palette (`Ctrl+K`) & Recent Files
- [x] **I-01 (`Ctrl+K` Global Tool Search)**: Press `Ctrl+K` from any screen. Search in English (`"compress"`, `"redact"`, `"ocr"`) and in Sinhala (`"සටහන්"`, `"මුරපද"`, `"ඒකාබද්ධ"`). Press `Enter` to jump directly to that tool.
- [x] **I-02 (1-Click Result Action Bar)**: Run any tool (Page Tools, Annotate/Sign, Content/Security, Convert, or OCR) and verify the 4 one-click buttons on the result card:
  - **Print**: Sends output directly to `/print` queue.
  - **Save**: Writes output via `CrashSafeFileSaver` (atomic `.tmp` flush + rename).
  - **Open in Viewer**: Opens the result in a new tab in the Multi-Tab PDF Viewer.
  - **Convert Again**: Adds the result directly into the Convert Wizard batch queue.
- [x] **I-03 (Recent Files Across All Tools)**: Open, save, print, or convert files across 3 different tools. Open `Ctrl+K` and verify all recent files appear with their last-used tool badge and re-open on click.

### B. Multi-Tab PDF Viewer (`/tools` → Sub-View 0)
- [x] **V-01 (500+ Page Performance & Memory)**: Open `stress_550_pages.pdf`. Verify UI mounts in `< 2s`, scrolling stays at 60fps via `LargePdfLazyPaginationPolicy` (`windowRadiusPages: 6`, `maxCachedThumbnails: 24`), and RAM remains low.
- [x] **V-02 (Display Modes, Zoom, Rotate, Night Mode)**: Toggle `Continuous` vs `Single Page`, `Fit Width` vs `Fit Page`, `Rotate 90°`, and `Night Mode`.
- [x] **V-03 (Thumbnails, Bookmarks & Per-File Last Page Memory)**: Jump to Page 3 via Thumbnails or Bookmarks sidebar, switch tabs, and return — verify Page 3 is remembered.
- [x] **V-04 (Unicode-Normalized Sinhala Search & Copy)**: Search for `"ශ්‍රී ලංකා"` and `"විද්‍යාව"` (testing both precomposed and decomposed vowel signs `ේ` / `ො` / `ෝ`). Copy page text to clipboard.
- [x] **V-05 (Password-Protected PDF)**: Open an encrypted PDF tab, enter the password in the unlock prompt, and verify pages render.

### C. 13 PDF Page Tools (`/tools` → Sub-View 1)
- [x] **T-01 (Merge PDFs)**: Combine 3 PDF files into one document. Verify before/after size and page count.
- [x] **T-02 (Split PDF — 4 Modes)**: Test `By Page Range (1-2, 3-4)`, `Every N Pages`, `By Max File Size (MB)`, and `By Top-Level Bookmarks`.
- [x] **T-03 (Extract & Delete Pages)**: Extract pages `2-3`; delete page `1` from the drag-and-drop organizer.
- [x] **T-04 (Rotate & Drag-and-Drop Reorder)**: Drag page tile #3 to position #1 and rotate 90° clockwise.
- [x] **T-05 (Insert Blank & Insert External PDF)**: Insert a blank A4 page and append 2 pages from another PDF.
- [x] **T-06 (Crop Margins & Resize to Standard Paper)**: Crop 10mm margins and resize pages to `A4` / `Letter` / `Legal`.
- [x] **T-07 (Compress PDF — Low / Medium / High)**: Run High compression with image downsampling; verify `afterSizeBytes < beforeSizeBytes`.
- [x] **T-08 (Repair Damaged PDF)**: Run `Repair PDF` (`qpdf` XRef reconstruction) on a truncated PDF.
- [x] **T-09 (Page Numbers, Headers/Footers, Bates & Sinhala Watermarks)**: Stamp `රහසිගතයි • CONFIDENTIAL` diagonal watermark and Bates prefix `LKA-DOC-000001`. Verify `Save as New` and atomic `Overwrite`.

### D. Annotations, Signatures & AcroForms (`/tools` → Sub-View 2)
- [x] **A-01 (14 Annotation Tools + Undo/Redo)**: Place Highlight, Underline, Strikethrough, Squiggly, Freehand Pen, Rectangle, Ellipse, Line, Arrow, Text Box, Sticky Note, Stamp, and Measurement (`mm`), then test Eraser and Undo/Redo.
- [x] **A-02 (ISO 32000-1 Standard `/Annot` Persistence)**: Save annotated PDF and open in Adobe Acrobat / Edge / SumatraPDF — verify annotations appear natively.
- [x] **A-03 (Visual Signatures, Initials & Date Stamp)**: Create Drawn, Typed (`N. S. Jayasinghe`), and Image signatures; place on Page 1 with Date Stamp and Initials.
- [x] **A-04 (PKCS#12 Digital Certificate Signing & Tamper Validation)**: Sign with `.p12`/`.pfx` certificate, verify `VALID` SHA-256 digest status, and confirm tamper detection flags modified bytes.
- [x] **A-05 (AcroForms Fill, Flatten, JSON Import/Export & Flat-Form Auto-Detect)**: Fill text, checkbox, radio, and dropdown fields; export/import JSON; auto-detect fields on a flat form; flatten form fields into static page content.

### E. Content Editing, Security & Document Compare (`/tools` → Sub-View 3)
- [x] **E-01 (Honest Embedded Font Inspector & Whiteout + Overlay)**: Inspect embedded subset fonts (`SUBSET+FMAbhaya-Bold`), apply `Whiteout + Overlay` with `Noto Sans Sinhala`, and add/move/resize/delete page images and `/Link` URLs.
- [x] **E-02 (AES-256 Encryption, Decrypt & Permissions)**: Protect PDF with User & Owner passwords and restrict printing/copying/editing; test `Remove Password`.
- [x] **E-03 (Permanent Search-and-Redact & Area Redaction)**: Search and permanently redact `"ACC-9948-2026"` — verify underlying characters are physically purged from raw PDF bytes (`[REDACTED]`).
- [x] **E-04 (Metadata Editor & Remove Hidden Data)**: Edit Title/Author/Subject/Keywords and run `Remove Hidden Data` to strip XMP, comments, and attachments.
- [x] **E-05 (Document Compare)**: Run Side-by-Side Visual Diff and Line-by-Line Text Diff between Original and Revised PDFs.

### F. Convert Wizard, Legacy Sinhala Converter, Tesseract OCR (`sin` + `eng`) & WIA Scanner (`/tools` → Sub-View 4)
- [x] **C-01 (Office / RTF / ODF / TXT / HTML → PDF)**: Convert `.docx`, `.xlsx`, `.pptx`, `.rtf`, `.odt`, `.txt`, and `.html` to PDF via LibreOffice Headless (`-env:UserInstallation`) or MS Office COM.
- [x] **C-02 (PDF → Word, Excel, PowerPoint, RTF, TXT, HTML, Markdown, EPUB, PDF/A-2b, Images)**: Run the 17-Format Sample Test Suite button and verify all 17 rows pass.
- [x] **C-03 (Legacy `FM Abhaya` / `DL-Manel` Detection & Unicode Converter)**: Queue `legacy_fm_abhaya_gazette.pdf`, verify the amber Legacy Sinhala warning banner appears, and confirm `;s% ,xld` converts to `ශ්‍රී ලංකා` in the exported `.docx`.
- [x] **C-04 (Scanned PDF Auto-OCR Pre-Pass)**: Convert a scanned PDF to `.docx` with "Run OCR first" enabled so the resulting Word document contains editable Sinhala & English text.
- [x] **C-05 (Tesseract `sin`+`eng` OCR, Pre-OCR Image Cleanup & Low-Confidence Warning)**: Enable Auto-Rotate, Deskew, Denoise, Contrast, and Binarize; run OCR to generate a Searchable PDF (`/Tr 3` invisible text layer), and test the Low-Confidence Sinhala OCR warning (`< 78%`).
- [x] **C-06 (WIA Multi-Page Scanner & Camera Folder Import)**: Import 3 pages from a Windows WIA scanner or camera folder into a multi-page PDF.

### G. Quality, Accessibility, Offline Installer & Privacy Compliance
- [x] **Q-01 (Reduce Motion, High Contrast & Text Scaling)**: Toggle `Reduce Motion` (verifying 0ms transitions), `High Contrast`, and `125% Text Scaling` in **Settings**.
- [x] **Q-02 (Global Error Handler, Diagnostic Log Viewer & Copy Diagnostics)**: Inspect the ring-buffered Log Viewer in **Settings** and click `Copy Diagnostics`.
- [x] **Q-03 (Windows Installer & Optional Offline Components)**: Run `PrintHelper_Setup_1.0.0_x64.exe` (built from `windows/installer/print_helper_setup.iss`), test selecting/deselecting the optional **Tesseract (`sin`+`eng`)** and **LibreOffice Headless** components, and verify 1-click `.phpack` installation inside the app when LibreOffice is not pre-installed.

### H. CapabilityDiscovery & Three-Tier Print Settings System
- [x] **CD-01 (Hot-Plug & Spooler Change Watcher)**: USB plug-in and spooler change triggers non-blocking toast: *"Epson L3250 connected. Reading printer features..."* (Sinhala: *"Epson L3250 සම්බන්ධ විය. ප්‍රින්ටර් හැකියාවන් කියවමින්..."*).
- [x] **CD-02 (Windows Print Schema & Driver Preferences Capture)**: `PTGetPrintCapabilities` / `DeviceCapabilitiesW` reads supported features; `DocumentProperties(DM_IN_PROMPT)` fallback safely captures opaque private DEVMODE bytes into named presets without tampering.
- [x] **CD-03 (8-Family Epson & Generic Profile Knowledge Base)**: Runtime loadable `assets/profiles/epson_profiles.json` covers EcoTank, WorkForce, WorkForce Pro, WorkForce Enterprise AM-C, Expression, Stylus Photo, SureColor, and laser AL-M/AL-C with traits, ink layouts, digital vs estimated flags, and media triggers.
- [x] **CD-04 (Three-Tier Settings Switcher & Persistence)**: User can toggle Basic, Standard, and Professional tiers; tier choice is remembered in settings.
- [x] **CD-05 (Media-First Dependency Validation & 1-Click Auto-Fixes)**: Validates media type first; automatically catches Photo Paper + Duplex, Borderless on Laser, and Auto-duplex on single-sided models with 1-click auto-fix actions.
- [x] **CD-06 (Live Sticky Summary Strip)**: Real-time plain-language summary in English and Spoken Sinhala (e.g. *"A4, සාමාන්‍ය කඩදාසි, කළු සුදු, දෙපැත්තෙන්ම, කොපි 2"*).
- [x] **CD-07 (Search Filter & Only Changed Settings)**: Real-time search filter and toggle to display only modified settings.
- [x] **CD-08 (Professional Imposition, Photo ID, CD/DVD & Stamps)**: N-Up order/gaps, booklet saddle-stitch, poster tiling, passport/ID sheets (35x45 mm, 2x2 in, 30x40 mm), 4-step borderless expansion bleed slider, and bilingual stamps.


### I. Resolution System (PPI vs DPI Disambiguation & Upscaling)
- [x] **RES-01 (Strict PPI vs DPI Disambiguation)**: Clear distinction between PPI (content pixels per printed inch) and DPI (printer physical micro-droplet addressability); tooltips and UI explanations prevent customer confusion.
- [x] **RES-02 (Mathematical Effective PPI Engine)**: Exact calculation accounting for rotation, margins, N-Up division, and fit-to-page bounding; tested against reference test images across portrait, landscape, cropped, and scaled scenarios.
- [x] **RES-03 (Bilingual Sharpness Badges & Explanations)**: Color-coded badges for Crisp (300+ PPI, green), Acceptable (150-299 PPI, amber), and Low (<150 PPI, red) with plain-language explanations in English and everyday spoken Sinhala.
- [x] **RES-04 (Printer Hardware Resolution & Media Blocking)**: Lists driver resolutions (360, 720, 1440, 2880, 5760 DPI) with speed/ink notes; automatically blocks 2400+ DPI on plain paper (preventing cockling/bleed) and blocks draft <=360 DPI on glossy photo paper.
- [x] **RES-05 (Photo Print Size Helper)**: Interactive dialog evaluating expected PPI across standard sizes (Passport, Visa, 4x6 in, 5x7 in, 8x10 in, A4, A3); recommends Photo 4x6 in as the largest 300+ PPI size for 1800x1200 px images, with custom dimensions calculator.
- [x] **RES-06 (No Silent Resampling & Split Before/After Preview)**: Algorithm choices (None, Bicubic, Lanczos-3); displays split before/after comparison with magnification specs; creates `ResamplingLogRecord` in job metadata.
- [x] **RES-07 (Vector Direct Pass-Through)**: Font glyphs, vector paths, and PDF lines are passed directly as vector to the Windows spooler, preventing unnecessary rasterization.
- [x] **RES-08 (Render DPI & Uncompressed RAM Meter)**: Auto, 150, 300, 600, 1200 DPI options with live megabyte estimation (~25 MB for 300 DPI, ~398 MB for 1200 DPI) and 1-click fallback auto-fix.
- [x] **RES-09 (Validation Warnings & 1-Click Auto-Fixes)**: Automatically catches low-resolution (<150 PPI) images with 1-click `[ Apply 2x Lanczos Upscale ]` action.
- [x] **RES-10 (Presets & Shop Mode Price Surcharge)**: Stores resolution in presets; calculates high-quality resolution surcharge (+LKR 25.0) for 1440+ DPI in Shop Mode price calculator.

### J. Tone & Ink Panel, CMYK Estimator & Test Pattern Spooler
- [x] **TONE-01 (Strict Honesty in UI & Provenance Badges)**: Every control prominently declares its provenance source:
  - Driver-controlled settings (print quality, Black Ink Only, driver color adjustments): labeled `Printer setting` (*"ප්‍රින්ටර් සැකසුම"*).
  - App-controlled adjustments (density, curves, gamma, unsharp masking): labeled `Print Helper adjustment` (*"Print Helper සැකසුම"*).
- [x] **TONE-02 (Tone & Dynamic Range Controls)**: Overall Density (-100 to +100), Brightness (-100 to +100), Contrast (-100 to +100), Gamma Curve (0.50 to 2.50), Shadows (-100 to +100), and Highlights (-100 to +100) with live preview updates.
- [x] **TONE-03 (Color Fidelity & Balance)**: Color Saturation (-100 to +100), Vibrance with skin-tone protection (-100 to +100), and 3-way Color Balance (Cyan ↔ Red, Magenta ↔ Green, Yellow ↔ Blue) with per-channel tone curves.
- [x] **TONE-04 (Typography Black Level & Sharpening)**: Black Level (-100 to +100) and Text Darkness (-100 to +100) to ensure deep, crisp typography; Text Sharpening (0-100) and Photo Sharpening (0-100).
- [x] **TONE-05 (Paper Compensation Presets)**:
  - `Plain Paper`: Midtone lift (+8), text darkness (+12), text sharp (+15), and density reduction (-6) to counteract porous fiber ink bleed.
  - `Matte Paper`: Deep shadow compensation (Black Level +12, Gamma 1.08) to counter matte ink absorption.
  - `Glossy Photo`: Dynamic range expansion (Contrast +10, Vibrance +8, Sat +6, Photo sharp +16).
- [x] **TONE-06 (Ink / Toner Saver Mode)**: Lighter-output mode with reduction levels (Light ~15%, Balanced ~28%, Aggressive ~42%), Text-Only Black option (preserves color tanks), and estimated savings badge clearly labeled `"~28% ink saved (estimate)"` (*"~28% තීන්ත ඉතිරියක් (ඇස්තමේන්තුව)"*).
- [x] **TONE-07 (Double Adjustment Guardrail & 1-Click Auto-Fix)**: Automatically detects when both driver color adjustment and app tone preprocessing are active, displaying an alert with 1-click `[ Let Print Helper Manage Tone ]` auto-fix.
- [x] **TONE-08 (Plain Paper Bleed Guardrail)**: Automatically flags excessive density (> +25%) on plain paper with 1-click `[ Reduce Density to +15% ]` auto-fix.
- [x] **TONE-09 (Optical CMYK Coverage Meter & Shop Mode Pricing)**: Real-time per-channel coverage analysis ($C, M, Y, K$) feeding Shop Mode price calculations and daily ink cost tracking.
- [x] **TONE-10 (Compare with Original & Approximate Preview Tag)**: Instant toggle button to compare original unadjusted input against active tone adjustments; approximate preview tag (*"Approximate print preview"* / *"මුද්‍රණ පෙරදසුන (ආසන්න)"*).
- [x] **TONE-11 (Spooler-Only Diagnostic Test Pattern)**:
  - Interactive Test Pattern Dialog featuring 11-step neutral gray ramp (0-100%), CMYK primary patches, 4-10pt micro-text sharpness target, and visual nozzle check pattern.
  - 100% normal document spooling; **NEVER** sends unverified raw ESC/P-R control codes or automatic cleaning commands.
  - Honest maintenance guidance pointing users to printer LCD menu or official Epson driver Maintenance tab (`DocumentProperties`).

### K. Multidimensional Pricing Engine, Mixed-Page Billing & Live Quotation
- [x] **PRICE-01 (Multidimensional Table & Wildcard Match Score)**: Supports 7 distinct dimensions (Print Type, Color, Paper Size, Paper Type, Sides, Quality, Printer Model). Specific matching outranks wildcards with exact score hierarchy; zero hard-coded prices.
- [x] **PRICE-02 (Quantity Tiers & Volume Thresholds)**: Seamless tiered pricing (e.g., 1-10 @ Rs. 15, 11-50 @ Rs. 12, 51-200 @ Rs. 10, 201+ @ Rs. 8) with mathematical verification at boundary transitions (10 vs 11, 50 vs 51, 200 vs 201 pages).
- [x] **PRICE-03 (Automatic Page Classification & Mixed-Document Billing)**: Scans individual pages and classifies them into B&W text vs. Color vs. Photo-heavy. Mixed documents (e.g. 17 B&W + 3 Color) are billed by itemized segments rather than charging the entire file at color rates. Supports per-page owner overrides.
- [x] **PRICE-04 (Ink-Coverage Pricing Bands)**: Optional pricing based on optical coverage bands (Light <10%, Medium 10-25%, Heavy >25%) tied to the optical CMYK estimator with multiplier adjustments.
- [x] **PRICE-05 (Customer Groups & Allowances)**: Configurable customer tiers (Regular, Student 15% discount, Business 2 Free Pages + 10% discount, VIP/Wholesale) with percentage discounts, fixed discounts, and free page allowances applied before tax.
- [x] **PRICE-06 (Fees & Surcharges)**: Minimum job charge safeguard (e.g. Rs. 20.00 minimum), one-off setup/service fee (Rs. 10.00), rush order surcharge (+25%), and borderless/specialty media surcharges.
- [x] **PRICE-07 (Bilingual Currency & Configurable Rounding)**: Default Sri Lankan Rupee (`LKR` / `Rs.` / `රු.`) and multi-currency support; configurable rounding rules (None, Nearest Rs. 1.00, Rs. 5.00, Rs. 10.00, Rs. 50.00) with clear indication of rounding adjustments.
- [x] **PRICE-08 (Live Price Strip & Pinned Print Button)**: Live price counter embedded in the pinned print panel right next to the Print button; expands to show a real-time segment breakdown and margin without pushing the Print button off-screen.
- [x] **PRICE-09 (Quote Mode Modal & PDF Receipts)**: 1-click **Quote** button opens an itemized quotation modal without spooling print jobs; exports bilingual receipts/invoices in English and everyday Spoken Sinhala with shop branding, tax breakdown, and estimated completion.
- [x] **PRICE-10 (Supply Cost & Net Profit Tracking)**: Owner inputs unit costs for ink bottles/toners and paper reams; engine computes estimated supply cost and net profit per job, honestly labeled with `(estimate)` / `(ඇස්තමේන්තුව)`.
- [x] **PRICE-11 (Missing Price Safeguard & Never-Zero Guarantee)**: Detects combinations with missing rates, alerts the shop owner with a warning banner, falls back to conservative safety rates, and never silently prints at Rs. 0.00. Includes a 1-click `[ Fix Missing Prices ]` action.
- [x] **PRICE-12 (Security PIN Lock, Audit Logging & Import/Export)**: 4-digit PIN lock prevents unauthorized price changes; full audit change history log (timestamp, field, old rate, new rate, user); duplicate price list; CSV and JSON export/import.

### L. Specialty Print Media Modules (Hardware-Native Gating & Spooler-Only Dispatch)
- [x] **SPEC-01 (Dynamic Capability Gating & Spooler-Only Policy)**: Specialty modules appear ONLY when the connected printer supports them based on live Print Schema / IPP / SNMP discovery or user-confirmed database records. Dispatches strictly via the official Windows driver through the spooler; NEVER sends unverified raw ESC/P-R control codes.
- [x] **SPEC-02 (CD/DVD/Blu-ray Disc Module & Mask Geometry)**: Circular layout template editor using outer & inner DIAMETERS (116mm outer / 43mm inner defaults; 80mm mini-disc option); doughnut clipping mask verified with unit tests; circular text path calculation; mandatory plain-paper 1:1 test print requirement with verification badge; disc tray loading instructions.
- [x] **SPEC-03 (CR80 PVC ID Card Module & Calibration Offset)**: Standard ISO/IEC 7810 ID-1 ($85.60 \times 53.98\text{ mm}$, $0.76\text{ mm}$); 1 or 2 card slots per tray (e.g. L8050/L18050); prominent inkjet-coated PVC requirement banner with user confirmation; printer-specific $(X, Y)$ calibration offset sliders; opt-in aftermarket tray mode with mechanical warning; batch CSV import.
- [x] **SPEC-04 (Passport & ID Photo Sheets Imposition)**: Standard presets (Sri Lanka/UK 35x45mm, US Visa 2x2" / 51x51mm, 30x40mm, 35x35mm, custom); automatic imposition optimization on 4x6" (6 photos) and A4 (28 photos rotated); customizable crop marks (dashed, solid, corner marks, none); yield counter.
- [x] **SPEC-05 (Rigid & Thick Media Guardrails)**: Media thickness validation against driver/confirmed limits (e.g. L8180 1.30mm, SC-P900 1.50mm, standard 0.30mm); blocks printing and displays red Mechanical Strike Hazard warning when exceeded; recommends straight-through rear/front feed tray path.
- [x] **SPEC-06 (Roll Paper & Rotary Cutter Management)**: Roll width selection (13", 17", 24", 36", 44"); cutter action modes (auto-cut after page, cut after job, print cut guide line, manual cut); banner length safeguards (up to 18m); borderless on roll support.
- [x] **SPEC-07 (Dye-Sublimation Merchandise & Auto-Mirror)**: Merchandise templates (11oz mug 200x95mm, 15oz mug 220x105mm, T-shirt A4/A3, lanyard 900x20mm, mousepad); Horizontal Mirror Flip locked ON when sublimation model or transfer preset is active; split live preview comparing original artwork vs mirrored transfer output.
- [x] **SPEC-08 (ColorWorks Labels & POS Receipt Printing)**:
  - ColorWorks industrial labels (continuous roll, die-cut 4x3", GHS chemical hazard, barcode generator, peeler/cutter mode).
  - TM-series shop counter thermal receipts (80mm 48-col & 58mm 32-col, monospace preview, Shop Mode pricing integration, ESC/POS `GS V 0` auto-cut command bytes).

### M. Multi-Printer Fleet Dashboard & Intelligent Routing Engine
- [x] **ROUT-01 (Strict Telemetry Hierarchy)**: Resolves live printer data in strict order: IPP (RFC 8011) first &rarr; SNMP (RFC 3805 / RFC 2790) second &rarr; Driver / Spooler third. Dynamic table walking avoids assuming fixed indexes.
- [x] **ROUT-02 (RFC 3805 Negative Special Values Protection)**: Rigorously handles negative supply levels:
  - Level `-1`: Rendered as `"OK"` (*"හරි (OK)"*), never computed as 100%.
  - Level `-3`: Rendered as `"Some Remaining"` (*"ප්‍රමාණවත්"*).
  - Level `-2` or Capacity `-2`: Rendered as `"Not reported"` (*"වාර්තා නැත"*).
  - Division by zero and negative percentage calculations are mathematically prevented.
- [x] **ROUT-03 (Honest Telemetry & Continuous Tank Estimation Tags)**: Continuous ink tank (EcoTank) virtual drop counter levels are prominently labeled `"(estimate)"` (*"(ඇස්තමේන්තුව)"*). Maintenance box fullness is tracked against the configurable alert threshold (default 15%).
- [x] **ROUT-04 (Subnet Discovery Permission Guardrail)**: Probing 254 IP addresses across a subnet (UDP 161 & TCP 631) requires explicit operator consent via `SubnetScanConsentDialog`. Features 1500ms timeouts, max 10 concurrent requests, and low polling cadence (30s-60s).
- [x] **ROUT-05 (Plain-Language Hardware Alerts)**: Plain-language translation of MIB alerts (e.g. Paper out, Jam, Cover open, Tray misaligned) in everyday English and Spoken Sinhala.
- [x] **ROUT-06 (Multi-Printer Fleet Dashboard Cards)**: Dynamic cards display device name, model, interface chip (USB, Wi-Fi, LAN, Virtual), queue job count, lifetime page counter (`prtMarkerLifeCount`), status dot, specialty badge row, ink channel meters, maintenance box gauge, and loaded paper tray summary.
- [x] **ROUT-07 (Intelligent Routing Rule Hierarchy)**:
  - Priority 1: Specialty Hardware Constraints (CD/DVD, PVC ID Card, Rigid Board, Roll, Sublimation strictly routed to capable devices).
  - Priority 2: Bulk Document (>50 pages) Load Balancing (routes to WorkForce Pro / RIPS high-speed duplex).
  - Priority 3: Photo & Fine Art Chromatic Priority (routes photos to 6-color / 10-color engines).
  - Priority 4: Offline / Low Supplies Failover.
- [x] **ROUT-08 (Operator Failover Etiquette & Single-Sentence Rationale)**: The engine NEVER silently diverts jobs without operator consent. Prompts with original target, proposed alternate, and a single plain sentence rationale in English and Spoken Sinhala (e.g. *"Rerouted to Epson EcoTank L8050 because target printer is offline and L8050 supports borderless photo printing"* / *"ඉලක්කගත මුද්‍රණ යන්ත්‍රය ක්‍රියාවිරහිත බැවින් සහ L8050 මඟින් ඡායාරූප මුද්‍රණය කළ හැකි බැවින් L8050 වෙත යොමු කරන ලදී"*).




