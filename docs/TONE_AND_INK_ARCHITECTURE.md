# Tone & Ink Reproduction Architecture (Driver & App Preprocessing)

## 1. Overview & Core Philosophy

The Print Helper **Tone and Ink** system provides precision tone, color, density, and ink-saving controls while upholding strict **honesty in the UI**:
1. **Driver-controlled** (`Printer setting` / `ප්‍රින්ටර් සැකසුම`): Settings the Epson driver itself exposes (hardware quality modes, Black Ink Only, driver color adjustments, density options where reported).
2. **App-controlled** (`Print Helper adjustment` / `Print Helper සැකසුම`): Preprocessing adjustments Print Helper applies to the page raster before spooling to the Windows driver. These work reliably across all printers.

```
+-----------------------------------------------------------------------------------+
|                            PRINT HELPER TONE ENGINE                               |
+-----------------------------------------------------------------------------------+
|  App-Controlled Image Preprocessing:                                              |
|  - Overall Density (-100 to +100)                                                 |
|  - Brightness, Contrast, Gamma (0.5 to 2.5), Shadows, Highlights                  |
|  - Saturation, Vibrance (Skin-Safe)                                               |
|  - Color Balance (Cyan-Red, Magenta-Green, Yellow-Blue)                           |
|  - Black Level & Text Darkness (Crisp text or ink preservation)                   |
|  - Sharpening (Text unsharp mask & Photo convolution)                             |
|  - Paper Compensation Presets (Plain Paper, Matte, Glossy Photo)                  |
|  - Ink Saver Mode (~28% estimated reduction, Text-Only Black)                      |
+-----------------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------------+
|                         DOUBLE-ADJUSTMENT GUARDRAIL                               |
|   Detects if driver color management & app color adjustments fight each other.    |
|   Provides 1-click Auto-Fix: [ Let Print Helper Manage Tone ]                     |
+-----------------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------------+
|                     STANDARD WINDOWS DOCUMENT SPOOLER                             |
|   Spools standard GDI / XPS Print Ticket to the official Epson Windows Driver.    |
|   NEVER sends raw ESC/P-R hardware control commands for cleaning or maintenance.  |
+-----------------------------------------------------------------------------------+
```

---

## 2. Provenance Badges (Honesty in UI)

Every control is explicitly tagged with its execution source so the user is never misled about where processing occurs:

| Provenance Source | UI Badge (EN) | UI Badge (SI) | Implementation |
|---|---|---|---|
| **Driver-Controlled** | `Printer setting` | `ප්‍රින්ටර් සැකසුම` | Mapped directly to Windows DEVMODE / PrintTicket schema (e.g. `DMCOLOR`, `DMRES`, Epson driver color controls). |
| **App-Controlled** | `Print Helper adjustment` | `Print Helper සැකසුම` | Rasterized and preprocessed in memory by Print Helper before handing off to the driver spooler. |

---

## 3. Adjustment Parameter Specifications

### A. Tone & Dynamics
- **Overall Density** (`-100` to `+100`): Controls overall ink laydown / deposition weight.
- **Brightness** (`-100` to `+100`): Adjusts linear luminance curve.
- **Contrast** (`-100` to `+100`): S-curve contrast expansion or compression.
- **Gamma Curve** (`0.50` to `2.50`): Non-linear power-law midtone correction ($V_{out} = V_{in}^\gamma$).
- **Shadows** (`-100` to `+100`): Lifts or crushes dark tones ($[0.0, 0.25]$ range).
- **Highlights** (`-100` to `+100`): Recovers or compresses high tones ($[0.75, 1.0]$ range).

### B. Typography & Line Definition
- **Black Level** (`-100` to `+100`): Clamps black floor to guarantee deep contrast on matte papers.
- **Text Darkness** (`-100` to `+100`): Selectively targets high-spatial-frequency dark glyphs to make text punchy or lighter to preserve toner/ink.
- **Text Sharpening** (`0` to `100`): Unsharp mask radius tuned for 4-12pt text letterforms.
- **Photo Sharpening** (`0` to `100`): Bicubic/Lanczos edge enhancement with noise suppression.

### C. Color Fidelity & Balance
- **Saturation** (`-100` to `+100`): Global chromatic intensity.
- **Vibrance** (`-100` to `+100`): Smart saturation that protects skin tones and prevents clipping already saturated primaries.
- **Color Balance**:
  - `Cyan ↔ Red` (`-100` to `+100`)
  - `Magenta ↔ Green` (`-100` to `+100`)
  - `Yellow ↔ Blue` (`-100` to `+100`)

### D. Paper-Type Compensation Presets

| Preset | Density | Midtone Lift | Black Level | Text Sharp | Photo Sharp | Sat / Vib | Description |
|---|---|---|---|---|---|---|---|
| **None** | `0` | `0` | `0` | `0` | `0` | `0 / 0` | Standard uncompensated output. |
| **Plain Paper** | `-6` | `+8` | `0` | `+15` | `0` | `0 / 0` | Compensates for porous paper bleed; lifts midtones, darkens text, reduces ink density. |
| **Matte Paper** | `0` | `Gamma 1.08` | `+12` | `0` | `0` | `0 / 0` | Compensates for heavy ink absorption by deepening shadows. |
| **Glossy Photo** | `0` | `0` | `0` | `0` | `+16` | `+6 / +8` | Maximizes dynamic range and vibrant color on resin-coated paper. |

---

## 4. Ink / Toner Saver Mode (Lighter Output)

The Ink Saver engine reduces ink consumption while maintaining document legibility:
- **Levels**:
  - `Light`: ~15% estimated reduction
  - `Balanced` (Default): ~28% estimated reduction
  - `Aggressive`: ~42% estimated reduction
- **Text-Only Black**: When enabled, body text uses the dedicated black ink tank ($K$) instead of composite CMY black, preserving expensive color ink.
- **Honest Labeling**: The UI explicitly states `"~28% ink saved (estimate)"` / `"~28% තීන්ත ඉතිරියක් (ඇස්තමේන්තුව)"` to ensure no false guarantees.

---

## 5. Optical CMYK Coverage Analyzer

The analyzer converts RGB raster pixels to CMYK:
$$K = 1 - \max(R, G, B)$$
$$C = \frac{1 - R - K}{1 - K}, \quad M = \frac{1 - G - K}{1 - K}, \quad Y = \frac{1 - B - K}{1 - K}$$

Per-channel percentages ($C, M, Y, K$) and total coverage feed:
1. Live progress meters in the UI.
2. The **Shop Mode Price Calculator** and profitability tracking to accurately compute cost per page based on actual ink coverage tiers (Low $<10\%$, Medium $10-25\%$, High $25-50\%$, Heavy $>50\%$).

---

## 6. Spooler Safety & Head Cleaning Policy

### Diagnostic Test Pattern
The Test Pattern Dialog produces:
1. **11-Step Neutral Gray Ramp** ($0\%$ to $100\%$ in $10\%$ steps) for tone curve and gamma inspection.
2. **CMYK Primary Color Patches** ($C, M, Y, K$) to check color density and purity.
3. **Micro-Text Sharpness Target** ($4\text{pt}, 6\text{pt}, 8\text{pt}, 10\text{pt}$) to verify unsharp masking and line crispness.
4. **Visual Nozzle Ladder Pattern** to detect missing or deflected nozzles.

### Safety Guardrails
- **Normal Document Spooling Only**: Test pages are spooled as ordinary documents through the Windows GDI/XPS print queue.
- **No Raw Device Control Commands**: Print Helper **NEVER** sends unverified raw ESC/P-R control codes (such as `\x1b(K...`) or automated head cleaning commands.
- **Honest Maintenance Guidance**: If the user's test pattern reveals clogged nozzles, Print Helper displays clear advice:
  > *"Run head cleaning from the printer's own control panel or the Epson driver Maintenance tab."*
  And provides a direct button to open the official driver's `DocumentProperties` dialog.
