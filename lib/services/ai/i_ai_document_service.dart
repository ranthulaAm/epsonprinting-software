import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_plugin_registry.dart';
import 'i_ai_service.dart';
import 'models/ai_models.dart';

export 'ai_plugin_registry.dart';
export 'i_ai_service.dart';
export 'models/ai_models.dart';

final aiServiceProvider = Provider<IAiDocumentService>((ref) {
  final registry = ref.watch(aiServiceRegistryProvider);
  return _LegacyAiDocumentServiceBridge(registry);
});

class AiPreflightReport {
  const AiPreflightReport({
    required this.summary,
    required this.warnings,
  });

  final String summary;
  final List<String> warnings;
}

/// Legacy bridge interface kept for backward compatibility while delegating
/// to the full [IAiService] plugin registry.
abstract interface class IAiDocumentService {
  bool get isEnabled;
  Future<AiPreflightReport?> analyzeDocumentPreflight(String filePath);
  Future<String?> extractAndTranslateText(
    String filePath, {
    required String targetLocale,
  });
}

class NoopAiDocumentService implements IAiDocumentService {
  const NoopAiDocumentService();

  @override
  bool get isEnabled => false;

  @override
  Future<AiPreflightReport?> analyzeDocumentPreflight(String filePath) async =>
      null;

  @override
  Future<String?> extractAndTranslateText(
    String filePath, {
    required String targetLocale,
  }) async =>
      null;
}

class _LegacyAiDocumentServiceBridge implements IAiDocumentService {
  const _LegacyAiDocumentServiceBridge(this._aiService);

  final IAiService _aiService;

  @override
  bool get isEnabled => _aiService.isEnabled;

  @override
  Future<AiPreflightReport?> analyzeDocumentPreflight(String filePath) async =>
      null;

  @override
  Future<String?> extractAndTranslateText(
    String filePath, {
    required String targetLocale,
  }) async =>
      null;
}
