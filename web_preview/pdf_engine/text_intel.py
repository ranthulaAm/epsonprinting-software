"""Smart Text Extraction Engine for Print Helper / PDF Gear.

Features:
- pdfium bounded text extraction with line-inset isolation
- Gutter and multi-column reading order detection
- Table row detection and formatting ("a | b | c")
- Continuation & paragraph reflow with lowercase de-hyphenation
- Running headers, footers, and page number removal
- Script repair for Sinhala pre-base vowels (U+0DD9/DDA/DDB)
- Per-page quality heuristics & automatic OCR fallback
"""

import io, os, re, shutil, subprocess, tempfile, unicodedata
import pypdfium2 as pdfium
from PIL import Image

# ---------------------------------------------------------------- Cleaning & Script Repair
SINHALA_CONSONANT_CLUSTER = r'[\u0D9A-\u0DC6](?:\u0DCA\u200D[\u0D9A-\u0DC6])*'
SINHALA_VOWEL_REPAIR_RE = re.compile(
    r'(?<![\u0D80-\u0DFF])([\u0DD9\u0DDA\u0DDB])(' + SINHALA_CONSONANT_CLUSTER + r')'
)

def clean_text_run(s):
    if not s:
        return ""
    # Map pdfium line-end hyphen \x02 to '-' before stripping control chars
    s = s.replace("\x02", "-")
    # Unicode NFC normalization
    s = unicodedata.normalize("NFC", s)
    # Common typographic ligatures to ASCII
    s = (s.replace("ﬁ", "fi")
          .replace("ﬂ", "fl")
          .replace("ﬃ", "ffi")
          .replace("ﬄ", "ffl")
          .replace("ﬀ", "ff"))
    # Remove soft hyphen, ZWSP, BOM; KEEP ZWJ (\u200d) and ZWNJ (\u200c)
    for ch in ("\u00ad", "\u200b", "\ufeff"):
        s = s.replace(ch, "")
    # Strip non-whitespace control characters
    s = "".join(c for c in s if c in ("\n", "\r", "\t") or ord(c) >= 32)
    # Repair Sinhala pre-base vowel order bug (only when preceded by non-Sinhala / word start)
    s = SINHALA_VOWEL_REPAIR_RE.sub(r"\2\1", s)
    return s

# ---------------------------------------------------------------- Per-page quality heuristics
def assess_page_quality(text):
    """Returns (is_empty, is_garbled, reason)."""
    non_space = [c for c in text if not c.isspace()]
    if len(non_space) < 25:
        return True, False, "Under 25 non-space characters"

    total = len(non_space)
    # Private use areas: U+E000-U+F8FF, U+F0000-U+FFFFD, U+100000-U+10FFFD or replacement char U+FFFD
    pua_count = sum(1 for c in non_space if (0xE000 <= ord(c) <= 0xF8FF) or (0xF0000 <= ord(c) <= 0x10FFFD) or c == '\uFFFD')
    if (pua_count / total) > 0.10:
        return False, True, f"High private-use/replacement character ratio ({pua_count/total:.1%})"

    # Accented-Latin letters (typical of legacy font re-encodings in non-Latin docs)
    # e.g., Latin-1 Supplement (0xC0-0xFF), Latin Extended-A/B (0x100-0x24F)
    accented_latin = sum(1 for c in non_space if (0xC0 <= ord(c) <= 0x024F) and unicodedata.category(c).startswith('L'))
    has_other_script = any(ord(c) > 0x024F and unicodedata.category(c).startswith('L') for c in non_space)
    if not has_other_script and (accented_latin / total) > 0.12:
        return False, True, f"High accented-Latin encoding artifacts ({accented_latin/total:.1%})"

    # Punctuation to letter ratio
    punct_count = sum(1 for c in non_space if unicodedata.category(c).startswith('P'))
    letter_count = sum(1 for c in non_space if unicodedata.category(c).startswith('L'))
    if letter_count > 0 and (punct_count / letter_count) > 0.55:
        return False, True, f"Excessive punctuation ratio ({punct_count/letter_count:.2f})"

    return False, False, "Good quality"

# ---------------------------------------------------------------- Headers / Footers Detection
def normalize_repeat_key(line):
    """Normalize ONLY the page-number part (leading or trailing number, 'N of M'), not inner numbers."""
    s = line.strip().lower()
    # Replace trailing or leading 'page X of Y' or 'page X'
    s = re.sub(r'\bpage\s+\d+(\s+of\s+\d+)?\b', '<PAGENUM>', s)
    # Replace trailing bare number e.g. "Title - 3"
    s = re.sub(r'(\s*[-—|•]\s*)?\b\d+\s*$', '', s)
    # Replace leading bare number e.g. "3 | Title"
    s = re.sub(r'^\s*\d+\s*([-—|•]\s*)?', '', s)
    return s.strip()

def is_bare_page_number(line):
    s = line.strip()
    if s.isdigit():
        return True
    if re.fullmatch(r'(?i)page\s+\d+(\s+of\s+\d+)?', s):
        return True
    if re.fullmatch(r'[-—|•]?\s*\d+\s*[-—|•]?', s):
        return True
    return False

# ---------------------------------------------------------------- OCR Engine
def run_tesseract_tsv(pil_img, lang, dpi=250):
    if not shutil.which("tesseract"):
        return None, 0.0, "Tesseract not installed"
    with tempfile.TemporaryDirectory() as td:
        img_path = os.path.join(td, "page.png")
        pil_img.save(img_path)
        cmd = ["tesseract", img_path, "stdout", "-l", lang, "--dpi", str(dpi), "--psm", "3", "tsv"]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if res.returncode != 0:
            return None, 0.0, f"Tesseract error: {res.stderr.strip()[:100]}"
        tsv_lines = res.stdout.splitlines()

    # Parse TSV: level, page_num, block_num, par_num, line_num, word_num, left, top, width, height, conf, text
    # Level 5 is WORD
    lines = []
    confs = []
    current_key = None
    current_words = []

    for line in tsv_lines[1:]:
        parts = line.split('\t')
        if len(parts) < 12:
            continue
        level = parts[0]
        if level != '5':
            continue
        block_num, par_num, line_num = parts[2], parts[3], parts[4]
        conf = float(parts[10])
        text = parts[11].strip()
        if not text or conf < 0:
            continue

        confs.append(conf)
        key = (block_num, par_num, line_num)
        if key != current_key:
            if current_words:
                lines.append(" ".join(current_words))
                current_words = []
            current_key = key
        current_words.append(text)

    if current_words:
        lines.append(" ".join(current_words))

    mean_conf = (sum(confs) / len(confs)) if confs else 0.0
    return "\n".join(lines), round(mean_conf, 1), ""

# ---------------------------------------------------------------- Run & Layout Analysis
class TextRun:
    def __init__(self, left, bottom, right, top, text):
        self.left = float(left)
        self.bottom = float(bottom)
        self.right = float(right)
        self.top = float(top)
        self.width = self.right - self.left
        self.height = self.top - self.bottom
        self.text = text

def extract_runs_from_page(page):
    tp = page.get_textpage()
    try:
        count = tp.count_rects()
        runs = []
        for i in range(count):
            rect = tp.get_rect(i)
            l, b, r, t = rect
            h = t - b
            txt = tp.get_text_bounded(l - 0.5, b + 0.2 * h, r + 0.5, t - 0.2 * h)
            cleaned = clean_text_run(txt)
            if cleaned.strip():
                runs.append(TextRun(l, b, r, t, cleaned))
        return runs
    finally:
        tp.close()

def detect_tables(runs):
    """Detect table rows with 2+ cells where cell gaps >= 1.2x line height and cells are short/numeric.
    Returns (table_lines, remaining_runs)."""
    if not runs:
        return [], []

    # Group runs into horizontal lines by vertical overlap
    sorted_runs = sorted(runs, key=lambda r: (-r.top, r.left))
    line_groups = []
    for r in sorted_runs:
        matched = False
        for g in line_groups:
            # Check vertical overlap
            overlap = min(g['top'], r.top) - max(g['bottom'], r.bottom)
            if overlap > 0.4 * min(g['height'], r.height):
                g['runs'].append(r)
                g['top'] = max(g['top'], r.top)
                g['bottom'] = min(g['bottom'], r.bottom)
                g['height'] = g['top'] - g['bottom']
                matched = True
                break
        if not matched:
            line_groups.append({
                'top': r.top, 'bottom': r.bottom, 'height': r.height, 'runs': [r]
            })

    table_runs = set()
    table_lines = []

    # Check consecutive rows for table characteristics
    potential_table_rows = []
    for g in line_groups:
        row_runs = sorted(g['runs'], key=lambda r: r.left)
        if len(row_runs) >= 2:
            # Check cell gaps >= 1.2 * line height
            gaps = [row_runs[i+1].left - row_runs[i].right for i in range(len(row_runs)-1)]
            avg_h = g['height']
            has_wide_gaps = all(gap >= 1.2 * avg_h for gap in gaps)
            avg_chars = sum(len(r.text.strip()) for r in row_runs) / len(row_runs)
            num_cells = sum(1 for r in row_runs if any(c.isdigit() for c in r.text))
            is_numeric = (num_cells / len(row_runs)) >= 0.25

            if has_wide_gaps and (avg_chars <= 24 or is_numeric):
                potential_table_rows.append((g, row_runs))
            else:
                potential_table_rows.append(None)
        else:
            potential_table_rows.append(None)

    # Require at least 2 consecutive table rows
    i = 0
    while i < len(potential_table_rows):
        if potential_table_rows[i] is not None:
            streak = []
            while i < len(potential_table_rows) and potential_table_rows[i] is not None:
                streak.append(potential_table_rows[i])
                i += 1
            if len(streak) >= 2:
                for g, rruns in streak:
                    row_text = " | ".join(r.text.strip() for r in rruns)
                    table_lines.append(row_text)
                    for r in rruns:
                        table_runs.add(r)
        else:
            i += 1

    remaining_runs = [r for r in runs if r not in table_runs]
    return table_lines, remaining_runs

def detect_gutters_and_columns(runs, page_w):
    """Detect 2pt bins gutter. Classify runs wider than 62% as full-width.
    Returns (num_columns, list_of_column_run_lists)."""
    if not runs:
        return 1, [[]]

    min_l = min(r.left for r in runs)
    max_r = max(r.right for r in runs)
    text_span = max_r - min_l
    if text_span <= 0:
        return 1, [runs]

    # Full-width runs (> 62% of text span)
    full_width = [r for r in runs if r.width > 0.62 * text_span]
    columnar = [r for r in runs if r.width <= 0.62 * text_span]

    if len(columnar) < 6:
        return 1, [sorted(runs, key=lambda r: (-r.top, r.left))]

    # Gutter detection between 12% and 88% of width, bin size 2pt
    start_x = int(page_w * 0.12)
    end_x = int(page_w * 0.88)
    bin_size = 2
    bins = [0] * int((end_x - start_x) / bin_size + 1)

    for r in columnar:
        b_start = max(0, int((r.left - start_x) / bin_size))
        b_end = min(len(bins), int((r.right - start_x) / bin_size) + 1)
        for b in range(b_start, b_end):
            bins[b] += 1

    # Find longest stretch of bins with <= 3% of columnar runs crossing
    max_allowed = max(1, int(0.03 * len(columnar)))
    best_gutter = None
    curr_start = None

    for i, count in enumerate(bins):
        if count <= max_allowed:
            if curr_start is None:
                curr_start = i
        else:
            if curr_start is not None:
                g_w = (i - curr_start) * bin_size
                if g_w >= 12: # at least 12pt wide
                    if best_gutter is None or g_w > best_gutter[2]:
                        best_gutter = (curr_start * bin_size + start_x, i * bin_size + start_x, g_w)
                curr_start = None

    if curr_start is not None:
        g_w = (len(bins) - curr_start) * bin_size
        if g_w >= 12:
            if best_gutter is None or g_w > best_gutter[2]:
                best_gutter = (curr_start * bin_size + start_x, len(bins) * bin_size + start_x, g_w)

    if not best_gutter:
        return 1, [sorted(runs, key=lambda r: (-r.top, r.left))]

    gutter_mid = (best_gutter[0] + best_gutter[1]) / 2.0
    col1 = [r for r in columnar if r.right <= gutter_mid]
    col2 = [r for r in columnar if r.left >= gutter_mid]

    # Each column needs at least max(3, 8%) runs
    min_col_runs = max(3, int(0.08 * len(columnar)))
    if len(col1) < min_col_runs or len(col2) < min_col_runs:
        return 1, [sorted(runs, key=lambda r: (-r.top, r.left))]

    # Order: full-width above, col1, col2, full-width below
    col1_sorted = sorted(col1, key=lambda r: (-r.top, r.left))
    col2_sorted = sorted(col2, key=lambda r: (-r.top, r.left))

    if full_width:
        # Separate full-width above top of columns vs below
        col_top = max(max(r.top for r in col1), max(r.top for r in col2))
        col_bottom = min(min(r.bottom for r in col1), min(r.bottom for r in col2))
        top_full = sorted([r for r in full_width if r.bottom >= col_top - 5], key=lambda r: (-r.top, r.left))
        mid_col = col1_sorted + col2_sorted
        bot_full = sorted([r for r in full_width if r.top <= col_bottom + 5], key=lambda r: (-r.top, r.left))
        remaining = [r for r in full_width if r not in top_full and r not in bot_full]
        return 2, [top_full + mid_col + remaining + bot_full]

    return 2, [col1_sorted + col2_sorted]

def reflow_paragraphs(runs, page_w, dehyphenate=True):
    """Paragraph breaks: gap > 1.55x median pitch, heading size change > 1.3x, short sentence ends.
    List/invoice handling (< 55% continuations)."""
    if not runs:
        return []

    # Calculate median height
    heights = sorted(r.height for r in runs if r.height > 2)
    median_h = heights[len(heights)//2] if heights else 10.0

    lines = []
    # Group runs into lines
    curr_line = [runs[0]]
    for r in runs[1:]:
        prev = curr_line[-1]
        vertical_overlap = min(prev.top, r.top) - max(prev.bottom, r.bottom)
        if vertical_overlap > 0.4 * min(prev.height, r.height):
            curr_line.append(r)
        else:
            # Finish line
            curr_line.sort(key=lambda x: x.left)
            line_txt = " ".join(x.text.strip() for x in curr_line)
            l_top = max(x.top for x in curr_line)
            l_bot = min(x.bottom for x in curr_line)
            l_left = min(x.left for x in curr_line)
            l_right = max(x.right for x in curr_line)
            lines.append({
                'text': line_txt, 'top': l_top, 'bottom': l_bot, 'height': l_top - l_bot,
                'left': l_left, 'right': l_right
            })
            curr_line = [r]

    if curr_line:
        curr_line.sort(key=lambda x: x.left)
        line_txt = " ".join(x.text.strip() for x in curr_line)
        l_top = max(x.top for x in curr_line)
        l_bot = min(x.bottom for x in curr_line)
        lines.append({
            'text': line_txt, 'top': l_top, 'bottom': l_bot, 'height': l_top - l_bot,
            'left': min(x.left for x in curr_line), 'right': max(x.right for x in curr_line)
        })

    if not lines:
        return []

    # Dehyphenate across lines: join without hyphen when next line starts lowercase
    if dehyphenate:
        i = 0
        while i < len(lines) - 1:
            t = lines[i]['text']
            next_t = lines[i+1]['text']
            if t.endswith('-') and next_t and next_t[0].islower():
                lines[i]['text'] = t[:-1] + next_t.split()[0]
                rest = " ".join(next_t.split()[1:])
                if rest:
                    lines[i+1]['text'] = rest
                    i += 1
                else:
                    lines.pop(i+1)
            else:
                i += 1

    # Check continuation ratio (< 55% continuations means list/invoice)
    continuations = 0
    for i in range(1, len(lines)):
        t = lines[i]['text'].strip()
        if t and (t[0].islower() or (not t[0].isdigit() and not t.startswith(('-', '*', '•')))):
            continuations += 1
    is_list_invoice = (continuations / max(1, len(lines) - 1)) < 0.55

    paragraphs = []
    curr_para = [lines[0]['text']]

    for i in range(len(lines) - 1):
        l1 = lines[i]
        l2 = lines[i+1]
        pitch = l1['bottom'] - l2['top']
        heading_change = l2['height'] > 1.3 * median_h or l1['height'] > 1.3 * median_h
        gap_break = pitch > 1.55 * median_h
        sentence_end = l1['text'].strip().endswith(('.', '?', '!', ':')) and (l1['right'] < page_w * 0.75)

        if is_list_invoice or gap_break or heading_change or sentence_end:
            paragraphs.append(" ".join(curr_para) if not is_list_invoice else "\n".join(curr_para))
            curr_para = [l2['text']]
        else:
            curr_para.append(l2['text'])

    if curr_para:
        paragraphs.append(" ".join(curr_para) if not is_list_invoice else "\n".join(curr_para))

    return paragraphs

# ---------------------------------------------------------------- Master Smart Text Pipeline
def smart_text(fid, files, spec="all", password="", mode="auto", layout="smart",
               fmt="txt", clean=True, dehyphenate=True, markers=True, lang="auto", dpi=250):
    """
    mode: auto / text / ocr
    layout: smart / raw
    fmt: txt / md / json
    returns: { "text": str, "report": list_of_page_dicts, "summary": dict }
    """
    import engine

    # Resolve OCR language
    installed_langs = engine.available_ocr_langs()
    has_tesseract = bool(installed_langs)
    if lang == "auto":
        ocr_lang = "eng+sin" if ("eng" in installed_langs and "sin" in installed_langs) else ("eng" if "eng" in installed_langs else (installed_langs[0] if installed_langs else "eng"))
    else:
        ocr_lang = lang

    data = files[fid]
    with engine.PDFIUM_LOCK:
        doc, should_close = engine.get_pdfium_doc((fid, password), data, password)
        try:
            total_pages = len(doc)
            page_indices = engine.parse_ranges(spec, total_pages)
            raw_pages_data = []

            for idx in page_indices:
                page = doc[idx]
                try:
                    pw, ph = page.get_size()
                    runs = extract_runs_from_page(page)
                    raw_pages_data.append({
                        'index': idx, 'pw': pw, 'ph': ph, 'runs': runs
                    })
                finally:
                    page.close()
        finally:
            if should_close:
                doc.close()

    # Pass 1: Raw line collection for repeating header/footer analysis
    header_footer_candidates = {}
    for pdata in raw_pages_data:
        ph = pdata['ph']
        for r in pdata['runs']:
            # Top or bottom 9%
            if r.top >= ph * 0.91 or r.bottom <= ph * 0.09:
                key = normalize_repeat_key(r.text)
                if key:
                    header_footer_candidates[key] = header_footer_candidates.get(key, 0) + 1

    # Lines repeating on at least 50% of pages (minimum 2)
    threshold = max(2, len(page_indices) * 0.5)
    repeating_headers = {k for k, v in header_footer_candidates.items() if v >= threshold}

    page_reports = []
    page_outputs = []
    total_words = 0
    ocr_pages_count = 0
    warnings = []

    if not has_tesseract and (mode in ("auto", "ocr")):
        warnings.append("Tesseract is not installed on this system. For image OCR, run: brew install tesseract tesseract-lang")

    for pdata in raw_pages_data:
        idx = pdata['index']
        pw = pdata['pw']
        ph = pdata['ph']
        runs = pdata['runs']
        hf_removed = 0

        # Filter out header/footer lines and bare page numbers if clean=True
        filtered_runs = []
        for r in runs:
            if clean and (r.top >= ph * 0.91 or r.bottom <= ph * 0.09):
                norm_key = normalize_repeat_key(r.text)
                if is_bare_page_number(r.text) or (norm_key in repeating_headers):
                    hf_removed += 1
                    continue
            filtered_runs.append(r)

        prelim_text = " ".join(r.text for r in filtered_runs)
        is_empty, is_garbled, quality_reason = assess_page_quality(prelim_text)

        method = "text"
        page_text = ""
        ocr_conf = None
        cols_detected = 1

        should_ocr = (mode == "ocr") or (mode == "auto" and (is_empty or is_garbled))

        if should_ocr and has_tesseract:
            # Render page image at 250 dpi
            with engine.PDFIUM_LOCK:
                img = engine.render_page(data, idx, scale=dpi / 72.0, password=password, key=(fid, password))
            ocr_text, conf, err = run_tesseract_tsv(img, ocr_lang, dpi=dpi)
            if ocr_text:
                page_text = ocr_text
                method = "ocr"
                ocr_conf = conf
                ocr_pages_count += 1
            else:
                method = "empty" if is_empty else "text"
                page_text = prelim_text
        else:
            if is_empty:
                method = "empty"
                page_text = ""
            elif layout == "raw":
                method = "text"
                page_text = "\n".join(r.text for r in filtered_runs)
            else:
                method = "text"
                table_lines, non_table_runs = detect_tables(filtered_runs)
                num_cols, col_runs_lists = detect_gutters_and_columns(non_table_runs, pw)
                cols_detected = num_cols

                flow_paras = []
                for cruns in col_runs_lists:
                    flow_paras.extend(reflow_paragraphs(cruns, pw, dehyphenate=dehyphenate))

                all_blocks = []
                if table_lines:
                    all_blocks.append("\n".join(table_lines))
                all_blocks.extend(flow_paras)
                page_text = "\n\n".join(all_blocks)

        words = len(page_text.split())
        chars = len(page_text)
        total_words += words

        notes = []
        if hf_removed: notes.append(f"{hf_removed} header/footer lines removed")
        if method == "ocr": notes.append(f"OCR ({ocr_lang}) conf: {ocr_conf}%")
        elif is_garbled: notes.append(f"Quality warning: {quality_reason}")

        page_reports.append({
            "page": idx + 1,
            "method": method,
            "chars": chars,
            "words": words,
            "columns": cols_detected,
            "ocr_confidence": ocr_conf,
            "headers_footers_removed": hf_removed,
            "notes": "; ".join(notes) if notes else "Clean"
        })

        if markers:
            page_outputs.append(f"--- Page {idx + 1} ---\n" + page_text)
        else:
            page_outputs.append(page_text)

    full_text = "\n\n".join(page_outputs)

    if fmt == "md":
        # Format as Markdown
        md_pages = []
        for rep, ptext in zip(page_reports, page_outputs):
            hdr = f"## Page {rep['page']}\n\n"
            md_pages.append(hdr + ptext)
        formatted_output = "\n\n".join(md_pages)
    elif fmt == "json":
        import json
        formatted_output = json.dumps({
            "summary": {
                "pages": len(page_indices),
                "words": total_words,
                "ocr_pages": ocr_pages_count,
                "warnings": warnings
            },
            "pages": page_reports,
            "content": page_outputs
        }, indent=2, ensure_ascii=False)
    else:
        formatted_output = full_text

    summary = {
        "pages": len(page_indices),
        "words": total_words,
        "ocr_pages": ocr_pages_count,
        "warnings": warnings
    }

    return {
        "text": formatted_output,
        "report": page_reports,
        "summary": summary
    }
