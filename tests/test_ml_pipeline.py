"""
Acceptance & Integrity tests for Machine Learning Subsystem (Phase B, C, D):
- Synthetic line generator with HarfBuzz shaping
- CTC decoder (greedy & beam search with Sinhala lexicon)
- Font & style classification CNN feature predictor
"""

import os
import sys
import unittest
import numpy as np

WORKSPACE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if WORKSPACE_ROOT not in sys.path:
    sys.path.insert(0, WORKSPACE_ROOT)

from web_preview.pdf_engine.ml.synthetic_generator import (
    generate_synthetic_line,
    generate_batch,
    get_available_fonts
)
from web_preview.pdf_engine.ml.ctc_model import (
    ctc_greedy_decode,
    ctc_beam_search_decode,
    VOCAB,
    CHAR2IDX
)
from web_preview.pdf_engine.ml.font_classifier import FontStyleClassifier


class TestMLPipeline(unittest.TestCase):

    def test_01_synthetic_line_generation(self):
        """Generates synthetic line images with ground truth text and realistic degradations."""
        img, text = generate_synthetic_line(degrade=True)
        self.assertGreater(img.width, 20)
        self.assertGreater(img.height, 10)
        self.assertGreater(len(text), 0)

        # Batch generation
        batch = generate_batch(count=5, degrade=False)
        self.assertEqual(len(batch), 5)
        for im, txt in batch:
            self.assertGreater(im.width, 0)
            self.assertGreater(len(txt), 0)

    def test_02_ctc_decoding(self):
        """Verifies CTC Greedy and Beam Search decoding with Sinhala vocabulary."""
        # Synthesize dummy logits: target text = '7871120'
        target = "7871120"
        T = len(target) * 2 + 1
        logits = np.full((T, len(VOCAB)), -5.0)
        # Place characters at odd steps with blank at even steps
        for i, ch in enumerate(target):
            step = i * 2 + 1
            idx = CHAR2IDX[ch]
            logits[step, idx] = 10.0
        # Step 0, 2, 4 are blank (index 0)
        for step in range(0, T, 2):
            logits[step, 0] = 10.0

        # Greedy decode
        decoded, conf = ctc_greedy_decode(logits)
        self.assertEqual(decoded, "7871120")
        self.assertGreaterEqual(conf, 90.0)

        # Beam search decode
        bs_decoded, bs_conf = ctc_beam_search_decode(logits, beam_width=5)
        self.assertEqual(bs_decoded, "7871120")

    def test_03_font_style_classifier(self):
        """Verifies font size, weight, and style prediction on synthetic lines."""
        classifier = FontStyleClassifier()
        img, _ = generate_synthetic_line(text="විභාග අංකය: 7871120", degrade=False)
        pred = classifier.predict(img, dpi=300)

        self.assertIn("font_family", pred)
        self.assertIn("font_size_pt", pred)
        self.assertIn("weight", pred)
        self.assertIn("italic", pred)
        self.assertIn("underline", pred)

        self.assertGreater(pred["font_size_pt"], 4.0)


if __name__ == "__main__":
    unittest.main()
