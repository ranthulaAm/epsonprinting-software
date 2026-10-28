"""
Comprehensive browser verification across resolutions, themes, and languages.
Verifies:
- 1440x900, 1280x720, 1100x700 resolutions
- Dark and Light themes
- English and Sinhala languages
- Zero console errors
"""

import os
from playwright.sync_api import sync_playwright

def test_full_ui_matrix():
    resolutions = [
        (1440, 900),
        (1280, 720),
        (1100, 700)
    ]
    themes = ["dark", "light"]
    languages = ["en", "si"]

    with sync_playwright() as p:
        browser = p.chromium.launch()

        for w, h in resolutions:
            for theme in themes:
                for lang in languages:
                    page = browser.new_page(viewport={"width": w, "height": h})
                    console_errors = []
                    page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)

                    page.goto("http://localhost:8080", wait_until="domcontentloaded")

                    # If login overlay is visible, dismiss with continue offline
                    if page.is_visible("#fullScreenLoginOverlay"):
                        page.click("#btnContinueOffline")
                        page.wait_for_timeout(200)

                    # Set theme and language
                    page.evaluate(f"""() => {{
                        document.documentElement.setAttribute('data-theme', '{theme}');
                        localStorage.setItem('theme', '{theme}');
                        if (window.setLanguage) window.setLanguage('{lang}');
                        else {{
                            document.documentElement.setAttribute('lang', '{lang}');
                            localStorage.setItem('lang', '{lang}');
                        }}
                    }}""")
                    page.wait_for_timeout(300)

                    # Go to Tools tab
                    page.click('button.nav-item[data-tab="tools"]')
                    page.wait_for_timeout(300)

                    # Click Modernize tool
                    page.click('.pt-tool[data-tool="modernize"]')
                    page.wait_for_timeout(300)

                    # Check key elements visible
                    assert page.locator("#ptPick").count() >= 1
                    assert page.is_visible("#tabTools")

                    real_errors = [
                        e for e in console_errors
                        if "favicon" not in e and "font" not in e and "ERR_CONNECTION_CLOSED" not in e and "ERR_ABORTED" not in e
                    ]
                    assert len(real_errors) == 0, f"Errors in {w}x{h} {theme} {lang}: {real_errors}"

                    page.close()
                    print(f"✓ Checked {w}x{h} | Theme: {theme} | Lang: {lang} | Errors: 0")

        browser.close()
    print("\nAll responsive resolutions, themes, and languages passed with 0 console errors!")

if __name__ == "__main__":
    test_full_ui_matrix()
