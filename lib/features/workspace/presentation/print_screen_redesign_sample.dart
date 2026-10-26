import 'package:flutter/material.dart';
import '../../../core/theme/desktop_design_system.dart';
import '../../../core/widgets/desktop_widgets.dart';

/// One-screen reference sample demonstrating the Print Workspace built
/// exclusively with `desktop_design_system.dart` tokens and the 8 reusable
/// widgets (`PrimaryButton`, `SecondaryButton`, `StatusBadge`, `SupplyBar`,
/// `Panel`, `EmptyState`, `InlineMessage`, `FormRow`).
///
/// Zero hard-coded colors, zero arbitrary spacing values, flat surfaces with
/// 1px borders, 4–8px corner radius, uniform outlined icons, and plain wording.
class PrintScreenRedesignSample extends StatefulWidget {
  final bool initialIsSinhala;
  final bool reduceMotion;

  const PrintScreenRedesignSample({
    super.key,
    this.initialIsSinhala = false,
    this.reduceMotion = false,
  });

  @override
  State<PrintScreenRedesignSample> createState() =>
      _PrintScreenRedesignSampleState();
}

class _PrintScreenRedesignSampleState extends State<PrintScreenRedesignSample> {
  late bool _isSinhala;
  bool _showEmptyQueue = false;
  String _selectedPrinter = 'EPSON WorkForce Pro WF-4830';
  String _selectedPaperSize = 'A4';
  String _selectedDuplex = 'Two-sided (long edge)';
  String _selectedColor = 'Color';
  String _selectedMedia = 'Plain Paper';
  int _copies = 1;

  @override
  void initState() {
    super.initState();
    _isSinhala = widget.initialIsSinhala;
  }

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final animDuration = DesktopMotion.resolve(
      DesktopMotion.standardTransition,
      reduceMotion: widget.reduceMotion,
    );

    return Scaffold(
      backgroundColor: palette.backgroundCanvas,
      body: Padding(
        padding: DesktopSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Command Bar (Flat Panel header bar)
            _buildTopBar(context, palette),
            const SizedBox(height: DesktopSpacing.s16),

            // 2. Three-Column Desktop Workspace
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Print Queue (flex 4)
                  Expanded(
                    flex: 4,
                    child: _buildQueuePanel(context, palette, animDuration),
                  ),
                  const SizedBox(width: DesktopSpacing.s16),

                  // Center Column: Print Options (flex 4)
                  Expanded(
                    flex: 4,
                    child: _buildSettingsPanel(context, palette),
                  ),
                  const SizedBox(width: DesktopSpacing.s16),

                  // Right Column: Live Printer Info (flex 4)
                  Expanded(
                    flex: 4,
                    child: _buildPrinterInfoPanel(context, palette, animDuration),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, DesktopPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopSpacing.s16,
        vertical: DesktopSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: DesktopRadius.border8,
        border: Border.all(
          color: palette.borderSubtle,
          width: DesktopRadius.borderWidth1px,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.print_outlined,
            size: DesktopTypography.scale20,
            color: palette.accent,
          ),
          const SizedBox(width: DesktopSpacing.s8),
          Text(
            _isSinhala ? 'මුද්‍රණ වැඩබිම' : 'Print Workspace',
            style: DesktopTypography.title20(
              palette,
              isSinhala: _isSinhala,
            ),
          ),
          const SizedBox(width: DesktopSpacing.s16),
          StatusBadge(
            label: _isSinhala ? 'සූදානම්' : 'Ready',
            kind: DesktopStatusKind.ready,
            icon: Icons.check_circle_outline,
            isSinhala: _isSinhala,
          ),
          const Spacer(),
          SecondaryButton(
            label: _showEmptyQueue
                ? (_isSinhala ? 'ගොනු පෙන්වන්න' : 'Show sample files')
                : (_isSinhala ? 'හිස් පෝලිම පෙන්වන්න' : 'Preview empty state'),
            icon: Icons.folder_open_outlined,
            isSinhala: _isSinhala,
            onPressed: () => setState(() => _showEmptyQueue = !_showEmptyQueue),
          ),
          const SizedBox(width: DesktopSpacing.s8),
          SecondaryButton(
            label: _isSinhala ? 'English' : 'සිංහල',
            icon: Icons.translate_outlined,
            isSinhala: !_isSinhala,
            onPressed: () => setState(() => _isSinhala = !_isSinhala),
          ),
          const SizedBox(width: DesktopSpacing.s8),
          SecondaryButton(
            label: _isSinhala ? 'ගොනු එක් කරන්න' : 'Add files',
            icon: Icons.add_outlined,
            isSinhala: _isSinhala,
            onPressed: () => setState(() => _showEmptyQueue = false),
          ),
          const SizedBox(width: DesktopSpacing.s8),
          PrimaryButton(
            label: _isSinhala ? 'මුද්‍රණය කරන්න' : 'Print',
            icon: Icons.print_outlined,
            isSinhala: _isSinhala,
            onPressed: _showEmptyQueue ? null : () {},
          ),
        ],
      ),
    );
  }

  Widget _buildQueuePanel(
    BuildContext context,
    DesktopPalette palette,
    Duration animDuration,
  ) {
    return Panel(
      title: _isSinhala ? 'මුද්‍රණ ගොනු ලැයිස්තුව' : 'Files to print',
      subtitle: _showEmptyQueue
          ? (_isSinhala ? 'ගොනු 0' : '0 files')
          : (_isSinhala ? 'ගොනු 2 • මුළු පිටු 14' : '2 files • 14 pages total'),
      isSinhala: _isSinhala,
      child: AnimatedSwitcher(
        duration: animDuration,
        switchInCurve: DesktopMotion.curve,
        switchOutCurve: DesktopMotion.curve,
        child: _showEmptyQueue
            ? EmptyState(
                key: const ValueKey('queue_empty'),
                icon: Icons.description_outlined,
                title: _isSinhala
                    ? 'මුද්‍රණ පෝලිමේ ගොනු නොමැත'
                    : 'No files in queue',
                message: _isSinhala
                    ? 'මුද්‍රණය කිරීමට PDF, Word හෝ රූප ගොනු මෙහි එක් කරන්න.'
                    : 'Drop PDF, Word, or image files here, or click Add files.',
                actionLabel: _isSinhala ? 'ගොනු එක් කරන්න' : 'Add files',
                isSinhala: _isSinhala,
                onActionPressed: () => setState(() => _showEmptyQueue = false),
              )
            : Column(
                key: const ValueKey('queue_populated'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFileRow(
                    palette,
                    fileName: 'Invoice_2026_1042.pdf',
                    pagesText: _isSinhala ? 'පිටු 2 • A4' : '2 pages • A4',
                    isSelected: true,
                  ),
                  const SizedBox(height: DesktopSpacing.s8),
                  _buildFileRow(
                    palette,
                    fileName: 'Annual_Accounts_Summary.pdf',
                    pagesText: _isSinhala ? 'පිටු 12 • A4' : '12 pages • A4',
                    isSelected: false,
                  ),
                  const SizedBox(height: DesktopSpacing.s16),
                  InlineMessage(
                    kind: DesktopStatusKind.ready,
                    isSinhala: _isSinhala,
                    title: _isSinhala
                        ? 'A4 කඩදාසි Cassette 1 තැටියේ පටවා ඇත'
                        : 'A4 paper is loaded in Cassette 1',
                    detail: _isSinhala
                        ? 'මෙම මුද්‍රණ යන්ත්‍රය ස්වයංක්‍රීය දෙපස මුද්‍රණයට සහාය දක්වයි.'
                        : 'Automatic two-sided printing is supported on this printer.',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFileRow(
    DesktopPalette palette, {
    required String fileName,
    required String pagesText,
    required bool isSelected,
  }) {
    return Container(
      padding: DesktopSpacing.compactPadding,
      decoration: BoxDecoration(
        color: isSelected ? palette.accentSubtleBg : palette.surfacePrimary,
        borderRadius: DesktopRadius.border4,
        border: Border.all(
          color: isSelected ? palette.accentSubtleBorder : palette.borderSubtle,
          width: DesktopRadius.borderWidth1px,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: DesktopTypography.scale16,
            color: isSelected ? palette.accent : palette.textSecondary,
          ),
          const SizedBox(width: DesktopSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: DesktopTypography.body14(
                    palette,
                    weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: DesktopSpacing.s4),
                Text(
                  pagesText,
                  style: DesktopTypography.caption12(
                    palette,
                    isSinhala: _isSinhala,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: _isSinhala ? 'සූදානම්' : 'Ready',
            kind: DesktopStatusKind.ready,
            isSinhala: _isSinhala,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(BuildContext context, DesktopPalette palette) {
    final isManualDuplexOnly = _selectedPrinter.contains('L3250');

    return Panel(
      title: _isSinhala ? 'මුද්‍රණ සැකසුම්' : 'Print settings',
      subtitle: _isSinhala
          ? 'නිල Windows මුද්‍රණ ධාවකය (DEVMODE) හරහා ක්‍රියාත්මක වේ'
          : 'Applied via official Windows driver (DEVMODE)',
      isSinhala: _isSinhala,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow(
            label: _isSinhala ? 'මුද්‍රණ යන්ත්‍රය' : 'Choose printer',
            isSinhala: _isSinhala,
            control: SecondaryButton(
              label: _selectedPrinter,
              icon: Icons.print_outlined,
              expandWidth: true,
              onPressed: () {
                setState(() {
                  _selectedPrinter = _selectedPrinter.contains('WF-4830')
                      ? 'EPSON EcoTank L3250 (USB)'
                      : 'EPSON WorkForce Pro WF-4830';
                });
              },
            ),
          ),
          FormRow(
            label: _isSinhala ? 'පිටපත් ගණන' : 'Copies',
            isSinhala: _isSinhala,
            control: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SecondaryButton(
                  label: '-',
                  onPressed: _copies > 1
                      ? () => setState(() => _copies--)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesktopSpacing.s16,
                  ),
                  child: Text(
                    '$_copies',
                    style: DesktopTypography.body14(
                      palette,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                SecondaryButton(
                  label: '+',
                  onPressed: () => setState(() => _copies++),
                ),
              ],
            ),
          ),
          FormRow(
            label: _isSinhala ? 'කඩදාසි ප්‍රමාණය' : 'Paper size',
            isSinhala: _isSinhala,
            control: Wrap(
              spacing: DesktopSpacing.s8,
              children: ['A4', 'A3', '4x6'].map((size) {
                return SecondaryButton(
                  label: size,
                  isSelected: _selectedPaperSize == size,
                  onPressed: () => setState(() => _selectedPaperSize = size),
                );
              }).toList(),
            ),
          ),
          FormRow(
            label: _isSinhala ? 'දෙපස මුද්‍රණය' : 'Two-sided printing',
            helperOrReasonText: isManualDuplexOnly
                ? (_isSinhala
                    ? 'ස්වයංක්‍රීය දෙපස ඒකකයක් නැත; අතින් පිටු පෙරළීමේ සහායකය භාවිතා වේ'
                    : 'No auto-duplex unit; uses manual flip assistant')
                : null,
            isSinhala: _isSinhala,
            control: SecondaryButton(
              label: isManualDuplexOnly
                  ? (_isSinhala ? 'අතින් පෙරළීම (Manual)' : 'Manual flip')
                  : _selectedDuplex,
              expandWidth: true,
              onPressed: () {
                setState(() {
                  _selectedDuplex = _selectedDuplex == 'One-sided'
                      ? 'Two-sided (long edge)'
                      : 'One-sided';
                });
              },
            ),
          ),
          FormRow(
            label: _isSinhala ? 'වර්ණ මාදිලිය' : 'Color mode',
            isSinhala: _isSinhala,
            control: Wrap(
              spacing: DesktopSpacing.s8,
              children: [
                SecondaryButton(
                  label: _isSinhala ? 'වර්ණ' : 'Color',
                  isSelected: _selectedColor == 'Color',
                  onPressed: () => setState(() => _selectedColor = 'Color'),
                ),
                SecondaryButton(
                  label: _isSinhala ? 'කළු-සුදු' : 'Black & white',
                  isSelected: _selectedColor == 'B&W',
                  onPressed: () => setState(() => _selectedColor = 'B&W'),
                ),
              ],
            ),
          ),
          FormRow(
            label: _isSinhala ? 'කඩදාසි වර්ගය' : 'Paper type',
            isSinhala: _isSinhala,
            control: SecondaryButton(
              label: _selectedMedia,
              expandWidth: true,
              onPressed: () {
                setState(() {
                  _selectedMedia = _selectedMedia == 'Plain Paper'
                      ? 'Photo Paper Glossy'
                      : 'Plain Paper';
                });
              },
            ),
          ),
          if (_selectedPaperSize == 'A3' && isManualDuplexOnly) ...[
            const SizedBox(height: DesktopSpacing.s8),
            InlineMessage(
              kind: DesktopStatusKind.warning,
              isSinhala: _isSinhala,
              title: _isSinhala
                  ? 'A3 මෙම මුද්‍රණ යන්ත්‍රය මගින් සහාය නොදක්වයි'
                  : 'A3 is not supported by this printer',
              detail: _isSinhala
                  ? 'EPSON L3250 සඳහා උපරිම කඩදාසි ප්‍රමාණය A4 / Legal වේ.'
                  : 'Maximum supported width on EPSON L3250 is A4 / Legal.',
              actionLabel: _isSinhala ? 'A4 තෝරන්න' : 'Switch to A4',
              onActionPressed: () => setState(() => _selectedPaperSize = 'A4'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrinterInfoPanel(
    BuildContext context,
    DesktopPalette palette,
    Duration animDuration,
  ) {
    final isUsbEcoTank = _selectedPrinter.contains('L3250');

    return Panel(
      title: _selectedPrinter,
      subtitle: isUsbEcoTank
          ? (_isSinhala ? 'USB කේබල් • Windows Spooler' : 'USB Direct • Windows Spooler')
          : (_isSinhala
              ? 'ජාලය 192.168.1.60 • IPP + SNMP'
              : 'Network 192.168.1.60 • IPP + SNMP'),
      isSinhala: _isSinhala,
      headerTrailing: StatusBadge(
        label: _isSinhala ? 'සූදානම්' : 'Ready',
        kind: DesktopStatusKind.ready,
        isSinhala: _isSinhala,
      ),
      child: AnimatedSwitcher(
        duration: animDuration,
        switchInCurve: DesktopMotion.curve,
        switchOutCurve: DesktopMotion.curve,
        child: Column(
          key: ValueKey(_selectedPrinter),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSinhala ? 'තීන්ත සහ නඩත්තු මට්ටම්' : 'Ink & maintenance levels',
              style: DesktopTypography.body14(
                palette,
                isSinhala: _isSinhala,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DesktopSpacing.s8),
            if (isUsbEcoTank) ...[
              SupplyBar(
                label: _isSinhala ? 'තීන්ත මට්ටම් (USB)' : 'Ink levels (USB)',
                percentage: null,
                statusText: _isSinhala
                    ? 'මෙම මුද්‍රණ යන්ත්‍රය මගින් වාර්තා නොකෙරේ'
                    : 'Not reported by this printer',
                barColor: palette.supplyBlack,
                statusKind: DesktopStatusKind.neutral,
                isSinhala: _isSinhala,
              ),
            ] else ...[
              SupplyBar(
                label: _isSinhala ? 'කළු (Black)' : 'Black',
                percentage: 84,
                statusText: '84%',
                barColor: palette.supplyBlack,
                statusKind: DesktopStatusKind.ready,
                estimateNote: _isSinhala
                    ? '~පිටු 2,100 (ඇස්තමේන්තුවකි)'
                    : '~2,100 pages remaining (estimate)',
                isSinhala: _isSinhala,
              ),
              SupplyBar(
                label: _isSinhala ? 'සයන් (Cyan)' : 'Cyan',
                percentage: 62,
                statusText: '62%',
                barColor: palette.supplyCyan,
                statusKind: DesktopStatusKind.ready,
                isSinhala: _isSinhala,
              ),
              SupplyBar(
                label: _isSinhala ? 'මැජෙන්ටා (Magenta)' : 'Magenta',
                percentage: 12,
                statusText: _isSinhala ? 'අඩුයි (12%)' : 'Low (12%)',
                barColor: palette.supplyMagenta,
                statusKind: DesktopStatusKind.warning,
                isSinhala: _isSinhala,
              ),
              SupplyBar(
                label: _isSinhala ? 'කහ (Yellow)' : 'Yellow',
                percentage: 78,
                statusText: '78%',
                barColor: palette.supplyYellow,
                statusKind: DesktopStatusKind.ready,
                isSinhala: _isSinhala,
              ),
              SupplyBar(
                label: _isSinhala
                    ? 'නඩත්තු කොටුව (Maintenance Box T04D1)'
                    : 'Maintenance Box (T04D1)',
                percentage: 14,
                statusText: _isSinhala ? 'අඩුයි (14%)' : 'Near end of life (14%)',
                barColor: palette.supplyMaintenance,
                statusKind: DesktopStatusKind.warning,
                isSinhala: _isSinhala,
              ),
            ],
            const SizedBox(height: DesktopSpacing.s8),
            InlineMessage(
              kind: DesktopStatusKind.warning,
              isSinhala: _isSinhala,
              title: _isSinhala
                  ? 'නඩත්තු කොටුව ආයු කාලය අවසන් වීමට ආසන්නයි'
                  : 'Maintenance box near end of life',
              detail: _isSinhala
                  ? 'ඔබට දැනට මුද්‍රණය කළ හැකි නමුත් ඉක්මනින් නව T04D1 කොටුවක් සූදානම් කර ගන්න.'
                  : 'You can continue printing now. Keep a replacement T04D1 box ready.',
            ),
            const SizedBox(height: DesktopSpacing.s16),
            SecondaryButton(
              label: _isSinhala
                  ? 'පරීක්ෂණ වාර්තාව පිටපත් කරන්න'
                  : 'Copy printer diagnostics',
              icon: Icons.copy_outlined,
              isSinhala: _isSinhala,
              expandWidth: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
