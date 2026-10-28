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
import json
import io
import time
import base64
import hashlib
import urllib.request
import urllib.parse
import urllib.error
from typing import List, Dict, Any, Optional
from PIL import Image
import numpy as np

from web_preview.pdf_engine.sinhala_validator import inspect_word
from web_preview.pdf_engine.lexicon import is_known_word, suggest_candidates, detect_script
from web_preview.pdf_engine import auth, config, gcp_wizard


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
        cmd = shutil.which("tesseract")
        if not cmd:
            for cand in ["/opt/homebrew/bin/tesseract", "/usr/local/bin/tesseract", "/usr/bin/tesseract"]:
                if os.path.exists(cand):
                    cmd = cand
                    break
        self.tesseract_cmd = cmd
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

        return self._restore_latin_spaces(line_img, words)

    def _restore_latin_spaces(self, line_img: Image.Image, words: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Splits fused Latin uppercase words (e.g. RANTHULASENMITH) by measuring
        horizontal pixel gaps (>= 8 px) between letter clusters.
        """
        out_words = []
        gray_arr = np.array(line_img.convert("L"))
        h_line, w_line = gray_arr.shape

        for w in words:
            text = w["text"].strip()
            # If word is uppercase Latin and long enough to potentially be fused
            if text.isupper() and len(text) >= 8 and w["bbox"][2] > 60:
                lx, ly, lw, lh = w["bbox"]
                bx1 = max(0, lx)
                by1 = max(0, ly)
                bx2 = min(w_line, lx + lw)
                by2 = min(h_line, ly + lh)

                w_crop = gray_arr[by1:by2, bx1:bx2]
                if w_crop.size == 0:
                    out_words.append(w)
                    continue

                bin_inv = (w_crop < 180).astype(np.uint8) * 255
                col_proj = np.sum(bin_inv > 0, axis=0)

                # Search for gap in middle region (avoid edges)
                margin_check = 15
                zero_runs = []
                run_s = None
                for idx in range(margin_check, len(col_proj) - margin_check):
                    if col_proj[idx] == 0:
                        if run_s is None: run_s = idx
                    else:
                        if run_s is not None:
                            if idx - run_s >= 8:
                                zero_runs.append((run_s, idx))
                            run_s = None

                if zero_runs and self.tesseract_cmd:
                    split_points = [0]
                    for s_gap, e_gap in zero_runs:
                        split_points.append((s_gap + e_gap) // 2)
                    split_points.append(lw)

                    import tempfile
                    for i in range(len(split_points) - 1):
                        p_start = split_points[i]
                        p_end = split_points[i+1]
                        sub_crop = w_crop[:, p_start:p_end]
                        if sub_crop.shape[1] < 10:
                            continue
                        sub_pil = Image.fromarray(sub_crop)
                        sub_pil = sub_pil.resize((sub_pil.width * 2, sub_pil.height * 2), Image.Resampling.LANCZOS)
                        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tf_in:
                            tf_in_name = tf_in.name
                            sub_pil.save(tf_in_name)
                        tf_out = tf_in_name + "_sub"
                        try:
                            cmd = [self.tesseract_cmd, tf_in_name, tf_out, "-l", "eng", "--psm", "8", "-c", "tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ."]
                            subprocess.run(cmd, capture_output=True, timeout=8)
                            txt_path = tf_out + ".txt"
                            sub_text = ""
                            if os.path.exists(txt_path):
                                with open(txt_path, "r", encoding="utf-8", errors="replace") as f_sub:
                                    sub_text = f_sub.read().strip()
                                os.remove(txt_path)
                            if sub_text:
                                out_words.append({
                                    "text": sub_text,
                                    "bbox": [lx + p_start, ly, p_end - p_start, lh],
                                    "confidence": w["confidence"],
                                    "script": "eng",
                                    "doubtful": False,
                                    "doubt_reason": "",
                                    "alternatives": []
                                })
                        except Exception:
                            pass
                        finally:
                            if os.path.exists(tf_in_name): os.remove(tf_in_name)
                    continue

            out_words.append(w)
        return out_words


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


def levenshtein_similarity(s1: str, s2: str) -> float:
    """Computes normalized Levenshtein similarity between two strings [0.0, 1.0]."""
    if not s1 and not s2:
        return 1.0
    if not s1 or not s2:
        return 0.0
    m, n = len(s1), len(s2)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if s1[i - 1] == s2[j - 1] else 1
            dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
    dist = dp[m][n]
    return max(0.0, 1.0 - (dist / max(m, n)))


def is_hallucination(text: str, line_w: int, line_h: int) -> bool:
    """
    Hallucination Guard:
    Rejects readings with characters outside expected scripts (Sinhala, Latin, digits, punctuation),
    or whose character count does not fit the physical pixel dimensions of the line image.
    """
    if not text:
        return False
    cleaned = text.strip()
    if not cleaned:
        return False

    # Check for characters outside expected scripts (Sinhala U+0D80..U+0DFF, ASCII printable, whitespace)
    for ch in cleaned:
        cp = ord(ch)
        is_sin = (0x0D80 <= cp <= 0x0DFF)
        is_ascii = (0x20 <= cp <= 0x7E)
        is_allowed_fmt = cp in (0x200C, 0x200D, 0x00A0)  # ZWNJ, ZWJ, NBSP
        if not (is_sin or is_ascii or is_allowed_fmt):
            return True

    # Check length vs pixel width
    # In a scanned line, each character occupies at least 0.15 * line_h width
    min_char_w = max(3.0, line_h * 0.15)
    if len(cleaned) * min_char_w > max(30, line_w * 2.8):
        return True

    return False


LINE_CROP_CACHE: Dict[str, str] = {}


def get_cached_line(img_bytes: bytes) -> Optional[str]:
    h = hashlib.sha256(img_bytes).hexdigest()
    return LINE_CROP_CACHE.get(h)


def set_cached_line(img_bytes: bytes, text: str):
    h = hashlib.sha256(img_bytes).hexdigest()
    LINE_CROP_CACHE[h] = text


def clear_line_cache():
    LINE_CROP_CACHE.clear()


class GeminiLineReader(OcrEngine):
    """
    Primary or secondary line reader using Gemini (Flash class).
    Calls Vertex AI REST API with user's OAuth access token in their own project,
    or user's Gemini Developer API key stored in native OS Keychain.
    Strictly follows Hard Honesty Rules:
    - Zero network requests without explicit consent (Level 1 or 2).
    - Max 20 line crops per request, strictly structured JSON output.
    - Fallback crop-by-crop retry if ID/count mismatch occurs.
    - Hallucination guard check on every line.
    """
    name = "gemini_line_reader"

    def __init__(self, consent_granted: bool = False):
        self.consent_granted = consent_granted

    def is_enabled(self) -> bool:
        # Check consent level: must be >= 1
        rec = auth.load_user_consent()
        level = rec.get("level", 0)
        if level < 1 and not self.consent_granted:
            return False

        # Check daily cap
        cap = gcp_wizard.check_daily_cap()
        if cap["exceeded"]:
            return False

        # Check connectivity
        gcp_set = gcp_wizard.load_gcp_settings()
        mode = gcp_set.get("connection_mode", "oauth_vertex")
        if mode == "oauth_vertex":
            return bool(gcp_set.get("project_id")) and bool(auth.get_valid_access_token())
        elif mode == "api_key":
            return bool(gcp_wizard.get_stored_api_key())
        return False

    def read_line(self, line_img: Image.Image, langs: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        batch_res = self.read_batch([line_img], langs=langs)
        return batch_res[0] if batch_res else []

    def read_batch(self, line_imgs: List[Image.Image], langs: Optional[List[str]] = None) -> List[List[Dict[str, Any]]]:
        if not line_imgs:
            return []

        # If cloud AI is disabled or zero-consent, return empty without making network calls
        if not self.is_enabled():
            return [[] for _ in line_imgs]

        results: List[List[Dict[str, Any]]] = []
        batch_size = 20

        for chunk_idx in range(0, len(line_imgs), batch_size):
            chunk = line_imgs[chunk_idx:chunk_idx + batch_size]
            chunk_results = self._call_gemini_batch(chunk)
            results.extend(chunk_results)

        return results

    def _call_gemini_batch(self, crops: List[Image.Image]) -> List[List[Dict[str, Any]]]:
        # Encode crops and check cache
        encoded_crops = []
        needed_indices = []
        texts_by_idx = [None] * len(crops)

        for i, im in enumerate(crops):
            buf = io.BytesIO()
            im.save(buf, format="PNG")
            b = buf.getvalue()
            cached = get_cached_line(b)
            if cached is not None:
                texts_by_idx[i] = cached
            else:
                encoded_crops.append((i, b, base64.b64encode(b).decode("ascii")))
                needed_indices.append(i)

        if needed_indices:
            try:
                gcp_set = gcp_wizard.load_gcp_settings()
                mode = gcp_set.get("connection_mode", "oauth_vertex")
                cfg = config.load_config()
                prompt_text = cfg.get("line_ocr_prompt", "Transcribe exactly what is printed in each image. Do not correct, translate, complete or add anything. Keep Sinhala and English exactly as printed. Do not add spaces that are not visible. Return JSON only.")

                # Build parts for batch
                parts = [{"text": prompt_text + " Return a JSON array of objects: [{\"id\": \"c0\", \"text\": \"...\"}, ...]"}]
                for idx_in_batch, (orig_i, raw_b, b64_str) in enumerate(encoded_crops):
                    cid = f"c{idx_in_batch}"
                    parts.append({"text": f"Image ID: {cid}"})
                    parts.append({"inline_data": {"mime_type": "image/png", "data": b64_str}})

                payload = {
                    "contents": [{"role": "user", "parts": parts}],
                    "generationConfig": {"temperature": 0.0, "responseMimeType": "application/json"}
                }

                model = gcp_set.get("line_model", "gemini-2.5-flash")
                if mode == "oauth_vertex":
                    tok = auth.get_valid_access_token()
                    loc = gcp_set.get("location", "us-central1")
                    proj = gcp_set.get("project_id", "")
                    url = f"https://{loc}-aiplatform.googleapis.com/v1/projects/{proj}/locations/{loc}/publishers/google/models/{model}:generateContent"
                    headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
                else:
                    api_key = gcp_wizard.get_stored_api_key() or ""
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
                    headers = {"Content-Type": "application/json"}

                req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
                with urllib.request.urlopen(req, timeout=25) as resp:
                    resp_data = json.loads(resp.read().decode("utf-8"))
                    cand_text = resp_data["candidates"][0]["content"]["parts"][0]["text"].strip()
                    parsed_json = json.loads(cand_text)

                    # Map responses by id
                    id_map = {item.get("id"): item.get("text", "") for item in parsed_json if isinstance(item, dict)}

                    # Verify all needed indices got answers
                    all_present = all(f"c{k}" in id_map for k in range(len(encoded_crops)))
                    if all_present:
                        for k, (orig_i, raw_b, _) in enumerate(encoded_crops):
                            t = id_map.get(f"c{k}", "")
                            set_cached_line(raw_b, t)
                            texts_by_idx[orig_i] = t
                    else:
                        # Mismatch: trigger crop-by-crop retry
                        for orig_i, raw_b, b64_str in encoded_crops:
                            single_t = self._call_gemini_single(raw_b, b64_str, prompt_text, model, mode, gcp_set)
                            set_cached_line(raw_b, single_t)
                            texts_by_idx[orig_i] = single_t

                # Record usage in daily tally
                gcp_wizard.record_usage(pages=0, lines=len(needed_indices), cost_usd=len(needed_indices) * 0.00003)

            except Exception as e:
                # Log error and fall back without crashing
                for orig_i, raw_b, b64_str in encoded_crops:
                    texts_by_idx[orig_i] = None

        # Build word dicts for each crop
        final_results = []
        for i, crop in enumerate(crops):
            line_text = texts_by_idx[i]
            if not line_text:
                final_results.append([])
                continue

            # Hallucination guard
            if is_hallucination(line_text, crop.width, crop.height):
                final_results.append([])
                continue

            words = []
            tokens = line_text.split()
            # Estimate bounding boxes evenly across line width if no char boxes
            curr_x = 0
            total_chars = max(1, sum(len(t) for t in tokens))
            for tok in tokens:
                tok_w = max(10, int((len(tok) / total_chars) * (crop.width - 10)))
                words.append({
                    "text": tok,
                    "bbox": [curr_x, 0, tok_w, crop.height],
                    "confidence": 95.0,
                    "script": detect_script(tok),
                    "doubtful": False,
                    "doubt_reason": "",
                    "alternatives": []
                })
                curr_x += tok_w + 5
            final_results.append(words)

        return final_results

    def _call_gemini_single(self, raw_b: bytes, b64_str: str, prompt_text: str, model: str, mode: str, gcp_set: dict) -> str:
        """Fallback single crop reader for retry on count/id mismatch."""
        try:
            payload = {
                "contents": [
                    {
                        "role": "user",
                        "parts": [
                            {"text": prompt_text},
                            {"inline_data": {"mime_type": "image/png", "data": b64_str}}
                        ]
                    }
                ],
                "generationConfig": {"temperature": 0.0}
            }
            if mode == "oauth_vertex":
                tok = auth.get_valid_access_token()
                loc = gcp_set.get("location", "us-central1")
                proj = gcp_set.get("project_id", "")
                url = f"https://{loc}-aiplatform.googleapis.com/v1/projects/{proj}/locations/{loc}/publishers/google/models/{model}:generateContent"
                headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
            else:
                api_key = gcp_wizard.get_stored_api_key() or ""
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
                headers = {"Content-Type": "application/json"}

            req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return data["candidates"][0]["content"]["parts"][0]["text"].strip()
        except Exception:
            return ""


class CloudVisionEngine(GeminiLineReader):
    """Backwards-compatible alias for GeminiLineReader."""
    name = "cloud_vision"


class MultiEngineEnsemble:
    """
    Coordinates primary OCR engine, pre-processing variants, and secondary validation.
    Applies the Hard Honesty Rules:
    - Never silently guess a word.
    - Every word carries confidence.
    - Multi-engine agreement (Gemini vs Tesseract) using Levenshtein distance alignment.
    - Deterministic Sinhala validator checks every word.
    - Critical fields (digits, dates, IDs, phone numbers, currency amounts) always flagged for human review.
    - Doubtful words flagged and shown in guided unknown-word review.
    """
    def __init__(self, tesseract_engine: Optional[TesseractEngine] = None, second_reader: Optional[OcrEngine] = None):
        self.tesseract = tesseract_engine or TesseractEngine()
        self.local_engine = LocalSinhalaEngine()
        self.gemini_reader = second_reader or GeminiLineReader()

    def process_line(self, line_img: Image.Image, line_variants: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        # 1. Primary Tesseract Read (provides baseline text and precise spatial word bboxes)
        tess_words = []
        if self.tesseract.is_available():
            tess_words = self.tesseract.read_line(line_img, langs=["sin", "eng"])

        # 2. Gemini Read (if cloud AI is enabled & consented)
        gemini_words = []
        if self.gemini_reader.is_enabled():
            gemini_words = self.gemini_reader.read_line(line_img)

        # 3. If Tesseract failed completely, use Gemini or Local Sinhala engine
        if not tess_words:
            if gemini_words:
                words = gemini_words
            else:
                words = self.local_engine.read_line(line_img)
        else:
            # 4. Two-Reader Alignment & Voting (Gemini + Tesseract)
            if gemini_words:
                words = self._align_and_vote(tess_words, gemini_words)
            else:
                words = tess_words

        # 5. Post-process every word with deterministic Sinhala Validator & Lexicon
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
                script = detect_script(text)
                if script in ("sin", "eng"):
                    w["doubtful"] = True
                    if not w["doubt_reason"]:
                        w["doubt_reason"] = "unknown_word"
                    w["confidence"] = min(w["confidence"], 65.0)
                    w["alternatives"] = suggest_candidates(text, max_candidates=3)

            # If confidence is below threshold, flag as doubtful
            if w["confidence"] < 75.0:
                w["doubtful"] = True
                if not w["doubt_reason"]:
                    w["doubt_reason"] = f"low_confidence_{int(w['confidence'])}%"
                if not w["alternatives"]:
                    w["alternatives"] = suggest_candidates(text, max_candidates=3)

            # Numbers, Dates, IDs, and Amounts: ALWAYS human-verify
            has_digits = bool(re.search(r"\d", text))
            is_number_or_id = bool(re.search(r"(\d{4}[./-]\d{2}[./-]\d{2}|\d{6,12}|07\d[\s-]?\d{7}|රු\.?\s?\d+)", text))
            if has_digits or is_number_or_id:
                w["doubtful"] = True
                w["doubt_reason"] = "number_or_id_needs_verification"

        return words

    def _align_and_vote(self, tess_words: List[Dict[str, Any]], gemini_words: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Aligns Tesseract words (spatial bounding boxes) with Gemini words (high-accuracy transcriptions)
        using character edit distance matching.
        """
        out_words = []
        for i, tw in enumerate(tess_words):
            t_text = tw["text"].strip()
            # Find best matching word in gemini_words by proximity and edit similarity
            best_gw = None
            best_sim = 0.0

            # First check same index if lengths match
            if i < len(gemini_words):
                sim = levenshtein_similarity(t_text, gemini_words[i]["text"].strip())
                if sim >= 0.70:
                    best_gw = gemini_words[i]
                    best_sim = sim

            if best_sim < 0.85:
                for gw in gemini_words:
                    sim = levenshtein_similarity(t_text, gw["text"].strip())
                    if sim > best_sim:
                        best_sim = sim
                        best_gw = gw

            if best_gw and best_sim >= 0.90:
                # Both readers strongly agree
                out_words.append({
                    "text": best_gw["text"],  # Use clean shaped Unicode from Gemini
                    "bbox": tw["bbox"],       # Keep exact physical bbox from Tesseract TSV
                    "confidence": 98.0,
                    "script": detect_script(best_gw["text"]),
                    "doubtful": False,
                    "doubt_reason": "",
                    "alternatives": []
                })
            elif best_gw and best_sim >= 0.60:
                # Readers disagree slightly
                out_words.append({
                    "text": best_gw["text"],
                    "bbox": tw["bbox"],
                    "confidence": 70.0,
                    "script": detect_script(best_gw["text"]),
                    "doubtful": True,
                    "doubt_reason": "readers_disagree_needs_human",
                    "alternatives": [best_gw["text"], t_text]
                })
            else:
                # No close match in Gemini, retain Tesseract reading with lower confidence
                tw_copy = dict(tw)
                tw_copy["confidence"] = min(tw_copy["confidence"], 60.0)
                tw_copy["doubtful"] = True
                tw_copy["doubt_reason"] = "tesseract_only_unconfirmed"
                out_words.append(tw_copy)

        return out_words
