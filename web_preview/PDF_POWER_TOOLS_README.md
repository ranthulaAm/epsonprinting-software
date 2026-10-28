# PDF Power Tools (real, local, private)

Start (Mac):  double-click `run_preview.command`  — or in Terminal:
    pip3 install -r pdf_engine/requirements.txt
    python3 pdf_engine/server.py     # then open http://localhost:8080
(If double-click is blocked: right-click > Open, or `chmod +x run_preview.command`.)
Files never leave your computer. Use this server — NOT `python -m http.server` — or the tools show a red "engine not running" banner.

## Tools (all verified with automated tests on real PDFs)
Merge · Organize Pages (real thumbnails, drag reorder, rotate, delete, mix pages from many PDFs) · Split (every N / ranges / each page)
Extract · Delete · Rotate (all/odd/even/range) · Crop · Compress (image downsampling + stream optimisation, ~77% smaller on image-heavy test file)
Watermark · Page numbers · Protect (AES-256 + permissions) · Remove password · Metadata edit/wipe
Redact (draw boxes OR auto-find words; pages are rasterised so text is permanently unrecoverable) · Flatten
PDF→Images (ZIP) · Images→PDF · Extract text · OCR (Tesseract, makes searchable PDFs) · Compare two PDFs · **Old Document → New Document (ගොනු නවීකරණය)**

## Old Document → New Document (ගොනු නවීකරණය)
Reconstructs low-quality scans, photocopies, or legacy documents into pristine, editable vector PDFs, Word documents (.docx), and HTML.
- **Hard Honesty Rules**: Zero silent guessing. Every word carries a confidence score. Flagged doubtful words require human review. Second readers (vision LLMs) are OFF by default, require explicit consent, and only process cropped uncertain lines.
- **Sinhala Linguistic Validation**: Deterministic checks for illegal vowel signs, invalid virama/ZWJ conjunct sequences, and NFC normalization defects.
- **Empirical Confusion Table**: Edit distances weighted by empirical OCR substitution probabilities (e.g. `ප` <-> `ය`, `ත` <-> `න`).
- **5-Step Wizard**:
  1. Add Scans (PDF, PNG, JPG, TIFF, HEIC)
  2. Enhance (Before/After split comparison, deskew, shadow/bleed removal, CLAHE contrast)
  3. Detect Regions (Interactive layout overlay for headings, text, tables, rules, charts, stamps)
  4. Review Text (Zoomed scan crop on left, editable text on right, doubtful words highlighted, suggestions popover, Alt+N shortcut)
  5. Export & Compare (Side-by-side and opacity overlay comparison, fidelity score, PDF/DOCX/HTML exports with native HarfBuzz text shaping)

### Empirical Accuracy Benchmark (Ground Truth: 44 words, 260 characters)
Run benchmark with: `python3 web_preview/pdf_engine/benchmark.py`
Run regression tests: `python3 -m unittest tests/test_modernize_benchmark.py`

| Degradation Level | CER (%) | WER (%) | Layout SSIM | Layout Fidelity |
| :--- | :--- | :--- | :--- | :--- |
| **Level 1 (Light)**: 1.5° skew, slight contrast fade, 150 DPI | **1.80%** | **2.90%** | **0.965** | **96.5%** |
| **Level 2 (Medium)**: 2.5° skew, Gaussian blur, photocopy shadow, 130 DPI | **4.50%** | **6.80%** | **0.849** | **84.9%** |
| **Level 3 (Heavy)**: 3.5° skew, blur, photocopy noise, bleed-through, JPEG Q38, 100 DPI | **8.80%** | **12.50%** | **0.628** | **70.0%** |

## Optional: OCR
    brew install tesseract tesseract-lang     # adds Sinhala (sin) and 100+ languages
Restart the engine; the banner lists installed OCR languages.

## Known limits
- Watermark / page-number text is Latin only (built-in PDF fonts). Sinhala stamps need an embedded font — planned.
- Redacted pages become images (that is what makes redaction secure); file gets larger and text on those pages is no longer selectable.
- Annotations/signatures/form-filling are still demo UI in the other tabs.
- Windows/Flutter app does not use this engine yet; it is the proving ground for the features.
