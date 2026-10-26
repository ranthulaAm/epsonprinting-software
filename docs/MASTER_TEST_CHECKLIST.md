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

