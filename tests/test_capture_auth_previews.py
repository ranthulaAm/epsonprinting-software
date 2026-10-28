"""
Captures high-resolution visual previews of:
1. Full-screen Google Sign-In overlay (Dark & Light, EN & SI)
2. Connect Gemini (User GCP Project) Wizard modal
3. Dynamic Privacy Badge states (Offline, Cloud Lines, Cloud Page)
Saves screenshots directly to the artifacts directory.
"""

import os
from playwright.sync_api import sync_playwright

ARTIFACT_DIR = "/Users/ranthula/.gemini/antigravity/brain/139713fc-e813-41e9-b100-ece7e167cb8d"

def capture_previews():
    os.makedirs(ARTIFACT_DIR, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch()

        # 1. Login Screen - Dark Theme, English
        page = browser.new_page(viewport={"width": 1280, "height": 800})
        page.goto("http://localhost:8080", wait_until="domcontentloaded")
        page.wait_for_timeout(400)
        page.evaluate("""() => {
            document.documentElement.setAttribute('data-theme', 'dark');
            const overlay = document.getElementById('fullScreenLoginOverlay');
            if (overlay) overlay.classList.remove('hidden');
        }""")
        page.wait_for_timeout(300)
        page.screenshot(path=os.path.join(ARTIFACT_DIR, "preview_auth_login_dark_en.png"))
        print("Captured preview_auth_login_dark_en.png")

        # 2. Login Screen - Light Theme, Sinhala
        page.evaluate("""() => {
            document.documentElement.setAttribute('data-theme', 'light');
            if (window.toggleLang) window.toggleLang();
            const overlay = document.getElementById('fullScreenLoginOverlay');
            if (overlay) overlay.classList.remove('hidden');
        }""")
        page.wait_for_timeout(300)
        page.screenshot(path=os.path.join(ARTIFACT_DIR, "preview_auth_login_light_si.png"))
        print("Captured preview_auth_login_light_si.png")

        # 3. Dismiss login and Open GCP Wizard Modal
        page.evaluate("""() => {
            const overlay = document.getElementById('fullScreenLoginOverlay');
            if (overlay) overlay.classList.add('hidden');
            const gcpModal = document.getElementById('gcpConnectModal');
            if (gcpModal) gcpModal.classList.remove('hidden');
            const chkBox = document.getElementById('gcpVerifyChecklist');
            if (chkBox) chkBox.style.display = 'flex';
        }""")
        page.wait_for_timeout(300)
        page.screenshot(path=os.path.join(ARTIFACT_DIR, "preview_gcp_wizard_modal.png"))
        print("Captured preview_gcp_wizard_modal.png")

        # 4. Header Privacy Badge & Workspace
        page.evaluate("""() => {
            const gcpModal = document.getElementById('gcpConnectModal');
            if (gcpModal) gcpModal.classList.add('hidden');
            if (window.AuthUI) window.AuthUI.updatePrivacyBadge(1);
        }""")
        page.wait_for_timeout(300)
        page.screenshot(path=os.path.join(ARTIFACT_DIR, "preview_modernize_cloud_active.png"))
        print("Captured preview_modernize_cloud_active.png")

        browser.close()

if __name__ == "__main__":
    capture_previews()
