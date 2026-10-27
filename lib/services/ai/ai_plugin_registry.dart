import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostic_logger.dart';
import '../../features/workspace/domain/print_queue_item.dart';
import 'i_ai_service.dart';
import 'models/ai_models.dart';

/// Default built-in no-op offline plugin.
/// Performs zero computation and zero network calls.
class NoopOfflineAiPlugin implements IAiPlugin {
  const NoopOfflineAiPlugin();

  static const AiPluginDescriptor kDescriptor = AiPluginDescriptor(
    id: 'noop_offline_default',
    name: 'Disabled (100% Offline No-Op)',
    version: '1.0.0',
    executionMode: AiExecutionMode.disabled,
    supportedCapabilities: <AiFeatureCapability>{},
    licenseSpdx: 'MIT',
    requiresNetwork: false,
    endpointOrRuntimeDescription: 'None — AI subsystem is disabled.',
  );

  @override
  AiPluginDescriptor get descriptor => kDescriptor;

  @override
  Future<AiDataDisclosurePreview> buildDisclosurePreview({
    required AiFeatureCapability capability,
    required PrintQueueItem item,
  }) async {
    return AiDataDisclosurePreview(
      capability: capability,
      executionMode: AiExecutionMode.disabled,
      targetEndpointOrModelName: descriptor.endpointOrRuntimeDescription,
      fileName: item.fileName,
      pagesIncluded: const <int>[],
      payloadSizeBytes: 0,
      dataFieldsIncluded: const <String>['None (AI is disabled)'],
      redactedSnippetPreview: 'Nothing is read or transmitted.',
      leavesLocalMachine: false,
    );
  }

  @override
  Future<AiPrintSettingsSuggestion?> suggestPrintSettings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiBlankPageDetectionResult?> detectBlankPages({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiInkPaperSavingAdvice?> analyzeInkAndPaperSavings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiScanEnhancementResult?> enhanceScannedDocument({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiOcrResult?> performOcr({
    required PrintQueueItem item,
    required List<String> languageHints,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiSummaryResult?> summarizeDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiTranslationResult?> translateDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  }) async =>
      null;
}

/// Reference template for a Local On-Device (100% Offline) AI Plugin
/// (e.g., ONNX Runtime + Tesseract 5 `sin`+`eng` traineddata).
/// Makes zero network calls (`requiresNetwork == false`).
class LocalOnDeviceHeuristicPluginStub implements IAiPlugin {
  const LocalOnDeviceHeuristicPluginStub();

  static const AiPluginDescriptor kDescriptor = AiPluginDescriptor(
    id: 'local_on_device_stub',
    name: 'Local On-Device Engine (Coming Soon — 100% Offline)',
    version: '0.1.0-preview',
    executionMode: AiExecutionMode.localOnDevice,
    supportedCapabilities: <AiFeatureCapability>{
      AiFeatureCapability.smartPrintSettings,
      AiFeatureCapability.blankPageDetection,
      AiFeatureCapability.inkPaperSavingAdvice,
      AiFeatureCapability.scanEnhancement,
      AiFeatureCapability.ocrExtraction,
      AiFeatureCapability.summarization,
      AiFeatureCapability.translation,
    },
    licenseSpdx: 'Apache-2.0 / MIT',
    requiresNetwork: false,
    endpointOrRuntimeDescription:
        'Local CPU/NPU Isolate (ONNX Runtime + Tesseract 5 sin/eng — Zero Network)',
  );

  @override
  AiPluginDescriptor get descriptor => kDescriptor;

  @override
  Future<AiDataDisclosurePreview> buildDisclosurePreview({
    required AiFeatureCapability capability,
    required PrintQueueItem item,
  }) async {
    final pages = List<int>.generate(item.pageCount.clamp(1, 500), (i) => i + 1);
    final snippet = (item.textPreviewSnippet ?? '').trim();
    return AiDataDisclosurePreview(
      capability: capability,
      executionMode: AiExecutionMode.localOnDevice,
      targetEndpointOrModelName: descriptor.endpointOrRuntimeDescription,
      fileName: item.fileName,
      pagesIncluded: pages,
      payloadSizeBytes: item.fileSizeBytes,
      dataFieldsIncluded: <String>[
        'File Name (${item.fileName})',
        'Document Type (${item.documentType.name})',
        'Page Count (${item.pageCount})',
        if (snippet.isNotEmpty) 'Local Text / Raster Buffers (In-Memory Only)',
      ],
      redactedSnippetPreview: snippet.isEmpty
          ? '[Binary PDF/Image buffer processed strictly in local RAM]'
          : (snippet.length > 180 ? '${snippet.substring(0, 180)}...' : snippet),
      leavesLocalMachine: false,
    );
  }

  @override
  Future<AiPrintSettingsSuggestion?> suggestPrintSettings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async {
    final isMultiPage = item.pageCount >= 2;
    final isTextOrMd = item.documentType == PrintDocumentType.plainText ||
        item.documentType == PrintDocumentType.markdown;
    final suggested = item.settings.copyWith(
      duplex: isMultiPage ? DuplexMode.longEdge : DuplexMode.none,
      isColor: !isTextOrMd,
      quality: isTextOrMd ? PrintQualityMode.draft : PrintQualityMode.normal,
    );
    return AiPrintSettingsSuggestion(
      recommendedSettings: suggested,
      rationaleEn: isMultiPage
          ? 'Detected ${item.pageCount}-page document: Long-Edge Duplex reduces paper usage by 50%.'
          : 'Single-page document: Simplex standard layout recommended.',
      rationaleSi: isMultiPage
          ? 'පිටු ${item.pageCount} ක ලේඛනයකි: දෙපස මුද්‍රණය (Duplex) මඟින් කඩදාසි 50% ක් ඉතිරි වේ.'
          : 'තනි පිටුවක ලේඛනයකි: සාමාන්‍ය එක්-පස මුද්‍රණය නිර්දේශ කෙරේ.',
      confidenceScore: 0.92,
    );
  }

  @override
  Future<AiBlankPageDetectionResult?> detectBlankPages({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async {
    return AiBlankPageDetectionResult(
      totalPagesScanned: item.pageCount,
      blankPageNumbers: const <int>[],
      recommendedPageRangeExpression: '',
      sheetsSaved: 0,
    );
  }

  @override
  Future<AiInkPaperSavingAdvice?> analyzeInkAndPaperSavings({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async {
    final currentSheets = item.pageCount * item.settings.copies;
    final optimizedSheets = ((item.pageCount + 3) ~/ 4) * item.settings.copies;
    return AiInkPaperSavingAdvice(
      estimatedInkReductionPercent: 35,
      estimatedPaperReductionPercent: currentSheets > 1 ? 50 : 0,
      currentSheetsRequired: currentSheets,
      optimizedSheetsRequired: optimizedSheets.clamp(1, currentSheets),
      tipsEn: const <String>[
        'Enable Long-Edge Duplex to halve physical sheets.',
        'Switch to Grayscale + Draft quality for internal review drafts.',
      ],
      tipsSi: const <String>[
        'කඩදාසි ප්‍රමාණය අඩකින් අඩු කිරීමට දෙපස මුද්‍රණය (Long-Edge Duplex) භාවිතා කරන්න.',
        'තීන්ත ඉතිරි කර ගැනීමට කළු-සුදු (Grayscale) සහ Draft තත්ත්වය තෝරන්න.',
      ],
      ecoPresetSettings: item.settings.copyWith(
        duplex: DuplexMode.longEdge,
        isColor: false,
        quality: PrintQualityMode.draft,
      ),
    );
  }

  @override
  Future<AiScanEnhancementResult?> enhanceScannedDocument({
    required PrintQueueItem item,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiOcrResult?> performOcr({
    required PrintQueueItem item,
    required List<String> languageHints,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiSummaryResult?> summarizeDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  }) async =>
      null;

  @override
  Future<AiTranslationResult?> translateDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant consent,
  }) async =>
      null;
}

/// Concrete [IAiService] implementation with plugin registry and strict
/// consent enforcement. Disabled by default (`masterAiEnabled: false`).
/// Contains ZERO network calls.
class AiServiceRegistry implements IAiService {
  AiServiceRegistry({
    required AiSettingsState settings,
    List<IAiPlugin>? initialPlugins,
  }) : _settings = settings {
    registerPlugin(const NoopOfflineAiPlugin());
    registerPlugin(const LocalOnDeviceHeuristicPluginStub());
    if (initialPlugins != null) {
      for (final p in initialPlugins) {
        registerPlugin(p);
      }
    }
  }

  final Map<String, IAiPlugin> _plugins = <String, IAiPlugin>{};
  AiSettingsState _settings;

  void updateSettings(AiSettingsState newSettings) {
    _settings = newSettings;
  }

  @override
  bool get isEnabled =>
      _settings.masterAiEnabled &&
      _settings.preferredMode != AiExecutionMode.disabled;

  @override
  AiSettingsState get currentSettings => _settings;

  @override
  List<AiPluginDescriptor> get registeredPlugins =>
      _plugins.values.map((p) => p.descriptor).toList(growable: false);

  @override
  IAiPlugin get activePlugin {
    if (!isEnabled) {
      return const NoopOfflineAiPlugin();
    }
    return _plugins[_settings.activePluginId] ?? const NoopOfflineAiPlugin();
  }

  @override
  void registerPlugin(IAiPlugin plugin) {
    _plugins[plugin.descriptor.id] = plugin;
  }

  @override
  void unregisterPlugin(String pluginId) {
    if (pluginId == NoopOfflineAiPlugin.kDescriptor.id) return;
    _plugins.remove(pluginId);
  }

  /// Verifies that:
  /// 1. Master AI switch is enabled.
  /// 2. The specific [capability] is enabled by the user.
  /// 3. A valid [AiConsentGrant] was provided for this capability.
  /// 4. If the plugin requires network, the user explicitly acknowledged `leavesLocalMachineAcknowledged`.
  bool _verifyConsentAndCapability(
    AiFeatureCapability capability,
    AiConsentGrant? consent,
  ) {
    if (!_settings.isCapabilityAllowed(capability)) {
      DiagnosticLogger.instance.info(
        'AiService',
        'Blocked ${capability.id}: capability or master AI switch is disabled.',
      );
      return false;
    }

    if (consent == null || consent.capability != capability) {
      DiagnosticLogger.instance.warn(
        'AiService',
        'Blocked ${capability.id}: missing explicit user AiConsentGrant.',
      );
      return false;
    }

    final plugin = activePlugin;
    if (plugin.descriptor.requiresNetwork &&
        !consent.leavesLocalMachineAcknowledged) {
      DiagnosticLogger.instance.warn(
        'AiService',
        'Blocked ${capability.id}: online plugin requires explicit leavesLocalMachineAcknowledged consent.',
      );
      return false;
    }

    return true;
  }

  @override
  Future<AiDataDisclosurePreview> previewDataDisclosure({
    required AiFeatureCapability capability,
    required PrintQueueItem item,
  }) {
    final plugin = _plugins[_settings.activePluginId] ??
        const LocalOnDeviceHeuristicPluginStub();
    return plugin.buildDisclosurePreview(capability: capability, item: item);
  }

  @override
  Future<AiPrintSettingsSuggestion?> suggestPrintSettings({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.smartPrintSettings,
      consent,
    )) {
      return null;
    }
    return activePlugin.suggestPrintSettings(item: item, consent: consent!);
  }

  @override
  Future<AiBlankPageDetectionResult?> detectBlankPages({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.blankPageDetection,
      consent,
    )) {
      return null;
    }
    return activePlugin.detectBlankPages(item: item, consent: consent!);
  }

  @override
  Future<AiInkPaperSavingAdvice?> analyzeInkAndPaperSavings({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.inkPaperSavingAdvice,
      consent,
    )) {
      return null;
    }
    return activePlugin.analyzeInkAndPaperSavings(
      item: item,
      consent: consent!,
    );
  }

  @override
  Future<AiScanEnhancementResult?> enhanceScannedDocument({
    required PrintQueueItem item,
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.scanEnhancement,
      consent,
    )) {
      return null;
    }
    return activePlugin.enhanceScannedDocument(item: item, consent: consent!);
  }

  @override
  Future<AiOcrResult?> performOcr({
    required PrintQueueItem item,
    List<String> languageHints = const ['si', 'en'],
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.ocrExtraction,
      consent,
    )) {
      return null;
    }
    return activePlugin.performOcr(
      item: item,
      languageHints: languageHints,
      consent: consent!,
    );
  }

  @override
  Future<AiSummaryResult?> summarizeDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.summarization,
      consent,
    )) {
      return null;
    }
    return activePlugin.summarizeDocument(
      item: item,
      targetLanguageCode: targetLanguageCode,
      consent: consent!,
    );
  }

  @override
  Future<AiTranslationResult?> translateDocument({
    required PrintQueueItem item,
    required String targetLanguageCode,
    required AiConsentGrant? consent,
  }) async {
    if (!_verifyConsentAndCapability(
      AiFeatureCapability.translation,
      consent,
    )) {
      return null;
    }
    return activePlugin.translateDocument(
      item: item,
      targetLanguageCode: targetLanguageCode,
      consent: consent!,
    );
  }
}

/// Riverpod controller managing [AiSettingsState] (disabled by default).
class AiSettingsNotifier extends StateNotifier<AiSettingsState> {
  AiSettingsNotifier() : super(const AiSettingsState());

  void toggleShowComingSoonSection(bool visible) {
    state = state.copyWith(showComingSoonSection: visible);
  }

  void setMasterAiEnabled(bool enabled) {
    if (!enabled) {
      state = state.copyWith(
        masterAiEnabled: false,
        preferredMode: AiExecutionMode.disabled,
      );
      DiagnosticLogger.instance.info(
        'AiSettings',
        'AI subsystem disabled (100% No-Op mode).',
      );
    } else {
      state = state.copyWith(
        masterAiEnabled: true,
        preferredMode: AiExecutionMode.localOnDevice,
        activePluginId: LocalOnDeviceHeuristicPluginStub.kDescriptor.id,
      );
      DiagnosticLogger.instance.info(
        'AiSettings',
        'AI subsystem preview enabled in Local On-Device mode (Zero Network).',
      );
    }
  }

  void setExecutionMode(AiExecutionMode mode) {
    state = state.copyWith(
      preferredMode: mode,
      masterAiEnabled: mode != AiExecutionMode.disabled,
      activePluginId: mode == AiExecutionMode.disabled
          ? NoopOfflineAiPlugin.kDescriptor.id
          : LocalOnDeviceHeuristicPluginStub.kDescriptor.id,
    );
  }

  void toggleCapability(AiFeatureCapability capability, bool enabled) {
    final updated = Set<AiFeatureCapability>.from(state.enabledCapabilities);
    if (enabled) {
      updated.add(capability);
    } else {
      updated.remove(capability);
    }
    state = state.copyWith(enabledCapabilities: updated);
  }
}

final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiSettingsState>((ref) {
  return AiSettingsNotifier();
});

final aiServiceRegistryProvider = Provider<IAiService>((ref) {
  final settings = ref.watch(aiSettingsProvider);
  return AiServiceRegistry(settings: settings);
});
