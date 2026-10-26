import 'package:flutter/material.dart';

import '../../../../services/printer/models/printer_intelligence_models.dart';

/// Interactive 3-step Manual Duplex Assistant for printers without automatic
/// double-sided hardware (e.g. Epson EcoTank L3210, L3250, L18050).
///
/// - Step 1: Prints odd pages (`1, 3, 5...`)
/// - Step 2: Shows an animated flip diagram with Long-Edge vs Short-Edge guidance
/// - Step 3: Prints even pages (`2, 4, 6...`) in the correct tray order
class ManualDuplexAssistantDialog extends StatefulWidget {
  final int totalPages;
  final String printerName;
  final bool isSinhala;
  final Future<void> Function(List<int> pagesToPrint) onDispatchPagesBatch;

  const ManualDuplexAssistantDialog({
    super.key,
    required this.totalPages,
    required this.printerName,
    required this.isSinhala,
    required this.onDispatchPagesBatch,
  });

  @override
  State<ManualDuplexAssistantDialog> createState() =>
      _ManualDuplexAssistantDialogState();
}

class _ManualDuplexAssistantDialogState
    extends State<ManualDuplexAssistantDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0 = Odd pages, 1 = Flip stack, 2 = Even pages
  ManualDuplexFlipEdge _flipEdge = ManualDuplexFlipEdge.longEdge;
  bool _reverseEvenForRearFeed = true;
  bool _isPrintingBatch = false;
  late final AnimationController _flipAnimController;

  @override
  void initState() {
    super.initState();
    _flipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flipAnimController.dispose();
    super.dispose();
  }

  ManualDuplexAssistantPlan _buildPlan() {
    final safeTotal = widget.totalPages < 2 ? 2 : widget.totalPages;
    final odd = <int>[];
    final even = <int>[];
    for (int i = 1; i <= safeTotal; i++) {
      if (i.isOdd) {
        odd.add(i);
      } else {
        even.add(i);
      }
    }
    final orderedEven =
        _reverseEvenForRearFeed ? even.reversed.toList() : even;

    return ManualDuplexAssistantPlan(
      totalDocumentPages: safeTotal,
      step1OddPages: odd,
      step3EvenPages: orderedEven,
      needsBlankLastSheetKeepOut: safeTotal.isOdd && safeTotal > 1,
      flipEdge: _flipEdge,
      trayGuidanceEn: safeTotal.isOdd && safeTotal > 1
          ? 'Important: Your document has $safeTotal pages (an odd number). Leave the last printed sheet (Page $safeTotal) in the output tray and only flip the remaining sheets.'
          : 'Take all printed sheets from the output tray, keep them together in order, and flip them as shown below.',
      trayGuidanceSi: safeTotal.isOdd && safeTotal > 1
          ? 'වැදගත්: ඔබගේ ලේඛනයේ ඔත්තේ පිටු ගණනක් ($safeTotal) ඇත. අවසාන කොළය (පිටුව $safeTotal) පිටවුම් තැටියේම තබා, ඉතිරි කොළ පමණක් පෙරළා නැවත තැටියට ඇතුළු කරන්න.'
          : 'පිටතට පැමිණි සියලුම මුද්‍රිත කොළ පිළිවෙලට ගෙන පහත රූපයේ පරිදි පෙරළා නැවත තැටියට දමන්න.',
    );
  }

  Future<void> _printOddBatch(ManualDuplexAssistantPlan plan) async {
    setState(() => _isPrintingBatch = true);
    try {
      await widget.onDispatchPagesBatch(plan.step1OddPages);
      if (mounted) {
        setState(() {
          _isPrintingBatch = false;
          _currentStep = 1;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isPrintingBatch = false);
    }
  }

  Future<void> _printEvenBatch(ManualDuplexAssistantPlan plan) async {
    setState(() => _isPrintingBatch = true);
    try {
      await widget.onDispatchPagesBatch(plan.step3EvenPages);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _isPrintingBatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _buildPlan();
    final si = widget.isSinhala;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_stories_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              si
                  ? 'අතින් දෙපස මුද්‍රණ සහායකය (Manual Duplex Assistant)'
                  : 'Manual Duplex Assistant',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              si
                  ? '${widget.printerName} ස්වයංක්‍රීය දෙපස මුද්‍රණයට සහාය නොදක්වයි. පහත පියවර 3 අනුගමනය කරන්න:'
                  : '${widget.printerName} does not have an automatic 2-sided unit. Follow these 3 guided steps:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // Binding edge selector
            SegmentedButton<ManualDuplexFlipEdge>(
              segments: [
                ButtonSegment(
                  value: ManualDuplexFlipEdge.longEdge,
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text(
                    si ? 'දිගු දාරය (Long-Edge)' : 'Long-Edge (Book)',
                  ),
                ),
                ButtonSegment(
                  value: ManualDuplexFlipEdge.shortEdge,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    si ? 'කෙටි දාරය (Short-Edge)' : 'Short-Edge (Notepad)',
                  ),
                ),
              ],
              selected: {_flipEdge},
              onSelectionChanged: (sel) {
                setState(() => _flipEdge = sel.first);
              },
            ),
            const SizedBox(height: 14),

            // Stepper indicator
            Row(
              children: [
                _buildStepPill(
                  context,
                  index: 0,
                  title: si ? '1. ඔත්තේ පිටු' : '1. Odd Pages',
                ),
                const SizedBox(width: 6),
                _buildStepPill(
                  context,
                  index: 1,
                  title: si ? '2. කොළ පෙරළන්න' : '2. Flip Stack',
                ),
                const SizedBox(width: 6),
                _buildStepPill(
                  context,
                  index: 2,
                  title: si ? '3. ඉරට්ටේ පිටු' : '3. Even Pages',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Active step body
            if (_currentStep == 0) _buildStep1OddBody(context, plan, si),
            if (_currentStep == 1) _buildStep2FlipBody(context, plan, si),
            if (_currentStep == 2) _buildStep3EvenBody(context, plan, si),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPrintingBatch
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(si ? 'අවලංගු කරන්න' : 'Cancel'),
        ),
        if (_currentStep == 0)
          FilledButton.icon(
            onPressed: _isPrintingBatch ? null : () => _printOddBatch(plan),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(
              si
                  ? 'පියවර 1: ඔත්තේ පිටු මුද්‍රණය කරන්න (${plan.oddPagesRangeText})'
                  : 'Step 1: Print Odd Pages (${plan.oddPagesRangeText})',
            ),
          ),
        if (_currentStep == 1)
          FilledButton.icon(
            onPressed: () => setState(() => _currentStep = 2),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              si
                  ? 'මම කොළ පෙරළා තැටියට දැමුවෙමි →'
                  : 'I Flipped & Reloaded the Stack →',
            ),
          ),
        if (_currentStep == 2)
          FilledButton.icon(
            onPressed: _isPrintingBatch ? null : () => _printEvenBatch(plan),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(
              si
                  ? 'පියවර 3: ඉරට්ටේ පිටු මුද්‍රණය කරන්න (${plan.evenPagesRangeText})'
                  : 'Step 3: Print Even Pages (${plan.evenPagesRangeText})',
            ),
          ),
      ],
    );
  }

  Widget _buildStepPill(
    BuildContext context, {
    required int index,
    required String title,
  }) {
    final theme = Theme.of(context);
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primaryContainer
              : (isDone
                  ? const Color(0xFF16A34A).withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : (isActive
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 14,
              color: isDone
                  ? const Color(0xFF16A34A)
                  : (isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1OddBody(
    BuildContext context,
    ManualDuplexAssistantPlan plan,
    bool si,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            si
                ? 'පළමුව ඔත්තේ පිටු (${plan.oddPagesRangeText}) මුද්‍රණය කෙරේ.'
                : 'First, Print Helper will print all odd-numbered pages (${plan.oddPagesRangeText}).',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            si
                ? 'මුද්‍රණය අවසන් වන තෙක් රැඳී සිටින්න, ඉන්පසු කොළ පෙරළන ආකාරය පියවර 2 මගින් පෙන්වනු ඇත.'
                : 'Wait until all odd pages finish coming out into the output tray, then Step 2 will show you exactly how to flip and reload them.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2FlipBody(
    BuildContext context,
    ManualDuplexAssistantPlan plan,
    bool si,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated 3D sheet flip visual
          Center(
            child: AnimatedBuilder(
              animation: _flipAnimController,
              builder: (context, _) {
                final angle = _flipAnimController.value * 3.14159;
                final matrix = Matrix4.identity()..setEntry(3, 2, 0.0015);
                if (_flipEdge == ManualDuplexFlipEdge.longEdge) {
                  matrix.rotateY(angle);
                } else {
                  matrix.rotateX(angle);
                }
                return Transform(
                  alignment: Alignment.center,
                  transform: matrix,
                  child: Container(
                    width: 96,
                    height: 124,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _flipEdge == ManualDuplexFlipEdge.longEdge
                              ? Icons.flip_rounded
                              : Icons.swap_vert_circle_outlined,
                          color: theme.colorScheme.primary,
                          size: 30,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          angle < 1.57
                              ? (si ? 'පිටුව 1 (ඉදිරිපස)' : 'Odd Side (1, 3...)')
                              : (si ? 'පිටුව 2 (පසුපස)' : 'Even Side (2, 4...)'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            si ? _flipEdge.instructionSi : _flipEdge.instructionEn,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            si ? plan.trayGuidanceSi : plan.trayGuidanceEn,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3EvenBody(
    BuildContext context,
    ManualDuplexAssistantPlan plan,
    bool si,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            si
                ? 'දැන් ඉරට්ටේ පිටු (${plan.evenPagesRangeText}) නිවැරදි අනුපිළිවෙලට මුද්‍රණය කෙරේ.'
                : 'Ready to print even pages (${plan.evenPagesRangeText}) onto the back side of your sheets.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              si
                  ? 'පසුපස තැටිය (Rear Feed Slot) සඳහා පිටු අනුපිළිවෙල ප්‍රතිලෝම කරන්න'
                  : 'Reverse even-page order (Recommended for Epson Rear Tray)',
              style: theme.textTheme.bodySmall,
            ),
            value: _reverseEvenForRearFeed,
            onChanged: (v) => setState(() => _reverseEvenForRearFeed = v),
          ),
        ],
      ),
    );
  }
}
