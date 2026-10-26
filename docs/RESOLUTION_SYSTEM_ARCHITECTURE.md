# Print Helper: Resolution System Architecture (PPI vs DPI)

## 1. Executive Summary & Strict Disambiguation

Print Helper strictly distinguishes between the two fundamentally different concepts in digital printing:

* **PPI (Pixels Per Inch)**: The resolution of the source digital content (image or rasterized page) at its **final physical printed dimensions** on paper. PPI measures the density of image data pixels.
* **DPI (Dots Per Inch)**: The physical addressability and droplet density that the printer hardware and Windows driver deposit onto paper. DPI measures the physical ink micro-droplets sprayed or toner spots fused.

> [!IMPORTANT]
> **No Conflation Rule**: A 5760 DPI printer cannot fix a 72 PPI low-resolution image. It merely renders each pixel block using thousands of microscopic ink droplets. Print Helper explicitly explains this to users in both English and everyday spoken Sinhala to eliminate customer disputes in print shops.

---

## 2. Mathematical Engine (`EffectivePpiCalculator`)

The effective PPI is calculated through physical geometry:

$$\text{Width}_{\text{in}} = \frac{\text{Width}_{\text{mm}} - (2 \times \text{Margin}_{\text{mm}})}{25.4}$$

$$\text{Height}_{\text{in}} = \frac{\text{Height}_{\text{mm}} - (2 \times \text{Margin}_{\text{mm}})}{25.4}$$

$$\text{TargetArea}_{\text{in}} = \text{PrintableArea}_{\text{in}} \times \text{Scale}_{\text{N-Up}}$$

$$\text{Effective PPI} = \min\left(\frac{\text{EffectivePixelWidth}}{\text{FinalPrintedWidth}_{\text{in}}}, \frac{\text{EffectivePixelHeight}}{\text{FinalPrintedHeight}_{\text{in}}}\right)$$

### Quality Thresholds & Bilingual Badges

| PPI Range | Rating | English Label | Spoken Sinhala Label | Meaning & Advice |
|---|---|---|---|---|
| **300+ PPI** | Crisp | `300+ PPI (Photo Grade)` | `ඉතා පැහැදිලියි (300+ PPI)` | Lab-grade sharpness for photos, fine art, and micro-text. |
| **150–299 PPI** | Acceptable | `Good (150-299 PPI)` | `ප්‍රමාණවත් (150-299 PPI)` | Crisp from normal reading distance. Suitable for general office documents. |
| **< 150 PPI** | Low | `Low (< 150 PPI)` | `අඩුයි (< 150 PPI)` | Warning: May appear soft, blurry, or blocky (pixelated) when printed. |

---

## 3. Resampling & Upscaling Engine

Print Helper adheres to a strict transparency guarantee: **Never resample silently**.

1. **Algorithms**:
   * **None (Nearest Neighbor)**: Exact raw pixels; fast but blocky when magnified.
   * **Bicubic Interpolation**: Smooth cubic spline curve; ideal for standard office graphics.
   * **Lanczos-3 (Windowed Sinc)**: High-fidelity 3-lobe windowed sinc filter; preserves sharp edges and fine texture without ringing artifacts.
2. **Upscale Multipliers**: `1.5×`, `2.0×` (Standard 4× pixel count), `3.0×`, `4.0×`.
3. **Audit Trail**: Every resampling operation creates a `ResamplingLogRecord` logged with original dimensions, target dimensions, algorithm, and timestamps in job metadata.
4. **Vector Direct Pass-Through**: TrueType/OpenType fonts, vector paths, and PDF linework are passed directly to the Windows spooler as vector graphics, bypassing rasterization.

---

## 4. Render DPI & RAM Footprint Estimation

When explicit page rasterization is required (e.g. transparency flattening or legacy printer drivers), users can select the raster density:

$$\text{RAM (MB)} = \frac{\text{PageWidth}_{\text{in}} \times \text{DPI} \times \text{PageHeight}_{\text{in}} \times \text{DPI} \times 3}{1024 \times 1024}$$

* **Auto (Default)**: Dynamically matches printer capability (300 DPI for office, 600 DPI for photo).
* **150 DPI Draft**: ~6.2 MB per A4 page.
* **300 DPI Standard**: ~24.9 MB per A4 page.
* **600 DPI High Detail**: ~99.6 MB per A4 page.
* **1200 DPI Ultra Fine**: ~398.3 MB per A4 page (*triggers high-memory warning and 1-click fallback*).

---

## 5. Printer Hardware Resolution (DPI) & Media Compatibility

Driver-reported resolutions are translated into plain-language choices with speed and ink usage indicators:

* **360 DPI**: Fast / Draft (*අධිවේගී කෙටුම්පත*). Blocked on Glossy Photo Paper.
* **720 DPI**: Standard / Normal (*සාමාන්‍ය ගුණාත්මක බව*). Balanced speed and ink.
* **1440 DPI**: High Quality / Fine (*උසස් ගුණාත්මක බව*). Moderate speed; sharp fine gradients.
* **2880 DPI / 5760 DPI**: Best / Photo Grade (*ඉහළම ඡායාරූප තත්ත්වය*). Micro-droplets. **Blocked on Plain Paper** (triggers droplet overload warning to prevent ink bleed and cockling).

---

## 6. Photo Print Size Helper

An interactive dialog that calculates resulting effective PPI across standard photo media:
* Passport 35×45 mm
* Visa 2×2 in (50×50 mm)
* **Photo 4×6 in (10×15 cm)**: Recommended as the largest size achieving lab-grade 300+ PPI for standard 1800×1200 px digital photos.
* Photo 5×7 in (13×18 cm)
* Photo 8×10 in (20×25 cm)
* A4 Document (21×29.7 cm)
* A3 Poster (29.7×42 cm)
* **Custom Dimension Calculator**: Allows typing target width and height in centimeters to preview live effective PPI.

---

## 7. Shop Mode Price Calculator Integration

* Per-job resolution settings are serialized in presets and print queue items (`targetDpi`, `resampleAlgorithm`, `renderDpiChoice`).
* In Shop Mode, jobs utilizing photo-grade resolution (1440+ DPI) automatically apply a configurable **High Quality Resolution Surcharge** (`+LKR 25.00` per sheet) to compensate for slower printhead sweep speeds and heavier ink deposition.

---

## 8. Captured Verification Artifacts

1. **Standard Tier Resolution Controls**: `docs/screenshots/18_resolution_standard_tier_ppi_dpi_en.png`
2. **Photo Print Size Helper Modal**: `docs/screenshots/19_resolution_photo_size_helper_modal_en.png`
3. **Resample & Upscale Preview Modal (Before / After Split)**: `docs/screenshots/20_resolution_resample_preview_modal_en.png`
4. **Professional Tier Render DPI in Spoken Sinhala**: `docs/screenshots/21_resolution_pro_tier_render_dpi_memory_si.png`
5. **Low-PPI Validation Warning & 1-Click Auto-Fix**: `docs/screenshots/22_resolution_validation_autofix_warning_en.png`
