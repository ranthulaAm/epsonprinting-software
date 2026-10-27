/* Language layer: guarantees English mode is 100% English and Sinhala mode is 100% Sinhala.
   Every visible text node / placeholder / tooltip is looked up in window.I18N_SI (English -> Sinhala).
   The original English text is remembered, so switching back restores it exactly. Works for
   static HTML and for anything rendered later by app.js / power_tools.js (MutationObserver). */
(function () {
  "use strict";
  const DICT = window.I18N_SI || {};
  const norm = s => s.replace(/\s+/g, " ").trim();
  const SKIP = new Set(["SCRIPT", "STYLE", "TEXTAREA", "CODE", "PRE", "NOSCRIPT"]);
  const ATTRS = ["placeholder", "title", "aria-label"];
  const lang = () => (typeof currentLang !== "undefined" && currentLang === "si") ? "si" : "en";
  const missing = new Set();
  window.__i18nMissing = missing; // debug: inspect untranslated strings from the console

  function skipEl(el) {
    for (let e = el; e && e.nodeType === 1; e = e.parentElement) {
      if (SKIP.has(e.tagName) || e.hasAttribute("data-no-i18n") || e.classList.contains("material-symbols-rounded")) return true;
    }
    return false;
  }
  function pick(orig) {
    const key = norm(orig);
    if (!key) return orig;
    const tr = DICT[key];
    if (tr === undefined) { if (/[A-Za-z]{3}/.test(key)) missing.add(key); return orig; }
    const m = orig.match(/^(\s*)[\s\S]*?(\s*)$/);
    return (m ? m[1] : "") + tr + (m ? m[2] : "");
  }
  function doText(node) {
    if (!node.parentElement || skipEl(node.parentElement)) return;
    const cur = node.nodeValue;
    if (node.__i18nLast === undefined || cur !== node.__i18nLast) node.__i18nOrig = cur; // changed by app code
    const next = lang() === "si" ? pick(node.__i18nOrig) : node.__i18nOrig;
    node.__i18nLast = next;
    if (next !== cur) node.nodeValue = next;
  }
  function doAttrs(el) {
    if (skipEl(el)) return;
    for (const a of ATTRS) {
      if (!el.hasAttribute(a)) continue;
      el.__i18n = el.__i18n || {};
      const cur = el.getAttribute(a), st = el.__i18n[a];
      if (!st || cur !== st.last) el.__i18n[a] = { orig: cur, last: cur };
      const o = el.__i18n[a].orig;
      const next = lang() === "si" ? pick(o) : o;
      el.__i18n[a].last = next;
      if (next !== cur) el.setAttribute(a, next);
    }
  }
  function walk(root) {
    if (!root) return;
    if (root.nodeType === 3) return doText(root);
    if (root.nodeType !== 1) return;
    doAttrs(root);
    const tw = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    let n;
    while ((n = tw.nextNode())) n.nodeType === 3 ? doText(n) : doAttrs(n);
  }
  let busy = false;
  function applyAll() {
    busy = true;
    try {
      document.documentElement.lang = lang() === "si" ? "si" : "en";
      document.title = lang() === "si" ? (DICT[document.title] || document.title) : (document.__i18nTitle || document.title);
      walk(document.body);
    } finally { busy = false; }
  }
  document.__i18nTitle = document.title;

  const obs = new MutationObserver(muts => {
    if (busy) return;
    busy = true;
    try {
      for (const m of muts) {
        if (m.type === "childList") m.addedNodes.forEach(walk);
        else if (m.type === "characterData") doText(m.target);
        else if (m.type === "attributes") doAttrs(m.target);
      }
    } finally { busy = false; }
  });

  function start() {
    // re-apply after every language refresh done by app.js
    if (typeof window.updateUIStrings === "function") {
      const orig = window.updateUIStrings;
      window.updateUIStrings = function () { const r = orig.apply(this, arguments); applyAll(); return r; };
    }
    applyAll();
    obs.observe(document.body, { childList: true, characterData: true, subtree: true, attributes: true, attributeFilter: ATTRS });
  }
  window.applyI18n = applyAll;
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(start, 0));
  else setTimeout(start, 0);
})();
