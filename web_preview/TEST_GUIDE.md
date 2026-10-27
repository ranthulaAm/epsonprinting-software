# Web preview — how to run & test on a MacBook

Run (don't double-click; a local server avoids file:// restrictions):
    cd web_preview && python3 -m http.server 8080
    open http://localhost:8080      # Safari or Chrome
Use Cmd+Shift+R to hard-reload after updating files.

## Fixed in this version
1. No file input existed -> JS crashed during startup, so everything wired after it was dead.
   Added hidden #filePicker.
2. updateLivePrinterPanel() was called but never defined -> added (name, status, ink bars, paper).
3. `paperSize` undefined in the dependency checker -> defined.
4. Wrong element ids (selPrinter -> printerSelect); missing btnExportDailyReport guarded.
5. Duplicate ids: zoom buttons/label and Passport dropdown -> second copies renamed and wired.
6. Copy-to-clipboard now has a fallback (was failing outside secure contexts).
7. Added -webkit-backdrop-filter for Safari blur effects.

## Manual checklist (tick each)
[ ] Page loads, no red errors in console (Cmd+Opt+I)
[ ] Print tab: "Add files" opens file chooser; picked file appears in queue
[ ] Drag a file onto the window: overlay shows, file is added
[ ] Printer dropdown: switching changes name, status badge, ink bars, paper line
[ ] "Show more details" expands; "Copy printer diagnostics" copies
[ ] Zoom +/- works in the preview bar and the viewer bar
[ ] Passport/ID checkbox enables its dropdown
[ ] Cmd+K opens command palette, Esc closes
[ ] Theme toggle and language (EN/SI) toggle change the UI
[ ] Printers / Jobs / Tools / Shop / Settings tabs open and their buttons respond
[ ] Tools > OCR: "Copy Text" copies
[ ] Shop: Export Daily CSV button responds

## Limits of this web preview
It is an HTML mockup. Buttons like "Print", "Send to thermal printer", exports and
printer status show demo toasts/sample data; they do not talk to real hardware.
Real printing exists only in the Flutter Windows app.
