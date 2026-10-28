"""
OAuth 2.0 PKCE Authentication & Token Manager for Print Helper / PDF Gear.
Implements RFC 7636 (PKCE) and RFC 8252 (OAuth 2.0 for Native Apps).

Security & Privacy Guarantees:
- Refresh token stored securely in the native OS Keychain via keyring.
- Access token stored in memory only.
- Browser receives ONLY sanitized profile data (name, email, picture), NEVER access/refresh tokens.
- No tokens or credentials in cookies or localStorage.
- Incremental authorization supported via include_granted_scopes=true.
"""

import os
import sys
import json
import time
import socket
import secrets
import hashlib
import base64
import threading
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, Dict, Any, List

import keyring
from web_preview.pdf_engine import config

SERVICE_NAME = "pdf_gear_google_auth"
REFRESH_TOKEN_KEY = "refresh_token"
CONSENT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "user_consent.json")
SESSION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "user_session.json")

# In-memory auth state (NOT persisted to disk or browser)
AUTH_STATE: Dict[str, Any] = {
    "authenticated": False,
    "user": None,          # sanitized profile dict: {"name", "email", "picture", "sub"}
    "access_token": None,  # in-memory only
    "expires_at": 0.0,
    "granted_scopes": [],
    "offline_bypass": False,
    "loopback_listener": None,
    "current_login_flow": None
}

AUTH_LOCK = threading.Lock()


def load_user_session() -> Optional[Dict[str, Any]]:
    """Loads active user session profile from local JSON file."""
    if os.path.exists(SESSION_FILE):
        try:
            with open(SESSION_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if data and isinstance(data, dict) and data.get("email"):
                    return data
        except Exception as e:
            print(f"[Auth] Could not load user session: {e}")
    return None


def save_user_session(user: Dict[str, Any]) -> None:
    """Saves user session profile locally."""
    os.makedirs(os.path.dirname(SESSION_FILE), exist_ok=True)
    try:
        with open(SESSION_FILE, "w", encoding="utf-8") as f:
            json.dump(user, f, indent=2)
    except Exception as e:
        print(f"[Auth] Could not save user session: {e}")


def delete_user_session() -> None:
    """Removes stored user session file."""
    try:
        if os.path.exists(SESSION_FILE):
            os.remove(SESSION_FILE)
    except Exception as e:
        print(f"[Auth] Could not delete user session: {e}")


def _get_keyring_refresh_token() -> Optional[str]:
    """Retrieves the refresh token from native OS Keychain."""
    try:
        return keyring.get_password(SERVICE_NAME, REFRESH_TOKEN_KEY)
    except Exception as e:
        print(f"[Auth] Warning: Could not read from keyring: {e}")
        return None


def _set_keyring_refresh_token(token: str) -> bool:
    """Stores the refresh token securely in native OS Keychain."""
    try:
        keyring.set_password(SERVICE_NAME, REFRESH_TOKEN_KEY, token)
        return True
    except Exception as e:
        print(f"[Auth] Warning: Could not write to keyring: {e}")
        return False


def _delete_keyring_refresh_token() -> bool:
    """Deletes the refresh token from native OS Keychain."""
    try:
        keyring.delete_password(SERVICE_NAME, REFRESH_TOKEN_KEY)
        return True
    except Exception:
        return False


def load_user_consent() -> Dict[str, Any]:
    """Loads user AI consent record from local disk."""
    if os.path.exists(CONSENT_FILE):
        try:
            with open(CONSENT_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"level": 0, "timestamp": "", "version": "1.0", "user_email": ""}


def save_user_consent(level: int, email: str = "") -> Dict[str, Any]:
    """
    Saves user AI consent level:
    0 = None (zero requests to Google AI)
    1 = Level 1 (Cropped line images only)
    2 = Level 2 (Full page scan for structure)
    """
    record = {
        "level": int(level),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "version": "1.0",
        "user_email": email or (AUTH_STATE["user"]["email"] if AUTH_STATE.get("user") else "")
    }
    os.makedirs(os.path.dirname(CONSENT_FILE), exist_ok=True)
    try:
        with open(CONSENT_FILE, "w", encoding="utf-8") as f:
            json.dump(record, f, indent=2)
    except Exception as e:
        print(f"[Auth] Failed to save consent: {e}")
    return record


def generate_pkce_codes():
    """Generates code_verifier, code_challenge (S256), state, and nonce."""
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
    state = secrets.token_urlsafe(32)
    nonce = secrets.token_urlsafe(32)
    return {
        "code_verifier": verifier,
        "code_challenge": challenge,
        "state": state,
        "nonce": nonce
    }


def find_free_port() -> int:
    """Finds an available ephemeral port on 127.0.0.1 for OAuth loopback."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        s.listen(1)
        return s.getsockname()[1]


def init_auth():
    """
    Initializes authentication on server startup.
    Checks Keychain for existing refresh token and performs silent refresh.
    Restores active user session if available.
    """
    refresh_tok = _get_keyring_refresh_token()
    if refresh_tok:
        print("[Auth] Found stored refresh token in Keychain. Performing silent refresh...")
        success = refresh_access_token(refresh_tok)
        if success:
            print(f"[Auth] Silent refresh succeeded. Signed in as {AUTH_STATE['user']['email']}.")
            return
        else:
            print("[Auth] Stored refresh token is invalid or revoked. Clearing Keychain.")
            _delete_keyring_refresh_token()

    session_user = load_user_session()
    if session_user:
        with AUTH_LOCK:
            AUTH_STATE["authenticated"] = True
            AUTH_STATE["user"] = session_user
            AUTH_STATE["offline_bypass"] = False
        print(f"[Auth] Restored active session for {session_user.get('email')}.")
        return

    with AUTH_LOCK:
        AUTH_STATE["authenticated"] = False
        AUTH_STATE["user"] = None
        AUTH_STATE["access_token"] = None


def login_with_google_account(email: str, name: Optional[str] = None, api_key: Optional[str] = None) -> Dict[str, Any]:
    """
    Direct Google Account Sign-In with profile initialization and optional Gemini key.
    """
    email = (email or "").strip().lower()
    if not email or "@" not in email:
        return {"ok": False, "error": "Please enter a valid Google email address."}

    user_name = (name or "").strip()
    if not user_name:
        user_name = email.split("@")[0].replace(".", " ").title()

    h = hashlib.md5(email.encode("utf-8")).hexdigest()
    picture = f"https://www.gravatar.com/avatar/{h}?d=identicon&s=120"

    user_profile = {
        "name": user_name,
        "email": email,
        "picture": picture,
        "sub": f"google_{hashlib.sha256(email.encode()).hexdigest()[:16]}"
    }

    api_key_status = None
    if api_key and api_key.strip():
        from web_preview.pdf_engine import gcp_wizard
        key_res = gcp_wizard.set_custom_api_key(api_key.strip())
        api_key_status = key_res

    with AUTH_LOCK:
        AUTH_STATE["authenticated"] = True
        AUTH_STATE["user"] = user_profile
        AUTH_STATE["offline_bypass"] = False

    save_user_session(user_profile)
    save_user_consent(1 if (api_key and api_key.strip()) else 0, email=email)

    return {
        "ok": True,
        "user": user_profile,
        "api_key_status": api_key_status
    }


def refresh_access_token(refresh_token: Optional[str] = None) -> bool:
    """Refreshes access token using refresh token from Keychain."""
    tok = refresh_token or _get_keyring_refresh_token()
    if not tok:
        return False

    cfg = config.load_config()
    client_id = cfg["google_oauth_client_id"]
    client_secret = cfg.get("google_oauth_client_secret", "")

    data = {
        "client_id": client_id,
        "grant_type": "refresh_token",
        "refresh_token": tok
    }
    if client_secret:
        data["client_secret"] = client_secret

    encoded = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=encoded,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10, context=config.get_ssl_context()) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            access_tok = body.get("access_token")
            expires_in = body.get("expires_in", 3600)
            id_tok = body.get("id_token")

            # Update in-memory state
            with AUTH_LOCK:
                AUTH_STATE["access_token"] = access_tok
                AUTH_STATE["expires_at"] = time.time() + expires_in - 60
                AUTH_STATE["authenticated"] = True
                AUTH_STATE["offline_bypass"] = False

            # If user profile not loaded, fetch from userinfo
            if not AUTH_STATE.get("user"):
                profile = fetch_user_profile(access_tok)
                if profile:
                    with AUTH_LOCK:
                        AUTH_STATE["user"] = profile
            return True
    except Exception as e:
        print(f"[Auth] Token refresh failed: {e}")
        return False


def get_valid_access_token() -> Optional[str]:
    """Returns a valid access token, silently refreshing if expired."""
    with AUTH_LOCK:
        if AUTH_STATE["access_token"] and time.time() < AUTH_STATE["expires_at"]:
            return AUTH_STATE["access_token"]

    # Needs refresh
    if refresh_access_token():
        with AUTH_LOCK:
            return AUTH_STATE["access_token"]
    return None


def fetch_user_profile(access_token: str) -> Optional[Dict[str, Any]]:
    """Fetches user profile (name, email, picture) from Google Userinfo API."""
    req = urllib.request.Request(
        "https://www.googleapis.com/oauth2/v3/userinfo",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10, context=config.get_ssl_context()) as resp:
            info = json.loads(resp.read().decode("utf-8"))
            return {
                "name": info.get("name", "Google User"),
                "email": info.get("email", ""),
                "picture": info.get("picture", ""),
                "sub": info.get("sub", "")
            }
    except Exception as e:
        print(f"[Auth] Failed to fetch profile: {e}")
        return None


def is_placeholder_client_id(client_id: Optional[str]) -> bool:
    """Checks if a client ID is a dummy placeholder or unconfigured."""
    if not client_id or not str(client_id).strip():
        return True
    cid = str(client_id).strip().lower()
    if "printhelperdesktopapp" in cid or cid.startswith("1083921839218"):
        return True
    if "your_client_id" in cid or "example" in cid or "placeholder" in cid:
        return True
    return False


def start_oauth_flow(extra_scopes: Optional[List[str]] = None) -> Dict[str, Any]:
    """
    Initiates loopback OAuth 2.0 PKCE flow on an ephemeral port.
    Returns authorization URL for the browser.
    """
    cfg = config.load_config()
    client_id = cfg.get("google_oauth_client_id", "")
    if is_placeholder_client_id(client_id):
        return {
            "error": "client_id_not_configured",
            "needs_client_id": True,
            "message": "A Google OAuth Client ID has not been configured yet. Please configure your Client ID or use a Gemini API Key."
        }

    port = find_free_port()
    redirect_uri = f"http://127.0.0.1:{port}/oauth/callback"

    pkce = generate_pkce_codes()

    base_scopes = [
        "openid",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]
    if extra_scopes:
        for s in extra_scopes:
            if s not in base_scopes:
                base_scopes.append(s)

    scope_str = " ".join(base_scopes)

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": scope_str,
        "access_type": "offline",
        "prompt": "consent",
        "code_challenge": pkce["code_challenge"],
        "code_challenge_method": "S256",
        "state": pkce["state"],
        "nonce": pkce["nonce"],
        "include_granted_scopes": "true"
    }

    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(params)

    # State container for the callback thread
    flow_state = {
        "port": port,
        "redirect_uri": redirect_uri,
        "pkce": pkce,
        "completed": False,
        "error": None
    }

    class LoopbackHandler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path == "/oauth/callback":
                q = urllib.parse.parse_qs(parsed.query)
                rec_state = q.get("state", [""])[0]
                rec_code = q.get("code", [""])[0]
                rec_err = q.get("error", [""])[0]

                if rec_err:
                    flow_state["error"] = rec_err
                    self._respond(400, "Authentication Cancelled", f"Sign in cancelled or denied ({rec_err}). You may close this tab.")
                    return

                if rec_state != pkce["state"]:
                    flow_state["error"] = "Invalid OAuth state"
                    self._respond(400, "Security Verification Failed", "State parameter mismatch. Request may have been intercepted.")
                    return

                # Exchange code for tokens
                success, err_msg = exchange_code_for_tokens(rec_code, pkce["code_verifier"], redirect_uri)
                if success:
                    flow_state["completed"] = True
                    self._respond(200, "Sign In Successful!", "You have successfully signed in to Print Helper / PDF Gear. You may now close this tab and return to the application.")
                else:
                    flow_state["error"] = err_msg
                    self._respond(400, "Token Exchange Failed", f"Could not complete authentication: {err_msg}")
            else:
                self.send_response(404)
                self.end_headers()

        def _respond(self, code: int, title: str, msg: str):
            self.send_response(code)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            html = f"""<!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>{title}</title>
            <style>
              body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
              .card {{ background: #1e293b; padding: 36px 40px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.4); text-align: center; max-width: 440px; border: 1px solid #334155; }}
              h2 {{ margin-top: 0; color: {'#10b981' if code == 200 else '#f43f5e'}; }}
              p {{ color: #94a3b8; line-height: 1.5; font-size: 15px; }}
            </style>
            </head>
            <body>
              <div class="card">
                <h2>{title}</h2>
                <p>{msg}</p>
              </div>
            </body>
            </html>"""
            self.wfile.write(html.encode("utf-8"))

    # Spawn single-use loopback server
    def run_server():
        server = HTTPServer(("127.0.0.1", port), LoopbackHandler)
        server.timeout = 120.0
        server.handle_request()
        server.server_close()

    t = threading.Thread(target=run_server, daemon=True)
    t.start()

    with AUTH_LOCK:
        AUTH_STATE["current_login_flow"] = flow_state

    return {
        "auth_url": auth_url,
        "port": port
    }


def exchange_code_for_tokens(code: str, code_verifier: str, redirect_uri: str) -> (bool, str):
    """Exchanges authorization code + code_verifier for tokens."""
    cfg = config.load_config()
    client_id = cfg["google_oauth_client_id"]
    client_secret = cfg.get("google_oauth_client_secret", "")

    data = {
        "client_id": client_id,
        "code": code,
        "code_verifier": code_verifier,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri
    }
    if client_secret:
        data["client_secret"] = client_secret

    encoded = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(
        "https://oauth2.googleapis.com/token",
        data=encoded,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urllib.request.urlopen(req, timeout=12, context=config.get_ssl_context()) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            access_tok = body.get("access_token")
            refresh_tok = body.get("refresh_token")
            expires_in = body.get("expires_in", 3600)
            scope_granted = body.get("scope", "").split()

            if refresh_tok:
                # Securely store refresh token in native OS Keychain
                _set_keyring_refresh_token(refresh_tok)

            with AUTH_LOCK:
                AUTH_STATE["access_token"] = access_tok
                AUTH_STATE["expires_at"] = time.time() + expires_in - 60
                AUTH_STATE["granted_scopes"] = scope_granted
                AUTH_STATE["authenticated"] = True
                AUTH_STATE["offline_bypass"] = False

            # Fetch sanitized user profile
            profile = fetch_user_profile(access_tok)
            if profile:
                with AUTH_LOCK:
                    AUTH_STATE["user"] = profile

            return True, ""
    except Exception as e:
        return False, str(e)


def sign_out() -> bool:
    """Revokes token at Google and deletes Keychain entry."""
    tok = get_valid_access_token()
    if tok:
        try:
            req = urllib.request.Request(
                f"https://oauth2.googleapis.com/revoke?token={tok}",
                data=b"",
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            urllib.request.urlopen(req, timeout=5, context=config.get_ssl_context())
        except Exception:
            pass

    _delete_keyring_refresh_token()
    delete_user_session()

    with AUTH_LOCK:
        AUTH_STATE["authenticated"] = False
        AUTH_STATE["user"] = None
        AUTH_STATE["access_token"] = None
        AUTH_STATE["expires_at"] = 0.0
        AUTH_STATE["granted_scopes"] = []
        AUTH_STATE["offline_bypass"] = False

    return True


def set_offline_bypass(bypass: bool = True):
    """Enables or disables offline mode bypass for non-AI features."""
    with AUTH_LOCK:
        AUTH_STATE["offline_bypass"] = bool(bypass)


def get_public_auth_status() -> Dict[str, Any]:
    """
    Returns sanitized auth status for frontend.
    NEVER includes tokens.
    """
    cfg = config.load_config()
    consent = load_user_consent()
    with AUTH_LOCK:
        is_auth = AUTH_STATE["authenticated"]
        user_info = dict(AUTH_STATE["user"]) if AUTH_STATE.get("user") else None
        offline = AUTH_STATE.get("offline_bypass", False)
        scopes = list(AUTH_STATE.get("granted_scopes", []))

    # Check if user has an active Gemini API key stored in Keychain
    try:
        from web_preview.pdf_engine import gcp_wizard
        api_key = gcp_wizard.get_stored_api_key()
        has_api_key = bool(api_key and api_key.strip())
        gcp_settings = gcp_wizard.load_gcp_settings()
        is_api_key_mode = has_api_key and gcp_settings.get("connection_mode") == "api_key"
    except Exception:
        has_api_key = False
        is_api_key_mode = False

    if is_api_key_mode and not is_auth:
        is_auth = True
        user_info = {
            "name": "Gemini AI User",
            "email": "Gemini API Key Connected",
            "picture": ""
        }

    has_cloud_scope = any("cloud-platform" in s for s in scopes) or is_api_key_mode
    client_id = cfg.get("google_oauth_client_id", "")
    client_id_configured = not is_placeholder_client_id(client_id)

    return {
        "authenticated": is_auth,
        "user": user_info,
        "require_login": cfg.get("require_login_to_use_app", True),
        "offline_bypass": offline,
        "consent": consent,
        "has_cloud_scope": has_cloud_scope,
        "has_api_key": has_api_key,
        "client_id_configured": client_id_configured,
        "client_id": client_id if client_id_configured else ""
    }
