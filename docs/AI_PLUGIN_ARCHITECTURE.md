# Print Helper — AI Plugin Architecture & Consent Model Guide

## 1. Core Principles & Non-Negotiables

1. **Disabled by Default (`isEnabled == false`)**:
   - Out of the box, [`AiSettingsState.masterAiEnabled`](../lib/services/ai/models/ai_models.dart) is `false` and the active plugin is [`NoopOfflineAiPlugin`](../lib/services/ai/ai_plugin_registry.dart).
   - Zero background processes, zero model weights loaded into RAM, and **zero network calls**.
2. **Strict Consent Model ("Nothing is sent anywhere without explicit user approval")**:
   - Every capability in [`IAiService`](../lib/services/ai/i_ai_service.dart) requires both:
     1. The user explicitly enabling the master AI toggle and the individual [`AiFeatureCapability`](../lib/services/ai/models/ai_models.dart) in **Settings > AI**.
     2. An explicit [`AiConsentGrant`](../lib/services/ai/models/ai_models.dart) produced after the user inspects the [`AiDataDisclosurePreview`](../lib/services/ai/models/ai_models.dart) in [`AiConsentDisclosureDialog`](../lib/features/settings/presentation/ai_settings_card.dart), which shows the exact file name, page numbers, byte size, target runtime/endpoint, and a preview of the payload.
   - If a plugin declares `requiresNetwork: true`, [`AiServiceRegistry._verifyConsentAndCapability`](../lib/services/ai/ai_plugin_registry.dart) additionally verifies `consent.leavesLocalMachineAcknowledged == true`.
3. **Permissive Licenses Only**:
   - All plugin runtimes and model wrappers must use **MIT**, **BSD**, **Apache-2.0**, or **SIL OFL-1.1** licenses. Avoid GPL/AGPL dependencies.

---

## 2. The 7 Defined Extension Points (`IAiPlugin` & `IAiService`)

All plugins implement [`IAiPlugin`](../lib/services/ai/i_ai_service.dart), which defines 7 strongly typed extension methods:

| # | Capability Enum (`AiFeatureCapability`) | Method in `IAiPlugin` / `IAiService` | Return Model | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `smartPrintSettings` | `suggestPrintSettings(...)` | `AiPrintSettingsSuggestion` | Recommends Duplex, N-Up, Grayscale, Draft quality, or paper size based on document structure. |
| **2** | `blankPageDetection` | `detectBlankPages(...)` | `AiBlankPageDetectionResult` | Detects empty/near-blank pages in PDFs/scans and returns a cleaned page range expression (e.g., `1-3, 5-9`) plus physical sheets saved. |
| **3** | `inkPaperSavingAdvice` | `analyzeInkAndPaperSavings(...)` | `AiInkPaperSavingAdvice` | Estimates ink/toner coverage and paper reduction % with an one-click `ecoPresetSettings` profile. |
| **4** | `scanEnhancement` | `enhanceScannedDocument(...)` | `AiScanEnhancementResult` | Deskews tilted camera scans, removes background shadows, and boosts text contrast before printing. |
| **5** | `ocrExtraction` | `performOcr(..., languageHints: ['si', 'en'])` | `AiOcrResult` | Extracts Sinhala (`සිංහල`) and English text from scanned images or flattened PDFs with per-page text and confidence scores. |
| **6** | `summarization` | `summarizeDocument(...)` | `AiSummaryResult` | Generates an executive summary and bullet points in English or Sinhala (`si`) for printing as a cover sheet. |
| **7** | `translation` | `translateDocument(...)` | `AiTranslationResult` | Translates document content between Sinhala (`si`) and English (`en`) while preserving Markdown headings and tables. |

---

## 3. How to Add a Local (On-Device, 100% Offline) Model Later

Local on-device plugins run **100% offline** (`AiExecutionMode.localOnDevice`, `requiresNetwork: false`) inside a background Dart `Isolate` via `dart:ffi`.

### Recommended Permissive On-Device Runtimes
- **OCR (Sinhala + English)**: **Tesseract 5** (`Apache-2.0`) via C API FFI (`libtesseract`) bundled with `sin.traineddata` (Sinhala) and `eng.traineddata` (English), or **PaddleOCR** (`Apache-2.0`) exported to ONNX.
- **Scan Enhancement & Blank Page Detection**: **ONNX Runtime** (`MIT`) or native C++ pixel histogram / Sauvola adaptive thresholding in a background isolate.
- **Summarization & Translation (Sinhala ↔ English)**: **ONNX Runtime GenAI** (`MIT`) or **llama.cpp** (`MIT`) running a quantized 4-bit GGUF model (e.g., Gemma / Qwen / NLLB-200 distilled under permissive terms) locally on CPU/DirectML GPU.

### Step-by-Step Implementation for an On-Device Plugin

1. **Create the Plugin Class** in `lib/services/ai/plugins/onnx_local_ai_plugin.dart`:

```dart
import 'dart:isolate';
import '../../../features/workspace/domain/print_queue_item.dart';
import '../i_ai_service.dart';
import '../models/ai_models.dart';

class OnnxLocalAiPlugin implements IAiPlugin {
  const OnnxLocalAiPlugin({required this.modelsDirectoryPath});

  final String modelsDirectoryPath;

  @override
  AiPluginDescriptor get descriptor => const AiPluginDescriptor(
        id: 'onnx_local_runtime',
        name: 'On-Device ONNX + Tesseract (සිංහල / English)',
        version: '1.0.0',
        executionMode: AiExecutionMode.localOnDevice,
        supportedCapabilities: {
          AiFeatureCapability.blankPageDetection,
          AiFeatureCapability.scanEnhancement,
          AiFeatureCapability.ocrExtraction,
          AiFeatureCapability.summarization,
          AiFeatureCapability.translation,
        },
        licenseSpdx: 'MIT / Apache-2.0',
        requiresNetwork: false, // 100% Offline
        endpointOrRuntimeDescription:
            'Local Windows DirectML / CPU Isolate (Nothing leaves your PC)',
      );

  @override
  Future<AiDataDisclosurePreview> buildDisclosurePreview({
    required AiFeatureCapability capability,
    required PrintQueueItem item,
  }) async {
    return AiDataDisclosurePreview(
      capability: capability,
      executionMode: AiExecutionMode.localOnDevice,
      targetEndpointOrModelName: descriptor.endpointOrRuntimeDescription,
      fileName: item.fileName,
      pagesIncluded: List<int>.generate(item.pageCount, (i) => i + 1),
      payloadSizeBytes: item.fileSizeBytes,
      dataFieldsIncluded: const ['Local file bytes (processed in local RAM only)'],
      redactedSnippetPreview: item.textPreviewSnippet ?? '[Binary raster pages]',
      leavesLocalMachine: false,
    );
  }

  @override
  Future<AiOcrResult?> performOcr({
    required PrintQueueItem item,
    required List<String> languageHints,
    required AiConsentGrant consent,
  }) async {
    // Run heavy FFI inference in a background Isolate so the 60fps UI never blocks
    final filePath = item.filePath;
    final modelDir = modelsDirectoryPath;
    return Isolate.run(() {
      // Call libtesseract / ONNX Runtime FFI bindings with `sin+eng`
      return const AiOcrResult(
        fullText: 'Extracted Sinhala & English text...',
        detectedLanguages: ['si', 'en'],
        containsSinhalaScript: true,
        averageConfidence: 0.94,
        pageTexts: {1: 'Extracted Sinhala & English text...'},
      );
    });
  }

  // Implement remaining extension points...
  @override
  Future<AiPrintSettingsSuggestion?> suggestPrintSettings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async => null;

  @override
  Future<AiBlankPageDetectionResult?> detectBlankPages({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async => null;

  @override
  Future<AiInkPaperSavingAdvice?> analyzeInkAndPaperSavings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async => null;

  @override
  Future<AiScanEnhancementResult?> enhanceScannedDocument({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async => null;

  @override
  Future<AiSummaryResult?> summarizeDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  }) async => null;

  @override
  Future<AiTranslationResult?> translateDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  }) async => null;
}
```

2. **Register the Plugin** in `aiServiceRegistryProvider` (`lib/services/ai/ai_plugin_registry.dart`):
   ```dart
   registry.registerPlugin(
     OnnxLocalAiPlugin(modelsDirectoryPath: localModelsDir),
   );
   ```

---

## 4. How to Add an Opt-In Online API Plugin Later

If a user or office administrator later chooses to connect an online API (for example, a self-hosted LAN LLM gateway or a cloud API with a user-supplied API key), the plugin **MUST** enforce full payload transparency before any socket is opened.

### Mandatory Requirements for Online API Plugins
1. Set `executionMode: AiExecutionMode.onlineApi` and `requiresNetwork: true` in `AiPluginDescriptor`.
2. In `buildDisclosurePreview(...)`:
   - Set `leavesLocalMachine: true`.
   - Set `targetEndpointOrModelName` to the exact HTTPS hostname (e.g., `https://api.example.com/v1/chat/completions`).
   - Populate `redactedSnippetPreview` with the **exact text/JSON payload** that will be sent over the wire so the user can review it in `AiConsentDisclosureDialog`.
3. Never store API keys in plaintext; use Windows Data Protection API (`CryptProtectData` via `package:win32`) or user-session environment variables.
4. Before sending any request inside the plugin method, assert:
   ```dart
   assert(
     consent.leavesLocalMachineAcknowledged,
     'Online API calls are strictly forbidden without explicit user acknowledgment.',
   );
   ```

### Workflow Sequence for Consent-Gated AI Calls

```
User clicks AI Action (e.g., "Summarize" or "Remove Blank Pages")
       │
       ▼
IAiService.previewDataDisclosure(capability, item)
       │
       ▼
Show AiConsentDisclosureDialog ("Inspect What Will Be Processed / Sent")
       │
       ├── User clicks "Deny / Cancel" ──► Abort immediately (0 bytes processed/sent)
       │
       └── User clicks "I Inspected the Payload — Approve Once"
                 │
                 ▼
       Creates signed AiConsentGrant(grantedAt, approvedPayloadBytes, leavesLocalMachineAcknowledged)
                 │
                 ▼
       IAiService verifies capability + AiConsentGrant and invokes active IAiPlugin
```
