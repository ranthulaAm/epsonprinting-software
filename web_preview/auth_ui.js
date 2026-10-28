/**
 * auth_ui.js - Google OAuth 2.0 PKCE, Dynamic Privacy Badge, and User Consent Management.
 * Works seamlessly with Python pdf_engine/auth.py and respects dark/light themes and EN/SI.
 */

(function () {
  "use strict";

  let pollInterval = null;

  async function fetchAuthStatus() {
    try {
      const resp = await fetch("/api/auth/status");
      if (!resp.ok) return null;
      return await resp.json();
    } catch (e) {
      console.warn("[AuthUI] Could not fetch auth status:", e);
      return null;
    }
  }

  function updatePrivacyBadge(level) {
    const badge = document.getElementById("headerPrivacyBadge");
    const icon = document.getElementById("headerPrivacyIcon");
    const lbl = document.getElementById("lblPrivacyStatus");
    if (!badge || !icon || !lbl) return;

    badge.classList.remove("mode-offline", "mode-cloud-lines", "mode-cloud-page");

    const isSi = (typeof currentLang !== "undefined" && currentLang === "si");

    if (level === 1) {
      badge.classList.add("mode-cloud-lines");
      icon.innerText = "cloud_done";
      lbl.innerText = isSi ? "Cloud AI ක්‍රියාත්මකයි (කැපූ පෙළ පේළි පමණි)" : "Cloud AI on (cropped lines)";
    } else if (level === 2) {
      badge.classList.add("mode-cloud-page");
      icon.innerText = "auto_awesome";
      lbl.innerText = isSi ? "Cloud AI ක්‍රියාත්මකයි (සම්පූර්ණ පිටුව)" : "Cloud AI on (full page)";
    } else {
      badge.classList.add("mode-offline");
      icon.innerText = "shield";
      lbl.innerText = isSi ? "නොබැඳි - කිසිවක් මෙම පරිගණකයෙන් පිටතට නොයයි" : "Offline - nothing leaves this computer";
    }
  }

  function updateAuthUI(status) {
    if (!status) return;

    const overlay = document.getElementById("fullScreenLoginOverlay");
    const userDisplay = document.getElementById("userDisplayName");
    const userMenuName = document.getElementById("userMenuName");
    const userMenuEmail = document.getElementById("userMenuEmail");
    const userAvatarImg = document.getElementById("userAvatarImg");
    const userMenuAvatar = document.getElementById("userMenuAvatar");
    const connPill = document.getElementById("userConnectionStatus");
    const unauthSec = document.getElementById("userMenuUnauthSection");
    const authSec = document.getElementById("userMenuAuthSection");

    // Login enforcement: if unauthenticated & require_login & not offline_bypass, show overlay
    if (overlay) {
      if (!status.authenticated && !status.offline_bypass && status.require_login) {
        overlay.classList.remove("hidden");
      } else {
        overlay.classList.add("hidden");
      }
    }

    // Dynamic Privacy Badge based on consent level
    const consentLevel = status.consent ? status.consent.level : 0;
    updatePrivacyBadge(consentLevel);

    // Profile & Menu details
    const isSi = (typeof currentLang !== "undefined" && currentLang === "si");

    if (status.authenticated && status.user) {
      const u = status.user;
      if (userDisplay) userDisplay.innerText = u.name || u.email || "Google User";
      if (userMenuName) userMenuName.innerText = u.name || "Google User";
      if (userMenuEmail) userMenuEmail.innerText = u.email || "";

      if (u.picture) {
        if (userAvatarImg) userAvatarImg.src = u.picture;
        if (userMenuAvatar) userMenuAvatar.src = u.picture;
      }

      if (connPill) {
        connPill.innerText = status.has_cloud_scope ? "Connected (GCP)" : (status.has_api_key ? "Connected (Gemini)" : "Signed In");
        connPill.className = "conn-pill online";
      }

      if (authSec) authSec.classList.remove("hidden");
      if (unauthSec) unauthSec.classList.add("hidden");
    } else {
      if (userDisplay) userDisplay.innerText = isSi ? "පුරනය වන්න" : "Sign In";
      if (userMenuName) userMenuName.innerText = isSi ? "පුරනය වී නැත" : "Not Signed In";
      if (userMenuEmail) userMenuEmail.innerText = isSi ? "Google මඟින් පුරනය වන්න" : "Sign in with Google";

      if (userAvatarImg) {
        userAvatarImg.src = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28'><circle cx='14' cy='14' r='14' fill='%234285F4'/><text x='14' y='18' text-anchor='middle' fill='%23fff' font-size='12' font-family='sans-serif' font-weight='bold'>G</text></svg>";
      }
      if (userMenuAvatar) {
        userMenuAvatar.src = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='36' height='36'><circle cx='18' cy='18' r='18' fill='%234285F4'/><text x='18' y='23' text-anchor='middle' fill='%23fff' font-size='16' font-family='sans-serif' font-weight='bold'>G</text></svg>";
      }

      if (connPill) {
        connPill.innerText = isSi ? "නොබැඳි" : "Offline";
        connPill.className = "conn-pill offline";
      }

      if (authSec) authSec.classList.add("hidden");
      if (unauthSec) unauthSec.classList.remove("hidden");
    }
  }

  function startAuthPolling() {
    if (pollInterval) clearInterval(pollInterval);
    pollInterval = setInterval(async () => {
      const st = await fetchAuthStatus();
      if (st && st.authenticated) {
        clearInterval(pollInterval);
        pollInterval = null;
        updateAuthUI(st);
        const btnSignIn = document.getElementById("btnGoogleSignIn");
        if (btnSignIn) {
          btnSignIn.disabled = false;
          btnSignIn.innerHTML = `
            <svg class="google-g-logo" viewBox="0 0 24 24" width="20" height="20">
              <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
              <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
              <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
              <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
            </svg>
            <span id="lblSignInGoogle">Sign in with Google Account</span>
          `;
        }
        if (window.showToast) {
          const isSi = (typeof currentLang !== "undefined" && currentLang === "si");
          window.showToast(isSi ? `සාර්ථකව පුරනය විය: ${st.user?.name || ""}` : `Successfully signed in as ${st.user?.name || "Google User"}`);
        }
      }
    }, 1200);
  }

  async function handleGoogleAccountSignIn() {
    const emailInput = document.getElementById("txtLoginGoogleEmail");
    const nameInput = document.getElementById("txtLoginGoogleName");
    const keyInput = document.getElementById("txtLoginApiKey");
    const btn = document.getElementById("btnGoogleSignIn");

    const email = (emailInput?.value || "").trim();
    const name = (nameInput?.value || "").trim();
    const apiKey = (keyInput?.value || "").trim();

    if (!email || !email.includes("@")) {
      alert("Please enter a valid Google Account email (e.g. name@gmail.com).");
      emailInput?.focus();
      return;
    }

    try {
      if (btn) {
        btn.disabled = true;
        btn.innerHTML = `<span class="material-symbols-rounded spin">sync</span> <span>Signing in...</span>`;
      }

      const resp = await fetch("/api/auth/google-sign-in", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, name, api_key: apiKey })
      });
      const data = await resp.json();

      if (btn) {
        btn.disabled = false;
        btn.innerHTML = `
          <svg class="google-g-logo" viewBox="0 0 24 24" width="20" height="20">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
          </svg>
          <span id="lblSignInGoogle">Sign in with Google Account</span>
        `;
      }

      if (data.ok && data.user) {
        const overlay = document.getElementById("fullScreenLoginOverlay");
        if (overlay) overlay.classList.add("hidden");
        const st = await fetchAuthStatus();
        updateAuthUI(st);
        if (window.showToast) {
          const isSi = (typeof currentLang !== "undefined" && currentLang === "si");
          window.showToast(isSi ? `සාර්ථකව පුරනය විය: ${data.user.name || data.user.email}` : `Signed in as ${data.user.name || data.user.email}`);
        }
      } else {
        alert("Sign-in failed: " + (data.error || "Please try again."));
      }
    } catch (e) {
      console.error("[AuthUI] Sign in error:", e);
      if (btn) btn.disabled = false;
      alert("Sign-in error: " + e.message);
    }
  }

  async function handleGoogleOAuthSignIn(extraScopes = []) {
    const btn = document.getElementById("btnGoogleSignIn");
    try {
      if (btn) {
        btn.disabled = true;
        btn.innerHTML = `<span class="material-symbols-rounded spin">sync</span> <span>Connecting...</span>`;
      }
      const resp = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ extra_scopes: extraScopes })
      });
      const data = await resp.json();
      if (data.needs_client_id) {
        if (btn) {
          btn.disabled = false;
          btn.innerHTML = `
            <svg class="google-g-logo" viewBox="0 0 24 24" width="20" height="20">
              <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
              <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
              <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
              <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
            </svg>
            <span id="lblSignInGoogle">Sign in with Google Account</span>
          `;
        }
        openCredentialsModal();
        return;
      }
      if (data.auth_url) {
        window.open(data.auth_url, "_blank");
        startAuthPolling();
      } else {
        alert("Failed to start OAuth flow: " + (data.error || "Unknown error"));
        if (btn) btn.disabled = false;
      }
    } catch (e) {
      console.error("[AuthUI] Sign in failed:", e);
      if (btn) btn.disabled = false;
      if (window.showToast) window.showToast("Could not reach local auth service: " + e.message);
    }
  }

  async function handleContinueOffline() {
    try {
      await fetch("/api/auth/bypass", { method: "POST" });
      const overlay = document.getElementById("fullScreenLoginOverlay");
      if (overlay) overlay.classList.add("hidden");
      const st = await fetchAuthStatus();
      updateAuthUI(st);
      if (window.showToast) {
        const isSi = (typeof currentLang !== "undefined" && currentLang === "si");
        window.showToast(isSi ? "නොබැඳි මෙහෙයුම් සඳහා සූදානම් (සියලු දේශීය මෙවලම් සක්‍රියයි)" : "Continuing in offline mode (all local tools active)");
      }
    } catch (e) {
      console.error("[AuthUI] Offline bypass failed:", e);
    }
  }

  async function handleSignOut() {
    try {
      await fetch("/api/auth/logout", { method: "POST" });
      const st = await fetchAuthStatus();
      updateAuthUI(st);
      const menu = document.getElementById("userMenuDropdown");
      if (menu) menu.classList.add("hidden");
      const overlay = document.getElementById("fullScreenLoginOverlay");
      if (overlay) overlay.classList.remove("hidden");
      if (window.showToast) {
        const isSi = (typeof currentLang !== "undefined" && currentLang === "si");
        window.showToast(isSi ? "ගිණුමෙන් ඉවත් විය" : "Signed out of Google account");
      }
    } catch (e) {
      console.error("[AuthUI] Sign out failed:", e);
    }
  }

  function setupAuthEventListeners() {
    // Form and Sign In button
    const formGoogle = document.getElementById("formGoogleSignIn");
    if (formGoogle) {
      formGoogle.addEventListener("submit", (e) => {
        e.preventDefault();
        handleGoogleAccountSignIn();
      });
    }

    const btnSignIn = document.getElementById("btnGoogleSignIn");
    if (btnSignIn) {
      btnSignIn.addEventListener("click", (e) => {
        e.preventDefault();
        handleGoogleAccountSignIn();
      });
    }

    // Continue Offline & Close Overlay
    const btnOffline = document.getElementById("btnContinueOffline");
    if (btnOffline) {
      btnOffline.addEventListener("click", handleContinueOffline);
    }

    const btnCloseOverlay = document.getElementById("btnCloseLoginOverlay");
    if (btnCloseOverlay) {
      btnCloseOverlay.addEventListener("click", handleContinueOffline);
    }

    // Dropdown Sign In Button
    const btnDropdownSignIn = document.getElementById("btnDropdownSignIn");
    if (btnDropdownSignIn) {
      btnDropdownSignIn.addEventListener("click", () => {
        const userMenuDropdown = document.getElementById("userMenuDropdown");
        if (userMenuDropdown) userMenuDropdown.classList.add("hidden");
        const overlay = document.getElementById("fullScreenLoginOverlay");
        if (overlay) overlay.classList.remove("hidden");
      });
    }

    // Login Overlay Lang & Theme toggles
    const btnLoginLang = document.getElementById("btnLoginLangToggle");
    if (btnLoginLang) {
      btnLoginLang.addEventListener("click", () => {
        if (window.toggleLang) window.toggleLang();
        const lbl = document.getElementById("loginLangLabel");
        if (lbl) lbl.innerText = (typeof currentLang !== "undefined" && currentLang === "si") ? "සිංහල" : "English";
      });
    }

    const btnLoginTheme = document.getElementById("btnLoginThemeToggle");
    if (btnLoginTheme) {
      btnLoginTheme.addEventListener("click", () => {
        if (window.toggleTheme) window.toggleTheme();
        const icon = document.getElementById("loginThemeIcon");
        if (icon) icon.innerText = (typeof currentTheme !== "undefined" && currentTheme === "dark") ? "light_mode" : "dark_mode";
      });
    }

    // Header User Menu Dropdown Toggle
    const btnUserMenu = document.getElementById("btnUserMenu");
    const userMenuDropdown = document.getElementById("userMenuDropdown");
    if (btnUserMenu && userMenuDropdown) {
      btnUserMenu.addEventListener("click", async (e) => {
        e.stopPropagation();
        const st = await fetchAuthStatus();
        if (!st || !st.authenticated) {
          // Open Login Overlay directly!
          const overlay = document.getElementById("fullScreenLoginOverlay");
          if (overlay) overlay.classList.remove("hidden");
        } else {
          userMenuDropdown.classList.toggle("hidden");
        }
      });

      document.addEventListener("click", (e) => {
        if (!btnUserMenu.contains(e.target) && !userMenuDropdown.contains(e.target)) {
          userMenuDropdown.classList.add("hidden");
        }
      });
    }

    // Menu Sign Out
    const btnSignOut = document.getElementById("btnMenuSignOut");
    if (btnSignOut) {
      btnSignOut.addEventListener("click", handleSignOut);
    }

    // Privacy & AI Consent Modal Trigger
    const btnPrivacyMenu = document.getElementById("btnMenuPrivacySettings");
    const privacyModal = document.getElementById("privacyConsentModal");
    if (btnPrivacyMenu && privacyModal) {
      btnPrivacyMenu.addEventListener("click", async () => {
        userMenuDropdown?.classList.add("hidden");
        const st = await fetchAuthStatus();
        const currentLevel = st?.consent?.level || 0;
        const rad = document.querySelector(`input[name="aiConsentLevel"][value="${currentLevel}"]`);
        if (rad) rad.checked = true;
        privacyModal.classList.remove("hidden");
      });
    }

    // Header Privacy Badge Click -> Open Consent Modal
    const headerBadge = document.getElementById("headerPrivacyBadge");
    if (headerBadge && privacyModal) {
      headerBadge.addEventListener("click", async () => {
        const st = await fetchAuthStatus();
        const currentLevel = st?.consent?.level || 0;
        const rad = document.querySelector(`input[name="aiConsentLevel"][value="${currentLevel}"]`);
        if (rad) rad.checked = true;
        privacyModal.classList.remove("hidden");
      });
    }

    // Save Consent Preferences
    const btnSaveConsent = document.getElementById("btnSaveConsentPreferences");
    if (btnSaveConsent && privacyModal) {
      btnSaveConsent.addEventListener("click", async () => {
        const checked = document.querySelector('input[name="aiConsentLevel"]:checked');
        const level = checked ? parseInt(checked.value, 10) : 0;
        try {
          const resp = await fetch("/api/auth/consent", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ level })
          });
          const rec = await resp.json();
          updatePrivacyBadge(rec.level);
          privacyModal.classList.add("hidden");
          if (window.showToast) {
            const isSi = (typeof currentLang !== "undefined" && currentLang === "si");
            window.showToast(isSi ? "AI එකඟතා සැකසුම් සුරැකිණි" : "Privacy & AI consent settings saved");
          }
        } catch (e) {
          console.error("[AuthUI] Failed to save consent:", e);
        }
      });
    }

    // Connect Gemini (User GCP Project) Wizard
    const btnConnectGemini = document.getElementById("btnMenuConnectGemini");
    const gcpModal = document.getElementById("gcpConnectModal");
    const tabOAuth = document.getElementById("tabGcpModeOAuth");
    const tabApiKey = document.getElementById("tabGcpModeApiKey");
    const panelOAuth = document.getElementById("panelGcpOAuth");
    const panelApiKey = document.getElementById("panelGcpApiKey");
    const selProject = document.getElementById("selGcpProject");
    const txtProjectId = document.getElementById("txtGcpProjectId");
    const selLocation = document.getElementById("selGcpLocation");
    const numDailyLimit = document.getElementById("numGcpDailyLimit");
    const btnRefresh = document.getElementById("btnRefreshProjects");
    const btnVerify = document.getElementById("btnVerifyConnectGcp");
    const verifyBox = document.getElementById("gcpVerifyChecklist");

    let currentGcpMode = "oauth";

    async function loadGcpProjects() {
      if (!selProject) return;
      selProject.innerHTML = `<option value="">Loading your Google Cloud projects...</option>`;
      try {
        const resp = await fetch("/api/gcp/projects");
        const data = await resp.json();
        selProject.innerHTML = `<option value="">Select a project or enter ID below...</option>`;
        if (data.ok && data.projects && data.projects.length > 0) {
          data.projects.forEach(p => {
            const opt = document.createElement("option");
            opt.value = p.id;
            opt.innerText = `${p.name} (${p.id})`;
            selProject.appendChild(opt);
          });
        } else if (data.scope_missing) {
          const opt = document.createElement("option");
          opt.value = "";
          opt.innerText = "Scope cloud-platform required (click re-auth)";
          selProject.appendChild(opt);
        }
      } catch (e) {
        selProject.innerHTML = `<option value="">Could not load projects (enter ID manually)</option>`;
      }
    }

    async function openGcpWizard() {
      userMenuDropdown?.classList.add("hidden");
      if (!gcpModal) return;
      gcpModal.classList.remove("hidden");
      if (verifyBox) verifyBox.style.display = "none";

      try {
        const resp = await fetch("/api/gcp/settings");
        const data = await resp.json();
        if (data.settings) {
          const s = data.settings;
          if (txtProjectId) txtProjectId.value = s.project_id || "";
          if (selLocation && s.location) selLocation.value = s.location;
          if (numDailyLimit && s.daily_page_limit) numDailyLimit.value = s.daily_page_limit;
          if (s.connection_mode === "api_key") {
            tabApiKey?.click();
          } else {
            tabOAuth?.click();
          }
        }
      } catch (e) {}

      loadGcpProjects();
    }

    if (btnConnectGemini) {
      btnConnectGemini.addEventListener("click", openGcpWizard);
    }

    if (tabOAuth && tabApiKey) {
      tabOAuth.addEventListener("click", () => {
        tabOAuth.classList.add("active");
        tabApiKey.classList.remove("active");
        panelOAuth?.classList.remove("hidden");
        panelApiKey?.classList.add("hidden");
        currentGcpMode = "oauth";
      });
      tabApiKey.addEventListener("click", () => {
        tabApiKey.classList.add("active");
        tabOAuth.classList.remove("active");
        panelApiKey?.classList.remove("hidden");
        panelOAuth?.classList.add("hidden");
        currentGcpMode = "api_key";
      });
    }

    if (selProject && txtProjectId) {
      selProject.addEventListener("change", () => {
        if (selProject.value) txtProjectId.value = selProject.value;
      });
    }

    if (btnRefresh) {
      btnRefresh.addEventListener("click", loadGcpProjects);
    }

    if (btnVerify) {
      btnVerify.addEventListener("click", async () => {
        if (currentGcpMode === "oauth") {
          const projId = (txtProjectId?.value || "").trim();
          const loc = selLocation?.value || "us-central1";
          const limit = parseInt(numDailyLimit?.value || "100", 10);
          if (!projId) {
            alert("Please select or enter a Google Cloud Project ID.");
            return;
          }

          if (verifyBox) {
            verifyBox.style.display = "flex";
            const setRow = (id, text, icon, color) => {
              const row = document.getElementById(id);
              if (!row) return;
              const ic = row.querySelector(".status-icon");
              const tx = row.querySelector(".chk-text");
              if (ic) { ic.innerText = icon; ic.style.color = color; }
              if (tx) tx.innerText = text;
            };
            setRow("chkRowBilling", "Verifying Cloud Billing...", "sync", "#f59e0b");
            setRow("chkRowApi", "Checking Vertex AI API...", "sync", "#f59e0b");
            setRow("chkRowPerm", "Checking IAM Permissions...", "sync", "#f59e0b");
            setRow("chkRowTest", "Executing latency test call...", "sync", "#f59e0b");

            btnVerify.disabled = true;
            try {
              const resp = await fetch("/api/gcp/verify", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ project_id: projId, location: loc })
              });
              const res = await resp.json();
              btnVerify.disabled = false;

              // Save settings including daily limit
              await fetch("/api/gcp/settings", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ project_id: projId, location: loc, daily_page_limit: limit })
              });

              const c = res.checks || {};
              const updateRow = (id, check, defaultLabel) => {
                const row = document.getElementById(id);
                if (!row) return;
                const ic = row.querySelector(".status-icon");
                const tx = row.querySelector(".chk-text");
                const fix = row.querySelector(".fix-link");
                if (check?.passed) {
                  if (ic) { ic.innerText = "check_circle"; ic.style.color = "#10b981"; }
                  if (tx) tx.innerText = check.message || defaultLabel;
                  if (fix) fix.classList.add("hidden");
                } else {
                  if (ic) { ic.innerText = "cancel"; ic.style.color = "#ef4444"; }
                  if (tx) tx.innerText = check?.message || "Check failed";
                  if (fix && check?.fix_url) {
                    fix.href = check.fix_url;
                    fix.classList.remove("hidden");
                  }
                }
              };

              updateRow("chkRowBilling", c.billing, "Cloud Billing enabled");
              updateRow("chkRowApi", c.api_enabled, "Vertex AI API enabled");
              updateRow("chkRowPerm", c.permissions, "User permissions verified");
              updateRow("chkRowTest", c.test_call, `Test call passed (${c.test_call?.latency_ms || 0} ms)`);

              if (res.all_passed) {
                if (window.showToast) window.showToast("Google Cloud Project connected successfully!");
                const connPill = document.getElementById("userConnectionStatus");
                if (connPill) {
                  connPill.innerText = "Connected (GCP)";
                  connPill.className = "conn-pill online";
                }
                setTimeout(() => gcpModal.classList.add("hidden"), 1600);
              }
            } catch (err) {
              btnVerify.disabled = false;
              alert("Verification failed: " + err.message);
            }
          }
        } else {
          // API Key mode
          const keyInput = document.getElementById("txtCustomApiKey");
          const keyVal = (keyInput?.value || "").trim();
          if (!keyVal) {
            alert("Please enter a valid Gemini API key.");
            return;
          }
          btnVerify.disabled = true;
          try {
            const resp = await fetch("/api/gcp/set-api-key", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ api_key: keyVal })
            });
            const res = await resp.json();
            btnVerify.disabled = false;
            if (res.ok) {
              if (window.showToast) window.showToast(`Gemini API Key saved in Keychain (${res.latency_ms} ms)!`);
              const connPill = document.getElementById("userConnectionStatus");
              if (connPill) {
                connPill.innerText = "Connected (API Key)";
                connPill.className = "conn-pill online";
              }
              setTimeout(() => gcpModal.classList.add("hidden"), 1000);
            } else {
              alert("API Key verification failed: " + (res.error || "Unknown error"));
            }
          } catch (e) {
            btnVerify.disabled = false;
            alert("API Key test failed: " + e.message);
          }
        }
      });
    }

    // Credentials Setup Trigger
    const btnOpenCreds = document.getElementById("btnOpenCredentialsSetup");
    if (btnOpenCreds) {
      btnOpenCreds.addEventListener("click", openCredentialsModal);
    }

    // Credentials Setup Tabs
    const tabCredApiKey = document.getElementById("tabCredModeApiKey");
    const tabCredOAuth = document.getElementById("tabCredModeOAuth");
    const panelCredApiKey = document.getElementById("panelCredApiKey");
    const panelCredOAuth = document.getElementById("panelCredOAuth");

    if (tabCredApiKey && tabCredOAuth) {
      tabCredApiKey.addEventListener("click", () => {
        tabCredApiKey.classList.add("active");
        tabCredOAuth.classList.remove("active");
        panelCredApiKey?.classList.remove("hidden");
        panelCredOAuth?.classList.add("hidden");
      });
      tabCredOAuth.addEventListener("click", () => {
        tabCredOAuth.classList.add("active");
        tabCredApiKey.classList.remove("active");
        panelCredOAuth?.classList.remove("hidden");
        panelCredApiKey?.classList.add("hidden");
      });
    }

    // Save API Key button in Credentials modal
    const btnSaveSetupApiKey = document.getElementById("btnSaveSetupApiKey");
    const txtSetupApiKey = document.getElementById("txtSetupApiKey");
    if (btnSaveSetupApiKey && txtSetupApiKey) {
      btnSaveSetupApiKey.addEventListener("click", async () => {
        const key = txtSetupApiKey.value.trim();
        if (!key) {
          alert("Please enter a valid Gemini API key.");
          return;
        }
        btnSaveSetupApiKey.disabled = true;
        btnSaveSetupApiKey.innerHTML = `<span class="material-symbols-rounded spin">sync</span> <span>Verifying...</span>`;
        try {
          const resp = await fetch("/api/gcp/set-api-key", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ api_key: key })
          });
          const res = await resp.json();
          btnSaveSetupApiKey.disabled = false;
          btnSaveSetupApiKey.innerHTML = `<span class="material-symbols-rounded">check</span> <span>Save Key & Start Using AI</span>`;
          if (res.ok) {
            await fetch("/api/auth/consent", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ level: 1 })
            });
            document.getElementById("credentialsSetupModal")?.classList.add("hidden");
            document.getElementById("fullScreenLoginOverlay")?.classList.add("hidden");
            const st = await fetchAuthStatus();
            updateAuthUI(st);
            if (window.showToast) window.showToast(`Gemini API Key verified and saved (${res.latency_ms} ms)!`);
          } else {
            alert("API Key verification failed: " + (res.error || "Unknown error"));
          }
        } catch (e) {
          btnSaveSetupApiKey.disabled = false;
          btnSaveSetupApiKey.innerHTML = `<span class="material-symbols-rounded">check</span> <span>Save Key & Start Using AI</span>`;
          alert("Connection error: " + e.message);
        }
      });
    }

    // Save Client ID button in Credentials modal
    const btnSaveSetupClientId = document.getElementById("btnSaveSetupClientId");
    const txtSetupClientId = document.getElementById("txtSetupClientId");
    const txtSetupClientSecret = document.getElementById("txtSetupClientSecret");
    if (btnSaveSetupClientId && txtSetupClientId) {
      btnSaveSetupClientId.addEventListener("click", async () => {
        const cid = txtSetupClientId.value.trim();
        const csec = txtSetupClientSecret ? txtSetupClientSecret.value.trim() : "";
        if (!cid) {
          alert("Please enter a valid Google OAuth Client ID.");
          return;
        }
        btnSaveSetupClientId.disabled = true;
        btnSaveSetupClientId.innerHTML = `<span class="material-symbols-rounded spin">sync</span> <span>Saving...</span>`;
        try {
          const resp = await fetch("/api/auth/set-client-id", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ client_id: cid, client_secret: csec })
          });
          const res = await resp.json();
          btnSaveSetupClientId.disabled = false;
          btnSaveSetupClientId.innerHTML = `<span class="material-symbols-rounded">login</span> <span>Save & Sign In With Google</span>`;
          if (res.ok) {
            document.getElementById("credentialsSetupModal")?.classList.add("hidden");
            if (window.showToast) window.showToast("Client ID saved. Opening Google Sign-In...");
            handleGoogleSignIn();
          } else {
            alert("Failed to save Client ID: " + (res.error || "Unknown error"));
          }
        } catch (e) {
          btnSaveSetupClientId.disabled = false;
          btnSaveSetupClientId.innerHTML = `<span class="material-symbols-rounded">login</span> <span>Save & Sign In With Google</span>`;
          alert("Connection error: " + e.message);
        }
      });
    }
  }

  function openCredentialsModal() {
    const credModal = document.getElementById("credentialsSetupModal");
    if (!credModal) return;
    credModal.classList.remove("hidden");
  }

  // Export functions to window
  window.AuthUI = {
    fetchAuthStatus,
    updateAuthUI,
    updatePrivacyBadge,
    handleGoogleSignIn: handleGoogleAccountSignIn,
    handleGoogleAccountSignIn,
    handleGoogleOAuthSignIn,
    handleSignOut,
    openCredentialsModal
  };

  // Auto-init on load
  document.addEventListener("DOMContentLoaded", async () => {
    setupAuthEventListeners();
    const st = await fetchAuthStatus();
    updateAuthUI(st);
  });
})();
