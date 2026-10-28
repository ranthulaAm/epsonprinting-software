"""
Central configuration for Print Helper / PDF Gear AI & Cloud Integration.
No secrets are stored here. Desktop OAuth Client IDs are public per RFC 8252.
"""

import os
import json

CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")

DEFAULT_CONFIG = {
    # Desktop OAuth 2.0 Client ID (public identifier for Desktop app)
    # The user can override via GOOGLE_OAUTH_CLIENT_ID environment variable or config.json
    "google_oauth_client_id": os.environ.get("GOOGLE_OAUTH_CLIENT_ID", "1083921839218-printhelperdesktopapp.apps.googleusercontent.com"),
    "google_oauth_client_secret": os.environ.get("GOOGLE_OAUTH_CLIENT_SECRET", ""),

    # Login enforcement
    "require_login_to_use_app": True,

    # Gemini Models (configurable, never hard-coded)
    "gemini_line_model": "gemini-2.5-flash",
    "gemini_page_model": "gemini-2.5-pro",
    "gemini_default_location": "us-central1",

    # Pricing estimates (USD per 1M tokens)
    "pricing": {
        "gemini-2.5-flash": {
            "input_per_million": 0.075,
            "output_per_million": 0.30
        },
        "gemini-2.5-pro": {
            "input_per_million": 1.25,
            "output_per_million": 5.00
        }
    },

    # Cost Guard Limits
    "default_daily_page_limit": 100,

    # Prompt Versions
    "line_ocr_prompt_version": "v1.2",
    "line_ocr_prompt": (
        "Transcribe exactly what is printed in each image. "
        "Do not correct, translate, complete or add anything. "
        "Keep Sinhala and English exactly as printed. "
        "Do not add spaces that are not visible. Return JSON only."
    )
}

def load_config():
    conf = dict(DEFAULT_CONFIG)
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                saved = json.load(f)
                conf.update(saved)
        except Exception:
            pass
    return conf

def save_config(updates: dict):
    conf = load_config()
    conf.update(updates)
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(conf, f, indent=2)
    except Exception as e:
        print(f"Failed to save config: {e}")
    return conf
