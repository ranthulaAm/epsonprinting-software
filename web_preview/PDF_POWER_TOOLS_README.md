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
PDF→Images (ZIP) · Images→PDF · Extract text · OCR (Tesseract, makes searchable PDFs) · Compare two PDFs

## Optional: OCR
    brew install tesseract tesseract-lang     # adds Sinhala (sin) and 100+ languages
Restart the engine; the banner lists installed OCR languages.

## Known limits
- Watermark / page-number text is Latin only (built-in PDF fonts). Sinhala stamps need an embedded font — planned.
- Redacted pages become images (that is what makes redaction secure); file gets larger and text on those pages is no longer selectable.
- Annotations/signatures/form-filling are still demo UI in the other tabs.
- Windows/Flutter app does not use this engine yet; it is the proving ground for the features.
