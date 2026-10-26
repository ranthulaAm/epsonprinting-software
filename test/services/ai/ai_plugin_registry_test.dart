import 'package:flutter_test/flutter_test.dart';
import 'package:print_helper/features/workspace/domain/print_queue_item.dart';
import 'package:print_helper/services/ai/ai_plugin_registry.dart';
import 'package:print_helper/services/ai/i_ai_service.dart';
import 'package:print_helper/services/ai/models/ai_models.dart';

void main() {
  final sampleQueueItem = PrintQueueItem(
    id: 'test-item-1',
    filePath: 'assets/test_documents/sinhala_orthography_test.md',
    fileName: 'sinhala_orthography_test.md',
    fileSizeBytes: 4096,
    pageCount: 4,
    documentType: PrintDocumentType.markdown,
    addedAt: DateTime(2026, 10, 26),
    textPreviewSnippet: '# ශ්‍රී ලංකා මුද්‍රණ සහායක\nපරීක්ෂණ ලේඛනය.',
  );

  group('AiService Interface, Plugin Registry & Strict Consent Model', () {
    test('is disabled by default and blocks all 7 extension points when disabled',
        () async {
      const defaultSettings = AiSettingsState();
      expect(defaultSettings.masterAiEnabled, isFalse);
      expect(defaultSettings.preferredMode, equals(AiExecutionMode.disabled));

      final service = AiServiceRegistry(settings: defaultSettings);
      expect(service.isEnabled, isFalse);
      expect(
        service.activePlugin.descriptor.id,
        equals(NoopOfflineAiPlugin.kDescriptor.id),
      );

      final fakeConsent = AiConsentGrant(
        capability: AiFeatureCapability.smartPrintSettings,
        executionMode: AiExecutionMode.localOnDevice,
        grantedAt: DateTime(2026, 10, 26),
        approvedPayloadBytes: 4096,
        leavesLocalMachineAcknowledged: false,
      );

      // Even if a caller passes a consent object, disabled service returns null
      expect(
        await service.suggestPrintSettings(
          item: sampleQueueItem,
          consent: fakeConsent,
        ),
        isNull,
      );
      expect(
        await service.detectBlankPages(
          item: sampleQueueItem,
          consent: fakeConsent,
        ),
        isNull,
      );
      expect(
        await service.analyzeInkAndPaperSavings(
          item: sampleQueueItem,
          consent: fakeConsent,
        ),
        isNull,
      );
      expect(
        await service.enhanceScannedDocument(
          item: sampleQueueItem,
          consent: fakeConsent,
        ),
        isNull,
      );
      expect(
        await service.performOcr(
          item: sampleQueueItem,
          consent: fakeConsent,
        ),
        isNull,
      );
      expect(
        await service.summarizeDocument(
          item: sampleQueueItem,
          targetLanguageCode: 'si',
          consent: fakeConsent,
        ),
        isNull,
      );
      expect(
        await service.translateDocument(
          item: sampleQueueItem,
          targetLanguageCode: 'en',
          consent: fakeConsent,
        ),
        isNull,
      );
    });

    test(
      'blocks execution when master AI is enabled but explicit AiConsentGrant is missing',
      () async {
        final enabledSettings = AiSettingsState(
          masterAiEnabled: true,
          preferredMode: AiExecutionMode.localOnDevice,
          enabledCapabilities: {
            AiFeatureCapability.smartPrintSettings,
            AiFeatureCapability.inkPaperSavingAdvice,
          },
          activePluginId: LocalOnDeviceHeuristicPluginStub.kDescriptor.id,
        );

        final service = AiServiceRegistry(settings: enabledSettings);
        expect(service.isEnabled, isTrue);

        // Missing consent -> must be blocked and return null
        final withoutConsent = await service.suggestPrintSettings(
          item: sampleQueueItem,
          consent: null,
        );
        expect(withoutConsent, isNull);

        // With valid consent after inspecting disclosure -> succeeds offline
        final disclosure = await service.previewDataDisclosure(
          capability: AiFeatureCapability.smartPrintSettings,
          item: sampleQueueItem,
        );
        expect(disclosure.leavesLocalMachine, isFalse);
        expect(disclosure.fileName, equals('sinhala_orthography_test.md'));

        final validConsent = AiConsentGrant(
          capability: AiFeatureCapability.smartPrintSettings,
          executionMode: disclosure.executionMode,
          grantedAt: DateTime(2026, 10, 26),
          approvedPayloadBytes: disclosure.payloadSizeBytes,
          leavesLocalMachineAcknowledged: disclosure.leavesLocalMachine,
        );

        final suggestion = await service.suggestPrintSettings(
          item: sampleQueueItem,
          consent: validConsent,
        );
        expect(suggestion, isNotNull);
        expect(
          suggestion!.recommendedSettings.duplex,
          equals(DuplexMode.longEdge),
        );
      },
    );
  });
}
