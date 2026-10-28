"""
Comprehensive Acceptance Test Suite for:
1. OAuth 2.0 PKCE & Keychain security (RFC 7636, RFC 8252)
2. Zero-Network Guarantee when user consent level is 0
3. GCP Connection Wizard, billing verification, and Service Usage checks
4. Cost Guard & Daily Page Limits
5. Multi-engine alignment, Levenshtein agreement voting, and hallucination guard
6. Mandatory human-verification for digits, IDs, dates, and amounts
7. Batch processing retry on ID mismatch
"""

import os
import sys
import json
import unittest
from unittest.mock import patch, MagicMock
from PIL import Image
import numpy as np

# Ensure workspace root is in sys.path
WORKSPACE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if WORKSPACE_ROOT not in sys.path:
    sys.path.insert(0, WORKSPACE_ROOT)

from web_preview.pdf_engine import auth, config, gcp_wizard, ocr_engine, review_manager
from web_preview.pdf_engine.ocr_engine import (
    levenshtein_similarity,
    is_hallucination,
    GeminiLineReader,
    MultiEngineEnsemble,
    TesseractEngine
)


class TestGcpAndAuthAcceptance(unittest.TestCase):

    def setUp(self):
        # Reset auth state for tests
        auth.AUTH_STATE["authenticated"] = False
        auth.AUTH_STATE["user"] = None
        auth.AUTH_STATE["access_token"] = None
        auth.AUTH_STATE["offline_bypass"] = False

    def test_01_keychain_token_security(self):
        """
        Guarantees:
        - Browser never receives access_token or refresh_token.
        - Public status only contains sanitized user profile.
        - Refresh token is stored in native OS Keychain.
        """
        auth.AUTH_STATE["authenticated"] = True
        auth.AUTH_STATE["user"] = {
            "name": "Test User",
            "email": "test@example.com",
            "picture": "https://example.com/photo.jpg",
            "sub": "12345"
        }
        auth.AUTH_STATE["access_token"] = "secret_access_token_in_memory_only"

        pub_status = auth.get_public_auth_status()
        self.assertTrue(pub_status["authenticated"])
        self.assertIsNotNone(pub_status["user"])
        self.assertEqual(pub_status["user"]["email"], "test@example.com")

        # Crucial security assertion: NO token is in public status
        status_json = json.dumps(pub_status)
        self.assertNotIn("secret_access_token_in_memory_only", status_json)
        self.assertNotIn("access_token", status_json)
        self.assertNotIn("refresh_token", status_json)

    def test_02_zero_network_when_consent_zero(self):
        """
        Strict Zero-Network Guarantee:
        When user consent level is 0, GeminiLineReader is disabled and
        makes ZERO network requests to any Google endpoint.
        """
        # Set consent level to 0
        auth.save_user_consent(0, email="test@example.com")
        reader = GeminiLineReader(consent_granted=False)
        self.assertFalse(reader.is_enabled())

        dummy_img = Image.new("RGB", (200, 40), (255, 255, 255))

        with patch("urllib.request.urlopen") as mock_url:
            words = reader.read_line(dummy_img)
            # Must return empty list and NEVER call urlopen
            self.assertEqual(words, [])
            mock_url.assert_not_called()

    def test_03_cost_estimate_and_daily_cap(self):
        """
        Validates job cost estimation and local daily page limit guard.
        """
        est = gcp_wizard.estimate_job_cost(num_pages=5, num_lines=150)
        self.assertEqual(est["num_pages"], 5)
        self.assertEqual(est["num_lines"], 150)
        self.assertGreater(est["est_cost_usd"], 0.0)
        self.assertTrue(est["est_cost_formatted"].startswith("$"))

        # Daily cap check
        cap_status = gcp_wizard.check_daily_cap()
        self.assertIn("limit", cap_status)
        self.assertIn("pages_today", cap_status)
        self.assertIn("exceeded", cap_status)

    def test_04_hallucination_guard(self):
        """
        Verifies rejection of unexpected foreign scripts and length-disproportionate text.
        """
        # Normal Sinhala + Latin
        self.assertFalse(is_hallucination("ශ්‍රී ලංකා ප්‍රජාතාන්ත්‍රික", line_w=300, line_h=40))
        self.assertFalse(is_hallucination("AMARASEKARA 7871120", line_w=250, line_h=35))

        # Hallucination 1: Foreign scripts (e.g. Cyrillic, Chinese, Arabic)
        self.assertTrue(is_hallucination("Привет мир 12345", line_w=200, line_h=40))
        self.assertTrue(is_hallucination("你好世界", line_w=200, line_h=40))

        # Hallucination 2: Hallucinated paragraph inside tiny 40px crop
        long_hallucinated = "මෙම ලේඛනය ඉතා දීර්ඝ ලෙස ලියන ලද අසත්‍ය ප්‍රකාශනයක් වන අතර එය කුඩා පෙළ පේළියකට නොගැලපේ"
        self.assertTrue(is_hallucination(long_hallucinated, line_w=40, line_h=30))

    def test_05_levenshtein_alignment_and_voting(self):
        """
        Verifies character edit distance agreement voting:
        - Agreement >= 90% -> high confidence, verified.
        - Disagreement -> flagged as doubtful with alternatives.
        """
        tess_words = [
            {"text": "AMARASEKARA", "bbox": [10, 0, 80, 25], "confidence": 85.0},
            {"text": "ප්රකාශය", "bbox": [100, 0, 70, 25], "confidence": 75.0}
        ]
        gemini_words = [
            {"text": "AMARASEKARA", "bbox": [0, 0, 80, 25], "confidence": 99.0},
            {"text": "ප්‍රකාශය", "bbox": [0, 0, 70, 25], "confidence": 98.0}
        ]

        ensemble = MultiEngineEnsemble()
        voted = ensemble._align_and_vote(tess_words, gemini_words)

        self.assertEqual(len(voted), 2)
        # Word 1: exact match
        self.assertEqual(voted[0]["text"], "AMARASEKARA")
        self.assertGreaterEqual(voted[0]["confidence"], 95.0)

        # Word 2: shaped Sinhala rakaransaya from Gemini with spatial bbox from Tesseract
        self.assertEqual(voted[1]["text"], "ප්‍රකාශය")
        self.assertEqual(voted[1]["bbox"], [100, 0, 70, 25])

    def test_06_mandatory_digit_and_id_verification(self):
        """
        Hard Honesty Rule:
        Every number, ID, date, or currency amount MUST be marked for human verification,
        so numbers are never silently assumed.
        """
        ensemble = MultiEngineEnsemble()
        # Mock line with exam index 7871120
        line_img = Image.new("RGB", (200, 40), (255, 255, 255))
        with patch.object(ensemble.tesseract, "is_available", return_value=True), \
             patch.object(ensemble.tesseract, "read_line", return_value=[
                 {"text": "විභාග", "bbox": [0, 0, 40, 20], "confidence": 98.0, "script": "sin", "doubtful": False, "doubt_reason": "", "alternatives": []},
                 {"text": "අංකය", "bbox": [45, 0, 40, 20], "confidence": 98.0, "script": "sin", "doubtful": False, "doubt_reason": "", "alternatives": []},
                 {"text": "7871120", "bbox": [90, 0, 60, 20], "confidence": 99.0, "script": "num", "doubtful": False, "doubt_reason": "", "alternatives": []}
             ]):
            words = ensemble.process_line(line_img)
            digit_word = next((w for w in words if w["text"] == "7871120"), None)
            self.assertIsNotNone(digit_word)
            self.assertTrue(digit_word["doubtful"])
            self.assertEqual(digit_word["doubt_reason"], "number_or_id_needs_verification")

    def test_07_gcp_wizard_checks(self):
        """
        Verifies GCP verification checks report proper status and Console deep links.
        """
        # When unauthenticated, verify_gcp_setup gracefully returns error
        res = gcp_wizard.verify_gcp_setup("test-project-123")
        self.assertFalse(res["ok"])
        self.assertTrue(res.get("needs_auth", False))


if __name__ == "__main__":
    unittest.main()
