"""
Browser acceptance and visual regression verification for Guided Unknown Word Loop.
Tests at 1280x720, dark and light themes, English and Sinhala, verifying zero console errors.
"""

import os
import sys
import time
import io
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from playwright.sync_api import sync_playwright

ARTIFACTS_DIR = "/Users/ranthula/.gemini/antigravity/brain/139713fc-e813-41e9-b100-ece7e167cb8d"
os.makedirs(ARTIFACTS_DIR, exist_ok=True)


def create_test_scan_image():
    """Creates a sample test scan image with Sinhala text."""
    h, w = 400, 600
    img = np.ones((h, w, 3), dtype=np.uint8) * 248
    # Add subtle scan noise and borders
    cv2.rectangle(img, (20, 20), (580, 380), (220, 220, 220), 1)
    # Draw dark simulated text lines
    for y in [60, 110, 160, 210, 260]:
        cv2.line(img, (40, y), (540, y), (40, 40, 40), 12)
        # Word gaps
        for gap_x in [120, 220, 340, 450]:
            cv2.line(img, (gap_x, y - 8), (gap_x + 14, y + 8), (248, 248, 248), 16)
    ret, buf = cv2.imencode(".png", img)
    return buf.tobytes()


def setup_browser_mock_job(job_id="browser_guided_review_job"):
    """Registers a mock session in REVIEW_MANAGER so Step 4 renders full guided card."""
    from web_preview.pdf_engine.review_manager import REVIEW_MANAGER
    h, w = 300, 600
    page_img = np.ones((h, w, 3), dtype=np.uint8) * 245
    cv2.putText(page_img, "ශ්රී ලංකා", (40, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (20, 20, 20), 2)
    cv2.putText(page_img, "ප්රජාතාන්ත්රික", (40, 140), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (20, 20, 20), 2)

    doc_model = {
        "version": "1.0",
        "doc_id": "doc_browser_test",
        "file_name": "sample_letter.pdf",
        "pages": [{
            "page_num": 1,
            "blocks": [{
                "type": "heading",
                "bbox": [30, 30, 500, 70],
                "lines": [{
                    "line_idx": 0,
                    "bbox": [30, 30, 500, 50],
                    "words": [
                        {
                            "id": "w_1_0_0_0",
                            "text": "ශ්රී",
                            "bbox": [10, 5, 45, 30],
                            "confidence": 62.0,
                            "script": "sin",
                            "doubtful": True,
                            "reasons": ["Letters look uncertain (62% confidence)"]
                        },
                        {
                            "id": "w_1_0_0_1",
                            "text": "ලංකා",
                            "bbox": [65, 5, 60, 30],
                            "confidence": 88.0,
                            "script": "sin",
                            "doubtful": False,
                            "reasons": []
                        }
                    ]
                }]
            }]
        }]
    }
    REVIEW_MANAGER.register_page_images(job_id, 1, page_img, page_img)
    REVIEW_MANAGER.get_or_create_session(job_id, doc_model=doc_model)
    return job_id


def verify_browser():
    errors = []
    job_id = setup_browser_mock_job()

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)

        for theme in ["dark", "light"]:
            for lang in ["en", "si"]:
                print(f"\n--- Testing 1280x720 | Theme: {theme} | Lang: {lang} ---")
                context = browser.new_context(
                    viewport={"width": 1280, "height": 720},
                    device_scale_factor=1
                )
                page = context.new_page()

                console_errors = []
                page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
                page.on("pageerror", lambda err: console_errors.append(str(err)))

                # 1. Navigate to localhost:8080
                page.goto("http://localhost:8080", wait_until="networkidle")
                page.wait_for_timeout(600)

                # Set theme
                page.evaluate(f"""() => {{
                    document.documentElement.setAttribute('data-theme', '{theme}');
                    if ('{theme}' === 'dark') document.body.classList.add('dark');
                    else document.body.classList.remove('dark');
                }}""")

                # Set language
                if lang == "si":
                    page.evaluate("() => { if (window.setLang) window.setLang('si'); }")
                else:
                    page.evaluate("() => { if (window.setLang) window.setLang('en'); }")
                page.wait_for_timeout(400)

                # 2. Set up session storage before clicking modernize tool
                page.evaluate(f"""() => {{
                    sessionStorage.setItem('pt_mod_job_id', '{job_id}');
                    sessionStorage.setItem('pt_mod_step', '4');
                }}""")

                # Switch to Tools tab
                tools_tab_btn = page.locator("button[data-tab='tools']")
                if tools_tab_btn.count() > 0:
                    tools_tab_btn.first.click()
                    page.wait_for_timeout(400)

                # Click Modernize tool button
                mod_btn = page.locator("button.pt-tool[data-tool='modernize']")
                if mod_btn.count() > 0:
                    mod_btn.first.click()
                    page.wait_for_selector(".pt-mod-guided-container", timeout=6000)

                # Check guided card elements
                guided_container = page.locator(".pt-mod-guided-container")
                word_input = page.locator("#ptModWordInput")
                word_crop = page.locator("#ptModWordCropImg")
                accept_btn = page.locator("#btnModAccept")

                assert guided_container.is_visible(), "Guided container not visible"
                assert word_input.is_visible(), "Word input not visible"
                assert word_crop.is_visible(), "Word crop image not visible"
                assert accept_btn.is_visible(), "Accept button not visible"

                print(f"✓ Guided Question Card visible & verified for {theme}-{lang}")

                # Test Singlish toggle
                singlish_btn = page.locator("#btnToggleSinglish")
                if singlish_btn.count() > 0:
                    singlish_btn.click()
                    page.wait_for_timeout(200)

                # Test Character Palette toggle
                palette_btn = page.locator("#btnTogglePalette")
                if palette_btn.count() > 0:
                    palette_btn.click()
                    page.wait_for_timeout(200)

                # Take screenshot for artifact
                screenshot_filename = f"preview_guided_review_{theme}_{lang}.png"
                screenshot_path = os.path.join(ARTIFACTS_DIR, screenshot_filename)
                page.screenshot(path=screenshot_path)
                print(f"Saved screenshot: {screenshot_path}")

                # Check console errors (ignoring Google Fonts / favicon network failures if offline)
                filtered_errors = [e for e in console_errors if "fonts.googleapis.com" not in e and "fonts.gstatic.com" not in e and "ERR_CONNECTION" not in e and "favicon" not in e]
                if filtered_errors:
                    print(f"Console errors for {theme}-{lang}: {filtered_errors}")
                    errors.extend(filtered_errors)
                else:
                    print(f"✓ Zero console errors ({theme}-{lang})")

                context.close()

        browser.close()

    if errors:
        print(f"\nFAILED with {len(errors)} console errors.")
        sys.exit(1)
    else:
        print("\nALL BROWSER ACCEPTANCE CHECKS PASSED WITH ZERO CONSOLE ERRORS!")


if __name__ == "__main__":
    verify_browser()
