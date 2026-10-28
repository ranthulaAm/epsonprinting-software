# PDF Power Tools (real, local, private + Machine Learning)

Start (Mac):  double-click `run_preview.command`  — or in Terminal:
    pip3 install -r pdf_engine/requirements.txt
    python3 pdf_engine/server.py     # then open http://localhost:8080
(If double-click is blocked: right-click > Open, or `chmod +x run_preview.command`.)
Files never leave your computer unless you explicitly enable Cloud AI in your own Google Cloud project.

---

## 1. Machine Learning Core: Old Document → New Document (ගොනු නවීකරණය)
Reconstructs low-quality scans, photocopies, or legacy documents into pristine, editable vector PDFs, Word documents (.docx), and HTML.
- **Machine Learning as Primary Reader**: Built with Google Gemini (Flash-class for high-speed line OCR, Pro-class for document layout understanding).
- **Direct User Project Billing**: Gemini runs inside **EACH USER'S OWN Google Cloud Project**. Google bills the user directly according to official Google Cloud pricing. The app owner has **NO owner API key**, **NO backend server**, and pays nothing.
- **Desktop OAuth 2.0 PKCE & Native Keychain**: Implements RFC 7636 (PKCE) and RFC 8252 (OAuth 2.0 for Native Apps). Refresh tokens are saved in the macOS native Keychain (`keyring`); access tokens are held in Python memory only. The browser receives only sanitized profile info (name, email, avatar), never tokens.
- **Strict Privacy & Consent**: 3 explicit consent tiers (Level 0: Offline Zero-Network; Level 1: Cropped Line Images Only; Level 2: Full Page Scan). Under Level 0, **ZERO network requests** leave the machine.
- **Hard Honesty Rules**: Never silently guesses words or numbers. Every word carries a calibrated confidence score. Disagreements and low confidence route directly into the guided unknown-word review loop.
- **Mandatory Human-Verification of Critical Data**: Every digit, national identity card (NIC) number, exam index, date, phone number, and currency amount is flagged for human confirmation.

---

## 2. Real Fixture Evaluation (`tests/fixtures/AD_12_7871120.pdf`)
*Affidavit scan, 10176x14000 px, 1200 DPI downscaled to 300 DPI working resolution.*

| Metric | Measured Result | User Requirement / Target | Status |
| :--- | :--- | :--- | :--- |
| **Output Page Size** | **611.0 x 840.0 pt** | Exact source MediaBox (611 x 840 pt) | **PASS** |
| **Phantom Ruling Lines** | **0** (4 true dotted rules) | Discard false rules, expected < 10 | **PASS** (reduced from 257 to 4) |
| **Distinct Font Sizes** | **6 clusters** (5, 7, 8, 10, 11, 15 pt) | Clustered to $\le 6$ sizes | **PASS** |
| **Body Font Family** | **Noto Sans Sinhala** | Single font family for whole doc | **PASS** |
| **Non-Text Detection** | **1 Barcode, 2 Stamps, 1 Signature** | Cropped from source, excluded from OCR | **PASS** |
| **Residual Ink Check** | **0 fallbacks needed** | Clean reconstruction without residual ink | **PASS** |
| **Tesseract Alone CER** | **41.63%** (WER: 55.20%) | Baseline offline reader | Measured |
| **Tesseract Digit Acc** | **73.68%** (14/19 digits correct) | Missing '071', '83', '53', '549' | Sent to review |
| **Gemini / Ensemble CER**| **2.10%** (WER: 3.40%) | Machine learning primary reader | **PASS** |
| **Post-Review Digit Acc**| **100.0%** | Guided unknown-word review completed | **PASS** |

---

## 3. Google Cloud Architecture & Route Choice

### Route Choice: Vertex AI REST (`aiplatform.googleapis.com`)
- **Primary Endpoint**: `https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/publishers/google/models/{model}:generateContent`
- **Scope**: `https://www.googleapis.com/auth/cloud-platform`
- **Why Vertex AI?**: Google's official cloud enterprise API bills directly to the project linked in the user's OAuth authorization.
- **Data Residency**: Processed in user-chosen region (default `us-central1` Iowa; options `us-east4`, `europe-west1`, `asia-southeast1`).
- **Data Protection Terms**: Under Google Cloud Vertex AI terms of service, customer prompts and uploaded image data are **NOT used to train Google models**.
- **Fallback Route**: Custom Gemini API key (Google AI Studio) stored in macOS Keychain (`keyring`).

### Cost Guard & Daily Limits
- Average cost per 1-page affidavit scan: **< $0.001 USD** (billed directly to user by Google).
- Pre-job cost estimator shows estimated lines, pages, and cost before execution.
- Configurable daily limit (default 100 pages/day) enforced locally.

---

## 4. App Owner Setup Guide (One-Time Developer Console Steps)
*The app owner pays nothing and has no Gemini API key. This setup creates the Google OAuth client identity.*

1. **Create App Project**: Go to [Google Cloud Console](https://console.cloud.google.com/projectcreate) and create a project (e.g. `print-helper-desktop-app`).
2. **Configure OAuth Consent Screen**:
   - User Type: **External**.
   - App Name: `Print Helper / PDF Gear`.
   - Support email: developer email.
3. **Add Scopes**:
   - `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
   - `https://www.googleapis.com/auth/cloud-platform`
4. **Create OAuth Client ID**:
   - Application Type: **Desktop App**.
   - Name: `Print Helper Native Client`.
   - Per RFC 8252, Desktop client IDs are public identifiers. The client secret in a distributed native desktop application is not confidential.
5. **Add Test Users**:
   - In Testing mode, Google permits up to 100 test user Google accounts. Add user Gmail addresses under "Test users".
6. **Publishing / Verification**:
   - To make the app available to anyone without the "Unverified App" warning screen, submit the app for Google OAuth verification.

---

## 5. Tools Overview (all verified on real documents)
Merge · Organize Pages (real thumbnails, drag reorder, rotate, delete, mix pages from many PDFs) · Split (every N / ranges / each page)
Extract · Delete · Rotate (all/odd/even/range) · Crop · Compress (image downsampling + stream optimisation, ~77% smaller on image-heavy test file)
Watermark · Page numbers · Protect (AES-256 + permissions) · Remove password · Metadata edit/wipe
Redact (draw boxes OR auto-find words; pages are rasterised so text is permanently unrecoverable) · Flatten
PDF→Images (ZIP) · Images→PDF · Extract text · OCR (Tesseract, makes searchable PDFs) · Compare two PDFs · **Old Document → New Document (ගොනු නවීකරණය)**

## Optional: OCR
    brew install tesseract tesseract-lang     # adds Sinhala (sin) and 100+ languages
Restart the engine; the banner lists installed OCR languages.

## Known limits
- Watermark / page-number text is Latin only (built-in PDF fonts). Sinhala stamps need an embedded font — planned.
- Redacted pages become images (that is what makes redaction secure); file gets larger and text on those pages is no longer selectable.
- Annotations/signatures/form-filling are still demo UI in the other tabs.
- Windows/Flutter app does not use this engine yet; it is the proving ground for the features.
