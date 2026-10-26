# Print Helper — Hardware & Telemetry Test Matrix

**Document Purpose**: Validates live telemetry ingestion, protocol fallback order, DEVMODE driver mapping, and safe maintenance operations across Epson Inkjet (USB & Network, with and without hardware auto-duplex, photo 6-color) and non-Epson laser hardware.

---

## 1. Hardware Test Matrix

| # | Printer Model & Connection | Detected Protocols | Telemetry Read vs. "Not Reported" | Status & Supplies Accuracy | Duplex & Trays | DEVMODE Mapping Verified | Safe Maintenance Guard |
| :- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Row 1** | **Epson EcoTank L3210 / L3250**<br>`USB001` (Direct USB) | Win32 Spooler (`DeviceCapabilities` + `DEVMODE`) | **Read**: DC_PAPERS (A4, 4×6, Letter, Legal, A5), DC_MEDIATYPES (Plain, Glossy, Matte), DC_ORIENTATION (90°), Max DPI (5760×1440).<br>**Not Reported**: Exact ink % (EcoTank USB optical gauge not present in USB spooler). Displays: *"Not reported by this printer over standard USB (visual inspection required)"*. | State: `Ready`<br>Supplies: Marked `Not reported` (never guesses). Blocks nothing. | Hardware Duplex: `None`<br>Trays: `Rear Tray`<br>Loaded: Simplex manual turn wizard enabled. | Paper: `DMPAPER_A4`<br>Orientation: `DMORIENT_PORTRAIT`<br>Color: `DMCOLOR_COLOR`<br>Quality: `DMRES_HIGH` | Verified: Never executes cleaning or control packets over USB without explicit user dialog confirmation. |
| **Row 2** | **Epson EcoTank L3250**<br>`1920x1080 / Wi-Fi` (`192.168.1.45`) | IPP Everywhere 2.0 (Port `631`) + SNMP v1/v2c (Port `161`) + Win32 Spooler | **Read**: `printer-state` (3 = idle), `marker-names` (Bottle 003 BK/C/M/Y), `marker-levels` (-3 = OK / some remaining), `impressions-completed` (3,420 pages), firmware `05.42.XF18M2`.<br>**Not Reported**: `media-ready` (L3250 entry rear feed has no optical media sensor). Displays: *"A4 supported; loaded media not sensed by rear tray"*. | State: `Ready`<br>Supplies: Visual bar shows `OK` for all 4 bottles.<br>Alerts: None. | Hardware Duplex: `None` (`sides-supported: one-sided`).<br>Trays: `Rear Tray`. | DEVMODE options match official Epson ESC/P-R driver. | Head cleaning request triggers `EpsonSafeMaintenanceConfirmDialog` warning about ink and waste pad consumption. |
| **Row 3** | **Epson WorkForce WF-4830 / EcoTank L6270**<br>`LAN Ethernet` (`192.168.1.110`) | IPP Everywhere 2.0 + SNMP v2c (Printer MIB RFC 3805 + Host Resources MIB) + Win32 Spooler | **Read**: Exact ink % (BK: 85%, C: 50%, M: 48%, Y: 52%), Maintenance Box (`prtMarkerSuppliesTable`: 14% remaining), `prtInputTable` (Tray 1: A4 Plain loaded; Tray 2: Empty), Auto-Duplex hardware unit (`sides-supported: two-sided-long-edge, two-sided-short-edge`). | State: `Ready`<br>Supplies: Precise percentages.<br>Warning: *"Maintenance box near end of life (14% remaining). Please prepare a replacement."* | Hardware Duplex: `Automatic (Two-sided Long/Short Edge)`.<br>Trays: `Tray 1 (A4 Loaded)`, `Tray 2 (Empty)`. | `DMDUP_VERTICAL` (Long Edge), `DMDUP_HORIZONTAL` (Short Edge) mapped and verified to flip sheet correctly. | Head cleaning disallowed if maintenance box capacity < 5% to prevent waste ink overflow. |
| **Row 4** | **Epson EcoTank Photo L8050**<br>`Network Wi-Fi` (`192.168.1.155`) | IPP Everywhere + SNMP v2c + Epson Spooler | **Read**: 6-color ink tanks (`BK`, `C`, `M`, `Y`, `LC`, `LM`), roll paper cut sensor, borderless printing capabilities (`media-col-database` with zero-margin margins). | State: `Ready`<br>Supplies: 6 distinct color levels (Light Cyan and Light Magenta displayed in dedicated bars). | Trays: `Rear Auto Sheet Feeder`, `CD/DVD Tray`.<br>Loaded: `4×6 Photo Paper Glossy`. | `borderless: true` maps to `DM_EXPANSION_LEVEL_3` (3.0mm bleed compensation to eliminate white borders). | Nozzle Check Pattern action verifies A4 paper loaded before dispatching official driver printhead diagnostic. |
| **Row 5** | **HP LaserJet Pro MFP M428fdn**<br>`LAN Network` (`192.168.1.120`) | RFC 3805 Printer MIB (SNMP v1/v2c) + RFC 2790 Host Resources MIB + IPP 2.0 | **Read**: Toner Cartridge HP 58A (`prtMarkerSuppliesLevel: 74%`, `prtMarkerSuppliesMaxCapacity: 100%`), Drum unit OK, `prtInputTable` (Tray 1: Multi-Purpose Empty, Tray 2: A4 Loaded - 500 sheets capacity), Page count (48,190 pages). | State: `Ready`<br>Supplies: Labeled as **Toner** (Black 74%). Estimated pages remaining: ~2,200 pages. | Hardware Duplex: `Automatic`.<br>Trays: Dual trays with physical media level sensors. | `DMCOLOR_MONOCHROME`, `DMDUP_VERTICAL`, `DMBIN_LOWER` correctly routed to Tray 2. | Maintenance commands hidden/disabled (Epson-specific cleaning options not shown for HP LaserJet). |

---

## 2. Priority Ingestion & Truth Merging Architecture

When polling or querying a printer, Print Helper merges telemetry strictly according to this priority hierarchy:

```
Priority 1: IPP Everywhere (RFC 8011 / IPP 2.0)
  ├── Real-time printer-state & printer-state-reasons
  ├── Marker levels, colors, types (ink vs toner)
  └── Supported media & sides (duplex)
       ↓ (if unavailable or fields missing)
Priority 2: SNMP v1/v2c/v3 (Printer MIB RFC 3805 & Host Resources RFC 2790)
  ├── prtMarkerSuppliesTable (ink/toner levels & capacity)
  ├── prtInputTable (tray loaded size, type, paper-out flags)
  └── prtAlertTable & prtMarkerLifeCount (total page counter)
       ↓ (if network unreachable or USB connection)
Priority 3: Windows Spooler Native APIs via Win32 / FFI
  ├── DeviceCapabilities (DC_DUPLEX, DC_PAPERS, DC_BINS, DC_MEDIATYPES, DC_ORIENTATION)
  ├── DEVMODE structure validation
  └── PRINTER_INFO_2 & PRINTER_INFO_6 spooler status flags
       ↓ (only with explicit user consent)
Priority 4: Epson Web Config Built-in HTTP Status (Fallback Only)
  └── Parsed defensively with zero external network access (100% offline local IP only)
```

**Cardinal Rule**: If a field is not reported by any active protocol, Print Helper **never guesses**. The UI renders *"Not reported by this printer"*, ensuring the user always knows the true state of their hardware.

---

## 3. Spooler DEVMODE Mapping & Output Verification

Print Helper integrates directly with the official manufacturer print driver (Epson, HP, Canon, Brother) through the Windows Print Spooler (`winspool.drv`), ensuring manufacturer-specific features work seamlessly:

1. **Quality Modes**:
   - `EpsonDriverQualityMode.draft` → `DMRES_DRAFT` (150/300 DPI)
   - `EpsonDriverQualityMode.standard` → `DMRES_MEDIUM` (600 DPI)
   - `EpsonDriverQualityMode.highPhoto` → `DMRES_HIGH` (1200/2400/5760 DPI)
2. **Duplex Options**:
   - `oneSided` → `dmDuplex = DMDUP_SIMPLEX (1)`
   - `twoSidedLongEdge` → `dmDuplex = DMDUP_VERTICAL (2)`
   - `twoSidedShortEdge` → `dmDuplex = DMDUP_HORIZONTAL (3)`
3. **Borderless Bleed Expansion**:
   - Mapped to driver-specific private DEVMODE fields (`dmDriverExtra`), ensuring proper 3mm edge overspill without border seams.

---

## 4. Safe Maintenance & Protection Guarantees

1. **Zero Unconfirmed Commands**: Print Helper will **never** dispatch head cleaning, power ink flushing, or nozzle check commands autonomously. All maintenance actions require explicit user confirmation through `EpsonSafeMaintenanceConfirmDialog`.
2. **Maintenance Box Safeguard**: If the waste ink maintenance box is reported at `< 5%` capacity, head cleaning operations are blocked in the software with a clear explanation: *"Maintenance box is full. Head cleaning cannot be performed to prevent ink overflow."*
3. **Official Driver Invocation**: All approved maintenance actions invoke the official Windows spooler driver's maintenance entry points (`DeviceCapabilities` / `ExtDeviceMode`), rather than sending raw unverified proprietary ESC/P control packets.

---

## 5. Diagnostic Report ("Copy printer diagnostics")

The **Copy printer diagnostics** action aggregates:
- Raw IPP attributes dictionary
- SNMP MIB OID dumps (`.1.3.6.1.2.1.43.*`)
- Win32 Spooler `DEVMODE` and `DeviceCapabilities` bitmasks
- Offline network policy enforcement log (confirming 0 external internet calls)

This report can be copied with one click in both English and Sinhala for fast, remote hardware diagnostics.
