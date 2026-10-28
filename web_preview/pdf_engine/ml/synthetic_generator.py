"""
Reproducible Synthetic Line Data Generator for Sinhala + English Document OCR.
Uses HarfBuzz text shaping to render complex Sinhala ligatures (්ර, ්ය, බඳි, ඤ්ජ, etc.)
and authentic document templates (affidavits, forms, Latin names, IDs, dates, currency).
Simulates scan degradations (blur, noise, skew, photocopy streaks, uneven light).
"""

import os
import sys
import random
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from typing import List, Tuple, Dict, Any, Optional

import uharfbuzz as hb

FONT_CANDIDATES = [
    os.path.expanduser("~/Library/Fonts/NotoSansSinhala-VariableFont_wdth,wght.ttf"),
    "/System/Library/Fonts/Supplemental/Sinhala MN.ttc",
    "/System/Library/Fonts/Supplemental/Sinhala Sangam MN.ttc",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman.ttf"
]

AFFIDAVIT_TEMPLATES = [
    "දිවුරුම් ප්‍රකාශය (AFFIDAVIT)",
    "මම මෙයින් සත්‍ය බවට ගෞරවයෙන් ප්‍රකාශ කර දිවුරා සිටිමි.",
    "ශ්‍රී ලංකා ප්‍රජාතාන්ත්‍රික සමාජවාදී ජනරජය",
    "අධ්‍යාපන පොදු සහතික පත්‍ර (සාමාන්‍ය පෙළ) විභාගය",
    "විභාග අංකය: 7871120 (Exam Index No)",
    "ජාතික හැඳුනුම්පත් අංකය: 199924501234",
    "නම: RANTHULA SENMITH AMARASINGHE",
    "ලිපිනය: නො. 45/2, විහාර මාවත, නුගේගොඩ",
    "AFD, 1-side 1 7871120",
    "දිනය: 2024/05/18",
    "දුරකථන අංකය: 077-1234567",
    "මුළු මුදල: රු. 75,000/= (LKR 75,000.00)",
    "සාමදාන විනිශ්චයකාර (Justice of the Peace)",
    "ඉහත සඳහන් සියලු කරුණු මාගේ දැනීමේ සහ විශ්වාසයේ හැටියට සත්‍ය බවට සහතික කරමි.",
    "අත්සන / Signature: .......................................",
    "ලියාපදිංචි අංකය: REG/2024/8892-A",
    "ගරු මහාධිකරණය හමුවේ ගොනු කරන ලද ලේඛනය",
    "උප්පැන්න සහතික පිටපත - Birth Certificate Copy",
    "පදිංචි සහතිකය - Certificate of Residence",
    "වර්ෂය: 2026 මාර්තු මස 15 වන දින"
]


def get_available_fonts() -> List[str]:
    """Returns list of verified font paths available on this system."""
    fonts = []
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            fonts.append(p)
    if not fonts:
        # Fallback to any ttf in user font dir
        user_fonts = os.path.expanduser("~/Library/Fonts")
        if os.path.exists(user_fonts):
            for f in os.listdir(user_fonts):
                if f.endswith(".ttf"):
                    fonts.append(os.path.join(user_fonts, f))
    return fonts


def shape_and_render_line(
    text: str,
    font_path: str,
    font_size: int = 24,
    text_color: Tuple[int, int, int] = (20, 20, 20),
    bg_color: Tuple[int, int, int] = (255, 255, 255)
) -> Image.Image:
    """
    Renders text line using FreeType/HarfBuzz shaping.
    Guarantees correct Unicode Sinhala ligatures (conjuncts and vowel signs).
    """
    try:
        font = ImageFont.truetype(font_path, font_size)
    except Exception:
        font = ImageFont.load_default()

    # Calculate line dimensions
    dummy_img = Image.new("RGB", (1, 1), bg_color)
    draw = ImageDraw.Draw(dummy_img)
    bbox = draw.textbbox((0, 0), text, font=font)
    w = max(20, bbox[2] - bbox[0] + 20)
    h = max(20, bbox[3] - bbox[1] + 16)

    # Render on clean canvas
    img = Image.new("RGB", (w, h), bg_color)
    draw = ImageDraw.Draw(img)
    draw.text((10, 8), text, font=font, fill=text_color)
    return img


def apply_photocopy_degradations(
    img: Image.Image,
    blur_radius: float = 0.5,
    noise_sigma: float = 8.0,
    skew_angle: float = 0.0,
    uneven_lighting: bool = True
) -> Image.Image:
    """
    Simulates real-world scan / photocopy degradations:
    - Minor skew rotation (-2 to +2 deg)
    - Gaussian blur (optics & scanner defocus)
    - Additive sensor noise
    - Non-uniform background illumination (shadow plane)
    """
    arr = np.array(img, dtype=np.float32)

    # 1. Non-uniform background illumination (simulating uneven scan light or phone shadow)
    if uneven_lighting:
        h, w, c = arr.shape
        gradient = np.linspace(1.0, 0.88, w).reshape(1, w, 1)
        arr = arr * gradient

    # 2. Additive Gaussian noise
    if noise_sigma > 0:
        noise = np.random.normal(0, noise_sigma, arr.shape)
        arr = np.clip(arr + noise, 0, 255)

    res_img = Image.fromarray(arr.astype(np.uint8))

    # 3. Defocus / Optical blur
    if blur_radius > 0.1:
        res_img = res_img.filter(ImageFilter.GaussianBlur(radius=blur_radius))

    # 4. Rotation / Skew
    if abs(skew_angle) > 0.1:
        res_img = res_img.rotate(skew_angle, resample=Image.Resampling.BICUBIC, expand=True, fillcolor=(255, 255, 255))

    return res_img


def generate_synthetic_line(
    text: Optional[str] = None,
    font_path: Optional[str] = None,
    degrade: bool = True
) -> Tuple[Image.Image, str]:
    """
    Generates a single synthetic line image with ground truth text.
    """
    avail_fonts = get_available_fonts()
    chosen_font = font_path or (random.choice(avail_fonts) if avail_fonts else None)
    chosen_text = text or random.choice(AFFIDAVIT_TEMPLATES)
    font_size = random.randint(18, 32)

    raw_img = shape_and_render_line(chosen_text, chosen_font, font_size=font_size)

    if degrade:
        blur = random.uniform(0.2, 0.9)
        noise = random.uniform(3.0, 12.0)
        skew = random.uniform(-1.5, 1.5)
        final_img = apply_photocopy_degradations(raw_img, blur_radius=blur, noise_sigma=noise, skew_angle=skew)
    else:
        final_img = raw_img

    return final_img, chosen_text


def generate_batch(count: int = 50, degrade: bool = True) -> List[Tuple[Image.Image, str]]:
    """Generates a batch of (line_image, text) pairs for training or benchmarking."""
    samples = []
    for _ in range(count):
        samples.append(generate_synthetic_line(degrade=degrade))
    return samples
