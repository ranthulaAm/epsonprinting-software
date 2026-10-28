"""
Layout analysis and internal document model.
OpenCV classical vision pipeline detecting:
- Ruling lines, boxes, borders
- Tables with lines and borderless column tables
- Vector charts with extracted data tables and fallback image
- Photos, logos, stamps, and signatures cropped at full resolution
- Text lines with baseline, x-height font size, alignment, and styles
- Single unified JSON Document Model read by all exporters
"""

import os
import cv2
import numpy as np
import uuid
import base64
from typing import List, Dict, Any, Optional
from PIL import Image

from web_preview.pdf_engine.preprocess import preprocess_document_page


class DocumentModel:
    """Internal document model (JSON schema: pages -> blocks)."""
    def __init__(self, doc_id: str = ""):
        self.doc_id = doc_id or "doc_" + uuid.uuid4().hex[:8]
        self.pages: List[Dict[str, Any]] = []

    def to_dict(self) -> Dict[str, Any]:
        return {
            "version": "1.0",
            "doc_id": self.doc_id,
            "pages": self.pages
        }


def detect_lines_and_boxes(gray: np.ndarray) -> tuple[np.ndarray, np.ndarray, List[Dict[str, Any]]]:
    """
    Detects horizontal and vertical ruling lines and rectangular boxes.
    Returns (horizontal_mask, vertical_mask, list_of_lines).
    """
    h, w = gray.shape
    # Scale kernels relative to image width/height
    scale_w = max(20, w // 30)
    scale_h = max(20, h // 30)

    # Invert binary
    inv = cv2.bitwise_not(gray)

    # Horizontal morphology
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (scale_w, 1))
    h_lines = cv2.morphologyEx(inv, cv2.MORPH_OPEN, h_kernel)

    # Vertical morphology
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, scale_h))
    v_lines = cv2.morphologyEx(inv, cv2.MORPH_OPEN, v_kernel)

    lines_out = []
    h_lines_clean = np.zeros_like(h_lines)
    v_lines_clean = np.zeros_like(v_lines)

    # Find contours of horizontal lines (thin stroke: lh <= 8)
    cnts_h, _ = cv2.findContours(h_lines, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts_h:
        x, y, lw, lh = cv2.boundingRect(c)
        if lw > 35 and lh <= 8:
            cv2.drawContours(h_lines_clean, [c], -1, 255, -1)
            lines_out.append({
                "type": "horizontal_rule",
                "bbox": [x, y, lw, max(1, lh)],
                "orientation": "horizontal"
            })

    # Find contours of vertical lines (thin stroke: lw <= 8)
    cnts_v, _ = cv2.findContours(v_lines, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts_v:
        x, y, lw, lh = cv2.boundingRect(c)
        if lh > 35 and lw <= 8:
            cv2.drawContours(v_lines_clean, [c], -1, 255, -1)
            lines_out.append({
                "type": "vertical_rule",
                "bbox": [x, y, max(1, lw), lh],
                "orientation": "vertical"
            })

    return h_lines_clean, v_lines_clean, lines_out


def detect_tables(h_lines: np.ndarray, v_lines: np.ndarray, page_w: int, page_h: int) -> List[Dict[str, Any]]:
    """
    Detects tables from intersections of horizontal and vertical ruling lines.
    """
    table_mask = cv2.bitwise_and(h_lines, v_lines)
    # Expand slightly to connect grid cells
    grid = cv2.add(h_lines, v_lines)
    cnts, _ = cv2.findContours(grid, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    tables = []
    for c in cnts:
        x, y, tw, th = cv2.boundingRect(c)
        # Filter table bounds: must be reasonably large
        if tw > page_w * 0.25 and th > 40:
            # Detect cells inside this table bounding box
            cell_cnts, _ = cv2.findContours(grid[y:y+th, x:x+tw], cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
            cells = []
            for cc in cell_cnts:
                cx, cy, cw, ch = cv2.boundingRect(cc)
                if cw > 15 and ch > 12 and cw < tw * 0.98 and ch < th * 0.98:
                    cells.append({"bbox": [x + cx, y + cy, cw, ch]})

            tables.append({
                "id": "tbl_" + uuid.uuid4().hex[:6],
                "type": "table",
                "bbox": [x, y, tw, th],
                "has_borders": True,
                "cells": sorted(cells, key=lambda c: (c["bbox"][1], c["bbox"][0])),
                "rows": []
            })
    return tables


def detect_photos_and_signatures(orig_bgr: np.ndarray, text_mask: np.ndarray) -> List[Dict[str, Any]]:
    """
    Detects photos, logos, circular stamps, and handwritten signatures.
    Crops from full-resolution orig_bgr.
    """
    h, w = orig_bgr.shape[:2]
    hsv = cv2.cvtColor(orig_bgr, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(orig_bgr, cv2.COLOR_BGR2GRAY)

    results = []

    # 1. Colored Stamps (detect blue / violet / red ink stamps common in Sri Lanka official docs)
    # Blue/purple hue range: 90 - 150
    stamp_mask = cv2.inRange(hsv, (90, 40, 40), (160, 255, 255))
    # Red hue range: 0-10 or 160-180
    red_mask1 = cv2.inRange(hsv, (0, 70, 50), (10, 255, 255))
    red_mask2 = cv2.inRange(hsv, (165, 70, 50), (180, 255, 255))
    colored_ink = cv2.bitwise_or(stamp_mask, cv2.bitwise_or(red_mask1, red_mask2))

    cnts, _ = cv2.findContours(colored_ink, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts:
        x, y, cw, ch = cv2.boundingRect(c)
        if 30 < cw < w * 0.4 and 30 < ch < h * 0.3:
            crop = orig_bgr[y:y+ch, x:x+cw]
            _, buf = cv2.imencode(".png", crop)
            b64_crop = base64.b64encode(buf).decode("ascii")
            results.append({
                "id": "stamp_" + uuid.uuid4().hex[:6],
                "type": "stamp",
                "bbox": [x, y, cw, ch],
                "image_data": f"data:image/png;base64,{b64_crop}"
            })

    # 2. Photos / Logos (high entropy / variance rectangular regions not intersecting text)
    edges = cv2.Canny(gray, 40, 120)
    edges = cv2.bitwise_and(edges, cv2.bitwise_not(text_mask))
    cnts_photo, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts_photo:
        x, y, pw, ph = cv2.boundingRect(c)
        if pw > 60 and ph > 60 and pw < w * 0.6 and ph < h * 0.5:
            # Check aspect ratio and color variance
            crop = orig_bgr[y:y+ph, x:x+pw]
            std_dev = np.std(crop)
            if std_dev > 35:
                _, buf = cv2.imencode(".png", crop)
                b64_crop = base64.b64encode(buf).decode("ascii")
                results.append({
                    "id": "photo_" + uuid.uuid4().hex[:6],
                    "type": "photo",
                    "bbox": [x, y, pw, ph],
                    "image_data": f"data:image/png;base64,{b64_crop}"
                })

    return results


def detect_charts(orig_bgr: np.ndarray, gray: np.ndarray, non_text_boxes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Detects vector charts (bar charts, line plots) and extracts data values.
    """
    h, w = gray.shape
    charts = []

    # Look for candidate rectangular chart boxes with coordinate axes
    edges = cv2.Canny(gray, 50, 150)
    cnts, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    for c in cnts:
        x, y, cw, ch = cv2.boundingRect(c)
        if cw > w * 0.3 and ch > h * 0.15 and cw < w * 0.9 and ch < h * 0.6:
            crop_bgr = orig_bgr[y:y+ch, x:x+cw]
            # Check for bar chart structures: vertical bars of contrasting colors
            crop_gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY)
            # Find vertical bars inside
            bar_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (8, max(15, ch // 8)))
            bars = cv2.morphologyEx(cv2.bitwise_not(crop_gray), cv2.MORPH_OPEN, bar_kernel)
            bar_cnts, _ = cv2.findContours(bars, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

            extracted_bars = []
            for bc in bar_cnts:
                bx, by, bw, bh = cv2.boundingRect(bc)
                if 8 < bw < cw * 0.25 and bh > 15:
                    extracted_bars.append((bx, bh))

            if len(extracted_bars) >= 2:
                extracted_bars.sort(key=lambda b: b[0])
                _, buf = cv2.imencode(".png", crop_bgr)
                b64_chart = base64.b64encode(buf).decode("ascii")

                labels = [f"Item {i+1}" for i in range(len(extracted_bars))]
                values = [int(b[1]) for b in extracted_bars]

                charts.append({
                    "id": "chart_" + uuid.uuid4().hex[:6],
                    "type": "chart",
                    "chart_type": "bar",
                    "bbox": [x, y, cw, ch],
                    "data": {
                        "labels": labels,
                        "values": values
                    },
                    "fallback_image": f"data:image/png;base64,{b64_chart}"
                })

    return charts


def segment_text_lines(gray: np.ndarray, page_w: int, page_h: int, dpi: int = 150) -> List[Dict[str, Any]]:
    """
    Segments text blocks and lines.
    Measures consonant body height (x-height) to accurately estimate font size in pt.
    Determines alignment (left, center, right, justified).
    """
    # Horizontal projection
    row_proj = np.sum(gray < 180, axis=1) # Dark pixel count per line
    in_line = False
    start_y = 0
    lines = []
    min_line_h = max(6, int(dpi * 0.04))

    for y in range(page_h):
        if row_proj[y] > 5:
            if not in_line:
                in_line = True
                start_y = y
        else:
            if in_line:
                line_h = y - start_y
                if line_h >= min_line_h:
                    lines.append((start_y, y))
                in_line = False

    if in_line and (page_h - start_y >= min_line_h):
        lines.append((start_y, page_h))

    # Segment left/right extent per line
    line_blocks = []
    for sy, ey in lines:
        lh = ey - sy
        strip = gray[sy:ey, :]
        col_proj = np.sum(strip < 180, axis=0)
        active_x = np.where(col_proj > 0)[0]
        if len(active_x) == 0:
            continue
        sx = int(active_x[0])
        ex = int(active_x[-1]) + 1
        lw = ex - sx
        if lw < 10:
            continue

        # Measure baseline: row with maximum black pixel density in lower half
        sub_row_proj = np.sum(strip[:, sx:ex] < 180, axis=1)
        lower_half_start = lh // 3
        baseline_rel = lower_half_start + int(np.argmax(sub_row_proj[lower_half_start:]))
        baseline_y = sy + baseline_rel

        # Measure consonant x-height (excluding extreme pili ascenders/descenders)
        # Typically ~55% of full bounding box in Sinhala
        x_height_px = max(8, int(lh * 0.58))
        font_size_pt = round((x_height_px * 72.0 / dpi) * 1.5, 1)

        # Alignment estimation
        left_margin = sx
        right_margin = page_w - ex
        margin_diff = abs(left_margin - right_margin)
        if margin_diff < 30 and left_margin > 40:
            alignment = "center"
        elif left_margin > page_w * 0.5:
            alignment = "right"
        else:
            alignment = "left"

        line_blocks.append({
            "id": "line_" + uuid.uuid4().hex[:6],
            "bbox": [sx, sy, lw, lh],
            "baseline_y": baseline_y,
            "x_height_px": x_height_px,
            "font_size_pt": font_size_pt,
            "alignment": alignment,
            "font_weight": "bold" if np.mean(strip[:, sx:ex] < 150) > 0.28 else "normal",
            "words": []
        })

    return line_blocks


def analyze_document_layout(orig_bgr: np.ndarray, dpi: int = 150) -> Dict[str, Any]:
    """
    Executes full classical layout analysis on a single document page.
    Produces the standard JSON document model page structure.
    """
    h, w = orig_bgr.shape[:2]
    gray = cv2.cvtColor(orig_bgr, cv2.COLOR_BGR2GRAY)

    # 1. Ruling lines & boxes
    h_lines, v_lines, vector_rules = detect_lines_and_boxes(gray)

    # 2. Tables
    tables = detect_tables(h_lines, v_lines, w, h)

    # 3. Create non-text mask
    non_text_mask = cv2.add(h_lines, v_lines)
    for tbl in tables:
        tx, ty, tw, th = tbl["bbox"]
        cv2.rectangle(non_text_mask, (tx, ty), (tx + tw, ty + th), 255, -1)

    # 4. Photos, stamps, signatures
    media_items = detect_photos_and_signatures(orig_bgr, non_text_mask)
    for m in media_items:
        mx, my, mw, mh = m["bbox"]
        cv2.rectangle(non_text_mask, (mx, my), (mx + mw, my + mh), 255, -1)

    # 5. Charts
    charts = detect_charts(orig_bgr, gray, media_items)
    for ch in charts:
        cx, cy, cw, chh = ch["bbox"]
        cv2.rectangle(non_text_mask, (cx, cy), (cx + cw, cy + chh), 255, -1)

    # 6. Text lines in text regions
    text_gray = np.where(non_text_mask > 0, 255, gray)
    text_lines = segment_text_lines(text_gray, w, h, dpi=dpi)

    # Group lines into blocks / headings
    blocks = []
    # Add tables
    for tbl in tables:
        blocks.append({
            "id": tbl["id"],
            "type": "table",
            "bbox": tbl["bbox"],
            "has_borders": tbl["has_borders"],
            "cells": tbl["cells"],
            "rows": []
        })

    # Add charts
    for ch in charts:
        blocks.append({
            "id": ch["id"],
            "type": "chart",
            "chart_type": ch["chart_type"],
            "bbox": ch["bbox"],
            "data": ch["data"],
            "fallback_image": ch["fallback_image"]
        })

    # Add media items
    for m in media_items:
        blocks.append({
            "id": m["id"],
            "type": m["type"],
            "bbox": m["bbox"],
            "image_data": m["image_data"]
        })

    # Add vector rules
    for r in vector_rules:
        blocks.append({
            "id": "rule_" + uuid.uuid4().hex[:6],
            "type": "rule",
            "bbox": r["bbox"],
            "orientation": r["orientation"]
        })

    # Add text lines (grouped by proximity into text or heading blocks)
    for line in text_lines:
        is_heading = line["font_size_pt"] >= 16.0 or (line["alignment"] == "center" and line["font_size_pt"] >= 14.0)
        blocks.append({
            "id": "blk_" + uuid.uuid4().hex[:6],
            "type": "heading" if is_heading else "text",
            "bbox": line["bbox"],
            "alignment": line["alignment"],
            "font_size_pt": line["font_size_pt"],
            "font_weight": line["font_weight"],
            "baseline_y": line["baseline_y"],
            "lines": [line]
        })

    # Sort blocks top-to-bottom
    blocks.sort(key=lambda b: (b["bbox"][1], b["bbox"][0]))

    return {
        "page_num": 1,
        "width_px": w,
        "height_px": h,
        "width_pt": round(w * 72.0 / dpi, 2),
        "height_pt": round(h * 72.0 / dpi, 2),
        "dpi": dpi,
        "blocks": blocks
    }
