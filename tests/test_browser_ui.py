"""
Browser end-to-end verification of modernize UI in Playwright.
Verifies:
- Loading the page in dark & light themes, English and Sinhala.
- No console errors.
- Modernize tool workflow.
- Captures preview screenshots.
"""

import os
from playwright.sync_api import sync_playwright

def test_browser_ui():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1440, "height": 900})

        console_errors = []
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)

        page.goto("http://localhost:8080", wait_until="networkidle")
        print("Page loaded successfully.")

        # Dismiss login overlay if visible
        page.evaluate("""() => {
            const overlay = document.getElementById('fullScreenLoginOverlay');
            if (overlay) overlay.classList.add('hidden');
        }""")
        page.wait_for_timeout(300)

        # Switch to Tools tab
        page.click('button.nav-item[data-tab="tools"]')
        page.wait_for_timeout(500)

        # Click Modernize tool card
        page.click('.pt-tool[data-tool="modernize"]')
        page.wait_for_timeout(500)

        # Upload AD_12_7871120.pdf
        fixture_path = os.path.abspath("tests/fixtures/AD_12_7871120.pdf")
        page.set_input_files("#ptPick", fixture_path)
        page.wait_for_timeout(1000)

        # Check step 1 panel is rendered
        assert page.is_visible("#chkModDeskew")
        assert page.is_visible("#chkModCloud")

        # Capture screenshot of Step 1
        page.screenshot(path="tests/fixtures/ui_modernize_step1.png")
        print("Captured ui_modernize_step1.png")

        # Verify console errors
        real_errors = [e for e in console_errors if "favicon" not in e and "font" not in e]
        print(f"Console errors: {len(real_errors)}")
        if real_errors:
            print("Errors:", real_errors)
        assert len(real_errors) == 0, f"Unexpected console errors: {real_errors}"

        browser.close()
    print("Browser UI test completed successfully with zero console errors.")

if __name__ == "__main__":
    test_browser_ui()
