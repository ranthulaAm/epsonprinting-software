# CapabilityDiscovery & Three-Tier Print Settings System

**Project:** Print Helper (Desktop Windows & Multi-Platform)  
**Status:** Complete & Verified  
**Date:** 2026-10-27  

---

## 1. Executive Summary

This release implements:
1. **CapabilityDiscovery System**: Dynamic printer feature detection combining Windows Print Schema (`prntvpt.dll`), Win32 `DeviceCapabilitiesW`, IPP (RFC 8011), SNMP Printer MIB (RFC 3805), and an editable JSON profile database (`assets/profiles/epson_profiles.json`) covering 8 Epson printer families and generic printers.
2. **Three-Tier Print Settings System**: User-switchable **Basic**, **Standard**, and **Professional** tiers with level persistence, settings search, "Only changed settings" filter, a sticky plain-language summary strip in English and Spoken Sinhala, and media-first dependency validation with 1-click auto-fixes.
3. **Driver Settings Capture Fallback**: `DocumentProperties(DM_IN_PROMPT)` fallback safely captures opaque private DEVMODE bytes into named presets without modifying or reverse-engineering private bytes.
4. **Hardware & Spooler Hot-Plug Monitoring**: Non-blocking toast notifications (*"Epson L3250 connected. Reading printer features..."* / *"Epson L3250 සම්බන්ධ විය. ප්‍රින්ටර් හැකියාවන් කියවමින්..."*) and interactive Printer Abilities dialog.

---

## 2. CapabilityDiscovery Architecture

```
                       +-------------------------------+
                       |     Hardware / Spooler Event  |
                       |  (USB Hot-Plug, WM_DEVCHANGE) |
                       +---------------+---------------+
                                       |
                                       v
                     +-----------------------------------+
                     |  CapabilityDiscoveryService       |
                     |  - Emits Non-Blocking Toast       |
                     |  - Queries Sources in Priority    |
                     +-----------------+-----------------+
                                       |
        +------------------------------+-------------------------------+
        |                              |                               |
        v                              v                               v
+-----------------------+   +----------------------+        +----------------------+
| Windows Print Schema  |   | IPP & SNMP Telemetry |        | Profile Knowledge    |
| (prntvpt.dll FFI)     |   | (RFC 8011 / RFC 3805)|        | Base (Runtime JSON)  |
| - PTGetPrintCaps      |   | - Live Markers & Trays|       | - 8 Epson Families   |
| - DeviceCapabilitiesW |   | - Hardware Duplex     |       | - Media Triggers     |
+-----------+-----------+   +----------+-----------+        +----------+-----------+
            |                          |                               |
            +--------------------------+-------------------------------+
                                       |
                                       v
                    +------------------------------------+
                    |     DiscoveredCapabilities         |
                    |  - Source Badging & Provenance     |
                    |  - Confidence Rating               |
                    |  - Filtered Settings Generation    |
                    +------------------+-----------------+
                                       |
                                       v
                    +------------------------------------+
                    |       PrintSettingsPanel           |
                    |   (Basic | Standard | Pro)         |
                    +------------------------------------+
```

### 2.1 Profile Database Coverage (`assets/profiles/epson_profiles.json`)
The runtime-editable JSON database covers 8 distinct Epson printer families and generic fallback profiles:
1. **Epson EcoTank Consumer Series** (L1210, L3150, L3250, ET-2810): Gravity-fed continuous ink tank, visual estimated levels, waste ink pad counter, manual-only duplex assistant, borderless up to A4 with 4-step overspray slider.
2. **Epson EcoTank Duplex & Business Series** (L4260, L6270, ET-3850, ET-5850): Pigment black + dye color, automatic duplex, replaceable maintenance box with chip readout (C9344 / T04D1), ADF.
3. **Epson WorkForce Home Office** (WF-2850, WF-2950): 4-color cartridge with digital microchip percentage, automatic duplex, ADF.
4. **Epson WorkForce Pro & RIPS** (WF-4830, WF-C5790, WF-C8690): DURABrite Ultra pigment cartridges / high-capacity ink bags, heavy-duty auto duplex, dual cassettes + rear bypass, chip maintenance box (T6716).
5. **Epson WorkForce Enterprise AM-C** (AM-C4000, AM-C5000, WF-C20590): Fixed linehead inkjet array (up to 100 ppm), 50k page ink bags, dual maintenance tanks, 5350 sheets capacity.
6. **Epson Expression Home & Photo** (XP-8600, XP-15000): 6-color Claria Photo HD dye inks, automatic duplex, borderless fine art up to A3+, direct CD/DVD print tray.
7. **Epson EcoTank Photo & Stylus Photo** (L8050, L8180, L18050): 6-color continuous ink tank, replaceable C9345 maintenance box, borderless up to A3+, direct CD/DVD and PVC CR80 ID card tray.
8. **Epson WorkForce AL-M & AL-C Laser** (AL-M300DN, AL-C300DN): Monochrome and CMYK toner cartridges, photoconductor drum unit, fuser counter, high-speed PCL6/PostScript3.
9. **Generic Windows PCL/PostScript / IPP Printer**: Universal fallback discovering paper sizes and duplex via Windows Print Schema.

---

## 3. Three-Tier Print Settings Breakdown

| Tier | Target User | Features Included |
| :--- | :--- | :--- |
| **Basic** | General users, students, quick prints | Printer selector, Copies (+/- stepper), Page range, Color vs B&W, Single vs Double-sided, Paper size, Orientation, Fit to page |
| **Standard** | Everyday office & small business | All Basic + Media type, Print quality (Draft/Standard/High), Paper tray selection, N-up (1, 2, 4, 6, 9 pages per sheet), Booklet, Borderless switch, Collate, Reverse order, Ink-saving mode, Black ink only |
| **Professional** | Print shops, photographers, production | All Standard + Color Management (App ICC / Driver / Off, Rendering Intent, Soft Proofing), Advanced B&W Toning (Neutral, Cool, Warm, Sepia), Custom DPI (300 to 5760 DPI), Halftone Screening, Bi-directional switch, Ink Density slider (-50% to +50%), Sheet Imposition (Step & Repeat, Gang Run, Poster Tiling, Banner), Passport / ID Photo Sheets (35x45 mm, 2x2 in, 30x40 mm), 4-step borderless expansion bleed slider, Direct CD/DVD print, Document Stamps (COPY, PAID, DRAFT, පිටපත, ගෙවන ලදී, කෙටුම්පත), and Staff Lock (PIN protection) |

---

## 4. Media-First Dependency Validation & Auto-Fixes

Print Helper strictly enforces **media-type-first validation** to protect hardware and output quality:

```
[Media Type Selected] ---> Determines permissible Paper Sizes
                      ---> Determines allowable Duplex Modes (blocks duplex on Photo/Glossy)
                      ---> Determines Borderless Eligibility (blocks on Envelopes/Cardstock)
                      ---> Directs Input Tray Routing (requires Rear Tray for Thick Board)
```

### Auto-Fix Action Examples
1. **Photo Paper + Duplex Conflict**:
   - *Detection*: User selects `Epson Premium Glossy` while `Duplex` is enabled.
   - *Message*: *"Glossy Photo Paper does not support 2-sided printing (ink may smudge)"* (Sinhala: *"ග්ලොසි ෆොටෝ කොළ සඳහා දෙපැත්තෙන්ම මුද්‍රණය කළ නොහැක"*).
   - *1-Click Auto-Fix*: `[ Switch to Single-Sided ]` immediately resets `duplex` to `none`.
2. **Borderless on Monochrome Laser Conflict**:
   - *Detection*: User selects `Borderless` on `HP LaserJet Pro M404dn`.
   - *Message*: *"HP LaserJet Pro M404dn does not support borderless printing"* (Sinhala: *"මෙම ප්‍රින්ටරයේ දාර රහිත පහසුකම නැත"*).
   - *1-Click Auto-Fix*: `[ Turn Off Borderless ]` resets to standard 3mm margins.
3. **Manual Duplex Assistant Recommendation**:
   - *Detection*: User selects double-sided on `Epson EcoTank L3250` (lacks hardware auto-duplex).
   - *1-Click Auto-Fix*: `[ Open Duplex Assistant ]` opens the step-by-step paper turn visual assistant.

---

## 5. Visual Screenshots & Verification

| Screenshot | Description | MD5 Hash |
| :--- | :--- | :--- |
| `12_three_tier_basic_en.png` | Basic Tier in English (Copies, Color, Sides, Paper size) | `f6218db1b39d3da83fd7cec8a9eee973` |
| `13_three_tier_standard_en.png` | Standard Tier in English (Media type, Quality, Trays, N-up) | `5812215c5dbe7692d5807b5485e3df49` |
| `14_three_tier_professional_en.png` | Professional Tier (ICC color mgmt, Imposition, Passport photos, Stamps) | `0d6ec7c2eb52ddd4a030e2f5299771d8` |
| `15_three_tier_basic_si.png` | Basic Tier in Spoken Sinhala (`ප්‍රින්ටරය`, `කොපි`, `පාටින්`, `තනි පැත්ත`) | `03ee8cc6e32a1fede0618ab76bc0e625` |
| `16_media_dependency_autofix_banner.png` | Media conflict banner with 1-click `[ Switch to Single-Sided ]` button | `9c021789be27a9ff432d8f45efd60046` |
| `17_printer_abilities_modal.png` | Discovered Capabilities modal with technology pills and provenance | `d971e1ef72585a08406bde7919393d2b` |

---

## 6. Verification Summary

- [x] **Zero Hardcoded Model Rules**: Capabilities are synthesized dynamically from Print Schema, IPP/SNMP, Win32 Spooler, and `epson_profiles.json`.
- [x] **Safe Driver Capture**: `DocumentProperties(DM_IN_PROMPT)` preserves opaque driver private bytes as named presets. Undocumented bytes are never edited directly.
- [x] **Sticky Bilingual Summary Strip**: Plain spoken words in English and Sinhala continuously update with real-time settings.
- [x] **Pinned Print Button**: The Primary Print button stays permanently anchored at the bottom-right of Zone 3 across all scroll states and tiers.
