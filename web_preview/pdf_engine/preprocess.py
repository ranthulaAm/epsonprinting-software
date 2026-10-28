"""
Low-quality scan and photocopy preprocessing pipeline.
Keeps original pixels untouched for high-resolution cropping.
Includes deskew, shadow/show-through removal, CLAHE contrast,
and Sauvola adaptive binarization tuned specifically for thin Sinhala diacritics.
"""

import cv2
import numpy as np
from PIL import Image


def mm_to_px(mm: float, dpi: float) -> int:
    """Converts millimeters to pixels at the given DPI."""
    return max(1, int(round((mm / 25.4) * dpi)))


def pt_to_px(pt: float, dpi: float) -> int:
    """Converts typographic points to pixels at the given DPI."""
    return max(1, int(round((pt / 72.0) * dpi)))


def px_to_pt(px: float, dpi: float) -> float:
    """Converts pixels to typographic points at the given DPI."""
    return (float(px) * 72.0) / float(dpi)


def remove_page_edge_artifacts(img_bgr: np.ndarray, dpi: int = 300) -> np.ndarray:
    """
    Detects and clears scanner margin streaks, vertical/horizontal border shadows,
    and mechanical scanner artifacts in the extreme outer margin (within ~5mm of page edges).
    Prevents false border lines and edge noise from propagating into layout analysis.
    """
    h, w = img_bgr.shape[:2]
    margin_px = mm_to_px(5.0, dpi)
    clean = img_bgr.copy()
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # Left margin: clear scanner edge streak if dark streak runs vertically
    left_strip = gray[:, :margin_px]
    left_dark = np.mean(left_strip < 160, axis=0)
    for col_idx in range(len(left_dark)):
        if left_dark[col_idx] > 0.35:
            clean[:, max(0, col_idx - 2):min(w, col_idx + 3)] = (255, 255, 255)

    # Right margin
    right_strip = gray[:, w - margin_px:]
    right_dark = np.mean(right_strip < 160, axis=0)
    for col_idx in range(len(right_dark)):
        if right_dark[col_idx] > 0.35:
            pos = w - margin_px + col_idx
            clean[:, max(0, pos - 2):min(w, pos + 3)] = (255, 255, 255)

    # Top margin
    top_strip = gray[:margin_px, :]
    top_dark = np.mean(top_strip < 160, axis=1)
    for row_idx in range(len(top_dark)):
        if top_dark[row_idx] > 0.35:
            clean[max(0, row_idx - 2):min(h, row_idx + 3), :] = (255, 255, 255)

    # Bottom margin
    bot_strip = gray[h - margin_px:, :]
    bot_dark = np.mean(bot_strip < 160, axis=1)
    for row_idx in range(len(bot_dark)):
        if bot_dark[row_idx] > 0.35:
            pos = h - margin_px + row_idx
            clean[max(0, pos - 2):min(h, pos + 3), :] = (255, 255, 255)

    return clean


def deskew_image(img_bgr: np.ndarray) -> tuple[np.ndarray, float]:
    """
    Detects skew angle and rotates image to upright orientation.
    Returns (deskewed_image, angle_degrees).
    """
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    # Detect edges
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=100, minLineLength=100, maxLineGap=10)

    angles = []
    if lines is not None:
        for l in lines:
            line_coords = l[0] if hasattr(l, "__len__") and len(l) == 1 and hasattr(l[0], "__len__") else l
            if len(line_coords) < 4:
                continue
            x1, y1, x2, y2 = int(line_coords[0]), int(line_coords[1]), int(line_coords[2]), int(line_coords[3])
            dx = x2 - x1
            dy = y2 - y1
            if dx == 0:
                continue
            angle = np.degrees(np.arctan2(dy, dx))
            # Only consider near-horizontal lines (-30 to +30 degrees)
            if -30.0 < angle < 30.0:
                angles.append(angle)

    if not angles:
        # Fallback to connected component minAreaRect
        coords = np.column_stack(np.where(edges > 0))
        if len(coords) > 50:
            angle = cv2.minAreaRect(coords)[-1]
            if angle < -45:
                angle = -(90 + angle)
            else:
                angle = -angle
            if -30.0 < angle < 30.0:
                angles.append(angle)

    median_angle = float(np.median(angles)) if angles else 0.0

    if abs(median_angle) < 0.2:
        return img_bgr, 0.0

    # Rotate around center
    h, w = img_bgr.shape[:2]
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    rotated = cv2.warpAffine(
        img_bgr, M, (w, h),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255)
    )
    return rotated, median_angle


def remove_shadows_and_bleed(img_bgr: np.ndarray, dpi: int = 300) -> np.ndarray:
    """
    Removes non-uniform illumination, shadows and backside show-through bleed.
    Uses physical-unit morphological dilation (approx 2mm) to estimate background plane.
    """
    rgb_planes = cv2.split(img_bgr)
    result_planes = []

    k_size = mm_to_px(2.0, dpi)
    if k_size % 2 == 0:
        k_size += 1
    blur_k = mm_to_px(3.0, dpi)
    if blur_k % 2 == 0:
        blur_k += 1

    kernel = np.ones((k_size, k_size), np.uint8)

    for plane in rgb_planes:
        # Estimate background illumination
        dilated = cv2.dilate(plane, kernel)
        bg_blur = cv2.medianBlur(dilated, blur_k)
        # Normalize: (foreground / background) * 255
        diff = 255 - cv2.absdiff(plane, bg_blur)
        norm = cv2.normalize(diff, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX, dtype=cv2.CV_8U)
        result_planes.append(norm)

    return cv2.merge(result_planes)


def enhance_contrast_clahe(gray: np.ndarray) -> np.ndarray:
    """Applies CLAHE on luminance channel without breaking thin vowel signs."""
    clahe = cv2.createCLAHE(clipLimit=2.2, tileGridSize=(8, 8))
    return clahe.apply(gray)


def sauvola_threshold(gray: np.ndarray, window_size: int = 25, k: float = 0.18, r: float = 128.0) -> np.ndarray:
    """
    Sauvola adaptive thresholding.
    Preserves fine Sinhala diacritics (pili, anusvaraya, virama) without eroding them.
    T(x,y) = mean * (1 + k * (std / R - 1))
    """
    if window_size % 2 == 0:
        window_size += 1

    gray_f = gray.astype(np.float32)
    mean = cv2.blur(gray_f, (window_size, window_size))
    mean_sq = cv2.blur(gray_f * gray_f, (window_size, window_size))
    var = np.maximum(0.0, mean_sq - mean * mean)
    std = np.sqrt(var)

    threshold = mean * (1.0 + k * ((std / r) - 1.0))
    binary = np.where(gray_f >= threshold, 255, 0).astype(np.uint8)
    return binary


def preprocess_document_page(image: Image.Image, dpi: int = 300) -> dict:
    """
    Processes a full document page at working DPI:
    - Retains original full-res pixels
    - Cleans scanner border artifacts
    - Deskews
    - Removes shadows and photocopier gradient
    - Produces clean RGB, high-contrast grayscale, and Sauvola binary masks
    """
    orig_bgr = cv2.cvtColor(np.array(image.convert("RGB")), cv2.COLOR_RGB2BGR)

    # 1. Scanner border artifact removal (clears stray vertical/horizontal margin streaks)
    cleaned_margin_bgr = remove_page_edge_artifacts(orig_bgr, dpi=dpi)

    # 2. Deskew
    deskewed_bgr, angle = deskew_image(cleaned_margin_bgr)

    # 3. Shadow & show-through removal
    clean_bgr = remove_shadows_and_bleed(deskewed_bgr, dpi=dpi)

    # 4. Grayscale + CLAHE
    gray = cv2.cvtColor(clean_bgr, cv2.COLOR_BGR2GRAY)
    clahe_gray = enhance_contrast_clahe(gray)

    # 5. Sauvola adaptive threshold (window size scaled by DPI, ~3.5mm)
    s_win = mm_to_px(3.5, dpi)
    if s_win % 2 == 0:
        s_win += 1
    sauvola_bin = sauvola_threshold(clahe_gray, window_size=s_win, k=0.18)

    # 6. Denoise (bilateral to preserve thin strokes)
    denoised_gray = cv2.bilateralFilter(clahe_gray, d=max(3, mm_to_px(0.6, dpi)), sigmaColor=50, sigmaSpace=50)

    return {
        "orig_bgr": orig_bgr,
        "deskewed_bgr": deskewed_bgr,
        "clean_bgr": clean_bgr,
        "gray": clahe_gray,
        "denoised_gray": denoised_gray,
        "sauvola_bin": sauvola_bin,
        "angle": angle
    }


def generate_line_variants(line_bgr: np.ndarray, dpi: int = 300) -> list[tuple[str, Image.Image]]:
    """
    Produces 3 distinct pre-processed variants of a text line image for multi-pass OCR.
    1. 'sauvola': High-preservation adaptive binary mask
    2. 'denoised_clahe': Grayscale with bilateral filter and CLAHE
    3. 'otsu_contrast': Normalized high-contrast background-subtracted grayscale
    """
    gray = cv2.cvtColor(line_bgr, cv2.COLOR_BGR2GRAY) if len(line_bgr.shape) == 3 else line_bgr
    s_win = mm_to_px(3.0, dpi)
    if s_win % 2 == 0:
        s_win += 1

    # Variant 1: Sauvola Adaptive
    v1_bin = sauvola_threshold(gray, window_size=s_win, k=0.16)
    v1_img = Image.fromarray(v1_bin)

    # Variant 2: Denoised CLAHE
    v2_clahe = enhance_contrast_clahe(gray)
    v2_denoised = cv2.bilateralFilter(v2_clahe, max(3, mm_to_px(0.5, dpi)), 40, 40)
    v2_img = Image.fromarray(v2_denoised)

    # Variant 3: Otsu
    _, v3_otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    v3_img = Image.fromarray(v3_otsu)

    return [
        ("sauvola", v1_img),
        ("clahe", v2_img),
        ("otsu", v3_img)
    ]
