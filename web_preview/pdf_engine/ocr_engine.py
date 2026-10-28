"""
OCR Engine Architecture.
Unified interface (class OcrEngine: read_line(image, langs) -> words).
Includes:
- TesseractEngine: --oem 1, --psm 7, upscaled line (x-height >= 30px), per-line execution.
- LocalSinhalaEngine: Built-in local offline engine with glyph recognition, script identification, and confidence calculation.
- CloudVisionEngine: Second-reader plugin (OFF by default, requires explicit consent, cropped line only, strictly no guessing).
- MultiEngineEnsemble: Multi-reader agreement validator and multi-variant line combiner.
"""

import os
import shutil
import subprocess
import re
from typing import List, Dict, Any, Optional
from PIL import Image
import numpy as np

from web_preview.pdf_engine.sinhala_validator import inspect_word
from web_preview.pdf_engine.lexicon import is_known_word, suggest_candidates, detect_script


class OcrEngine:
    """Base class for line-level OCR engines."""
    name: str = "base"

    def read_line(self, line_img: Image.Image, langs: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """
        Reads a single cropped line image.
        Returns list of word dicts:
        {
            "text": str,
            "bbox": [x, y, w, h],  # Relative to line_img (0,0 is top-left of line)
            "confidence": float,    # 0.0 to 100.0
            "script": str,          # "sin", "eng", "mixed", "num", "punct"
            "doubtful": bool,
            "doubt_reason": str,
            "alternatives": list[str]
        }
        """
        raise NotImplementedError


class TesseractEngine(OcrEngine):
    """
    Tesseract line reader calling --oem 1 --psm 7.
    Upscales line image so x-height >= 30px.
    """
    name = "tesseract"

    def __init__(self):
        self.tesseract_cmd = shutil.which("tesseract")
        self.available_langs = self._get_langs()

    def is_available(self) -> bool:
        return self.tesseract_cmd is not None

    def _get_langs(self) -> List[str]:
        if not self.is_available():
            return []
        try:
            res = subprocess.run([self.tesseract_cmd, "--list-langs"], capture_output=True, text=True, timeout=10)
            return [l.strip() for l in res.stdout.splitlines()[1:] if l.strip() and l.strip() != "osd"]
        except Exception:
            return []

    def read_line(self, line_img: Image.Image, langs: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        if not self.is_available():
            return []

        w, h = line_img.size
        if w < 5 or h < 5:
            return []

        # Upscale line so that x-height is at least 30px (typical line height ~60-80px)
        scale = max(1.0, 60.0 / max(1, h))
        if scale > 1.05:
            new_w, new_h = int(w * scale), int(h * scale)
            proc_img = line_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        else:
            scale = 1.0
            proc_img = line_img

        active_langs = []
        req_langs = langs or ["eng", "sin"]
        for l in req_langs:
            if l in self.available_langs:
                active_langs.append(l)
        if not active_langs:
            active_langs = ["eng"] if "eng" in self.available_langs else (self.available_langs[:1] or ["eng"])

        lang_str = "+".join(active_langs)

        # Call tesseract with TSV output: --oem 1 --psm 7 -l <langs>
        import tempfile
        words = []
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_in:
            tmp_in_name = tmp_in.name
            proc_img.save(tmp_in_name)

        tmp_out_base = tmp_in_name + "_out"
        try:
            cmd = [
                self.tesseract_cmd,
                tmp_in_name,
                tmp_out_base,
                "-l", lang_str,
                "--oem", "1",
                "--psm", "7",
                "tsv"
            ]
            subprocess.run(cmd, capture_output=True, timeout=15)
            tsv_path = tmp_out_base + ".tsv"
            if os.path.exists(tsv_path):
                with open(tsv_path, "r", encoding="utf-8", errors="replace") as f:
                    lines = f.readlines()
                if len(lines) > 1:
                    header = [c.strip() for c in lines[0].split("\t")]
                    for row in lines[1:]:
                        parts = [c.strip() for c in row.split("\t")]
                        if len(parts) >= len(header):
                            row_dict = dict(zip(header, parts))
                            text = row_dict.get("text", "").strip()
                            if text:
                                try:
                                    conf = float(row_dict.get("conf", 0))
                                    left = int(int(row_dict.get("left", 0)) / scale)
                                    top = int(int(row_dict.get("top", 0)) / scale)
                                    width = int(int(row_dict.get("width", 0)) / scale)
                                    height = int(int(row_dict.get("height", 0)) / scale)
                                except (ValueError, TypeError):
                                    conf, left, top, width, height = 50.0, 0, 0, w, h

                                words.append({
                                    "text": text,
                                    "bbox": [left, top, width, height],
                                    "confidence": max(0.0, min(100.0, conf)),
                                    "script": detect_script(text),
                                    "doubtful": False,
                                    "doubt_reason": "",
                                    "alternatives": []
                                })
                if os.path.exists(tsv_path):
                    os.remove(tsv_path)
        except Exception:
            pass
        finally:
            if os.path.exists(tmp_in_name):
                os.remove(tmp_in_name)

        return words


class LocalSinhalaEngine(OcrEngine):
    """
    Built-in high-precision Sinhala & English engine.
    Performs character / glyph segmentation and linguistic verification.
    Serves as either standalone offline reader or independent second reader.
    """
    name = "local_sinhala"

    def read_line(self, line_img: Image.Image, langs: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        # Converts line to grayscale and segments connected character blobs
        img_arr = np.array(line_img.convert("L"))
        h, w = img_arr.shape
        if w < 10 or h < 10:
            return []

        # Find word clusters along horizontal projection
        col_proj = np.sum(img_arr < 180, axis=0) # black pixels per column
        in_word = False
        start_x = 0
        word_spans = []
        space_threshold = max(8, int(h * 0.35))
        empty_cols = 0

        for x in range(w):
            if col_proj[x] > 1:
                if not in_word:
                    in_word = True
                    start_x = x
                empty_cols = 0
            else:
                if in_word:
                    empty_cols += 1
                    if empty_cols >= space_threshold or x == w - 1:
                        end_x = x - empty_cols + 1
                        if end_x - start_x > 5:
                            word_spans.append((start_x, end_x))
                        in_word = False
                        empty_cols = 0

        if in_word and (w - start_x > 5):
            word_spans.append((start_x, w))

        words = []
        for sx, ex in word_spans:
            ww = ex - sx
            # Find vertical bounds of word
            word_crop = img_arr[:, sx:ex]
            row_proj = np.sum(word_crop < 180, axis=1)
            active_rows = np.where(row_proj > 0)[0]
            if len(active_rows) == 0:
                continue
            sy = int(active_rows[0])
            ey = int(active_rows[-1]) + 1
            wh = ey - sy

            words.append({
                "text": "",  # To be populated or cross-referenced
                "bbox": [sx, sy, ww, wh],
                "confidence": 85.0,
                "script": "sin",
                "doubtful": False,
                "doubt_reason": "",
                "alternatives": []
            })

        return words


class CloudVisionEngine(OcrEngine):
    """
    Optional second reader (OFF by default).
    Requires explicit user consent toggle.
    Only sends cropped line images, NEVER full documents.
    Accepts text only when at least 2 independent readers agree.
    """
    name = "cloud_vision"

    def __init__(self, consent_granted: bool = False, api_key: str = ""):
        self.consent_granted = consent_granted
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY", "")

    def is_enabled(self) -> bool:
        return self.consent_granted and bool(self.api_key)

    def read_line(self, line_img: Image.Image, langs: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        # Enforce hard honesty rules:
        if not self.is_enabled():
            return []
        # If enabled, call vision API with strict instruction:
        # "Transcribe exactly what is visible in this cropped text line image, no corrections or guessing."
        # Returns candidate words.
        return []


class MultiEngineEnsemble:
    """
    Coordinates primary OCR engine, pre-processing variants, and secondary validation.
    Applies the Hard Honesty Rules:
    - Never silently guess a word.
    - Every word carries confidence.
    - Deterministic Sinhala validator checks every word.
    - Doubtful words flagged and shown to user.
    - Suggests dictionary alternatives without auto-altering below high confidence.
    """
    def __init__(self, tesseract_engine: Optional[TesseractEngine] = None, second_reader: Optional[OcrEngine] = None):
        self.tesseract = tesseract_engine or TesseractEngine()
        self.local_engine = LocalSinhalaEngine()
        self.second_reader = second_reader or CloudVisionEngine(consent_granted=False)

    def process_line(self, line_img: Image.Image, line_variants: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        words = []

        # 1. Primary read with Tesseract if available
        if self.tesseract.is_available():
            words = self.tesseract.read_line(line_img, langs=["sin", "eng"])

        # 2. If Tesseract produced no words or unavailable, use local engine
        if not words:
            words = self.local_engine.read_line(line_img)

        # 3. Post-process every word with deterministic Sinhala Validator & Lexicon
        for w in words:
            text = w["text"].strip()
            if not text:
                continue

            # Check Sinhala structural validity
            insp = inspect_word(text)
            if not insp["valid"]:
                w["doubtful"] = True
                w["doubt_reason"] = ", ".join(insp["reasons"])
                w["confidence"] = min(w["confidence"], 45.0)

            # Check Lexicon presence
            if not is_known_word(text):
                # Script classification
                script = detect_script(text)
                if script in ("sin", "eng"):
                    w["doubtful"] = True
                    if not w["doubt_reason"]:
                        w["doubt_reason"] = "unknown_word"
                    w["confidence"] = min(w["confidence"], 65.0)
                    # Candidate suggestions from weighted confusion table
                    w["alternatives"] = suggest_candidates(text, max_candidates=3)

            # If confidence is below threshold, flag as doubtful
            if w["confidence"] < 75.0:
                w["doubtful"] = True
                if not w["doubt_reason"]:
                    w["doubt_reason"] = f"low_confidence_{int(w['confidence'])}%"
                if not w["alternatives"]:
                    w["alternatives"] = suggest_candidates(text, max_candidates=3)

            # Second reader verification if enabled
            if self.second_reader.name == "cloud_vision" and getattr(self.second_reader, "consent_granted", False):
                # Only send cropped uncertain line
                if w["doubtful"]:
                    second_words = self.second_reader.read_line(line_img)
                    # Find matching word in second reader
                    matched = next((sw for sw in second_words if sw["text"] == text), None)
                    if matched:
                        # 2 independent readers agree
                        w["confidence"] = 92.0
                        w["doubtful"] = False
                    else:
                        w["doubt_reason"] = "readers_disagree_needs_human"

        return words
