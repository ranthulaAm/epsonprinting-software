"""
Low-quality scan and photocopy preprocessing pipeline.
Keeps original pixels untouched for high-resolution cropping.
Includes deskew, shadow/show-through removal, CLAHE contrast,
and Sauvola adaptive binarization tuned specifically for thin Sinhala diacritics.
"""

import cv2
import numpy as np
from PIL import Image


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


def remove_shadows_and_bleed(img_bgr: np.ndarray) -> np.ndarray:
    """
    Removes non-uniform illumination, shadows and backside show-through bleed.
    Uses large-kernel morphological dilation to estimate background plane.
    """
    rgb_planes = cv2.split(img_bgr)
    result_planes = []

    for plane in rgb_planes:
        # Estimate background illumination
        dilated = cv2.dilate(plane, np.ones((17, 17), np.uint8))
        bg_blur = cv2.medianBlur(dilated, 21)
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


def preprocess_document_page(image: Image.Image) -> dict:
    """
    Processes a full document page:
    - Retains original full-res pixels
    - Deskews
    - Removes shadows and photocopier gradient
    - Produces clean RGB, high-contrast grayscale, and Sauvola binary masks
    """
    orig_bgr = cv2.cvtColor(np.array(image.convert("RGB")), cv2.COLOR_RGB2BGR)

    # 1. Deskew
    deskewed_bgr, angle = deskew_image(orig_bgr)

    # 2. Shadow & show-through removal
    clean_bgr = remove_shadows_and_bleed(deskewed_bgr)

    # 3. Grayscale + CLAHE
    gray = cv2.cvtColor(clean_bgr, cv2.COLOR_BGR2GRAY)
    clahe_gray = enhance_contrast_clahe(gray)

    # 4. Sauvola adaptive threshold
    sauvola_bin = sauvola_threshold(clahe_gray, window_size=25, k=0.18)

    # 5. Denoise (bilateral to preserve thin strokes)
    denoised_gray = cv2.bilateralFilter(clahe_gray, d=7, sigmaColor=50, sigmaSpace=50)

    return {
        "orig_bgr": orig_bgr,
        "deskewed_bgr": deskewed_bgr,
        "clean_bgr": clean_bgr,
        "gray": clahe_gray,
        "denoised_gray": denoised_gray,
        "sauvola_bin": sauvola_bin,
        "angle": angle
    }


def generate_line_variants(line_bgr: np.ndarray) -> list[tuple[str, Image.Image]]:
    """
    Produces 3 distinct pre-processed variants of a text line image for multi-pass OCR.
    1. 'sauvola': High-preservation adaptive binary mask
    2. 'denoised_clahe': Grayscale with bilateral filter and CLAHE
    3. 'otsu_contrast': Normalized high-contrast background-subtracted grayscale
    """
    gray = cv2.cvtColor(line_bgr, cv2.COLOR_BGR2GRAY) if len(line_bgr.shape) == 3 else line_bgr

    # Variant 1: Sauvola Adaptive
    v1_bin = sauvola_threshold(gray, window_size=21, k=0.16)
    v1_img = Image.fromarray(v1_bin)

    # Variant 2: Denoised CLAHE
    v2_clahe = enhance_contrast_clahe(gray)
    v2_denoised = cv2.bilateralFilter(v2_clahe, 5, 40, 40)
    v2_img = Image.fromarray(v2_denoised)

    # Variant 3: Otsu
    _, v3_otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    v3_img = Image.fromarray(v3_otsu)

    return [
        ("sauvola", v1_img),
        ("clahe", v2_img),
        ("otsu", v3_img)
    ]
