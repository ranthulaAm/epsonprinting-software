#!/bin/bash
# Double-click on Mac (or run in Terminal). First run installs the PDF engine libraries.
cd "$(dirname "$0")"
if ! command -v python3 >/dev/null; then echo "Install Python 3 from python.org first."; exit 1; fi
python3 -c "import pikepdf, pypdfium2, PIL, reportlab" 2>/dev/null || {
  echo "Installing PDF engine libraries (one time)..."
  python3 -m pip install --user -r pdf_engine/requirements.txt || exit 1
}
( sleep 1.5; open "http://localhost:8080" ) &
python3 pdf_engine/server.py
