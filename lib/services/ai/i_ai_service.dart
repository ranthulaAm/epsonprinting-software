import '../../features/workspace/domain/print_queue_item.dart';
import 'models/ai_models.dart';

/// Metadata describing an installable or built-in AI plugin for Print Helper.
class AiPluginDescriptor {
  const AiPluginDescriptor({
    required this.id,
    required this.name,
    required this.version,
    required this.executionMode,
    required this.supportedCapabilities,
    required this.licenseSpdx,
    required this.requiresNetwork,
    required this.endpointOrRuntimeDescription,
  });

  final String id;
  final String name;
  final String version;
  final AiExecutionMode executionMode;
  final Set<AiFeatureCapability> supportedCapabilities;
  final String licenseSpdx;
  final bool requiresNetwork;
  final String endpointOrRuntimeDescription;
}

/// Pluggable contract for any AI provider (Local On-Device ONNX/llama.cpp/Tesseract
/// OR Opt-In Online API). All implementations MUST be pure offline or gated behind
/// [AiConsentGrant] verification.
abstract interface class IAiPlugin {
  AiPluginDescriptor get descriptor;

  /// Builds a transparent disclosure of the exact bytes/fields that would be
  /// inspected or transmitted if the user approves this capability.
  Future<AiDataDisclosurePreview> buildDisclosurePreview({
    required AiFeatureCapability capability,
    required PrintQueueItem item,
  });

  /// 1. Smart print settings suggestions
  Future<AiPrintSettingsSuggestion?> suggestPrintSettings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  });

  /// 2. Auto-detecting blank pages and removing them
  Future<AiBlankPageDetectionResult?> detectBlankPages({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  });

  /// 3. Ink/paper saving advice
  Future<AiInkPaperSavingAdvice?> analyzeInkAndPaperSavings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  });

  /// 4. Document enhancement for scans (deskew, shadow removal, contrast)
  Future<AiScanEnhancementResult?> enhanceScannedDocument({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  });

  /// 5. OCR (including Sinhala සිංහල and English)
  Future<AiOcrResult?> performOcr({
    required PrintQueueItem item,
    required List<String> languageHints,
    required AiConsentGrant consent,
  });

  /// 6. Document summarization
  Future<AiSummaryResult?> summarizeDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  });

  /// 7. Document translation (Sinhala <-> English)
  Future<AiTranslationResult?> translateDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  });
}

/// High-level application service that enforces:
/// 1. Default-disabled state (`isEnabled == false` out of the box).
/// 2. Per-capability opt-in checks.
/// 3. Mandatory [AiConsentGrant] verification before invoking any registered [IAiPlugin].
/// 4. Zero network calls.
abstract interface class IAiService {
  bool get isEnabled;
  AiSettingsState get currentSettings;
  List<AiPluginDescriptor> get registeredPlugins;
  IAiPlugin get activePlugin;

  void registerPlugin(IAiPlugin plugin);
  void unregisterPlugin(String pluginId);

  /// Generates a human-readable disclosure of what will be processed/sent
  /// so the UI can show it in a consent dialog before running any AI action.
  Future<AiDataDisclosurePreview> previewDataDisclosure({
    required AiFeatureCapability capability,
    required PrintQueueItem item,
  });

  /// 1. Smart print settings suggestions
  Future<AiPrintSettingsSuggestion?> suggestPrintSettings({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  });

  /// 2. Auto-detecting blank pages and removing them
  Future<AiBlankPageDetectionResult?> detectBlankPages({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  });

  /// 3. Ink/paper saving advice
  Future<AiInkPaperSavingAdvice?> analyzeInkAndPaperSavings({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  });

  /// 4. Document enhancement for scans
  Future<AiScanEnhancementResult?> enhanceScannedDocument({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  });

  /// 5. OCR (including Sinhala සිංහල)
  Future<AiOcrResult?> performOcr({
    required PrintQueueItem item,
    List<String> languageHints = const ['si', 'en'],
    required AiConsentGrant? consent,
  });

  /// 6. Summarization
  Future<AiSummaryResult?> summarizeDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant? consent,
  });

  /// 7. Translation (Sinhala <-> English)
  Future<AiTranslationResult?> translateDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant? consent,
  });
}
