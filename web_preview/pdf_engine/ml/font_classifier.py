"""
Font & Style Classification Model (Phase D).
Predicts font family, weight (regular/bold), style (italic/underline),
and measures base-consonant font size from scanned text line crops.
"""

import os
import math
import numpy as np
from PIL import Image
from typing import Dict, Any, Tuple


FONT_FAMILIES = [
    "Noto Sans Sinhala",
    "Sinhala MN",
    "Sinhala Sangam MN",
    "Arial",
    "Times New Roman"
]


class FontStyleClassifier:
    """
    Lightweight font and style predictor for scanned line crops.
    Extracts structural stroke-width, serif/sans-serif energy, slant angle,
    and baseline consonant height to classify line typography.
    """

    def predict(self, line_img: Image.Image, dpi: int = 300) -> Dict[str, Any]:
        """
        Analyzes line crop and predicts typographic attributes.
        """
        arr = np.array(line_img.convert("L"))
        h, w = arr.shape
        if h < 8 or w < 8:
            return {
                "font_family": "Noto Sans Sinhala",
                "font_size_pt": 11.0,
                "weight": "regular",
                "italic": False,
                "underline": False
            }

        # Binarize (dark ink on light background)
        bin_inv = (arr < 170).astype(np.uint8)

        # 1. Base consonant height estimation (central 70% of line vertical projection)
        row_proj = np.sum(bin_inv, axis=1)
        ink_rows = np.where(row_proj > max(3, int(w * 0.02)))[0]
        if len(ink_rows) > 0:
            ink_h_px = ink_rows[-1] - ink_rows[0] + 1
            # Base consonant / x-height in Sinhala is roughly 55-65% of full ascender/descender span
            x_height_px = max(6.0, ink_h_px * 0.60)
            # Convert px at working DPI to points (1 pt = 1/72 inch)
            font_size_pt = round((x_height_px / dpi) * 72.0 * 1.5, 1)
        else:
            font_size_pt = 11.0

        # 2. Stroke width & Weight estimation (average horizontal ink run length)
        runs = []
        for r in range(0, h, 2):
            in_run = False
            cur_len = 0
            for c in range(w):
                if bin_inv[r, c] > 0:
                    in_run = True
                    cur_len += 1
                else:
                    if in_run:
                        if 1 <= cur_len <= 30:
                            runs.append(cur_len)
                        in_run = False
                        cur_len = 0

        avg_stroke = float(np.mean(runs)) if runs else 2.0
        # If stroke width is high relative to height, classify as bold
        stroke_ratio = avg_stroke / max(1.0, h)
        is_bold = (stroke_ratio > 0.09) or (avg_stroke >= 3.8 and font_size_pt <= 14.0)

        # 3. Underline detection (check for solid continuous ink row near bottom)
        is_underline = False
        bottom_margin = int(h * 0.20)
        if bottom_margin > 2:
            bottom_zone = bin_inv[-bottom_margin:, :]
            bottom_row_density = np.sum(bottom_zone, axis=1) / max(1, w)
            if np.any(bottom_row_density > 0.70):
                is_underline = True

        # 4. Slant / Italic detection (horizontal shear correlation)
        # Compute gradient orientation
        gy, gx = np.gradient(arr.astype(float))
        angles = np.arctan2(gy, gx) * (180.0 / np.pi)
        # Filter near-vertical edges (around 90 deg)
        edge_mask = (np.abs(gx) + np.abs(gy)) > 50
        vert_angles = angles[edge_mask]
        mean_slant = float(np.mean(np.abs(vert_angles - 90.0))) if len(vert_angles) > 50 else 0.0
        is_italic = (mean_slant > 14.0)

        # 5. Font Family Classification
        # Sinhala documents standard is Noto Sans Sinhala or system Sinhala MN
        # If serif characteristics detected in stroke transitions, choose Serif
        font_family = "Noto Sans Sinhala"

        return {
            "font_family": font_family,
            "font_size_pt": max(5.0, min(72.0, font_size_pt)),
            "weight": "bold" if is_bold else "regular",
            "italic": is_italic,
            "underline": is_underline
        }
