import 'dart:typed_data';

import '../../features/workspace/domain/print_queue_item.dart';

/// All 7 extensible AI capabilities supported by the Print Helper AI Plugin System.
enum AiFeatureCapability {
  /// 1. Smart Print Settings Suggestions (duplex, N-up, grayscale, tray, paper size)
  smartPrintSettings(
    id: 'smart_print_settings',
    titleEn: 'Smart Print Settings Suggestions',
    titleSi: 'බුද්ධිමත් මුද්‍රණ සැකසුම් යෝජනා (Smart Print Settings)',
    descriptionEn:
        'Analyzes document structure (text-heavy vs. photo, page count, dimensions) to recommend optimal Duplex, N-Up, Grayscale, or Draft settings.',
    descriptionSi:
        'ලේඛනයේ ස්වභාවය සහ පිටු ගණන පරීක්ෂා කර සුදුසුම Duplex, N-Up හෝ කළු-සුදු සැකසුම් නිර්දේශ කරයි.',
  ),

  /// 2. Auto-Detecting Blank Pages & Removing Them
  blankPageDetection(
    id: 'blank_page_detection',
    titleEn: 'Auto-Detect & Remove Blank Pages',
    titleSi: 'හිස් පිටු ස්වයංක්‍රීයව හඳුනාගෙන ඉවත් කිරීම (Blank Page Detection)',
    descriptionEn:
        'Scans multi-page PDFs or scanned batches for near-empty/blank pages and suggests a cleaned page range so no paper is wasted.',
    descriptionSi:
        'බහු-පිටු PDF හෝ ස්කෑන් කළ ලේඛනවල ඇති හිස් පිටු හඳුනාගෙන කඩදාසි අපතේ යාම වළක්වයි.',
  ),

  /// 3. Ink / Toner & Paper Saving Advice
  inkPaperSavingAdvice(
    id: 'ink_paper_saving_advice',
    titleEn: 'Ink, Toner & Paper Saving Advice',
    titleSi: 'තීන්ත සහ කඩදාසි ඉතිරි කිරීමේ උපදෙස් (Eco Print Advisor)',
    descriptionEn:
        'Estimates ink coverage and physical sheet usage, offering actionable eco-presets (e.g., 2-Up + Long-Edge Duplex + Draft Mode).',
    descriptionSi:
        'තීන්ත සහ කඩදාසි භාවිතය ගණනය කර වියදම් අඩු කර ගැනීමට Eco සැකසුම් යෝජනා කරයි.',
  ),

  /// 4. Document Enhancement for Scans (Deskew, Dewarp, Shadow Removal, Contrast)
  scanEnhancement(
    id: 'scan_enhancement',
    titleEn: 'Document Enhancement for Camera Scans',
    titleSi: 'ස්කෑන් කළ ලේඛන පැහැදිලි කිරීම (Scan Enhancement)',
    descriptionEn:
        'Removes background shadows, deskews tilted pages, and sharpens text contrast before printing camera-captured documents.',
    descriptionSi:
        'කැමරාවෙන් ගත් හෝ ස්කෑන් කළ ලේඛනවල අඳුරු සෙවනැලි ඉවත් කර අකුරු තියුණු සහ පැහැදිලි කරයි.',
  ),

  /// 5. Optical Character Recognition (OCR) including Sinhala (සිංහල) & English
  ocrExtraction(
    id: 'ocr_sinhala_english',
    titleEn: 'Optical Character Recognition (OCR — සිංහල & English)',
    titleSi: 'සිංහල සහ ඉංග්‍රීසි අකුරු හඳුනාගැනීම (OCR — සිංහල / English)',
    descriptionEn:
        'Extracts searchable, selectable Sinhala (සිංහල) and English text from scanned images and flattened PDFs.',
    descriptionSi:
        'ස්කෑන් කළ රූප සහ PDF තුළ ඇති සිංහල සහ ඉංග්‍රීසි අකුරු පිටපත් කළ හැකි පෙළ බවට පත් කරයි.',
  ),

  /// 6. Document Summarization (Cover Sheet / Executive Summary)
  summarization(
    id: 'document_summarization',
    titleEn: 'Document Summarization',
    titleSi: 'ලේඛන සාරාංශගත කිරීම (Document Summarization)',
    descriptionEn:
        'Generates a concise bulleted summary of long reports (in English or සිංහල) that can be printed alone or as a cover sheet.',
    descriptionSi:
        'දිගු වාර්තාවල ප්‍රධාන කරුණු සිංහලෙන් හෝ ඉංග්‍රීසියෙන් සාරාංශ කර මුල් පිටුවක් ලෙස මුද්‍රණය කිරීමට ලබා දෙයි.',
  ),

  /// 7. Bilingual Document Translation (Sinhala <-> English)
  translation(
    id: 'document_translation',
    titleEn: 'Document Translation (සිංහල ↔ English)',
    titleSi: 'ලේඛන පරිවර්තනය (සිංහල ↔ English Translation)',
    descriptionEn:
        'Translates document text between Sinhala (සිංහල) and English while preserving headings, tables, and printable formatting.',
    descriptionSi:
        'ලේඛනයේ ආකෘතිය ආරක්ෂා කරමින් සිංහල සහ ඉංග්‍රීසි අතර පරිවර්තනය කර මුද්‍රණය කිරීමට සකසයි.',
  );

  const AiFeatureCapability({
    required this.id,
    required this.titleEn,
    required this.titleSi,
    required this.descriptionEn,
    required this.descriptionSi,
  });

  final String id;
  final String titleEn;
  final String titleSi;
  final String descriptionEn;
  final String descriptionSi;
}

/// Execution mode for an AI plugin:
/// - [disabled]: Default state. No model runs, zero CPU/memory overhead, zero network.
/// - [localOnDevice]: Runs 100% offline on the user's PC (e.g., ONNX Runtime, Tesseract/PaddleOCR, llama.cpp).
/// - [onlineApi]: Opt-in cloud API (requires explicit per-request payload inspection & user consent).
enum AiExecutionMode {
  disabled,
  localOnDevice,
  onlineApi,
}

/// Transparent preview of the exact payload that would be processed by an AI plugin.
/// Under Print Helper's strict consent model, nothing is processed or sent unless
/// the user explicitly enables the feature and approves this disclosure.
class AiDataDisclosurePreview {
  const AiDataDisclosurePreview({
    required this.capability,
    required this.executionMode,
    required this.targetEndpointOrModelName,
    required this.fileName,
    required this.pagesIncluded,
    required this.payloadSizeBytes,
    required this.dataFieldsIncluded,
    required this.redactedSnippetPreview,
    required this.leavesLocalMachine,
  });

  final AiFeatureCapability capability;
  final AiExecutionMode executionMode;
  final String targetEndpointOrModelName;
  final String fileName;
  final List<int> pagesIncluded;
  final int payloadSizeBytes;
  final List<String> dataFieldsIncluded;
  final String redactedSnippetPreview;
  final bool leavesLocalMachine;

  String get formattedPayloadSize {
    if (payloadSizeBytes < 1024) return '$payloadSizeBytes B';
    if (payloadSizeBytes < 1024 * 1024) {
      return '${(payloadSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(payloadSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Immutable record proving that the user inspected the [AiDataDisclosurePreview]
/// and explicitly granted consent for a specific operation.
class AiConsentGrant {
  const AiConsentGrant({
    required this.capability,
    required this.executionMode,
    required this.grantedAt,
    required this.approvedPayloadBytes,
    required this.leavesLocalMachineAcknowledged,
  });

  final AiFeatureCapability capability;
  final AiExecutionMode executionMode;
  final DateTime grantedAt;
  final int approvedPayloadBytes;
  final bool leavesLocalMachineAcknowledged;
}

/// Global user configuration for the AI subsystem (persisted locally; disabled by default).
class AiSettingsState {
  const AiSettingsState({
    this.showComingSoonSection = true,
    this.masterAiEnabled = false,
    this.preferredMode = AiExecutionMode.disabled,
    this.enabledCapabilities = const <AiFeatureCapability>{},
    this.requirePreviewBeforeEveryAction = true,
    this.activePluginId = 'noop_offline_default',
  });

  /// Whether the "AI Assistant (Coming Soon)" card is visible in Settings
  /// (can be hidden completely by users who want a minimal UI).
  final bool showComingSoonSection;

  /// Master kill-switch: false by default. When false, all AI calls short-circuit immediately.
  final bool masterAiEnabled;

  /// Preferred execution mode when enabled (defaults to [AiExecutionMode.disabled]).
  final AiExecutionMode preferredMode;

  /// Specific capabilities opted into by the user.
  final Set<AiFeatureCapability> enabledCapabilities;

  /// Enforces the mandatory consent modal showing exact payload before execution.
  final bool requirePreviewBeforeEveryAction;

  /// Currently selected plugin ID in the registry.
  final String activePluginId;

  bool isCapabilityAllowed(AiFeatureCapability capability) {
    return masterAiEnabled &&
        preferredMode != AiExecutionMode.disabled &&
        enabledCapabilities.contains(capability);
  }

  AiSettingsState copyWith({
    bool? showComingSoonSection,
    bool? masterAiEnabled,
    AiExecutionMode? preferredMode,
    Set<AiFeatureCapability>? enabledCapabilities,
    bool? requirePreviewBeforeEveryAction,
    String? activePluginId,
  }) {
    return AiSettingsState(
      showComingSoonSection:
          showComingSoonSection ?? this.showComingSoonSection,
      masterAiEnabled: masterAiEnabled ?? this.masterAiEnabled,
      preferredMode: preferredMode ?? this.preferredMode,
      enabledCapabilities: enabledCapabilities ?? this.enabledCapabilities,
      requirePreviewBeforeEveryAction: requirePreviewBeforeEveryAction ??
          this.requirePreviewBeforeEveryAction,
      activePluginId: activePluginId ?? this.activePluginId,
    );
  }
}

// ============================================================================
// Extension Point Result Models (for the 7 AI Capabilities)
// ============================================================================

/// 1. Result of Smart Print Settings Suggestion
class AiPrintSettingsSuggestion {
  const AiPrintSettingsSuggestion({
    required this.recommendedSettings,
    required this.rationaleEn,
    required this.rationaleSi,
    required this.confidenceScore,
  });

  final FilePrintSettings recommendedSettings;
  final String rationaleEn;
  final String rationaleSi;
  final double confidenceScore;
}

/// 2. Result of Auto-Detecting Blank Pages & Removing Them
class AiBlankPageDetectionResult {
  const AiBlankPageDetectionResult({
    required this.totalPagesScanned,
    required this.blankPageNumbers,
    required this.recommendedPageRangeExpression,
    required this.sheetsSaved,
  });

  /// Total pages inspected (1-based).
  final int totalPagesScanned;

  /// 1-based page numbers detected as blank or near-blank (< 0.3% ink density).
  final List<int> blankPageNumbers;

  /// Ready-to-apply page range expression excluding blank pages (e.g. "1-3, 5-8").
  final String recommendedPageRangeExpression;

  /// Number of physical paper sheets saved if blank pages are excluded.
  final int sheetsSaved;

  bool get hasBlankPages => blankPageNumbers.isNotEmpty;
}

/// 3. Result of Ink / Paper Saving Advice
class AiInkPaperSavingAdvice {
  const AiInkPaperSavingAdvice({
    required this.estimatedInkReductionPercent,
    required this.estimatedPaperReductionPercent,
    required this.currentSheetsRequired,
    required this.optimizedSheetsRequired,
    required this.tipsEn,
    required this.tipsSi,
    required this.ecoPresetSettings,
  });

  final int estimatedInkReductionPercent;
  final int estimatedPaperReductionPercent;
  final int currentSheetsRequired;
  final int optimizedSheetsRequired;
  final List<String> tipsEn;
  final List<String> tipsSi;
  final FilePrintSettings ecoPresetSettings;
}

/// 4. Result of Document Enhancement for Scans
class AiScanEnhancementResult {
  const AiScanEnhancementResult({
    required this.enhancedDocumentBytes,
    required this.deskewAngleDegrees,
    required this.shadowsRemoved,
    required this.contrastBoostApplied,
  });

  final Uint8List enhancedDocumentBytes;
  final double deskewAngleDegrees;
  final bool shadowsRemoved;
  final bool contrastBoostApplied;
}

/// 5. Result of OCR (including Sinhala සිංහල & English)
class AiOcrResult {
  const AiOcrResult({
    required this.fullText,
    required this.detectedLanguages,
    required this.containsSinhalaScript,
    required this.averageConfidence,
    required this.pageTexts,
  });

  final String fullText;
  final List<String> detectedLanguages;
  final bool containsSinhalaScript;
  final double averageConfidence;
  final Map<int, String> pageTexts;
}

/// 6. Result of Document Summarization
class AiSummaryResult {
  const AiSummaryResult({
    required this.title,
    required this.executiveSummary,
    required this.keyBulletPoints,
    required this.languageCode,
  });

  final String title;
  final String executiveSummary;
  final List<String> keyBulletPoints;
  final String languageCode;
}

/// 7. Result of Document Translation (Sinhala <-> English)
class AiTranslationResult {
  const AiTranslationResult({
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.translatedText,
    required this.preservedMarkdownFormatting,
  });

  final String sourceLanguageCode;
  final String targetLanguageCode;
  final String translatedText;
  final bool preservedMarkdownFormatting;
}
