#!/usr/bin/env python3
"""Print Helper local PDF server.  Run:  python3 pdf_engine/server.py   then open http://localhost:8080
Serves the web preview and a JSON API. Everything stays on your computer."""
import io, json, os, sys, threading, uuid, zipfile, mimetypes, traceback, collections, base64
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# Ensure workspace root is in sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Ensure standard Homebrew & local tool paths are in PATH
for p in ("/opt/homebrew/bin", "/usr/local/bin"):
    if os.path.exists(p) and p not in os.environ.get("PATH", "").split(":"):
        os.environ["PATH"] = p + ":" + os.environ.get("PATH", "")
import engine
from engine import PdfError, PDFIUM_LOCK

try:
    import pillow_heif
    pillow_heif.register_heif_opener()
except Exception:
    pass

import preprocess
import layout_analyzer
import ocr_engine
import renderer
import fidelity
import review_manager
from PIL import Image, ImageSequence

JOBS = {}       # job_id -> dict
JOBS_LOCK = threading.Lock()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_UPLOAD = 300 * 1024 * 1024
FILES = {}      # id -> bytes
NAMES = {}      # id -> filename
PWS = {}        # id -> password used to open (for thumbnails/ops)
LOCK = threading.Lock()
THUMBS = collections.OrderedDict()

def new_id(data, name, pw=""):
    fid = uuid.uuid4().hex[:12]
    with LOCK:
        FILES[fid] = data; NAMES[fid] = name; PWS[fid] = pw
    return fid

def describe(fid):
    d = FILES[fid]
    base = {"id": fid, "name": NAMES[fid], "size": len(d)}
    if d[:4] == b"%PDF" or d[:1024].find(b"%PDF") >= 0:
        try:
            i = engine.info(d, password=PWS.get(fid, ""))
            base.update(i); base["kind"] = "pdf"
        except PdfError as e:
            base.update({"kind": "pdf", "pages": 0, "error": str(e)})
    else:
        try:
            with Image.open(io.BytesIO(d)) as img:
                n_frames = getattr(img, "n_frames", 1)
                page_sizes = []
                for idx in range(min(50, n_frames)):
                    try:
                        img.seek(idx)
                        page_sizes.append([round(img.width * 72 / 150, 2), round(img.height * 72 / 150, 2)])
                    except Exception:
                        page_sizes.append([595.28, 841.89])
                base.update({
                    "kind": "image",
                    "format": (img.format or "image").lower(),
                    "pages": n_frames,
                    "page_sizes": page_sizes
                })
        except Exception:
            base.update({"kind": "other", "pages": 0})
    return base

def ensure_pdf(fid, files_dict=None):
    """Wraps an uploaded image (or multi-frame image) as a PDF in memory."""
    d = FILES[fid]
    if d[:4] == b"%PDF" or d[:1024].find(b"%PDF") >= 0:
        return d
    try:
        with Image.open(io.BytesIO(d)) as img:
            frames = []
            for frame in ImageSequence.Iterator(img):
                frames.append(frame.convert("RGB"))
            if frames:
                buf = io.BytesIO()
                frames[0].save(buf, format="PDF", save_all=True, append_images=frames[1:])
                pdf_data = buf.getvalue()
                if files_dict is not None:
                    files_dict[fid] = pdf_data
                return pdf_data
    except Exception as e:
        print(f"Error wrapping image {fid} as PDF: {e}")
    return d

def out_name(src_id, suffix, ext="pdf"):
    stem = os.path.splitext(NAMES.get(src_id, "document"))[0]
    return f"{stem}_{suffix}.{ext}"

def run_op(op, fids, o):
    pw = lambda f: PWS.get(f, "")
    pws = {f: pw(f) for f in fids}
    files = {f: ensure_pdf(f) for f in fids}
    f0 = fids[0] if fids else None
    res = []   # list of (name, bytes, msg)
    msg = ""
    if op == "merge":
        if len(fids) < 2: raise PdfError("Select at least 2 PDFs to merge")
        res.append((o.get("name") or "merged.pdf", engine.merge(fids, files, pws)))
        msg = f"Merged {len(fids)} files"
    elif op == "assemble":
        items = o["items"]
        for it in items:
            if it.get("blank"):
                continue
            files.setdefault(it["file"], FILES[it["file"]]); pws.setdefault(it["file"], pw(it["file"]))
        res.append((o.get("name") or "organized.pdf", engine.assemble(items, files, pws)))
        msg = f"Built document with {len(items)} pages"
    elif op in ("extract", "delete"):
        res.append((out_name(f0, op), engine.select(f0, files, o.get("pages", "all"), op, pw(f0))))
    elif op == "rotate":
        res.append((out_name(f0, "rotated"), engine.rotate(f0, files, o.get("pages", "all"), int(o.get("degrees", 90)), pw(f0))))
    elif op == "split":
        parts = engine.split(f0, files, o.get("mode", "every"), o.get("value", "1"), pw(f0))
        for suffix, data in parts:
            res.append((out_name(f0, suffix), data))
        msg = f"Split into {len(parts)} files"
    elif op == "crop":
        m = {k: float(o.get(k, 0)) for k in ("top", "right", "bottom", "left")}
        res.append((out_name(f0, "cropped"), engine.crop(f0, files, o.get("pages", "all"), m, pw(f0))))
    elif op == "compress":
        data, b, a = engine.compress(f0, files, o.get("level", "medium"), pw(f0))
        saved = 100 * (1 - a / b) if b else 0
        res.append((out_name(f0, "compressed"), data))
        msg = f"{b/1024:.0f} KB -> {a/1024:.0f} KB ({saved:.0f}% smaller)" if a < b else "Already optimal — no smaller version possible"
    elif op == "watermark":
        res.append((out_name(f0, "watermarked"), engine.watermark(f0, files, o.get("text", ""), o.get("pages", "all"),
                    float(o.get("opacity", 0.25)), float(o.get("size", 64)), float(o.get("angle", 45)), o.get("color", "#888888"), pw(f0))))
    elif op == "pagenumbers":
        res.append((out_name(f0, "numbered"), engine.page_numbers(f0, files, o.get("format", "Page {n} of {total}"),
                    o.get("position", "bottom-center"), int(o.get("start", 1)), float(o.get("size", 10)), o.get("pages", "all"), pw(f0))))
    elif op == "protect":
        res.append((out_name(f0, "protected"), engine.protect(f0, files, o.get("user", ""), o.get("owner") or None,
                    bool(o.get("allow_print", True)), bool(o.get("allow_copy", True)), bool(o.get("allow_edit", False)), pw(f0))))
        msg = "AES-256 encryption applied"
    elif op == "unprotect":
        res.append((out_name(f0, "unlocked"), engine.unprotect(f0, files, o.get("password", pw(f0)))))
    elif op == "metadata":
        res.append((out_name(f0, "meta"), engine.set_metadata(f0, files, o.get("meta", {}), bool(o.get("strip")), pw(f0))))
    elif op == "redact":
        data, hits, pages = engine.redact(f0, files, o.get("regions"), o.get("terms"), int(o.get("dpi", 150)), pw(f0))
        res.append((out_name(f0, "redacted"), data))
        msg = f"Burned in black boxes on {pages} page(s)" + (f", {hits} text match(es)" if hits else "") + ". Text under them is permanently removed."
    elif op == "flatten":
        res.append((out_name(f0, "flattened"), engine.flatten(f0, files, int(o.get("dpi", 150)), pw(f0))))
    elif op == "pdf_to_images":
        res.append((out_name(f0, "images", "zip"), engine.pdf_to_images(f0, files, o.get("format", "png"), int(o.get("dpi", 150)), o.get("pages", "all"), pw(f0))))
    elif op == "images_to_pdf":
        res.append((o.get("name") or "images.pdf", engine.images_to_pdf([FILES[f] for f in fids])))
    elif op == "text":
        from text_intel import smart_text
        res_dict = smart_text(
            f0, files,
            spec=o.get("pages", "all"),
            password=pw(f0),
            mode=o.get("mode", "auto"),
            layout=o.get("layout", "smart"),
            fmt=o.get("fmt", "txt"),
            clean=bool(o.get("clean", True)),
            dehyphenate=bool(o.get("dehyphenate", True)),
            markers=bool(o.get("markers", True)),
            lang=o.get("lang", "auto"),
            dpi=int(o.get("dpi", 250))
        )
        ext = o.get("fmt", "txt")
        download_name = out_name(f0, "extracted", ext)
        fid = new_id(res_dict["text"].encode("utf-8"), download_name)
        res_dict["results"] = [describe(fid)]
        res_dict["message"] = f"Extracted {res_dict['summary']['words']} words across {res_dict['summary']['pages']} page(s)"
        return res_dict
    elif op == "ocr":
        t, merged = engine.ocr(f0, files, o.get("lang", "eng"), int(o.get("dpi", 200)), o.get("pages", "all"), pw(f0), bool(o.get("searchable", True)))
        out = {"text": t, "results": [], "message": "OCR complete"}
        if merged:
            fid = new_id(merged, out_name(f0, "searchable"))
            out["results"].append(describe(fid)); out["message"] = "OCR complete — searchable PDF created"
        return out
    elif op == "compare":
        if len(fids) != 2: raise PdfError("Select exactly 2 PDFs to compare")
        r = engine.compare(fids[0], fids[1], files, pws.get(fids[0], ""), pws.get(fids[1], ""))
        return {"compare": r, "results": [], "message": "Identical text" if r["identical"] else f"{r['added']} lines added, {r['removed']} removed"}
    else:
        raise PdfError(f"Unknown operation: {op}")
    results = []
    for name, data in res:
        fid = new_id(data, name)
        results.append(describe(fid))
    return {"results": results, "message": msg or "Done"}

def run_modernize_worker(job_id, fid, opts):
    import cv2
    try:
        raw_data = FILES.get(fid)
        if not raw_data:
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "error"
                JOBS[job_id]["error"] = "Input file not found"
            return

        is_pdf = (raw_data[:4] == b"%PDF" or raw_data[:1024].find(b"%PDF") >= 0)
        page_images = []

        if is_pdf:
            import pypdfium2 as pdfium
            with PDFIUM_LOCK:
                doc = pdfium.PdfDocument(raw_data, password=PWS.get(fid, "") or None)
                n_pages = len(doc)
                for i in range(n_pages):
                    pil_img = doc[i].render(scale=150 / 72.0).to_pil().convert("RGB")
                    page_images.append(pil_img)
                doc.close()
        else:
            with Image.open(io.BytesIO(raw_data)) as img:
                for frame in ImageSequence.Iterator(img):
                    page_images.append(frame.convert("RGB"))

        total_pages = len(page_images)
        with JOBS_LOCK:
            JOBS[job_id]["total_pages"] = total_pages

        ensemble = ocr_engine.MultiEngineEnsemble()
        doc_pages = []
        previews = []

        for p_idx, pil_img in enumerate(page_images):
            with JOBS_LOCK:
                if JOBS[job_id].get("cancelled"):
                    JOBS[job_id]["status"] = "cancelled"
                    return
                JOBS[job_id]["current_page"] = p_idx + 1
                JOBS[job_id]["step"] = f"Enhancing & deskewing page {p_idx + 1} of {total_pages}"
                JOBS[job_id]["progress"] = round((p_idx / max(1, total_pages)) * 100, 1)

            # 1. Preprocess
            prep_res = preprocess.preprocess_document_page(pil_img)
            clean_bgr = prep_res["clean_bgr"]
            review_manager.REVIEW_MANAGER.register_page_images(job_id, p_idx + 1, prep_res["orig_bgr"], clean_bgr)

            # Save preview before/after
            _, orig_buf = cv2.imencode(".jpg", prep_res["orig_bgr"], [int(cv2.IMWRITE_JPEG_QUALITY), 75])
            _, enh_buf = cv2.imencode(".jpg", clean_bgr, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
            previews.append({
                "page": p_idx + 1,
                "orig_b64": f"data:image/jpeg;base64,{base64.b64encode(orig_buf).decode('ascii')}",
                "enh_b64": f"data:image/jpeg;base64,{base64.b64encode(enh_buf).decode('ascii')}"
            })

            with JOBS_LOCK:
                JOBS[job_id]["step"] = f"Analyzing layout & reading lines for page {p_idx + 1} of {total_pages}"

            # 2. Layout Analysis
            page_layout = layout_analyzer.analyze_document_layout(clean_bgr, dpi=150)
            page_layout["page_num"] = p_idx + 1

            # 3. Line OCR & Word Verification
            for blk in page_layout["blocks"]:
                if blk["type"] in ("heading", "text"):
                    for ln in blk.get("lines", []):
                        lx, ly, lw, lh = ln["bbox"]
                        line_crop = clean_bgr[ly:ly+lh, lx:lx+lw]
                        if line_crop.size > 0:
                            crop_pil = Image.fromarray(cv2.cvtColor(line_crop, cv2.COLOR_BGR2RGB))
                            words = ensemble.process_line(crop_pil)
                            ln["words"] = words

            # 4. Evaluate fidelity
            eval_res = fidelity.evaluate_fidelity(prep_res["orig_bgr"], clean_bgr, page_layout["blocks"])
            page_layout["fidelity"] = eval_res
            doc_pages.append(page_layout)

        doc_model = {
            "version": "1.0",
            "doc_id": "mod_" + uuid.uuid4().hex[:8],
            "file_name": NAMES.get(fid, "document.pdf"),
            "pages": doc_pages
        }
        review_manager.REVIEW_MANAGER.get_or_create_session(job_id, doc_model=doc_model)

        with JOBS_LOCK:
            JOBS[job_id]["status"] = "done"
            JOBS[job_id]["progress"] = 100.0
            JOBS[job_id]["doc_model"] = doc_model
            JOBS[job_id]["previews"] = previews
            JOBS[job_id]["step"] = "Complete"

    except Exception as e:
        traceback.print_exc()
        with JOBS_LOCK:
            JOBS[job_id]["status"] = "error"
            JOBS[job_id]["error"] = str(e)

class H(BaseHTTPRequestHandler):
    server_version = "PrintHelperPDF/1.0"
    def log_message(self, fmt, *a):
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.send_header("Cache-Control", "no-store"); self.end_headers(); self.wfile.write(b)

    def _bytes(self, data, ctype, name=None, download=False):
        self.send_response(200); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(data)))
        if name:
            from urllib.parse import quote
            self.send_header("Content-Disposition", ("attachment" if download else "inline") + f"; filename*=UTF-8''{quote(name)}")
        self.end_headers(); self.wfile.write(data)

    def do_GET(self):
        u = urlparse(self.path); path = unquote(u.path)
        try:
            if path == "/api/health":
                langs = engine.available_ocr_langs()
                has_sin = "sin" in langs
                return self._json({
                    "ok": True,
                    "installed_engines": ["tesseract", "local_sinhala", "cloud_vision"],
                    "ocr_langs": langs,
                    "has_sin": has_sin,
                    "setup_cmd_mac": "brew install tesseract tesseract-lang, then put tessdata_best sin.traineddata in the tessdata folder"
                })
            if path.startswith("/api/jobs/"):
                job_id = path.split("/")[3]
                with JOBS_LOCK:
                    job = JOBS.get(job_id)
                if not job:
                    return self._json({"error": "Job not found"}, 404)
                return self._json(job)
            if path.startswith("/api/modernize/") and "/crop/word/" in path:
                parts = path.split("/")
                job_id = parts[3]
                word_id = parts[6]
                mode = parse_qs(u.query).get("mode", ["orig"])[0]
                png_bytes = review_manager.REVIEW_MANAGER.get_word_crop_png(job_id, word_id, mode=mode)
                if not png_bytes:
                    return self._json({"error": "Word crop not found"}, 404)
                return self._bytes(png_bytes, "image/png")
            if path.startswith("/api/modernize/") and "/crop/line/" in path:
                parts = path.split("/")
                job_id = parts[3]
                word_id = parts[6]
                mode = parse_qs(u.query).get("mode", ["orig"])[0]
                png_bytes = review_manager.REVIEW_MANAGER.get_line_crop_png(job_id, word_id, mode=mode)
                if not png_bytes:
                    return self._json({"error": "Line crop not found"}, 404)
                return self._bytes(png_bytes, "image/png")
            if path.startswith("/api/modernize/") and path.endswith("/next-unknown"):
                parts = path.split("/")
                job_id = parts[3]
                sens = parse_qs(u.query).get("sensitivity", [None])[0]
                res = review_manager.REVIEW_MANAGER.get_next_unknown(job_id, sensitivity=sens)
                return self._json(res)
            if path.startswith("/api/modernize/") and path.endswith("/auto-applied"):
                parts = path.split("/")
                job_id = parts[3]
                res = review_manager.REVIEW_MANAGER.get_auto_applied(job_id)
                return self._json(res)
            if path.startswith("/api/file/"):
                parts = path.split("/")
                if len(parts) < 4: return self._json({"error": "File not found"}, 404)
                fid = parts[3]
                if fid not in FILES: return self._json({"error": "File not found"}, 404)
                q = parse_qs(u.query); name = NAMES.get(fid, "download.pdf")
                guessed_type = mimetypes.guess_type(name)[0]
                ctype = guessed_type or ("application/zip" if name.endswith(".zip") else "application/pdf")
                return self._bytes(FILES[fid], ctype, name, q.get("download") == ["1"])
            if path.startswith("/api/thumb/"):
                parts = path.split("/")
                if len(parts) < 5: return self._json({"error": "Invalid thumbnail URL"}, 400)
                fid = parts[3]
                page = parts[4]
                if fid not in FILES: return self._json({"error": "File not found"}, 404)
                try:
                    w = int(parse_qs(u.query).get("w", ["240"])[0])
                except (ValueError, TypeError):
                    w = 240
                w = max(60, min(900, w))
                try:
                    page_idx = int(page) - 1
                except ValueError:
                    return self._json({"error": "Invalid page number"}, 400)

                key = (fid, page_idx, w, PWS.get(fid, ""))
                with LOCK:
                    if key in THUMBS:
                        THUMBS.move_to_end(key)
                        cached = THUMBS[key]
                    else:
                        cached = None
                
                if cached is None:
                    raw_d = FILES[fid]
                    if not (raw_d[:4] == b"%PDF" or raw_d[:1024].find(b"%PDF") >= 0):
                        with Image.open(io.BytesIO(raw_d)) as im:
                            n_fr = getattr(im, "n_frames", 1)
                            if page_idx < 0 or page_idx >= n_fr:
                                page_idx = 0
                            im.seek(page_idx)
                            im_rgb = im.convert("RGB")
                            scale = w / max(1, im_rgb.width)
                            new_h = max(1, int(im_rgb.height * scale))
                            thumb_im = im_rgb.resize((w, new_h), Image.Resampling.BILINEAR)
                            b = io.BytesIO()
                            thumb_im.save(b, "PNG")
                            cached = b.getvalue()
                    else:
                        pw = PWS.get(fid, "")
                        img = engine.render_thumb((fid, pw), FILES[fid], page_idx, w, pw)
                        b = io.BytesIO()
                        img.save(b, "PNG")
                        cached = b.getvalue()
                    with LOCK:
                        THUMBS[key] = cached
                        while len(THUMBS) > 800:
                            THUMBS.popitem(last=False)

                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(cached)))
                self.send_header("Cache-Control", "private, max-age=86400")
                self.end_headers()
                self.wfile.write(cached)
                return
            if path.startswith("/api/pagepng/"):
                parts = path.split("/")
                if len(parts) < 5: return self._json({"error": "Invalid page URL"}, 400)
                fid = parts[3]
                page = parts[4]
                if fid not in FILES: return self._json({"error": "File not found"}, 404)
                zoom = float(parse_qs(u.query).get("zoom", ["1.4"])[0])
                pw = PWS.get(fid, "")
                img = engine.render_page(FILES[fid], int(page) - 1, zoom, pw, key=(fid, pw))
                b = io.BytesIO(); img.save(b, "PNG")
                return self._bytes(b.getvalue(), "image/png")
        except (PdfError, ValueError, IndexError) as e:
            return self._json({"error": str(e)}, 400)
        except Exception as e:
            return self._json({"error": f"Server error: {e}"}, 500)
        # static
        rel = "index.html" if path in ("/", "") else path.lstrip("/")
        full = os.path.normpath(os.path.join(ROOT, rel))
        if not full.startswith(ROOT) or "pdf_engine" in rel or not os.path.isfile(full):
            self.send_response(404); self.end_headers(); return
        ct = mimetypes.guess_type(full)[0] or "application/octet-stream"
        with open(full, "rb") as f: data = f.read()
        self.send_response(200); self.send_header("Content-Type", ct + ("; charset=utf-8" if ct.startswith("text") or ct.endswith("javascript") else ""))
        self.send_header("Content-Length", str(len(data))); self.send_header("Cache-Control", "no-cache"); self.end_headers(); self.wfile.write(data)

    def do_POST(self):
        u = urlparse(self.path); path = unquote(u.path)
        try:
            n = int(self.headers.get("Content-Length", 0))
            if n > MAX_UPLOAD: return self._json({"error": "File too large (max 300 MB)"}, 413)
            body = self.rfile.read(n)
            if path == "/api/upload":
                name = unquote(self.headers.get("X-Filename", "file.pdf"))
                fid = new_id(body, name)
                return self._json(describe(fid))
            if path == "/api/unlock":
                j = json.loads(body); fid = j["id"]
                pw = j.get("password", "")
                try:
                    i = engine.info(FILES[fid], password=pw)
                    if not i.get("encrypted"):
                        with LOCK:
                            PWS[fid] = pw
                        return self._json(describe(fid))
                    return self._json({"error": "Wrong password"}, 400)
                except pikepdf.PasswordError:
                    return self._json({"error": "Wrong password"}, 400)
                except Exception as e:
                    return self._json({"error": str(e)}, 400)
            if path == "/api/op":
                j = json.loads(body)
                return self._json(run_op(j["op"], j.get("files", []), j.get("options", {})))
            if path.startswith("/api/jobs/") and path.endswith("/cancel"):
                job_id = path.split("/")[3]
                with JOBS_LOCK:
                    if job_id in JOBS:
                        JOBS[job_id]["cancelled"] = True
                return self._json({"ok": True})
            if path == "/api/modernize/start":
                j = json.loads(body)
                fid = j.get("file")
                if not fid or fid not in FILES:
                    return self._json({"error": "Invalid file"}, 400)
                opts = j.get("options", {})
                job_id = "job_" + uuid.uuid4().hex[:10]
                with JOBS_LOCK:
                    JOBS[job_id] = {
                        "id": job_id,
                        "file_id": fid,
                        "status": "processing",
                        "progress": 0.0,
                        "step": "Starting modernization...",
                        "current_page": 1,
                        "total_pages": 1,
                        "doc_model": None,
                        "previews": [],
                        "error": None,
                        "cancelled": False
                    }
                t = threading.Thread(target=run_modernize_worker, args=(job_id, fid, opts), daemon=True)
                t.start()
                return self._json({"job_id": job_id, "status": "processing"})
            if path == "/api/modernize/update":
                j = json.loads(body)
                job_id = j.get("job_id")
                new_model = j.get("doc_model")
                with JOBS_LOCK:
                    if job_id in JOBS and new_model:
                        JOBS[job_id]["doc_model"] = new_model
                        return self._json({"ok": True})
                return self._json({"error": "Job or model not found"}, 404)
            if path.startswith("/api/modernize/") and path.endswith("/answer"):
                parts = path.split("/")
                job_id = parts[3]
                j = json.loads(body)
                res = review_manager.REVIEW_MANAGER.answer_word(
                    job_id,
                    j.get("id"),
                    action=j.get("action", "accept"),
                    text=j.get("text"),
                    split_words=j.get("split_words")
                )
                return self._json(res)
            if path.startswith("/api/modernize/") and path.endswith("/undo"):
                parts = path.split("/")
                job_id = parts[3]
                res = review_manager.REVIEW_MANAGER.undo(job_id)
                return self._json(res)
            if path.startswith("/api/modernize/") and path.endswith("/auto-applied/undo"):
                parts = path.split("/")
                job_id = parts[3]
                j = json.loads(body)
                res = review_manager.REVIEW_MANAGER.undo_auto_applied_word(job_id, j.get("id"))
                return self._json(res)
            if path.startswith("/api/modernize/") and path.endswith("/update-crop"):
                parts = path.split("/")
                job_id = parts[3]
                j = json.loads(body)
                res = review_manager.REVIEW_MANAGER.update_crop(job_id, j.get("id"), j.get("bbox", []))
                return self._json(res)
            if path == "/api/modernize/export":
                j = json.loads(body)
                job_id = j.get("job_id")
                fmt = j.get("format", "pdf").lower()
                doc_m = j.get("doc_model")
                if not doc_m:
                    with JOBS_LOCK:
                        job = JOBS.get(job_id)
                        if job:
                            doc_m = job.get("doc_model")
                if not doc_m:
                    return self._json({"error": "Document model not found"}, 404)

                src_name = doc_m.get("file_name", "document.pdf")
                stem = os.path.splitext(src_name)[0]

                if fmt == "docx":
                    out_bytes = renderer.export_docx(doc_m)
                    out_filename = f"{stem}_modernized.docx"
                elif fmt == "html":
                    out_html = renderer.generate_document_html(doc_m, standalone=True)
                    out_bytes = out_html.encode("utf-8")
                    out_filename = f"{stem}_modernized.html"
                else: # pdf
                    out_bytes = renderer.export_pdf(doc_m)
                    out_filename = f"{stem}_modernized.pdf"

                new_fid = new_id(out_bytes, out_filename)
                return self._json(describe(new_fid))
            if path == "/api/forget":
                j = json.loads(body)
                for f in j.get("ids", []):
                    with LOCK:
                        FILES.pop(f, None); NAMES.pop(f, None); PWS.pop(f, None)
                        keys_to_del = [k for k in list(THUMBS.keys()) if k[0] == f]
                        for k in keys_to_del:
                            THUMBS.pop(k, None)
                    engine.forget_doc(f)
                return self._json({"ok": True})
        except PdfError as e:
            return self._json({"error": str(e)}, 400)
        except KeyError as e:
            return self._json({"error": f"Missing file or option: {e}"}, 400)
        except Exception as e:
            traceback.print_exc()
            return self._json({"error": f"Unexpected error: {e}"}, 500)
        self.send_response(404); self.end_headers()

def main():
    port = int(os.environ.get("PORT", "8080"))
    srv = ThreadingHTTPServer(("127.0.0.1", port), H)
    print(f"Print Helper PDF engine running -> http://localhost:{port}   (Ctrl+C to stop)")
    try: srv.serve_forever()
    except KeyboardInterrupt: print("\nStopped.")

if __name__ == "__main__":
    main()
