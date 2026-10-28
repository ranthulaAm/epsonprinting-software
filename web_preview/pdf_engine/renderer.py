"""
Document renderer and multi-format exporter.
Converts the internal document model into:
1. Vector PDF via headless Chromium (Playwright) with HarfBuzz Sinhala text shaping and embedded fonts.
2. Microsoft Word (.docx) via python-docx with complex-script (w:cs) font attributes.
3. Standalone clean HTML/CSS with absolutely positioned blocks.
"""

import os
import io
import uuid
import base64
from typing import Dict, Any
import pikepdf
import docx
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from playwright.sync_api import sync_playwright

WORKSPACE_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS_DIR = os.path.join(WORKSPACE_ROOT, "assets", "fonts")
NOTO_REGULAR = os.path.join(FONTS_DIR, "NotoSansSinhala-Regular.ttf")
NOTO_BOLD = os.path.join(FONTS_DIR, "NotoSansSinhala-Bold.ttf")

FONT_REG_B64 = ""
FONT_BOLD_B64 = ""

if os.path.exists(NOTO_REGULAR):
    with open(NOTO_REGULAR, "rb") as f:
        FONT_REG_B64 = base64.b64encode(f.read()).decode("ascii")
if os.path.exists(NOTO_BOLD):
    with open(NOTO_BOLD, "rb") as f:
        FONT_BOLD_B64 = base64.b64encode(f.read()).decode("ascii")


def generate_document_html(doc_model: Dict[str, Any], standalone: bool = True) -> str:
    """
    Renders the document model as high-fidelity HTML/CSS with absolute positioning,
    native embedded fonts, vector rules, and real table grids.
    """
    pages_html = []
    first_page = doc_model.get("pages", [{}])[0] if doc_model.get("pages") else {}
    doc_w_pt = first_page.get("width_pt", 611.0)
    doc_h_pt = first_page.get("height_pt", 840.0)

    for page in doc_model.get("pages", []):
        w_pt = page.get("width_pt", 611.0)
        h_pt = page.get("height_pt", 840.0)
        dpi = page.get("dpi", 300)
        px_to_pt = 72.0 / dpi

        blocks_html = []
        for blk in page.get("blocks", []):
            b_type = blk.get("type", "text")
            bx, by, bw, bh = blk.get("bbox", [0, 0, 100, 20])
            left_pt = bx * px_to_pt
            top_pt = by * px_to_pt
            width_pt = bw * px_to_pt
            height_pt = bh * px_to_pt

            if b_type in ("text", "heading"):
                lines = blk.get("lines", [])
                if lines:
                    for ln in lines:
                        lx, ly, lw, lh = ln.get("bbox", [bx, by, bw, bh])
                        l_left = lx * px_to_pt
                        l_width = lw * px_to_pt
                        base_y = ln.get("baseline_y", ly + int(lh * 0.75))
                        f_size = ln.get("font_size_pt", blk.get("font_size_pt", 11.0))
                        l_top = (base_y * px_to_pt) - (f_size * 0.82)
                        f_weight = "bold" if ln.get("font_weight") == "bold" or b_type == "heading" else "normal"
                        col = ln.get("color", blk.get("color", "#111827"))
                        und = ln.get("underline", blk.get("underline", False))
                        und_css = "text-decoration: underline; text-decoration-thickness: 1.2pt; text-underline-offset: 2.5pt;" if und else ""
                        words = ln.get("words", [])
                        if words:
                            l_text = " ".join(w.get("text", "") for w in words if w.get("text"))
                        else:
                            l_text = ln.get("text", "")
                        lid = ln.get("id", "ln_" + uuid.uuid4().hex[:6])

                        blocks_html.append(f"""
                        <div id="{lid}" class="doc-line" data-target-width="{l_width:.2f}" style="
                            position: absolute;
                            left: {l_left:.2f}pt;
                            top: {l_top:.2f}pt;
                            font-size: {f_size:.1f}pt;
                            font-weight: {f_weight};
                            color: {col};
                            white-space: nowrap;
                            line-height: 1.0;
                            {und_css}
                        ">{l_text}</div>
                        """)
                else:
                    f_size = blk.get("font_size_pt", 11.0)
                    f_weight = "bold" if blk.get("font_weight") == "bold" or b_type == "heading" else "normal"
                    col = blk.get("color", "#111827")
                    txt = blk.get("text", "")
                    blocks_html.append(f"""
                    <div class="doc-line" data-target-width="{width_pt:.2f}" style="
                        position: absolute;
                        left: {left_pt:.2f}pt;
                        top: {top_pt:.2f}pt;
                        font-size: {f_size:.1f}pt;
                        font-weight: {f_weight};
                        color: {col};
                        white-space: nowrap;
                        line-height: 1.0;
                    ">{txt}</div>
                    """)

            elif b_type == "table":
                rows_data = blk.get("rows", [])
                if rows_data:
                    tr_list = []
                    for r in rows_data:
                        tds = "".join(f"<td style='border:1px solid #000; padding:4pt 6pt;'>{c}</td>" for c in r)
                        tr_list.append(f"<tr>{tds}</tr>")
                    table_content = "".join(tr_list)
                    blocks_html.append(f"""
                    <div class="doc-block block-table" style="
                        position: absolute;
                        left: {left_pt:.2f}pt;
                        top: {top_pt:.2f}pt;
                        width: {width_pt:.2f}pt;
                    ">
                        <table style="width:100%; border-collapse:collapse; font-size:10pt;">
                            {table_content}
                        </table>
                    </div>
                    """)
                else:
                    blocks_html.append(f"""
                    <div class="doc-block block-table" style="
                        position: absolute;
                        left: {left_pt:.2f}pt;
                        top: {top_pt:.2f}pt;
                        width: {width_pt:.2f}pt;
                        height: {height_pt:.2f}pt;
                        border: 1px solid #000;
                        box-sizing: border-box;
                    "></div>
                    """)

            elif b_type == "rule":
                orientation = blk.get("orientation", "horizontal")
                rule_style = blk.get("rule_style", "solid")
                if orientation == "horizontal":
                    if rule_style == "dotted":
                        blocks_html.append(f"""
                        <div class="doc-block block-rule" style="
                            position: absolute;
                            left: {left_pt:.2f}pt;
                            top: {top_pt:.2f}pt;
                            width: {width_pt:.2f}pt;
                            height: 0px;
                            border-bottom: 1.5pt dotted #111827;
                        "></div>
                        """)
                    else:
                        blocks_html.append(f"""
                        <div class="doc-block block-rule" style="
                            position: absolute;
                            left: {left_pt:.2f}pt;
                            top: {top_pt:.2f}pt;
                            width: {width_pt:.2f}pt;
                            height: 1.2pt;
                            background-color: #111827;
                        "></div>
                        """)
                else:
                    blocks_html.append(f"""
                    <div class="doc-block block-rule" style="
                        position: absolute;
                        left: {left_pt:.2f}pt;
                        top: {top_pt:.2f}pt;
                        width: 1.2pt;
                        height: {height_pt:.2f}pt;
                        background-color: #111827;
                    "></div>
                    """)

            elif b_type == "chart":
                chart_data = blk.get("data", {})
                labels = chart_data.get("labels", [])
                values = chart_data.get("values", [])
                max_val = max(values) if values else 1
                bars_svg = []
                bar_count = len(values)
                if bar_count > 0:
                    bar_w = width_pt / max(1, bar_count * 1.5)
                    gap = bar_w * 0.5
                    for i, (lab, val) in enumerate(zip(labels, values)):
                        bh = (val / max_val) * (height_pt - 25)
                        bx_pos = i * (bar_w + gap) + 15
                        by_pos = (height_pt - 20) - bh
                        bars_svg.append(f"""
                        <rect x='{bx_pos:.1f}' y='{by_pos:.1f}' width='{bar_w:.1f}' height='{bh:.1f}' fill='#2563eb' rx='2'/>
                        <text x='{bx_pos + bar_w/2:.1f}' y='{height_pt - 5:.1f}' font-size='8pt' text-anchor='middle' fill='#374151'>{lab}</text>
                        """)

                svg_content = f"""
                <svg width='{width_pt:.1f}pt' height='{height_pt:.1f}pt' style='background:#f9fafb; border:1px solid #e5e7eb; border-radius:4px;'>
                    {"".join(bars_svg)}
                </svg>
                """
                blocks_html.append(f"""
                <div class="doc-block block-chart" style="
                    position: absolute;
                    left: {left_pt:.2f}pt;
                    top: {top_pt:.2f}pt;
                    width: {width_pt:.2f}pt;
                    height: {height_pt:.2f}pt;
                ">{svg_content}</div>
                """)

            elif b_type in ("photo", "stamp", "signature", "barcode"):
                img_src = blk.get("image_data", "")
                if img_src:
                    blocks_html.append(f"""
                    <div class="doc-block block-{b_type}" style="
                        position: absolute;
                        left: {left_pt:.2f}pt;
                        top: {top_pt:.2f}pt;
                        width: {width_pt:.2f}pt;
                        height: {height_pt:.2f}pt;
                    ">
                        <img src="{img_src}" style="width:100%; height:100%; object-fit:contain;" alt="{b_type}"/>
                    </div>
                    """)

        pages_html.append(f"""
        <div class="doc-page" style="
            position: relative;
            width: {w_pt:.2f}pt;
            height: {h_pt:.2f}pt;
            background: #ffffff;
            margin: 0 auto 30px auto;
            box-shadow: 0 4px 14px rgba(0,0,0,0.1);
            overflow: hidden;
            box-sizing: border-box;
            page-break-after: always;
        ">
            {"".join(blocks_html)}
        </div>
        """)

    font_faces = f"""
    @font-face {{
        font-family: "Noto Sans Sinhala";
        src: url("data:font/ttf;base64,{FONT_REG_B64}") format("truetype");
        font-weight: normal;
        font-style: normal;
    }}
    @font-face {{
        font-family: "Noto Sans Sinhala";
        src: url("data:font/ttf;base64,{FONT_BOLD_B64}") format("truetype");
        font-weight: bold;
        font-style: normal;
    }}
    """ if FONT_REG_B64 else ""

    return f"""<!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <title>Modernized Document</title>
    <style>
    {font_faces}
    @page {{
        size: {doc_w_pt:.2f}pt {doc_h_pt:.2f}pt;
        margin: 0;
    }}
    body {{
        margin: 0;
        padding: 0;
        background-color: #f3f4f6;
        font-family: "Noto Sans Sinhala", sans-serif;
        color: #111827;
        -webkit-font-smoothing: antialiased;
    }}
    @media print {{
        body {{ background: transparent; }}
        .doc-page {{ margin: 0 !important; box-shadow: none !important; }}
    }}
    </style>
    </head>
    <body>
    {"".join(pages_html)}
    <script>
    function fitLines() {{
        document.querySelectorAll('.doc-line').forEach(function(el) {{
            var target = parseFloat(el.getAttribute('data-target-width'));
            if (!target || target <= 0) return;
            var cur = el.getBoundingClientRect().width;
            if (cur <= 0) return;
            var ratio = target / cur;
            if (ratio >= 0.85 && ratio <= 1.25 && Math.abs(ratio - 1.0) > 0.01) {{
                el.style.transformOrigin = 'left center';
                el.style.transform = 'scaleX(' + ratio.toFixed(4) + ')';
            }}
        }});
    }}
    if (document.readyState === 'loading') {{
        document.addEventListener('DOMContentLoaded', fitLines);
    }} else {{
        fitLines();
    }}
    </script>
    </body>
    </html>"""

def export_pdf(doc_model: Dict[str, Any]) -> bytes:
    """Generates vector PDF with native HarfBuzz text shaping using headless Chromium."""
    html_content = generate_document_html(doc_model, standalone=True)
    first_page = doc_model.get("pages", [{}])[0]
    w_pt = float(first_page.get("width_pt", 611.0))
    h_pt = float(first_page.get("height_pt", 840.0))

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.set_content(html_content, wait_until="networkidle")
        page.evaluate("document.fonts.ready")
        page.evaluate("if (typeof fitLines === 'function') fitLines();")
        pdf_bytes = page.pdf(
            prefer_css_page_size=True,
            print_background=True,
            margin={"top": "0in", "bottom": "0in", "left": "0in", "right": "0in"}
        )
        browser.close()

    # Exact MediaBox enforcement
    with pikepdf.open(io.BytesIO(pdf_bytes)) as pdf:
        for pg in pdf.pages:
            pg.mediabox = [0, 0, w_pt, h_pt]
        out_buf = io.BytesIO()
        pdf.save(out_buf)
        pdf_bytes = out_buf.getvalue()

    return pdf_bytes


def export_docx(doc_model: Dict[str, Any]) -> bytes:
    """Generates Word document with complex-script font tags for Sinhala."""
    doc = docx.Document()
    # Configure 1 inch margins
    sections = doc.sections
    for sec in sections:
        sec.top_margin = Inches(0.8)
        sec.bottom_margin = Inches(0.8)
        sec.left_margin = Inches(0.8)
        sec.right_margin = Inches(0.8)

    for page in doc_model.get("pages", []):
        for blk in page.get("blocks", []):
            b_type = blk.get("type", "text")

            if b_type in ("text", "heading"):
                p = doc.add_paragraph()
                align = blk.get("alignment", "left")
                if align == "center":
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                elif align == "right":
                    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

                font_size = blk.get("font_size_pt", 12.0)
                is_bold = blk.get("font_weight") == "bold" or b_type == "heading"

                line_texts = []
                for ln in blk.get("lines", []):
                    words = ln.get("words", [])
                    if words:
                        line_texts.append(" ".join(w.get("text", "") for w in words if w.get("text")))
                    elif ln.get("text"):
                        line_texts.append(ln.get("text"))

                full_text = "\n".join(line_texts) or blk.get("text", "")
                if full_text:
                    run = p.add_run(full_text)
                    run.font.size = Pt(font_size)
                    run.bold = is_bold
                    run.font.name = "Noto Sans Sinhala"

                    # Add complex script attributes
                    rPr = run._r.get_or_add_rPr()
                    rFonts = rPr.find(qn("w:rFonts"))
                    if rFonts is None:
                        rFonts = OxmlElement("w:rFonts")
                        rPr.append(rFonts)
                    rFonts.set(qn("w:cs"), "Noto Sans Sinhala")
                    rFonts.set(qn("w:ascii"), "Noto Sans Sinhala")
                    rFonts.set(qn("w:hAnsi"), "Noto Sans Sinhala")

            elif b_type == "table":
                rows_data = blk.get("rows", [])
                if rows_data:
                    tbl = doc.add_table(rows=len(rows_data), cols=len(rows_data[0]))
                    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
                    for ri, r in enumerate(rows_data):
                        for ci, val in enumerate(r):
                            cell = tbl.cell(ri, ci)
                            cell.text = str(val)
                            for cp in cell.paragraphs:
                                for cr in cp.runs:
                                    cr.font.name = "Noto Sans Sinhala"
                                    crPr = cr._r.get_or_add_rPr()
                                    crFonts = crPr.find(qn("w:rFonts"))
                                    if crFonts is None:
                                        crFonts = OxmlElement("w:rFonts")
                                        crPr.append(crFonts)
                                    crFonts.set(qn("w:cs"), "Noto Sans Sinhala")

            elif b_type in ("photo", "stamp", "signature"):
                img_data = blk.get("image_data", "")
                if img_data.startswith("data:image/png;base64,"):
                    raw_b64 = img_data.split(",", 1)[1]
                    img_bytes = base64.b64decode(raw_b64)
                    doc.add_picture(io.BytesIO(img_bytes), width=Inches(2.0))

    out = io.BytesIO()
    doc.save(out)
    return out.getvalue()


def compute_residual_check(clean_bgr, doc_model: Dict[str, Any], page_idx: int = 0, dpi: int = 300) -> Dict[str, Any]:
    """
    Renders output page at working DPI, computes residual ink map against clean_bgr.
    If any region > 12x12 mm has unexplained residual ink, creates fallback raster block.
    """
    import cv2
    import numpy as np
    from web_preview.pdf_engine.preprocess import mm_to_px

    h, w = clean_bgr.shape[:2]
    # Render PDF to image at working DPI
    pdf_bytes = export_pdf(doc_model)
    import pypdfium2 as pdfium
    doc = pdfium.PdfDocument(pdf_bytes)
    n_pages = len(doc)
    p_num = min(page_idx, n_pages - 1)
    rendered_pil = doc[p_num].render(scale=dpi / 72.0).to_pil().convert("RGB")
    rendered_np = np.array(rendered_pil)
    doc.close()

    # Align size if difference is 1-2 px
    if rendered_np.shape[:2] != (h, w):
        rendered_np = cv2.resize(rendered_np, (w, h))

    gray_clean = cv2.cvtColor(clean_bgr, cv2.COLOR_BGR2GRAY)
    gray_rend = cv2.cvtColor(rendered_np, cv2.COLOR_RGB2GRAY)

    # Ink in clean_bgr (dark) but missing in rendered (light)
    clean_ink = (gray_clean < 180)
    rend_ink = (gray_rend < 180)

    # Dilate rendered ink slightly (2 mm) to account for slight stroke font differences
    pad_ink = mm_to_px(2.0, dpi)
    rend_dilated = cv2.dilate(rend_ink.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_RECT, (pad_ink, pad_ink)))

    # Missing residual ink
    missing_ink = np.logical_and(clean_ink, rend_dilated == 0).astype(np.uint8) * 255

    # Filter out outer scanner margin (5mm)
    margin = mm_to_px(5.0, dpi)
    missing_ink[:margin, :] = 0
    missing_ink[-margin:, :] = 0
    missing_ink[:, :margin] = 0
    missing_ink[:, -margin:] = 0

    # Find large unexplained regions (> 12x12 mm)
    min_dim = mm_to_px(12.0, dpi)
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(missing_ink)
    fallback_blocks = []

    for i in range(1, num_labels):
        rx, ry, rw, rh, area = stats[i]
        if rw >= min_dim and rh >= min_dim and area > (min_dim * min_dim * 0.25):
            crop_bgr = clean_bgr[ry:ry+rh, rx:rx+rw]
            _, buf = cv2.imencode(".png", crop_bgr)
            b64_crop = base64.b64encode(buf).decode("ascii")
            fallback_blocks.append({
                "id": "fallback_" + uuid.uuid4().hex[:6],
                "type": "photo",
                "bbox": [int(rx), int(ry), int(rw), int(rh)],
                "image_data": f"data:image/png;base64,{b64_crop}"
            })

    return {
        "fallback_count": len(fallback_blocks),
        "fallback_blocks": fallback_blocks,
        "clean_reconstruction": len(fallback_blocks) == 0
    }
