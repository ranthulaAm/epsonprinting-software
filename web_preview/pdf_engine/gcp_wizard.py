"""
Google Cloud Platform (GCP) Gemini Connection Wizard & Cost Guard.
Connects Gemini through the user's OWN Google Cloud project.
Billing is charged directly to the user by Google.
Zero backend server of ours; zero owner API keys.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.parse
import urllib.error
from typing import Dict, Any, List, Optional
import keyring

from web_preview.pdf_engine import config
from web_preview.pdf_engine import auth

GCP_SETTINGS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "gcp_settings.json")
USAGE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "user_usage.json")
KEYRING_GEMINI_KEY = "gemini_api_key"


def load_gcp_settings() -> Dict[str, Any]:
    """Loads saved GCP project connection settings (no secrets)."""
    if os.path.exists(GCP_SETTINGS_FILE):
        try:
            with open(GCP_SETTINGS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    cfg = config.load_config()
    return {
        "project_id": "",
        "location": cfg.get("gemini_default_location", "us-central1"),
        "line_model": cfg.get("gemini_line_model", "gemini-2.5-flash"),
        "page_model": cfg.get("gemini_page_model", "gemini-2.5-pro"),
        "connection_mode": "oauth_vertex",  # 'oauth_vertex' | 'api_key' | 'offline'
        "verified": False,
        "daily_page_limit": cfg.get("default_daily_page_limit", 100)
    }


def save_gcp_settings(settings: Dict[str, Any]) -> Dict[str, Any]:
    """Saves GCP project settings (project_id, location, model, mode)."""
    current = load_gcp_settings()
    current.update(settings)
    os.makedirs(os.path.dirname(GCP_SETTINGS_FILE), exist_ok=True)
    try:
        with open(GCP_SETTINGS_FILE, "w", encoding="utf-8") as f:
            json.dump(current, f, indent=2)
    except Exception as e:
        print(f"[GCP Wizard] Failed to save settings: {e}")
    return current


def load_usage() -> Dict[str, Any]:
    """Loads daily usage records."""
    today = time.strftime("%Y-%m-%d")
    default = {"date": today, "pages_today": 0, "lines_today": 0, "est_cost_usd": 0.0}
    if os.path.exists(USAGE_FILE):
        try:
            with open(USAGE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if data.get("date") == today:
                    return data
        except Exception:
            pass
    return default


def record_usage(pages: int = 0, lines: int = 0, cost_usd: float = 0.0) -> Dict[str, Any]:
    """Records usage and updates daily running tally."""
    usage = load_usage()
    usage["pages_today"] += pages
    usage["lines_today"] += lines
    usage["est_cost_usd"] += cost_usd
    os.makedirs(os.path.dirname(USAGE_FILE), exist_ok=True)
    try:
        with open(USAGE_FILE, "w", encoding="utf-8") as f:
            json.dump(usage, f, indent=2)
    except Exception as e:
        print(f"[GCP Wizard] Failed to record usage: {e}")
    return usage


def check_daily_cap() -> Dict[str, Any]:
    """Checks whether the user-configured daily page cap has been exceeded."""
    settings = load_gcp_settings()
    usage = load_usage()
    limit = settings.get("daily_page_limit", 100)
    exceeded = usage.get("pages_today", 0) >= limit
    return {
        "limit": limit,
        "pages_today": usage.get("pages_today", 0),
        "lines_today": usage.get("lines_today", 0),
        "est_cost_usd": usage.get("est_cost_usd", 0.0),
        "exceeded": exceeded
    }


def estimate_job_cost(num_pages: int, num_lines: int) -> Dict[str, Any]:
    """Estimates the job cost in USD using current config pricing."""
    cfg = config.load_config()
    pricing = cfg.get("pricing", {}).get("gemini-2.5-flash", {
        "input_per_million": 0.075,
        "output_per_million": 0.30
    })
    # Average tokens: ~300 input tokens per line image crop, ~20 output tokens
    est_input_tokens = num_lines * 300
    est_output_tokens = num_lines * 20
    est_cost = (
        (est_input_tokens / 1_000_000.0) * pricing["input_per_million"] +
        (est_output_tokens / 1_000_000.0) * pricing["output_per_million"]
    )
    return {
        "num_pages": num_pages,
        "num_lines": num_lines,
        "est_input_tokens": est_input_tokens,
        "est_output_tokens": est_output_tokens,
        "est_cost_usd": round(est_cost, 6),
        "est_cost_formatted": f"${est_cost:.4f}" if est_cost >= 0.0001 else "< $0.0001"
    }


def list_user_gcp_projects() -> Dict[str, Any]:
    """
    Lists user's Google Cloud projects via Cloud Resource Manager API.
    Uses the authenticated user's OAuth access token.
    """
    token = auth.get_valid_access_token()
    if not token:
        return {
            "ok": False,
            "error": "Not authenticated with Google. Please sign in first.",
            "projects": [],
            "needs_auth": True
        }

    url = "https://cloudresourcemanager.googleapis.com/v1/projects"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=12, context=config.get_ssl_context()) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            projects = []
            for p in data.get("projects", []):
                if p.get("lifecycleState") == "ACTIVE":
                    projects.append({
                        "id": p.get("projectId"),
                        "name": p.get("name", p.get("projectId")),
                        "projectNumber": p.get("projectNumber")
                    })
            return {"ok": True, "projects": projects}
    except urllib.error.HTTPError as e:
        status_code = e.code
        err_msg = e.read().decode("utf-8", errors="ignore")
        if status_code == 403:
            # Scope missing or API not enabled
            return {
                "ok": False,
                "error": "Cloud Resource Manager API not enabled or cloud-platform scope required.",
                "scope_missing": True,
                "create_project_url": "https://console.cloud.google.com/projectcreate",
                "projects": []
            }
        return {"ok": False, "error": f"HTTP {status_code}: {err_msg}", "projects": []}
    except Exception as e:
        return {"ok": False, "error": str(e), "projects": []}


def verify_gcp_setup(project_id: str, location: Optional[str] = None) -> Dict[str, Any]:
    """
    Runs the 4-step verification checklist:
    1. Billing enabled on project (Cloud Billing API)
    2. Vertex AI API (aiplatform.googleapis.com) enabled (Service Usage API)
    3. User permissions & model availability
    4. Tiny test call (latency measurement)
    """
    if not project_id:
        return {"ok": False, "error": "Project ID is required."}

    token = auth.get_valid_access_token()
    if not token:
        return {"ok": False, "error": "User not authenticated with Google.", "needs_auth": True}

    cfg = config.load_config()
    loc = location or cfg.get("gemini_default_location", "us-central1")
    model = cfg.get("gemini_line_model", "gemini-2.5-flash")

    results = {
        "project_id": project_id,
        "location": loc,
        "model": model,
        "checks": {
            "billing": {"passed": False, "message": "", "fix_url": f"https://console.cloud.google.com/billing/linkedaccount?project={project_id}"},
            "api_enabled": {"passed": False, "message": "", "fix_url": f"https://console.cloud.google.com/apis/library/aiplatform.googleapis.com?project={project_id}"},
            "permissions": {"passed": False, "message": "", "fix_url": f"https://console.cloud.google.com/iam-admin/iam?project={project_id}"},
            "test_call": {"passed": False, "latency_ms": 0, "message": ""}
        },
        "all_passed": False
    }

    # --- Check 1: Billing enabled ---
    billing_url = f"https://cloudbilling.googleapis.com/v1/projects/{project_id}/billingInfo"
    b_req = urllib.request.Request(billing_url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(b_req, timeout=10, context=config.get_ssl_context()) as resp:
            b_data = json.loads(resp.read().decode("utf-8"))
            if b_data.get("billingEnabled"):
                results["checks"]["billing"]["passed"] = True
                results["checks"]["billing"]["message"] = f"Billing account active: {b_data.get('billingAccountName', '')}"
            else:
                results["checks"]["billing"]["passed"] = False
                results["checks"]["billing"]["message"] = "Billing is not enabled on this project."
    except urllib.error.HTTPError as e:
        results["checks"]["billing"]["passed"] = False
        results["checks"]["billing"]["message"] = f"Cloud Billing check returned HTTP {e.code}."
    except Exception as e:
        results["checks"]["billing"]["passed"] = False
        results["checks"]["billing"]["message"] = f"Could not verify billing: {e}"

    # --- Check 2: Vertex AI API Enabled ---
    svc_url = f"https://serviceusage.googleapis.com/v1/projects/{project_id}/services/aiplatform.googleapis.com"
    s_req = urllib.request.Request(svc_url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(s_req, timeout=10, context=config.get_ssl_context()) as resp:
            s_data = json.loads(resp.read().decode("utf-8"))
            if s_data.get("state") == "ENABLED":
                results["checks"]["api_enabled"]["passed"] = True
                results["checks"]["api_enabled"]["message"] = "Vertex AI API (aiplatform.googleapis.com) is enabled."
            else:
                # Attempt to automatically enable it
                results["checks"]["api_enabled"]["passed"] = False
                results["checks"]["api_enabled"]["message"] = "Vertex AI API is not enabled on this project."
    except urllib.error.HTTPError as e:
        results["checks"]["api_enabled"]["passed"] = False
        results["checks"]["api_enabled"]["message"] = f"Service Usage check returned HTTP {e.code}."
    except Exception as e:
        results["checks"]["api_enabled"]["passed"] = False
        results["checks"]["api_enabled"]["message"] = f"Could not check API status: {e}"

    # --- Check 3 & 4: Permission & Tiny Test Call ---
    # Endpoint: https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/publishers/google/models/{model}:generateContent
    test_url = f"https://{loc}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{loc}/publishers/google/models/{model}:generateContent"
    test_payload = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": "ping"}]
            }
        ],
        "generationConfig": {
            "temperature": 0.0,
            "maxOutputTokens": 5
        }
    }
    t_req = urllib.request.Request(
        test_url,
        data=json.dumps(test_payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
    )

    t0 = time.time()
    try:
        with urllib.request.urlopen(t_req, timeout=15, context=config.get_ssl_context()) as resp:
            latency = int((time.time() - t0) * 1000)
            t_data = json.loads(resp.read().decode("utf-8"))
            results["checks"]["permissions"]["passed"] = True
            results["checks"]["permissions"]["message"] = "User has Vertex AI user permissions on project."
            results["checks"]["test_call"]["passed"] = True
            results["checks"]["test_call"]["latency_ms"] = latency
            results["checks"]["test_call"]["message"] = f"Successfully generated test token in {latency} ms."
            # If test call succeeds, billing and API must be functionally active
            results["checks"]["billing"]["passed"] = True
            results["checks"]["api_enabled"]["passed"] = True
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        if e.code == 403:
            results["checks"]["permissions"]["passed"] = False
            results["checks"]["permissions"]["message"] = f"Permission denied (HTTP 403). Ensure 'Vertex AI User' role is assigned."
        elif e.code == 404:
            results["checks"]["test_call"]["passed"] = False
            results["checks"]["test_call"]["message"] = f"Model {model} not found in location {loc} (HTTP 404)."
        elif e.code == 429:
            results["checks"]["test_call"]["passed"] = False
            results["checks"]["test_call"]["message"] = "Quota exceeded (HTTP 429). Please check quotas in Cloud Console."
        else:
            results["checks"]["test_call"]["passed"] = False
            results["checks"]["test_call"]["message"] = f"HTTP {e.code}: {err_body[:200]}"
    except Exception as e:
        results["checks"]["test_call"]["passed"] = False
        results["checks"]["test_call"]["message"] = f"Test call error: {e}"

    all_passed = (
        results["checks"]["billing"]["passed"] and
        results["checks"]["api_enabled"]["passed"] and
        results["checks"]["permissions"]["passed"] and
        results["checks"]["test_call"]["passed"]
    )
    results["all_passed"] = all_passed

    if all_passed:
        save_gcp_settings({
            "project_id": project_id,
            "location": loc,
            "line_model": model,
            "verified": True,
            "connection_mode": "oauth_vertex"
        })

    return results


def set_custom_api_key(api_key: str) -> Dict[str, Any]:
    """
    Stores user's Gemini Developer API key in macOS Keychain.
    Verifies key with a test call before saving.
    """
    if not api_key:
        return {"ok": False, "error": "API key cannot be empty."}

    test_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    test_payload = {
        "contents": [{"role": "user", "parts": [{"text": "ping"}]}],
        "generationConfig": {"temperature": 0.0, "maxOutputTokens": 5}
    }
    req = urllib.request.Request(
        test_url,
        data=json.dumps(test_payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=12, context=config.get_ssl_context()) as resp:
            latency = int((time.time() - t0) * 1000)
            keyring.set_password(auth.SERVICE_NAME, KEYRING_GEMINI_KEY, api_key)
            save_gcp_settings({"connection_mode": "api_key", "verified": True})
            return {"ok": True, "latency_ms": latency, "mode": "api_key"}
    except urllib.error.HTTPError as e:
        return {"ok": False, "error": f"API key test failed: HTTP {e.code}"}
    except Exception as e:
        return {"ok": False, "error": f"API key test failed: {e}"}


def get_stored_api_key() -> Optional[str]:
    """Retrieves API key securely from native OS Keychain."""
    try:
        return keyring.get_password(auth.SERVICE_NAME, KEYRING_GEMINI_KEY)
    except Exception:
        return None
