#!/usr/bin/env python3
"""Print Helper local PDF server.  Run:  python3 pdf_engine/server.py   then open http://localhost:8080
Serves the web preview and a JSON API. Everything stays on your computer."""
import io, json, os, sys, threading, uuid, zipfile, mimetypes, traceback
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine
from engine import PdfError

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_UPLOAD = 300 * 1024 * 1024
FILES = {}      # id -> bytes
NAMES = {}      # id -> filename
PWS = {}        # id -> password used to open (for thumbnails/ops)
LOCK = threading.Lock()
THUMBS = {}

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
            i = engine.info(d)
            base.update(i); base["kind"] = "pdf"
        except PdfError as e:
            base.update({"kind": "pdf", "pages": 0, "error": str(e)})
    else:
        base.update({"kind": "other", "pages": 0})
    return base

def out_name(src_id, suffix, ext="pdf"):
    stem = os.path.splitext(NAMES.get(src_id, "document"))[0]
    return f"{stem}_{suffix}.{ext}"

def run_op(op, fids, o):
    pw = lambda f: PWS.get(f, "")
    pws = {f: pw(f) for f in fids}
    files = {f: FILES[f] for f in fids}
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
        t = engine.extract_text(f0, files, o.get("pages", "all"), pw(f0))
        return {"text": t, "results": [], "message": f"Extracted {len(t)} characters"}
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
                return self._json({"ok": True, "ocr_langs": engine.available_ocr_langs()})
            if path.startswith("/api/file/"):
                fid = path.split("/")[3]
                if fid not in FILES: return self._json({"error": "File not found"}, 404)
                q = parse_qs(u.query); name = NAMES[fid]
                ctype = "application/zip" if name.endswith(".zip") else "application/pdf"
                return self._bytes(FILES[fid], ctype, name, q.get("download") == ["1"])
            if path.startswith("/api/thumb/"):
                _, _, _, fid, page = path.split("/")[:5]
                w = int(parse_qs(u.query).get("w", ["180"])[0])
                key = (fid, int(page), w, PWS.get(fid, ""))
                if key not in THUMBS:
                    img = engine.render_page(FILES[fid], int(page) - 1, 1.0, PWS.get(fid, ""))
                    img.thumbnail((w, w * 2))
                    b = io.BytesIO(); img.save(b, "PNG"); THUMBS[key] = b.getvalue()
                return self._bytes(THUMBS[key], "image/png")
            if path.startswith("/api/pagepng/"):
                _, _, _, fid, page = path.split("/")[:5]
                zoom = float(parse_qs(u.query).get("zoom", ["1.4"])[0])
                img = engine.render_page(FILES[fid], int(page) - 1, zoom, PWS.get(fid, ""))
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
                try:
                    engine.info(FILES[fid])
                except PdfError: pass
                import pikepdf
                try:
                    with pikepdf.open(io.BytesIO(FILES[fid]), password=j.get("password", "")) as p:
                        PWS[fid] = j.get("password", ""); d = {"id": fid, "name": NAMES[fid], "size": len(FILES[fid]), "kind": "pdf", "pages": len(p.pages), "encrypted": False, "meta": {}}
                        return self._json(d)
                except pikepdf.PasswordError:
                    return self._json({"error": "Wrong password"}, 400)
            if path == "/api/op":
                j = json.loads(body)
                return self._json(run_op(j["op"], j.get("files", []), j.get("options", {})))
            if path == "/api/forget":
                j = json.loads(body)
                for f in j.get("ids", []):
                    FILES.pop(f, None); NAMES.pop(f, None); PWS.pop(f, None)
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
