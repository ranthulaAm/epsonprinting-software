"""
Playwright automated test to verify Step 3 layout region overlay alignment on Form 15.
"""

import os
import sys
import time
from playwright.sync_api import sync_playwright

def test_step3_alignment():
    pdf_path = "/Users/ranthula/Downloads/Esis - Form 15_20261028_0001.pdf"
    assert os.path.exists(pdf_path), f"File not found: {pdf_path}"

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1100})

        console_errors = []
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)

        print("Navigating to http://localhost:8080...")
        page.goto("http://localhost:8080", wait_until="networkidle")

        # Dismiss login overlay if visible
        page.evaluate("""() => {
            const overlay = document.getElementById('fullScreenLoginOverlay');
            if (overlay) overlay.classList.add('hidden');
        }""")
        page.wait_for_timeout(300)

        # Open Tools tab
        page.click('button.nav-item[data-tab="tools"]')
        page.wait_for_timeout(400)

        # Select Modernize tool
        page.click('.pt-tool[data-tool="modernize"]')
        page.wait_for_timeout(400)

        # Upload Form 15
        print(f"Uploading {pdf_path}...")
        page.set_input_files("#ptPick", pdf_path)
        page.wait_for_timeout(1000)

        # Click Start Modernizing
        print("Clicking Start Modernizing...")
        page.wait_for_selector("#btnStartMod", timeout=5000)
        start_btn = page.query_selector("#btnStartMod")
        assert start_btn, "Start button not found"
        start_btn.click()

        # Wait for Step 2 Detect Regions button to appear (or auto-poll)
        print("Waiting for Step 2 Before/After enhancement to complete...")
        page.wait_for_selector("#btnGoTo3", timeout=60000)
        page.wait_for_timeout(800)

        # Click Detect Regions -> to navigate to Step 3
        print("Navigating to Step 3 (Layout Regions & Document Structure)...")
        page.click("#btnGoTo3")
        page.wait_for_selector(".pt-mod-region-overlay-container", timeout=10000)
        page.wait_for_timeout(1000)

        # Measure DOM bounding rects of image vs container
        container_box = page.eval_on_selector(".pt-mod-region-overlay-container", "el => el.getBoundingClientRect()")
        img_box = page.eval_on_selector(".pt-mod-region-overlay-container img", "el => el.getBoundingClientRect()")

        print(f"Container geometry: width={container_box['width']:.1f}, height={container_box['height']:.1f}, top={container_box['top']:.1f}")
        print(f"Image geometry:     width={img_box['width']:.1f}, height={img_box['height']:.1f}, top={img_box['top']:.1f}")

        # Assert sub-pixel alignment between container and image
        assert abs(container_box["width"] - img_box["width"]) < 1.0, "Container and image widths must match"
        assert abs(container_box["height"] - img_box["height"]) < 1.0, "Container and image heights must match exactly (no letterboxing)"
        assert abs(container_box["top"] - img_box["top"]) < 1.0, "Container and image tops must be identical"

        # Capture high-res screenshot
        out_shot = "/Users/ranthula/.gemini/antigravity/brain/139713fc-e813-41e9-b100-ece7e167cb8d/preview_step3_form15_aligned.png"
        page.screenshot(path=out_shot)
        print(f"Captured screenshot to: {out_shot}")

        # Verify boxes are present
        boxes = page.query_selector_all(".pt-mod-region-box")
        print(f"Detected overlay boxes in DOM: {len(boxes)}")
        assert len(boxes) > 0, "Overlay boxes must be rendered"

        browser.close()

if __name__ == "__main__":
    test_step3_alignment()
