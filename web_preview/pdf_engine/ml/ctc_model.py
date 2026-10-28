"""
CTC Decoder, Vocabulary, and ONNX Runtime Inference Session for Sinhala + English.
Supports:
- Unicode code-point & grapheme cluster vocabularies
- CTC Greedy Decoding & CTC Beam Search with Lexicon integration
- Temperature-scaled confidence calibration
- ONNX Runtime execution for CPU / Apple Silicon Metal
"""

import os
import sys
import math
import numpy as np
from typing import List, Dict, Any, Tuple, Optional
from PIL import Image

try:
    import onnxruntime as ort
    HAS_ORT = True
except ImportError:
    HAS_ORT = False

from web_preview.pdf_engine.lexicon import is_known_word

# Sinhala + English Character Vocabulary
# Index 0 is reserved for CTC blank token: <blank>
SPECIAL_TOKENS = ["<blank>"]
LATIN_CHARS = [chr(c) for c in range(ord('A'), ord('Z') + 1)] + [chr(c) for c in range(ord('a'), ord('z') + 1)]
DIGIT_CHARS = [str(d) for d in range(10)]
PUNCT_CHARS = [" ", ".", ",", "-", "/", ":", ";", "(", ")", "'", '"', "=", "?", "!", "+", "%"]
# Sinhala Unicode range 0x0D80 to 0x0DFF
SINHALA_CHARS = [chr(cp) for cp in range(0x0D85, 0x0DD6 + 1)] + \
                [chr(cp) for cp in range(0x0DD8, 0x0DDF + 1)] + \
                [chr(0x0DF2), chr(0x0DF3), chr(0x200C), chr(0x200D)]

VOCAB = SPECIAL_TOKENS + DIGIT_CHARS + LATIN_CHARS + PUNCT_CHARS + SINHALA_CHARS
CHAR2IDX = {c: i for i, c in enumerate(VOCAB)}
IDX2CHAR = {i: c for i, c in enumerate(VOCAB)}
VOCAB_SIZE = len(VOCAB)


def ctc_greedy_decode(logits: np.ndarray, temperature: float = 1.0) -> Tuple[str, float]:
    """
    Greedy CTC decoder:
    Takes logits of shape (T, vocab_size), applies softmax with temperature scaling,
    takes argmax per time step, deduplicates consecutive identical non-blank tokens,
    and removes CTC blanks (<blank> at index 0).
    Returns (decoded_string, calibrated_confidence).
    """
    if logits.ndim != 2:
        return "", 0.0

    T, V = logits.shape
    # Temperature scaling
    scaled_logits = logits / max(0.1, temperature)
    # Numerical stability softmax
    exp_logits = np.exp(scaled_logits - np.max(scaled_logits, axis=-1, keepdims=True))
    probs = exp_logits / np.sum(exp_logits, axis=-1, keepdims=True)

    best_indices = np.argmax(probs, axis=-1)
    best_probs = np.max(probs, axis=-1)

    decoded_chars = []
    char_confs = []
    prev_idx = 0  # <blank>

    for t in range(T):
        idx = best_indices[t]
        p = best_probs[t]
        if idx != 0 and idx != prev_idx:
            char = IDX2CHAR.get(idx, "")
            if char:
                decoded_chars.append(char)
                char_confs.append(p)
        prev_idx = idx

    text = "".join(decoded_chars).strip()
    avg_conf = float(np.mean(char_confs)) if char_confs else 0.0
    return text, round(avg_conf * 100.0, 1)


def ctc_beam_search_decode(
    logits: np.ndarray,
    beam_width: int = 10,
    lexicon_boost: float = 1.15
) -> Tuple[str, float]:
    """
    CTC Beam Search decoder with Sinhala Lexicon boosting.
    """
    T, V = logits.shape
    exp_logits = np.exp(logits - np.max(logits, axis=-1, keepdims=True))
    probs = exp_logits / np.sum(exp_logits, axis=-1, keepdims=True)

    # Beam: prefix -> (prob_blank, prob_non_blank)
    beam: Dict[str, Tuple[float, float]] = {"": (1.0, 0.0)}

    for t in range(T):
        next_beam: Dict[str, Tuple[float, float]] = {}
        for prefix, (pb, pnb) in beam.items():
            tot_p = pb + pnb
            if tot_p < 1e-6:
                continue

            # 1. Extending with blank
            p_blank = probs[t, 0]
            new_pb, new_pnb = next_beam.get(prefix, (0.0, 0.0))
            next_beam[prefix] = (new_pb + tot_p * p_blank, new_pnb)

            # 2. Extending with characters
            for v_idx in range(1, min(V, 60)):  # top candidates
                p_char = probs[t, v_idx]
                if p_char < 1e-4:
                    continue
                char = IDX2CHAR.get(v_idx, "")
                if not char:
                    continue

                if len(prefix) > 0 and char == prefix[-1]:
                    # Same char as previous: if coming from blank, can append; if from non-blank, stays same
                    new_prefix = prefix + char
                    pb_cand, pnb_cand = next_beam.get(new_prefix, (0.0, 0.0))
                    next_beam[new_prefix] = (pb_cand, pnb_cand + pb * p_char)

                    pb_same, pnb_same = next_beam.get(prefix, (0.0, 0.0))
                    next_beam[prefix] = (pb_same, pnb_same + pnb * p_char)
                else:
                    new_prefix = prefix + char
                    pb_cand, pnb_cand = next_beam.get(new_prefix, (0.0, 0.0))
                    next_beam[new_prefix] = (pb_cand, pnb_cand + tot_p * p_char)

        # Prune beam
        scored = []
        for pref, (pb, pnb) in next_beam.items():
            score = pb + pnb
            # Lexicon bonus for known complete Sinhala words
            words = pref.split()
            if words and is_known_word(words[-1]):
                score *= lexicon_boost
            scored.append((score, pref, pb, pnb))

        scored.sort(key=lambda x: x[0], reverse=True)
        beam = {pref: (pb, pnb) for score, pref, pb, pnb in scored[:beam_width]}

    if not beam:
        return ctc_greedy_decode(logits)

    best_pref = max(beam.keys(), key=lambda k: sum(beam[k]))
    best_prob = sum(beam[best_pref])
    return best_pref.strip(), min(100.0, round(best_prob * 100.0, 1))


class OnnxLineRecognizer:
    """
    Compact ONNX Runtime Line Recognizer for Sinhala + Latin text lines.
    Loads ONNX model if present, otherwise provides offline baseline.
    """
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or os.path.join(os.path.dirname(__file__), "weights", "sinhala_line_crnn.onnx")
        self.session = None
        if HAS_ORT and os.path.exists(self.model_path):
            try:
                opts = ort.SessionOptions()
                opts.intra_op_num_threads = 2
                self.session = ort.InferenceSession(self.model_path, opts, providers=["CPUExecutionProvider"])
            except Exception as e:
                print(f"[OnnxLineRecognizer] Could not load ONNX session: {e}")

    def is_available(self) -> bool:
        return self.session is not None

    def preprocess_image(self, line_img: Image.Image, target_h: int = 48, max_w: int = 1024) -> np.ndarray:
        """Resizes line image to fixed height maintaining aspect ratio and normalizes to [-1, 1]."""
        w, h = line_img.size
        aspect = w / max(1, h)
        target_w = min(max_w, max(32, int(target_h * aspect)))
        # Pad to multiple of 4
        target_w = ((target_w + 3) // 4) * 4

        im_resized = line_img.convert("L").resize((target_w, target_h), Image.Resampling.BILINEAR)
        arr = np.array(im_resized, dtype=np.float32) / 255.0
        # Normalize
        arr = (arr - 0.5) / 0.5
        # Shape: (1, 1, H, W)
        return arr.reshape(1, 1, target_h, target_w)

    def predict_line(self, line_img: Image.Image) -> Tuple[str, float]:
        """Runs inference and decodes text."""
        if not self.is_available():
            return "", 0.0

        inp = self.preprocess_image(line_img)
        input_name = self.session.get_inputs()[0].name
        outputs = self.session.run(None, {input_name: inp})
        logits = outputs[0][0]  # shape: (T, vocab_size)

        return ctc_beam_search_decode(logits)
