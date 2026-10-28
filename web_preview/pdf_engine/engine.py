"""Print Helper PDF engine: real PDF operations (no cloud, fully local).

Dependencies: pikepdf, pypdfium2, pillow, reportlab.  Optional: tesseract (OCR).
"""
import io, os, re, shutil, subprocess, tempfile, zipfile, difflib, threading, collections
import pikepdf
import pypdfium2 as pdfium
from PIL import Image, ImageDraw
from reportlab.pdfgen import canvas as rl_canvas
from reportlab.lib.colors import Color

class PdfError(Exception):
    pass

PDFIUM_LOCK = threading.RLock()
_PDFIUM_DOC_CACHE = collections.OrderedDict()

def get_pdfium_doc(key, data, password=""):
    """Thread-safe cached or one-off PdfDocument. Must be called under PDFIUM_LOCK."""
    if key and key in _PDFIUM_DOC_CACHE:
        _PDFIUM_DOC_CACHE.move_to_end(key)
        return _PDFIUM_DOC_CACHE[key], False
    doc = pdfium.PdfDocument(data, password=password or None)
    if key:
        _PDFIUM_DOC_CACHE[key] = doc
        while len(_PDFIUM_DOC_CACHE) > 6:
            _, old_doc = _PDFIUM_DOC_CACHE.popitem(last=False)
            try:
                old_doc.close()
            except Exception:
                pass
        return doc, False
    return doc, True

def forget_doc(fid):
    """Evict any cached pdfium doc belonging to fid."""
    with PDFIUM_LOCK:
        keys_to_del = [k for k in _PDFIUM_DOC_CACHE if k[0] == fid]
        for k in keys_to_del:
            old_doc = _PDFIUM_DOC_CACHE.pop(k, None)
            if old_doc:
                try:
                    old_doc.close()
                except Exception:
                    pass

def parse_ranges(spec, total):
    """'1-3,5,8-' / 'odd' / 'even' / 'all' -> sorted unique 0-based list (order kept)."""
    spec = (spec or "all").strip().lower()
    if spec in ("", "all"):
        return list(range(total))
    if spec == "odd":
        return [i for i in range(total) if i % 2 == 0]
    if spec == "even":
        return [i for i in range(total) if i % 2 == 1]
    out = []
    for part in re.split(r"[,\s]+", spec):
        if not part:
            continue
        m = re.fullmatch(r"(\d*)-(\d*)", part)
        if m:
            a = int(m.group(1)) if m.group(1) else 1
            b = int(m.group(2)) if m.group(2) else total
            if a > b:
                a, b = b, a
            rng = range(a, b + 1)
        elif part.isdigit():
            rng = [int(part)]
        else:
            raise PdfError(f"Bad page range: '{part}'")
        for n in rng:
            if n < 1 or n > total:
                raise PdfError(f"Page {n} is out of range (document has {total} pages)")
            out.append(n - 1)
    if not out:
        raise PdfError("No pages selected")
    return out

def _open(data, password=""):
    try:
        return pikepdf.open(io.BytesIO(data), password=password)
    except pikepdf.PasswordError:
        raise PdfError("This PDF is password-protected. Enter the password first.")
    except pikepdf.PdfError as e:
        raise PdfError(f"Cannot read PDF: {e}")

def _save(pdf, **kw):
    buf = io.BytesIO()
    pdf.save(buf, **kw)
    return buf.getvalue()

def info(data, password=""):
    try:
        kw = {"password": password} if password else {}
        with pikepdf.open(io.BytesIO(data), **kw) as pdf:
            meta = {}
            with pdf.open_metadata() as m:
                pass
            for k, v in (pdf.docinfo or {}).items():
                meta[str(k).lstrip("/")] = str(v)
            page_sizes = []
            for p in pdf.pages:
                box = p.CropBox if "/CropBox" in p else p.MediaBox
                w = float(abs(box[2] - box[0]))
                h = float(abs(box[3] - box[1]))
                rot = int(p.get("/Rotate", 0)) % 360
                if rot % 180 != 0:
                    w, h = h, w
                page_sizes.append([round(w, 2), round(h, 2)])
            return {"pages": len(pdf.pages), "encrypted": False, "meta": meta,
                    "version": str(pdf.pdf_version), "page_sizes": page_sizes}
    except pikepdf.PasswordError:
        return {"pages": 0, "encrypted": True, "meta": {}, "version": "", "page_sizes": []}
    except pikepdf.PdfError as e:
        raise PdfError(f"Not a valid PDF: {e}")

# ---------------------------------------------------------------- page ops
def assemble(items, files, passwords=None):
    """items: [{file, page(1-based), rotate(deg, optional), blank(bool, optional), width, height}] -> new PDF."""
    passwords = passwords or {}
    out = pikepdf.new()
    cache = {}
    for it in items:
        if it.get("blank"):
            w = float(it.get("width", 595.28))
            h = float(it.get("height", 841.89))
            out.add_blank_page(page_size=(w, h))
            rot = int(it.get("rotate", 0)) % 360
            if rot:
                out.pages[-1].rotate(rot, relative=True)
            continue
        fid = it["file"]
        if fid not in cache:
            cache[fid] = _open(files[fid], passwords.get(fid, ""))
        src = cache[fid]
        n = int(it["page"]) - 1
        if n < 0 or n >= len(src.pages):
            raise PdfError(f"Page {n+1} not in file")
        out.pages.append(src.pages[n])
        rot = int(it.get("rotate", 0)) % 360
        if rot:
            p = out.pages[-1]
            p.rotate(rot, relative=True)
    data = _save(out)
    for s in cache.values():
        s.close()
    return data

def merge(fids, files, passwords=None):
    items = []
    for fid in fids:
        with _open(files[fid], (passwords or {}).get(fid, "")) as p:
            items += [{"file": fid, "page": i + 1} for i in range(len(p.pages))]
    return assemble(items, files, passwords)

def select(fid, files, spec, mode="extract", password=""):
    with _open(files[fid], password) as p:
        total = len(p.pages)
    idx = parse_ranges(spec, total)
    if mode == "delete":
        keep = [i for i in range(total) if i not in set(idx)]
        if not keep:
            raise PdfError("Cannot delete every page")
        idx = keep
    items = [{"file": fid, "page": i + 1} for i in idx]
    return assemble(items, files, {fid: password})

def rotate(fid, files, spec, degrees, password=""):
    with _open(files[fid], password) as p:
        idx = set(parse_ranges(spec, len(p.pages)))
        for i, page in enumerate(p.pages):
            if i in idx:
                page.rotate(int(degrees), relative=True)
        return _save(p)

def split(fid, files, mode, value, password=""):
    """mode: 'every' (N pages per file) | 'ranges' ('1-3;4-6') | 'single' (each page). -> [(name_suffix, bytes)]"""
    with _open(files[fid], password) as p:
        total = len(p.pages)
    groups = []
    if mode == "single":
        groups = [[i] for i in range(total)]
    elif mode == "every":
        n = max(1, int(value or 1))
        groups = [list(range(i, min(i + n, total))) for i in range(0, total, n)]
    elif mode == "ranges":
        for part in str(value).split(";"):
            if part.strip():
                groups.append(parse_ranges(part, total))
    else:
        raise PdfError("Unknown split mode")
    out = []
    for gi, g in enumerate(groups, 1):
        data = assemble([{"file": fid, "page": i + 1} for i in g], files, {fid: password})
        out.append((f"part{gi:02d}_p{g[0]+1}-{g[-1]+1}", data))
    return out

def crop(fid, files, spec, margins, password=""):
    """margins in points: dict top/right/bottom/left"""
    with _open(files[fid], password) as p:
        idx = set(parse_ranges(spec, len(p.pages)))
        for i, page in enumerate(p.pages):
            if i not in idx:
                continue
            box = [float(x) for x in (page.get("/CropBox") or page.MediaBox)]
            l, b, r, t = box
            nb = [l + margins.get("left", 0), b + margins.get("bottom", 0),
                  r - margins.get("right", 0), t - margins.get("top", 0)]
            if nb[2] <= nb[0] or nb[3] <= nb[1]:
                raise PdfError("Crop margins are larger than the page")
            page.CropBox = pikepdf.Array(nb)
        return _save(p)

# ---------------------------------------------------------------- overlay helpers
def _overlay(pdf, draw_fn, spec="all"):
    idx = set(parse_ranges(spec, len(pdf.pages)))
    for i, page in enumerate(pdf.pages):
        if i not in idx:
            continue
        box = [float(x) for x in (page.get("/CropBox") or page.MediaBox)]
        w, h = box[2] - box[0], box[3] - box[1]
        rot = int(page.get("/Rotate", 0) or 0) % 360
        buf = io.BytesIO()
        c = rl_canvas.Canvas(buf, pagesize=(w, h))
        draw_fn(c, w, h, i)
        c.save()
        ov = pikepdf.open(io.BytesIO(buf.getvalue()))
        page.add_overlay(ov.pages[0], pikepdf.Rectangle(*box))

def watermark(fid, files, text, spec="all", opacity=0.25, size=64, angle=45, color="#888888", password=""):
    if not text:
        raise PdfError("Watermark text is empty")
    col = Color(*_hex(color), alpha=float(opacity))
    with _open(files[fid], password) as p:
        def draw(c, w, h, i):
            c.saveState()
            c.setFillColor(col)
            c.setFont("Helvetica-Bold", float(size))
            c.translate(w / 2, h / 2)
            c.rotate(float(angle))
            c.drawCentredString(0, 0, _latin(text))
            c.restoreState()
        _overlay(p, draw, spec)
        return _save(p)

def page_numbers(fid, files, fmt="Page {n} of {total}", position="bottom-center", start=1, size=10, spec="all", password=""):
    with _open(files[fid], password) as p:
        total = len(p.pages)
        def draw(c, w, h, i):
            label = fmt.replace("{n}", str(i + int(start))).replace("{total}", str(total + int(start) - 1))
            c.setFont("Helvetica", float(size))
            v, hz = position.split("-")
            y = 24 if v == "bottom" else h - 24 - float(size)
            if hz == "left":
                c.drawString(36, y, _latin(label))
            elif hz == "right":
                c.drawRightString(w - 36, y, _latin(label))
            else:
                c.drawCentredString(w / 2, y, _latin(label))
        _overlay(p, draw, spec)
        return _save(p)

def _latin(s):
    # Built-in PDF fonts are Latin-1 only; replace others so output never crashes.
    return s.encode("latin-1", "replace").decode("latin-1")

def _hex(h):
    h = h.lstrip("#")
    if len(h) != 6:
        return (0.5, 0.5, 0.5)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

# ---------------------------------------------------------------- security
def protect(fid, files, user_pw, owner_pw=None, allow_print=True, allow_copy=True, allow_edit=False, password=""):
    if not user_pw and not owner_pw:
        raise PdfError("Enter at least one password")
    with _open(files[fid], password) as p:
        perms = pikepdf.Permissions(extract=bool(allow_copy), modify_other=bool(allow_edit),
                                    modify_annotation=bool(allow_edit), modify_form=bool(allow_edit),
                                    modify_assembly=bool(allow_edit),
                                    print_lowres=bool(allow_print), print_highres=bool(allow_print))
        return _save(p, encryption=pikepdf.Encryption(user=user_pw or "", owner=owner_pw or user_pw or "x", R=6, allow=perms))

def unprotect(fid, files, password):
    with _open(files[fid], password) as p:
        return _save(p)

def set_metadata(fid, files, meta, strip=False, password=""):
    with _open(files[fid], password) as p:
        if strip:
            for k in list(p.docinfo.keys()):
                del p.docinfo[k]
            if "/Metadata" in p.Root:
                del p.Root["/Metadata"]
        else:
            for k, v in meta.items():
                if k in ("Title", "Author", "Subject", "Keywords", "Creator", "Producer"):
                    p.docinfo["/" + k] = str(v)
        return _save(p)

# ---------------------------------------------------------------- rendering based
def render_thumb(key, data, page_idx, width_px, password=""):
    with PDFIUM_LOCK:
        doc, should_close = get_pdfium_doc(key, data, password)
        try:
            page = doc[page_idx]
            try:
                pw_pt, _ = page.get_size()
                if pw_pt <= 0:
                    pw_pt = 595.28
                scale = float(width_px) / float(pw_pt)
                scale = max(0.05, min(6.0, scale))
                return page.render(scale=scale).to_pil().convert("RGB")
            finally:
                page.close()
        finally:
            if should_close:
                doc.close()

def render_page(data, page_idx, scale=1.0, password="", key=None):
    with PDFIUM_LOCK:
        doc, should_close = get_pdfium_doc(key, data, password)
        try:
            page = doc[page_idx]
            try:
                return page.render(scale=scale).to_pil().convert("RGB")
            finally:
                page.close()
        finally:
            if should_close:
                doc.close()

def _images_to_pdf(images, dpi=150):
    buf = io.BytesIO()
    images[0].save(buf, "PDF", resolution=float(dpi), save_all=True, append_images=images[1:])
    return buf.getvalue()

def redact(fid, files, regions=None, terms=None, dpi=150, password=""):
    """True redaction: affected pages are rasterised with black boxes burnt in, so the text is gone."""
    regions = regions or []
    terms = [t for t in (terms or []) if t.strip()]
    data = files[fid]
    with PDFIUM_LOCK:
        doc, should_close = get_pdfium_doc((fid, password), data, password)
        try:
            n = len(doc)
            boxes = {i: [] for i in range(n)}   # fractional boxes (x, y, w, h) from top-left
            for r in regions:
                pg = int(r["page"]) - 1
                if 0 <= pg < n:
                    boxes[pg].append((float(r["x"]), float(r["y"]), float(r["w"]), float(r["h"])))
            hits = 0
            if terms:
                for i in range(n):
                    page = doc[i]
                    W, H = page.get_size()
                    tp = page.get_textpage()
                    for term in terms:
                        srch = tp.search(term, match_case=False)
                        while True:
                            m = srch.get_next()
                            if not m:
                                break
                            idx, cnt = m
                            xs = []
                            for k in range(idx, idx + cnt):
                                l, b, r_, t = tp.get_charbox(k)
                                xs.append((l, b, r_, t))
                            l = min(x[0] for x in xs); r_ = max(x[2] for x in xs)
                            b = min(x[1] for x in xs); t = max(x[3] for x in xs)
                            boxes[i].append((l / W, 1 - t / H, (r_ - l) / W, (t - b) / H))
                            hits += 1
            touched = [i for i in range(n) if boxes[i]]
            if not touched:
                raise PdfError("Nothing to redact: no regions drawn and no search term matched")
            out_items = []
            tmp_pdfs = {}
            with pikepdf.new() as out:
                src = _open(data, password)
                for i in range(n):
                    if i in touched:
                        img = doc[i].render(scale=dpi / 72).to_pil().convert("RGB")
                        d = ImageDraw.Draw(img)
                        W, H = img.size
                        pad = 2
                        for (x, y, w, h) in boxes[i]:
                            d.rectangle([x * W - pad, y * H - pad, (x + w) * W + pad, (y + h) * H + pad], fill=(0, 0, 0))
                        pw, ph = doc[i].get_size()
                        b = io.BytesIO()
                        img.save(b, "PDF", resolution=dpi)
                        tmp = pikepdf.open(io.BytesIO(b.getvalue()))
                        out.pages.append(tmp.pages[0])
                        tmp_pdfs[i] = tmp
                    else:
                        out.pages.append(src.pages[i])
                result = _save(out)
                src.close()
            for t in tmp_pdfs.values():
                t.close()
            return result, hits, len(touched)
        finally:
            if should_close:
                doc.close()

def flatten(fid, files, dpi=150, password=""):
    with PDFIUM_LOCK:
        doc, should_close = get_pdfium_doc((fid, password), files[fid], password)
        try:
            imgs = [doc[i].render(scale=dpi / 72).to_pil().convert("RGB") for i in range(len(doc))]
        finally:
            if should_close:
                doc.close()
    return _images_to_pdf(imgs, dpi)

def pdf_to_images(fid, files, fmt="png", dpi=150, spec="all", password=""):
    with PDFIUM_LOCK:
        doc, should_close = get_pdfium_doc((fid, password), files[fid], password)
        try:
            idx = parse_ranges(spec, len(doc))
            buf = io.BytesIO()
            with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
                for i in idx:
                    img = doc[i].render(scale=float(dpi) / 72).to_pil().convert("RGB")
                    b = io.BytesIO()
                    if fmt == "jpg":
                        img.save(b, "JPEG", quality=90)
                    else:
                        img.save(b, "PNG")
                    z.writestr(f"page_{i+1:03d}.{fmt}", b.getvalue())
            return buf.getvalue()
        finally:
            if should_close:
                doc.close()

def images_to_pdf(blobs, page="fit"):
    imgs = []
    for b in blobs:
        try:
            im = Image.open(io.BytesIO(b))
            im = ImageOps_exif(im).convert("RGB")
            imgs.append(im)
        except Exception:
            raise PdfError("One of the files is not a readable image")
    if not imgs:
        raise PdfError("No images supplied")
    return _images_to_pdf(imgs, 150)

def ImageOps_exif(im):
    from PIL import ImageOps
    return ImageOps.exif_transpose(im)

def extract_text(fid, files, spec="all", password=""):
    doc = pdfium.PdfDocument(files[fid], password=password or None)
    idx = parse_ranges(spec, len(doc))
    parts = []
    for i in idx:
        tp = doc[i].get_textpage()
        parts.append(f"--- Page {i+1} ---\n" + tp.get_text_range())
    doc.close()
    text = "\n\n".join(parts)
    return text

def available_ocr_langs():
    if not shutil.which("tesseract"):
        return []
    try:
        out = subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True, timeout=15).stdout
        return [l.strip() for l in out.splitlines()[1:] if l.strip() and l.strip() != "osd"]
    except Exception:
        return []

def ocr(fid, files, lang="eng", dpi=200, spec="all", password="", as_pdf=True):
    langs = available_ocr_langs()
    if not langs:
        raise PdfError("Tesseract is not installed. On Mac: brew install tesseract tesseract-lang")
    for l in lang.split("+"):
        if l not in langs:
            raise PdfError(f"OCR language '{l}' is not installed. Installed: {', '.join(langs)}. On Mac: brew install tesseract-lang")
    with PDFIUM_LOCK:
        doc, should_close = get_pdfium_doc((fid, password), files[fid], password)
        try:
            idx = parse_ranges(spec, len(doc))
            page_imgs = [doc[i].render(scale=dpi / 72).to_pil().convert("RGB") for i in idx]
        finally:
            if should_close:
                doc.close()
    texts, pdfs = [], []
    with tempfile.TemporaryDirectory() as td:
        for n, img in enumerate(page_imgs):
            ip = os.path.join(td, f"p{n}.png")
            img.save(ip)
            base = os.path.join(td, f"o{n}")
            r = subprocess.run(["tesseract", ip, base, "-l", lang, "--dpi", str(dpi), "txt", "pdf"],
                               capture_output=True, text=True, timeout=300)
            if r.returncode != 0:
                raise PdfError("OCR failed: " + r.stderr[-200:])
            texts.append(f"--- Page {idx[n]+1} ---\n" + open(base + ".txt", encoding="utf8").read().strip())
            pdfs.append(open(base + ".pdf", "rb").read())
    merged = None
    if as_pdf:
        out = pikepdf.new()
        srcs = [pikepdf.open(io.BytesIO(b)) for b in pdfs]
        for s in srcs:
            out.pages.extend(s.pages)
        merged = _save(out)
        for s in srcs:
            s.close()
    return "\n\n".join(texts), merged

def compare(a, b, files, pa="", pb=""):
    from text_intel import smart_text
    ta = smart_text(a, files, "all", password=pa, mode="auto", markers=False)["text"].splitlines()
    tb = smart_text(b, files, "all", password=pb, mode="auto", markers=False)["text"].splitlines()
    diff = list(difflib.unified_diff(ta, tb, "A", "B", lineterm="", n=1))
    added = sum(1 for l in diff if l.startswith("+") and not l.startswith("+++"))
    removed = sum(1 for l in diff if l.startswith("-") and not l.startswith("---"))
    return {"added": added, "removed": removed, "identical": not diff, "diff": "\n".join(diff[:2000])}

# ---------------------------------------------------------------- compress
LEVELS = {"low": (0.9, 85, 200), "medium": (0.75, 70, 150), "high": (0.55, 50, 110)}

def compress(fid, files, level="medium", password=""):
    _, q, target_dpi = LEVELS.get(level, LEVELS["medium"])
    before = len(files[fid])
    with _open(files[fid], password) as p:
        done = set()
        for page in p.pages:
            try:
                imgs = page.images.items()
            except Exception:
                continue
            pw = float(page.MediaBox[2]) - float(page.MediaBox[0])
            for name, raw in list(imgs):
                if raw.objgen in done:
                    continue
                done.add(raw.objgen)
                try:
                    pimg = pikepdf.PdfImage(raw)
                    if raw.get("/ImageMask") or raw.get("/SMask") is not None:
                        continue
                    im = pimg.as_pil_image()
                    if im.mode not in ("RGB", "L"):
                        im = im.convert("RGB")
                    # approx effective dpi across the page width
                    eff = im.width / max(pw / 72.0, 1)
                    if eff > target_dpi:
                        f = target_dpi / eff
                        im = im.resize((max(1, int(im.width * f)), max(1, int(im.height * f))), Image.LANCZOS)
                    b = io.BytesIO()
                    im.save(b, "JPEG", quality=q, optimize=True)
                    if b.tell() < len(raw.read_raw_bytes()):
                        raw.write(b.getvalue(), filter=pikepdf.Name.DCTDecode)
                        raw.Width, raw.Height = im.width, im.height
                        raw.ColorSpace = pikepdf.Name.DeviceRGB if im.mode == "RGB" else pikepdf.Name.DeviceGray
                        raw.BitsPerComponent = 8
                        for k in ("/DecodeParms", "/Decode"):
                            if k in raw:
                                del raw[k]
                except Exception:
                    continue
        data = _save(p, compress_streams=True, recompress_flate=True,
                     object_stream_mode=pikepdf.ObjectStreamMode.generate)
    if len(data) >= before:
        return files[fid], before, before
    return data, before, len(data)
