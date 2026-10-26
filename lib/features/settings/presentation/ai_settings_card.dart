import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../services/ai/ai_plugin_registry.dart';
import '../../../services/ai/models/ai_models.dart';
import '../../workspace/domain/print_queue_item.dart';

/// Settings > AI Section ("Coming Soon", Disabled by Default) +
/// Interactive Data Disclosure & Consent Preview Dialog.
class AiSettingsSectionCard extends ConsumerWidget {
  const AiSettingsSectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final strings = AppStrings.of(lang);
    final aiSettings = ref.watch(aiSettingsProvider);
    final aiNotifier = ref.read(aiSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (!aiSettings.showComingSoonSection) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => aiNotifier.toggleShowComingSoonSection(true),
          icon: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(
            strings.isSi
                ? 'AI විශේෂාංග කොටස පෙන්වන්න (Show AI "Coming Soon" Section)'
                : 'Show AI Assistant ("Coming Soon") Section',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with "COMING SOON" & "DISABLED BY DEFAULT" badges + Hide button
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      strings.isSi
                          ? 'AI සහායක (ළඟදීම පැමිණේ • Coming Soon)'
                          : 'AI Document Assistant (Coming Soon)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        strings.isSi
                            ? 'පෙරනිමියෙන් අක්‍රියයි (Disabled by Default)'
                            : 'DISABLED BY DEFAULT • COMING SOON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () =>
                      aiNotifier.toggleShowComingSoonSection(false),
                  icon: const Icon(Icons.visibility_off_outlined, size: 16),
                  label: Text(
                    strings.isSi ? 'සඟවන්න (Hide Section)' : 'Hide Section',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Strict Consent Model Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.32),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.isSi
                              ? 'දැඩි අනුමැති ප්‍රතිපත්තිය (Strict Consent Guarantee):'
                              : 'Strict Consent Model — Nothing Is Sent Anywhere Without Your Approval:',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.isSi
                              ? 'ඔබ විසින්ම විශේෂාංගයක් සක්‍රිය කර, යවනු ලබන දත්ත මොනවාදැයි පෙරදසුනෙන් (Payload Inspection) පරීක්ෂා කර අනුමත කරන තුරු කිසිදු දත්තයක් කිසිදු තැනකට යවනු නොලැබේ. මේ අදියරේදී කිසිදු ජාල ඇමතුමක් (Zero Network Calls) ඇතුළත් කර නොමැත.'
                              : 'Nothing is processed or sent anywhere unless you explicitly enable a feature AND inspect the exact payload preview before execution. In this release, zero network calls exist in the codebase.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Master Toggle & Execution Mode Selector
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                strings.isSi
                    ? 'AI පද්ධති පෙරදසුන සක්‍රිය කරන්න (Enable AI Architecture Sandbox)'
                    : 'Enable AI Plugin Architecture Sandbox (Local Offline Preview)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                aiSettings.masterAiEnabled
                    ? (strings.isSi
                        ? 'සක්‍රියයි: දේශීය (On-Device) පරීක්ෂණ ප්‍රකාරය — ජාල සම්බන්ධතා 0කි.'
                        : 'Active: Local On-Device Sandbox — Zero network calls.')
                    : (strings.isSi
                        ? 'අක්‍රියයි (No-Op): කිසිදු AI ක්‍රියාවලියක් සිදු නොවේ.'
                        : 'Disabled (Default): All AI extension points are completely inactive.'),
              ),
              value: aiSettings.masterAiEnabled,
              onChanged: aiNotifier.setMasterAiEnabled,
            ),

            const Divider(height: 16),

            // List of the 7 Extension Points (Marked "Coming Soon")
            Text(
              strings.isSi
                  ? 'අනාගත AI දිගු කිරීම් (Planned Extension Points — Coming Soon):'
                  : 'Planned AI Extension Points (Coming Soon):',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),

            ...AiFeatureCapability.values.map((cap) {
              final isChecked = aiSettings.enabledCapabilities.contains(cap);
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: aiSettings.masterAiEnabled && isChecked,
                onChanged: aiSettings.masterAiEnabled
                    ? (val) =>
                        aiNotifier.toggleCapability(cap, val ?? false)
                    : null,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.isSi ? cap.titleSi : cap.titleEn,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        strings.isSi ? 'ළඟදීම' : 'Coming Soon',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  strings.isSi ? cap.descriptionSi : cap.descriptionEn,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Button to preview the Mandatory Consent & Payload Inspection Dialog
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _showConsentPreviewDemoDialog(context, ref, strings),
                  icon: const Icon(Icons.policy_rounded, size: 18),
                  label: Text(
                    strings.isSi
                        ? 'දත්ත අනුමැති පෙරදසුන පරීක්ෂා කරන්න (Preview Consent & Payload Inspector)'
                        : 'Preview "What Will Be Sent" Consent Dialog',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConsentPreviewDemoDialog(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final aiService = ref.read(aiServiceRegistryProvider);
    final demoItem = PrintQueueItem(
      id: 'demo-doc-1',
      filePath: 'assets/test_documents/sinhala_orthography_test.md',
      fileName: 'sinhala_orthography_test.md',
      fileSizeBytes: 3420,
      pageCount: 2,
      documentType: PrintDocumentType.markdown,
      addedAt: DateTime(2026, 10, 26),
      textPreviewSnippet:
          '# ශ්‍රී ලංකා මුද්‍රණ සහායක (Print Helper)\nවිද්‍යාව, තාක්ෂණය සහ ධර්මය පිළිබඳ පරීක්ෂණ ලේඛනය.',
    );

    final disclosure = await aiService.previewDataDisclosure(
      capability: AiFeatureCapability.ocrExtraction,
      item: demoItem,
    );

    if (!context.mounted) return;

    await showDialog<AiConsentGrant?>(
      context: context,
      builder: (ctx) => AiConsentDisclosureDialog(
        disclosure: disclosure,
        strings: strings,
      ),
    );
  }
}

/// Interactive Consent & Data Disclosure Modal that shows the user the exact
/// file metadata, pages, byte size, execution target (Local On-Device vs. Online API),
/// and redacted payload snippet before any AI plugin is allowed to run.
class AiConsentDisclosureDialog extends StatelessWidget {
  const AiConsentDisclosureDialog({
    super.key,
    required this.disclosure,
    required this.strings,
  });

  final AiDataDisclosurePreview disclosure;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.shield_outlined, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.isSi
                  ? 'AI දත්ත පරීක්ෂාව සහ අනුමැතිය (AI Data Disclosure & Consent)'
                  : 'AI Data Disclosure — Inspect What Will Be Processed',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: disclosure.leavesLocalMachine
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      disclosure.leavesLocalMachine
                          ? Icons.cloud_upload_outlined
                          : Icons.computer_rounded,
                      size: 18,
                      color: disclosure.leavesLocalMachine
                          ? colorScheme.onErrorContainer
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        disclosure.leavesLocalMachine
                            ? (strings.isSi
                                ? 'අවවාදයයි: මෙමගින් තෝරාගත් දත්ත බාහිර සේවාවකට යවනු ලැබේ.'
                                : 'Online API Mode: Approved payload will be sent to the configured endpoint.')
                            : (strings.isSi
                                ? '100% දේශීයයි (On-Device): කිසිදු දත්තයක් ඔබගේ පරිගණකයෙන් පිටතට නොයයි.'
                                : '100% Local On-Device Mode: Nothing leaves your PC.'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _DisclosureRow(
                label: strings.isSi ? 'විශේෂාංගය (Feature):' : 'Capability:',
                value: strings.isSi
                    ? disclosure.capability.titleSi
                    : disclosure.capability.titleEn,
              ),
              _DisclosureRow(
                label: strings.isSi ? 'ක්‍රියාත්මක වන ආකාරය:' : 'Target Runtime:',
                value: disclosure.targetEndpointOrModelName,
              ),
              _DisclosureRow(
                label: strings.isSi ? 'ගොනුව සහ ප්‍රමාණය:' : 'File & Payload Size:',
                value:
                    '${disclosure.fileName} (${disclosure.formattedPayloadSize}, Pages: ${disclosure.pagesIncluded.join(", ")})',
              ),
              _DisclosureRow(
                label: strings.isSi
                    ? 'ඇතුළත් දත්ත ක්ෂේත්‍ර:'
                    : 'Fields Included:',
                value: disclosure.dataFieldsIncluded.join(' • '),
              ),
              const SizedBox(height: 10),
              Text(
                strings.isSi
                    ? 'සැකසීමට නියමිත දත්ත පෙරදසුන (Exact Payload Preview):'
                    : 'Exact Payload Preview:',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: SelectableText(
                  disclosure.redactedSnippetPreview,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontFamilyFallback: ['NotoSansSinhala'],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            strings.isSi ? 'ප්‍රතික්ෂේප කරන්න (Cancel)' : 'Deny / Cancel',
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              AiConsentGrant(
                capability: disclosure.capability,
                executionMode: disclosure.executionMode,
                grantedAt: DateTime.now(),
                approvedPayloadBytes: disclosure.payloadSizeBytes,
                leavesLocalMachineAcknowledged: disclosure.leavesLocalMachine,
              ),
            );
          },
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(
            strings.isSi
                ? 'මම පරීක්ෂා කළෙමි — අනුමත කරන්න'
                : 'I Inspected the Payload — Approve Once',
          ),
        ),
      ],
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
