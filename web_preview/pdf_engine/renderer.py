"""
Document renderer and multi-format exporter.
Converts the internal document model into:
1. Vector PDF via headless Chromium (Playwright) with HarfBuzz Sinhala text shaping and embedded fonts.
2. Microsoft Word (.docx) via python-docx with complex-script (w:cs) font attributes.
3. Standalone clean HTML/CSS with absolutely positioned blocks.
"""

import os
import io
import base64
from typing import Dict, Any
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

    for page in doc_model.get("pages", []):
        w_pt = page.get("width_pt", 595.28)
        h_pt = page.get("height_pt", 841.89)
        dpi = page.get("dpi", 150)
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
                align = blk.get("alignment", "left")
                font_size = blk.get("font_size_pt", 12.0)
                font_weight = "bold" if blk.get("font_weight") == "bold" or b_type == "heading" else "normal"

                # Aggregate words across lines
                line_strs = []
                for ln in blk.get("lines", []):
                    words = ln.get("words", [])
                    if words:
                        ln_text = " ".join(w.get("text", "") for w in words if w.get("text"))
                    else:
                        ln_text = ln.get("text", "")
                    if ln_text:
                        line_strs.append(f"<div>{ln_text}</div>")

                content = "".join(line_strs) if line_strs else blk.get("text", "")
                blocks_html.append(f"""
                <div class="doc-block block-{b_type}" style="
                    position: absolute;
                    left: {left_pt:.2f}pt;
                    top: {top_pt:.2f}pt;
                    width: {width_pt:.2f}pt;
                    text-align: {align};
                    font-size: {font_size:.1f}pt;
                    font-weight: {font_weight};
                    line-height: 1.35;
                ">{content}</div>
                """)

            elif b_type == "table":
                cells = blk.get("cells", [])
                rows_data = blk.get("rows", [])
                if rows_data:
                    # Formatted rows
                    tr_list = []
                    for r in rows_data:
                        tds = "".join(f"<td style='border:1px solid #000; padding:4pt 6pt;'>{c}</td>" for c in r)
                        tr_list.append(f"<tr>{tds}</tr>")
                    table_content = "".join(tr_list)
                else:
                    table_content = "<tr><td style='border:1px solid #000; padding:6pt;'>Table Data</td></tr>"

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

            elif b_type == "rule":
                orientation = blk.get("orientation", "horizontal")
                if orientation == "horizontal":
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

                # Generate clean inline SVG bar chart
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

            elif b_type in ("photo", "stamp", "signature"):
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
        size: A4;
        margin: 0;
    }}
    body {{
        margin: 0;
        padding: 0;
        background-color: #f3f4f6;
        font-family: "Noto Sans Sinhala", "Sinhala MN", "Iskoola Pota", -apple-system, sans-serif;
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
    </body>
    </html>"""


def export_pdf(doc_model: Dict[str, Any]) -> bytes:
    """Generates vector PDF with native HarfBuzz text shaping using headless Chromium."""
    html_content = generate_document_html(doc_model, standalone=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.set_content(html_content)
        # First page format
        first_page = doc_model.get("pages", [{}])[0]
        w_pt = first_page.get("width_pt", 595.28)
        h_pt = first_page.get("height_pt", 841.89)

        pdf_bytes = page.pdf(
            width=f"{w_pt / 72.0:.3f}in",
            height=f"{h_pt / 72.0:.3f}in",
            print_background=True,
            margin={"top": "0in", "bottom": "0in", "left": "0in", "right": "0in"}
        )
        browser.close()
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
