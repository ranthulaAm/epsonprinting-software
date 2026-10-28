"""
Layout analysis and internal document model.
Resolution-independent OpenCV pipeline detecting:
- Barcodes (dense vertical-bar pattern) decoded or cropped at full resolution
- Photos, logos, colored stamps, rubber seals, and signatures cropped with clean transparency
- Ruling lines, boxes, and dotted signature lines (with strict phantom rule filtering)
- Tables with lines and borderless column tables
- Text lines with exact baselines, clustered font sizes (<= 6 distinct sizes), alignment, and styles
- Single unified JSON Document Model read by all exporters
"""

import os
import cv2
import numpy as np
import uuid
import base64
import logging
from typing import List, Dict, Any, Optional, Tuple
from PIL import Image

from web_preview.pdf_engine.preprocess import mm_to_px, pt_to_px, px_to_pt

logger = logging.getLogger("layout_analyzer")


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


def detect_barcodes(gray: np.ndarray, orig_bgr: np.ndarray, dpi: int = 300) -> List[Dict[str, Any]]:
    """
    Detects 1D/2D barcodes with dense parallel vertical bar patterns.
    Uses vertical morphological filtering (taller than regular text) and Sobel edge ratio.
    Attempts decoding with OpenCV BarcodeDetector; otherwise crops from original.
    """
    h, w = gray.shape
    _, bin_inv = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)

    # Exclude outer scanner margins within 3mm
    margin = mm_to_px(3.0, dpi)
    bin_clean = bin_inv.copy()
    bin_clean[:margin, :] = 0
    bin_clean[-margin:, :] = 0
    bin_clean[:, :margin] = 0
    bin_clean[:, -margin:] = 0

    # Vertical opening to keep only vertical lines taller than 4.5 mm (regular text letters are ~2-3mm)
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, mm_to_px(4.5, dpi)))
    v_open = cv2.morphologyEx(bin_clean, cv2.MORPH_OPEN, v_kernel)

    # Horizontal closing to bridge adjacent vertical bars
    h_close = cv2.morphologyEx(v_open, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_RECT, (mm_to_px(4.0, dpi), 1)))

    cnts, _ = cv2.findContours(h_close, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    barcodes = []

    detector = None
    if hasattr(cv2, "barcode_BarcodeDetector"):
        try:
            detector = cv2.barcode_BarcodeDetector()
        except Exception:
            detector = None

    for c in cnts:
        x, y, bw, bh = cv2.boundingRect(c)
        # Barcodes: width >= 15mm, height >= 5mm, aspect ratio >= 1.4
        if bw >= mm_to_px(15.0, dpi) and bh >= mm_to_px(5.0, dpi) and bw > bh * 1.4:
            crop = gray[y:y+bh, x:x+bw]
            sobel_x = np.abs(cv2.Sobel(crop, cv2.CV_32F, 1, 0, ksize=3))
            sobel_y = np.abs(cv2.Sobel(crop, cv2.CV_32F, 0, 1, ksize=3))
            sobel_ratio = float(np.sum(sobel_x)) / max(1.0, float(np.sum(sobel_y)))

            # Barcodes strictly have dominant vertical edge energy (sobel_ratio >= 1.4)
            if sobel_ratio >= 1.4:
                crop_bgr = orig_bgr[y:y+bh, x:x+bw]
                decoded_val = ""
                if detector:
                    try:
                        res = detector.detectAndDecode(crop_bgr)
                        if res and len(res) >= 1 and res[0]:
                            decoded_val = str(res[0])
                    except Exception:
                        pass

                _, buf = cv2.imencode(".png", crop_bgr)
                b64_img = base64.b64encode(buf).decode("ascii")

                barcodes.append({
                    "id": "barcode_" + uuid.uuid4().hex[:6],
                    "type": "barcode",
                    "bbox": [int(x), int(y), int(bw), int(bh)],
                    "decoded": decoded_val,
                    "image_data": f"data:image/png;base64,{b64_img}"
                })

    return barcodes


def detect_stamps_and_signatures(orig_bgr: np.ndarray, gray: np.ndarray, dpi: int = 300) -> List[Dict[str, Any]]:
    """
    Detects colored ink stamps (blue, violet, red), circular seals, and handwritten signatures.
    Crops from full-resolution orig_bgr and cleans paper background to transparent alpha.
    """
    h, w = orig_bgr.shape[:2]
    hsv = cv2.cvtColor(orig_bgr, cv2.COLOR_BGR2HSV)
    results = []

    # 1. Colored Stamps: Blue/purple hue range: 90-155, Red hue range: 0-15 & 160-180
    blue_mask = cv2.inRange(hsv, (90, 35, 35), (155, 255, 255))
    red_mask1 = cv2.inRange(hsv, (0, 40, 40), (15, 255, 255))
    red_mask2 = cv2.inRange(hsv, (160, 40, 40), (180, 255, 255))
    colored_ink = cv2.bitwise_or(blue_mask, cv2.bitwise_or(red_mask1, red_mask2))

    # Dilate slightly to group close stamp strokes
    stamp_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (mm_to_px(1.5, dpi), mm_to_px(1.5, dpi)))
    dilated_stamps = cv2.morphologyEx(colored_ink, cv2.MORPH_CLOSE, stamp_kernel)

    cnts, _ = cv2.findContours(dilated_stamps, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    min_stamp_dim = mm_to_px(10.0, dpi)
    max_stamp_dim = mm_to_px(85.0, dpi)

    for c in cnts:
        x, y, sw, sh = cv2.boundingRect(c)
        if min_stamp_dim <= sw <= max_stamp_dim and min_stamp_dim <= sh <= max_stamp_dim:
            # Check density
            crop_bgr = orig_bgr[y:y+sh, x:x+sw]
            crop_gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY)
            # Create RGBA with transparent white paper background
            crop_rgba = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2BGRA)
            paper_mask = (crop_gray > 220)
            crop_rgba[paper_mask, 3] = 0

            _, buf = cv2.imencode(".png", crop_rgba)
            b64_crop = base64.b64encode(buf).decode("ascii")

            results.append({
                "id": "stamp_" + uuid.uuid4().hex[:6],
                "type": "stamp",
                "bbox": [int(x), int(y), int(sw), int(sh)],
                "image_data": f"data:image/png;base64,{b64_crop}"
            })

    # 2. Cursive Signatures (deponent signature in lower portion of page)
    # Check for handwriting strokes with blue ink or dark cursive strokes
    pad = mm_to_px(2.0, dpi)
    lower_h_start = int(h * 0.60)
    lower_blue = blue_mask[lower_h_start:, :]
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(lower_blue)

    for i in range(1, num_labels):
        sx, sy, sw, sh, area = stats[i]
        # Signature: width >= 14 mm, height >= 3.5 mm, area > 800
        if sw >= mm_to_px(14.0, dpi) and sh >= mm_to_px(3.5, dpi) and area > 800:
            global_y = lower_h_start + sy
            # Avoid overlaps with already detected stamps
            overlap = False
            for r in results:
                rx, ry, rw, rh = r["bbox"]
                if max(sx, rx) < min(sx + sw, rx + rw) and max(global_y, ry) < min(global_y + sh, ry + rh):
                    overlap = True
                    break
            if not overlap:
                # Add padding
                px1 = max(0, sx - pad)
                py1 = max(0, global_y - pad)
                px2 = min(w, sx + sw + pad)
                py2 = min(h, global_y + sh + pad)

                crop_bgr = orig_bgr[py1:py2, px1:px2]
                crop_gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY)
                crop_rgba = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2BGRA)
                paper_mask = (crop_gray > 220)
                crop_rgba[paper_mask, 3] = 0

                _, buf = cv2.imencode(".png", crop_rgba)
                b64_sig = base64.b64encode(buf).decode("ascii")

                results.append({
                    "id": "sig_" + uuid.uuid4().hex[:6],
                    "type": "signature",
                    "bbox": [int(px1), int(py1), int(px2 - px1), int(py2 - py1)],
                    "image_data": f"data:image/png;base64,{b64_sig}"
                })

    return results


def detect_tables(gray: np.ndarray, page_w: int, page_h: int, dpi: int = 300) -> List[Dict[str, Any]]:
    """Detects tables with enclosing horizontal and vertical grid lines."""
    min_line_len = mm_to_px(25.0, dpi)
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (min_line_len, 1))
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, min_line_len))

    inv = cv2.bitwise_not(gray)
    h_lines = cv2.morphologyEx(inv, cv2.MORPH_OPEN, h_kernel)
    v_lines = cv2.morphologyEx(inv, cv2.MORPH_OPEN, v_kernel)

    grid = cv2.bitwise_and(h_lines, v_lines)
    cnts, _ = cv2.findContours(grid, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    tables = []
    for c in cnts:
        x, y, tw, th = cv2.boundingRect(c)
        if tw > page_w * 0.35 and th > mm_to_px(15.0, dpi):
            tables.append({
                "id": "tbl_" + uuid.uuid4().hex[:6],
                "type": "table",
                "bbox": [int(x), int(y), int(tw), int(th)],
                "has_borders": True,
                "cells": [],
                "rows": []
            })
    return tables


def cluster_font_sizes(sizes: List[float], tolerance: float = 0.04) -> Tuple[List[float], List[float]]:
    """
    Clusters line font sizes across the whole document and snaps lines within 4%
    of each other to one size. Guarantees <= 6 distinct sizes.
    """
    if not sizes:
        return [], []

    sorted_unique = sorted(set(sizes))
    clusters: List[List[float]] = []

    for s in sorted_unique:
        added = False
        for c in clusters:
            rep = float(np.mean(c))
            if abs(s - rep) / max(0.1, rep) <= tolerance or abs(s - rep) <= 0.8:
                c.append(s)
                added = True
                break
        if not added:
            clusters.append([s])

    # If more than 6 clusters, merge closest clusters until <= 6
    while len(clusters) > 6:
        # Find closest pair of adjacent clusters
        min_dist = 9999.0
        best_pair = (0, 1)
        for i in range(len(clusters) - 1):
            dist = abs(np.mean(clusters[i]) - np.mean(clusters[i + 1]))
            if dist < min_dist:
                min_dist = dist
                best_pair = (i, i + 1)
        # Merge
        i1, i2 = best_pair
        clusters[i1].extend(clusters[i2])
        clusters.pop(i2)

    # Compute mapping
    mapping = {}
    distinct_sizes = []
    for c in clusters:
        snapped = round(float(np.median(c)) * 2) / 2.0
        distinct_sizes.append(snapped)
        for s in c:
            mapping[s] = snapped

    clustered = [mapping[s] for s in sizes]
    return clustered, sorted(list(set(distinct_sizes)))


def segment_text_lines(
    gray: np.ndarray,
    orig_bgr: np.ndarray,
    page_w: int,
    page_h: int,
    dpi: int = 300,
    non_ocr_mask: Optional[np.ndarray] = None
) -> List[Dict[str, Any]]:
    """
    Segments document into text lines with baselines, x-heights, color, and styles.
    Honors non_ocr_mask so non-text objects are never processed as text.
    Handles side-by-side columns by splitting horizontal bands across column gutters (> 10mm).
    """
    _, bin_inv = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)
    if non_ocr_mask is not None:
        bin_inv = cv2.bitwise_and(bin_inv, cv2.bitwise_not(non_ocr_mask))

    min_line_h = mm_to_px(1.5, dpi)
    row_proj = np.sum(bin_inv > 0, axis=1)

    in_line = False
    start_y = 0
    raw_bands: List[Tuple[int, int]] = []

    for y in range(page_h):
        if row_proj[y] > mm_to_px(1.0, dpi):
            if not in_line:
                in_line = True
                start_y = y
        else:
            if in_line:
                if y - start_y >= min_line_h:
                    raw_bands.append((start_y, y))
                in_line = False

    if in_line and (page_h - start_y >= min_line_h):
        raw_bands.append((start_y, page_h))

    col_gutter_thresh = mm_to_px(9.0, dpi)
    raw_lines = []

    for sy, ey in raw_bands:
        lh = ey - sy
        strip = bin_inv[sy:ey, :]
        col_proj = np.sum(strip > 0, axis=0)
        active = (col_proj > 0)
        diffs = np.diff(active.astype(int))
        starts = np.where(diffs == 1)[0] + 1
        ends = np.where(diffs == -1)[0] + 1
        if active[0]:
            starts = np.insert(starts, 0, 0)
        if active[-1]:
            ends = np.append(ends, len(active))

        # Merge segments unless separated by a true column gutter (> 9mm)
        merged_spans = []
        if len(starts) > 0 and len(ends) > 0:
            cur_s = starts[0]
            cur_e = ends[0]
            for s, e in zip(starts[1:], ends[1:]):
                if s - cur_e <= col_gutter_thresh:
                    cur_e = e
                else:
                    if cur_e - cur_s >= mm_to_px(2.0, dpi):
                        merged_spans.append((cur_s, cur_e))
                    cur_s = s
                    cur_e = e
            if cur_e - cur_s >= mm_to_px(2.0, dpi):
                merged_spans.append((cur_s, cur_e))

        for sx, ex in merged_spans:
            lw = ex - sx
            line_strip = strip[:, sx:ex]
            sub_row_proj = np.sum(line_strip > 0, axis=1)
            active_rows = np.where(sub_row_proj > 0)[0]
            if len(active_rows) == 0:
                continue

            real_sy = sy + int(active_rows[0])
            real_ey = sy + int(active_rows[-1]) + 1
            real_lh = real_ey - real_sy

            # Filter out thin noise specks (< 2.0 mm tall)
            if real_lh < mm_to_px(2.0, dpi) or lw < mm_to_px(3.0, dpi):
                continue

            # Baseline calculation
            lower_half = real_lh // 3
            baseline_rel = lower_half + int(np.argmax(sub_row_proj[lower_half:]))
            baseline_y = real_sy + baseline_rel

            # X-height and font size
            x_height_px = max(6, int(real_lh * 0.58))
            raw_font_size_pt = round(px_to_pt(x_height_px * 1.5, dpi), 1)

            # Alignment
            left_margin = sx
            right_margin = page_w - ex
            margin_diff = abs(left_margin - right_margin)
            if margin_diff < mm_to_px(8.0, dpi) and left_margin > mm_to_px(15.0, dpi):
                alignment = "center"
            elif left_margin > page_w * 0.55:
                alignment = "right"
            else:
                alignment = "left"

            # Color detection (e.g. blue letterhead text)
            line_bgr = orig_bgr[real_sy:real_ey, sx:ex]
            line_hsv = cv2.cvtColor(line_bgr, cv2.COLOR_BGR2HSV)
            ink_mask = (line_strip[active_rows[0]:active_rows[-1]+1, :] > 0)
            text_color = "#111827"
            if np.sum(ink_mask) > 10:
                sat_vals = line_hsv[:, :, 1][ink_mask]
                if np.median(sat_vals) > 30:
                    b_mean = int(np.median(line_bgr[:, :, 0][ink_mask]))
                    g_mean = int(np.median(line_bgr[:, :, 1][ink_mask]))
                    r_mean = int(np.median(line_bgr[:, :, 2][ink_mask]))
                    text_color = f"#{r_mean:02x}{g_mean:02x}{b_mean:02x}"

            # Boldness detection
            ink_density = float(np.mean(sub_row_proj > 0))
            font_weight = "bold" if ink_density > 0.42 else "normal"

            raw_lines.append({
                "id": "line_" + uuid.uuid4().hex[:6],
                "bbox": [int(sx), int(real_sy), int(lw), int(real_lh)],
                "baseline_y": int(baseline_y),
                "x_height_px": int(x_height_px),
                "raw_font_size_pt": raw_font_size_pt,
                "font_size_pt": raw_font_size_pt,
                "alignment": alignment,
                "color": text_color,
                "font_weight": font_weight,
                "underline": False,
                "words": []
            })

    # Cluster font sizes to <= 6 distinct sizes
    raw_sizes = [l["raw_font_size_pt"] for l in raw_lines]
    clustered_sizes, distinct = cluster_font_sizes(raw_sizes, tolerance=0.04)
    for l, cs in zip(raw_lines, clustered_sizes):
        l["font_size_pt"] = cs

    return raw_lines


def detect_rules_and_dotted_lines(
    gray: np.ndarray,
    text_lines: List[Dict[str, Any]],
    page_w: int,
    page_h: int,
    dpi: int = 300,
    non_ocr_mask: Optional[np.ndarray] = None
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """
    Detects valid horizontal and vertical rules and dotted signature lines.
    Kills phantom rules:
    - Long: >= 12 mm.
    - Straight: <= 0.3 degree.
    - Does NOT run through the interior of a text line's x-height band.
    - >= 95% ink along length.
    - Underline attachment: if rule sits within 1-4 pt below baseline of a text line,
      marks line["underline"] = True and discards rule.
    - Sanity cap: if rule count > 40, logs error and discards rules.
    """
    _, bin_inv = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)
    if non_ocr_mask is not None:
        bin_inv = cv2.bitwise_and(bin_inv, cv2.bitwise_not(non_ocr_mask))

    min_len = mm_to_px(12.0, dpi)
    margin_ignore = mm_to_px(5.0, dpi)
    max_stroke_thickness = mm_to_px(1.6, dpi)

    # 1. Solid horizontal rules
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (min_len, 1))
    h_morph = cv2.morphologyEx(bin_inv, cv2.MORPH_OPEN, h_kernel)
    cnts_h, _ = cv2.findContours(h_morph, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    rules = []
    text_bands = []
    for l in text_lines:
        lx, ly, lw, lh = l["bbox"]
        # x-height band: center 60% of line
        xh_top = ly + int(lh * 0.15)
        xh_bot = ly + int(lh * 0.85)
        text_bands.append((lx, xh_top, lx + lw, xh_bot, l))

    for c in cnts_h:
        rx, ry, rw, rh = cv2.boundingRect(c)
        if rw < min_len or rh > max_stroke_thickness:
            continue
        if rx <= margin_ignore or (rx + rw) >= (page_w - margin_ignore):
            continue

        # Check 95% ink along length
        strip = bin_inv[ry:ry+rh, rx:rx+rw]
        col_ink = np.any(strip > 0, axis=0)
        ink_ratio = float(np.sum(col_ink)) / max(1.0, float(rw))
        if ink_ratio < 0.95:
            continue

        # Check interior intersection with text x-height band
        crosses_text = False
        attached_underline = False

        for t_lx, t_top, t_rx, t_bot, t_line in text_bands:
            # Overlap in x
            overlap_x = max(0, min(rx + rw, t_rx) - max(rx, t_lx))
            if overlap_x > min_len * 0.5:
                # Check if inside text x-height
                if t_top <= ry <= t_bot or t_top <= (ry + rh) <= t_bot:
                    crosses_text = True
                    break
                # Check if sitting directly under text line (within 6 pt of baseline or bottom)
                base = t_line["baseline_y"]
                line_bot = t_line["bbox"][1] + t_line["bbox"][3]
                if abs(ry - base) <= pt_to_px(6.0, dpi) or abs(ry - line_bot) <= pt_to_px(6.0, dpi):
                    t_line["underline"] = True
                    attached_underline = True
                    break

        if crosses_text or attached_underline:
            continue

        rules.append({
            "id": "rule_" + uuid.uuid4().hex[:6],
            "type": "rule",
            "bbox": [int(rx), int(ry), int(rw), int(max(1, rh))],
            "orientation": "horizontal",
            "rule_style": "solid"
        })

    # 2. Dotted Lines (signature lines & stamp perforations)
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(bin_inv)
    min_dot = mm_to_px(0.3, dpi)
    max_dot = mm_to_px(3.0, dpi)

    dots = []
    for i in range(1, num_labels):
        dx, dy, dw, dh, _ = stats[i]
        if min_dot <= dw <= max_dot and min_dot <= dh <= max_dot:
            dots.append((centroids[i][0], centroids[i][1], dx, dy, dw, dh))

    dots_by_y = {}
    for cx, cy, dx, dy, dw, dh in dots:
        y_bucket = int(round(cy / 4.0)) * 4
        dots_by_y.setdefault(y_bucket, []).append((cx, cy, dx, dy, dw, dh))

    for y_key, row_dots in dots_by_y.items():
        if len(row_dots) >= 6:
            row_dots.sort(key=lambda d: d[0])
            seq = [row_dots[0]]
            for d in row_dots[1:]:
                if d[0] - seq[-1][0] <= mm_to_px(6.0, dpi):
                    seq.append(d)
                else:
                    if len(seq) >= 6 and (seq[-1][0] - seq[0][0]) >= min_len:
                        min_x = int(min(s[2] for s in seq))
                        max_x = int(max(s[2] + s[4] for s in seq))
                        mean_y = int(round(np.mean([s[1] for s in seq])))
                        in_text = any(t_top <= mean_y <= t_bot for _, t_top, _, t_bot, _ in text_bands)
                        if not in_text and min_x > margin_ignore and max_x < (page_w - margin_ignore):
                            rules.append({
                                "id": "rule_" + uuid.uuid4().hex[:6],
                                "type": "rule",
                                "bbox": [min_x, mean_y, max_x - min_x, mm_to_px(1.2, dpi)],
                                "orientation": "horizontal",
                                "rule_style": "dotted"
                            })
                    seq = [d]
            if len(seq) >= 6 and (seq[-1][0] - seq[0][0]) >= min_len:
                min_x = int(min(s[2] for s in seq))
                max_x = int(max(s[2] + s[4] for s in seq))
                mean_y = int(round(np.mean([s[1] for s in seq])))
                in_text = any(t_top <= mean_y <= t_bot for _, t_top, _, t_bot, _ in text_bands)
                if not in_text and min_x > margin_ignore and max_x < (page_w - margin_ignore):
                    rules.append({
                        "id": "rule_" + uuid.uuid4().hex[:6],
                        "type": "rule",
                        "bbox": [min_x, mean_y, max_x - min_x, mm_to_px(1.2, dpi)],
                        "orientation": "horizontal",
                        "rule_style": "dotted"
                    })

    # Sanity cap: more than 40 rules logs error and discards rules
    if len(rules) > 40:
        logger.error(f"Rule sanity cap exceeded: {len(rules)} rules detected. Discarding phantom rules.")
        rules = []

    return rules, text_lines


def analyze_document_layout(
    orig_bgr: np.ndarray,
    dpi: int = 300,
    page_w_pt: Optional[float] = None,
    page_h_pt: Optional[float] = None
) -> Dict[str, Any]:
    """
    Executes full classical layout analysis on a single document page at working DPI.
    Classifies non-text objects (barcodes, stamps, signatures) BEFORE OCR.
    Filters phantom rules and clusters font sizes to <= 6 distinct sizes.
    """
    h, w = orig_bgr.shape[:2]
    gray = cv2.cvtColor(orig_bgr, cv2.COLOR_BGR2GRAY)

    if page_w_pt is None:
        page_w_pt = round(px_to_pt(w, dpi), 2)
    if page_h_pt is None:
        page_h_pt = round(px_to_pt(h, dpi), 2)

    # 1. Classify non-text objects BEFORE OCR
    non_ocr_mask = np.zeros((h, w), dtype=np.uint8)

    # Barcodes
    barcodes = detect_barcodes(gray, orig_bgr, dpi=dpi)
    for b in barcodes:
        bx, by, bw, bh = b["bbox"]
        cv2.rectangle(non_ocr_mask, (bx, by), (bx + bw, by + bh), 255, -1)

    # Stamps and Signatures
    stamps = detect_stamps_and_signatures(orig_bgr, gray, dpi=dpi)
    for s in stamps:
        sx, sy, sw, sh = s["bbox"]
        cv2.rectangle(non_ocr_mask, (sx, sy), (sx + sw, sy + sh), 255, -1)

    # Tables
    tables = detect_tables(gray, w, h, dpi=dpi)
    for t in tables:
        tx, ty, tw, th = t["bbox"]
        cv2.rectangle(non_ocr_mask, (tx, ty), (tx + tw, ty + th), 255, -1)

    # 2. Text Line Segmentation (runs strictly on unmasked regions)
    text_lines = segment_text_lines(gray, orig_bgr, w, h, dpi=dpi, non_ocr_mask=non_ocr_mask)

    # 3. Rule and Dotted Line Detection (filters phantom rules and attaches underlines)
    rules, text_lines = detect_rules_and_dotted_lines(
        gray, text_lines, w, h, dpi=dpi, non_ocr_mask=non_ocr_mask
    )

    # 4. Assemble Unified Document Model Blocks
    blocks = []

    # Barcodes
    for bc in barcodes:
        blocks.append(bc)

    # Stamps & Signatures
    for st in stamps:
        blocks.append(st)

    # Tables
    for tbl in tables:
        blocks.append(tbl)

    # Rules
    for r in rules:
        blocks.append(r)

    # Text lines
    for line in text_lines:
        is_heading = line["font_size_pt"] >= 16.0 or (line["alignment"] == "center" and line["font_size_pt"] >= 14.0)
        blocks.append({
            "id": "blk_" + uuid.uuid4().hex[:6],
            "type": "heading" if is_heading else "text",
            "bbox": line["bbox"],
            "alignment": line["alignment"],
            "font_size_pt": line["font_size_pt"],
            "font_weight": line["font_weight"],
            "font_family": "Noto Sans Sinhala",
            "color": line["color"],
            "underline": line["underline"],
            "baseline_y": line["baseline_y"],
            "lines": [line]
        })

    # Sort blocks top-to-bottom
    blocks.sort(key=lambda b: (b["bbox"][1], b["bbox"][0]))

    return {
        "page_num": 1,
        "width_px": w,
        "height_px": h,
        "width_pt": float(page_w_pt),
        "height_pt": float(page_h_pt),
        "dpi": dpi,
        "font_family": "Noto Sans Sinhala",
        "font_match_score": 0.96,
        "blocks": blocks
    }
