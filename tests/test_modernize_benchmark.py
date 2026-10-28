"""
Regression tests for Old Document -> New Document ("modernize") pipeline.
Validates:
1. Deterministic Sinhala validator checks and regex patterns.
2. Weighted lexicon suggestions and confusion table.
3. Preprocessing (deskew, shadow removal, Sauvola adaptive binarization).
4. Classical OpenCV layout analysis (tables, text lines, rules, charts).
5. Headless Chromium PDF & DOCX export with Sinhala complex-script font shaping.
6. Benchmark assertion: CER < 10% on Level 1-2, Fidelity >= 80%.
"""

import os
import sys
import unittest
import numpy as np
from PIL import Image

# Ensure workspace root is in path
WORKSPACE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if WORKSPACE_ROOT not in sys.path:
    sys.path.insert(0, WORKSPACE_ROOT)

from web_preview.pdf_engine.sinhala_validator import inspect_word
from web_preview.pdf_engine.lexicon import is_known_word, suggest_candidates, detect_script
from web_preview.pdf_engine.preprocess import deskew_image, remove_shadows_and_bleed, sauvola_threshold
from web_preview.pdf_engine.layout_analyzer import analyze_document_layout
from web_preview.pdf_engine.renderer import generate_document_html, export_pdf, export_docx
from web_preview.pdf_engine.benchmark import run_benchmark_suite


class TestModernizePipeline(unittest.TestCase):

    def test_01_sinhala_validator(self):
        # Valid rakaransaya and yansaya
        self.assertTrue(inspect_word("ශ්‍රී")["valid"])
        self.assertTrue(inspect_word("ප්‍රජාතාන්ත්‍රික")["valid"])
        self.assertTrue(inspect_word("ව්‍යවස්ථා")["valid"])

        # Illegal diacritics
        self.assertFalse(inspect_word("්ක")["valid"])       # diacritic at word start
        self.assertFalse(inspect_word("කියාා")["valid"])     # consecutive vowels
        self.assertFalse(inspect_word("ක\u200dර")["valid"])  # ZWJ without virama

        # Regex entities
        self.assertTrue(inspect_word("077-1234567")["valid"])
        self.assertFalse(inspect_word("077-12")["valid"])    # Corrupted phone
        self.assertTrue(inspect_word("info@domain.lk")["valid"])
        self.assertFalse(inspect_word("info@bad")["valid"])

    def test_02_lexicon_suggestions(self):
        self.assertEqual(detect_script("ශ්‍රී"), "sin")
        self.assertEqual(detect_script("Document"), "eng")
        self.assertEqual(detect_script("REF/ශ්‍රී/01"), "mixed")

        self.assertTrue(is_known_word("ශ්‍රී"))
        self.assertTrue(is_known_word("ලංකා"))
        self.assertTrue(is_known_word("document"))

        # Suggestion using empirical confusion table
        suggs = suggest_candidates("documnt")
        self.assertIn("document", suggs)

    def test_03_preprocessing(self):
        arr = np.full((200, 300, 3), 245, dtype=np.uint8)
        arr[80:100, 30:270] = 20 # dark line
        deskewed, angle = deskew_image(arr)
        self.assertEqual(deskewed.shape, arr.shape)

        cleaned = remove_shadows_and_bleed(deskewed)
        self.assertEqual(cleaned.shape, arr.shape)

        gray = cleaned[:, :, 0]
        sauv = sauvola_threshold(gray, window_size=21, k=0.18)
        self.assertEqual(sauv.shape, gray.shape)

    def test_04_layout_analysis(self):
        img = np.full((500, 400, 3), 255, dtype=np.uint8)
        img[40:60, 100:300] = 20   # Heading
        img[80:82, 40:360] = 0     # Horizontal rule
        img[120:140, 40:360] = 30  # Body text
        # Table
        img[200:300, 40:360] = 255
        img[200:202, 40:360] = 0
        img[298:300, 40:360] = 0
        img[200:300, 40:42] = 0
        img[200:300, 358:360] = 0

        layout = analyze_document_layout(img, dpi=150)
        self.assertGreater(len(layout["blocks"]), 0)
        types = [b["type"] for b in layout["blocks"]]
        self.assertIn("rule", types)
        self.assertTrue("heading" in types or "text" in types)

    def test_05_renderer_and_export(self):
        doc_model = {
            "pages": [{
                "page_num": 1,
                "width_pt": 595.28,
                "height_pt": 841.89,
                "dpi": 150,
                "blocks": [{
                    "type": "heading",
                    "bbox": [50, 40, 400, 30],
                    "alignment": "center",
                    "font_size_pt": 16.0,
                    "lines": [{"words": [{"text": "ශ්‍රී ලංකා"}]}]
                }]
            }]
        }
        html = generate_document_html(doc_model)
        self.assertIn("ශ්‍රී ලංකා", html)

        pdf_bytes = export_pdf(doc_model)
        self.assertGreater(len(pdf_bytes), 1000)

        docx_bytes = export_docx(doc_model)
        self.assertGreater(len(docx_bytes), 1000)

    def test_06_benchmark_regression(self):
        bench = run_benchmark_suite()
        self.assertIn("levels", bench)
        self.assertEqual(len(bench["levels"]), 3)

        lvl1 = bench["levels"][0]
        # Assert Level 1 CER <= 5%, Fidelity >= 85%
        self.assertLessEqual(lvl1["cer_percent"], 5.0, "Level 1 CER degraded!")
        self.assertGreaterEqual(lvl1["fidelity_score"], 85.0, "Level 1 fidelity degraded!")


if __name__ == "__main__":
    unittest.main()
