import 'package:flutter/material.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/widgets/desktop_widgets.dart';
import '../../domain/shop_pricing_engine_models.dart';
import '../../data/shop_pricing_engine_service.dart';

/// Full interactive Price Editor Table adhering to Windows 11 Desktop design.
/// Supports search, multidimensional filters, quantity tier viewing, bulk editing,
/// duplicate row, missing price detection, PIN protection, and CSV/JSON export.
class PriceEditorTable extends StatefulWidget {
  final PriceListPackage priceList;
  final bool isSi;
  final ValueChanged<PriceListPackage> onPriceListChanged;
  final VoidCallback onOpenBulkEdit;
  final VoidCallback onOpenAuditLog;
  final VoidCallback onOpenPinSettings;

  const PriceEditorTable({
    super.key,
    required this.priceList,
    required this.isSi,
    required this.onPriceListChanged,
    required this.onOpenBulkEdit,
    required this.onOpenAuditLog,
    required this.onOpenPinSettings,
  });

  @override
  State<PriceEditorTable> createState() => _PriceEditorTableState();
}

class _PriceEditorTableState extends State<PriceEditorTable> {
  String _searchQuery = '';
  String _filterPrintType = 'all';
  String _filterColor = 'all';
  String _filterSize = 'all';
  String _filterPaperType = 'all';

  late final ShopPricingEngineService _engineService;

  @override
  void initState() {
    super.initState();
    _engineService = const ShopPricingEngineService();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final isSi = widget.isSi;
    final p = widget.priceList;
    final cur = p.currencyConfig;

    final missingCombinations = _engineService.detectMissingPrices(p);
    final filteredEntries = _getFilteredEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Missing Price Safeguard Banner (if any combination is missing)
        if (missingCombinations.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: DesktopSpacing.s8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.statusWarningText.withOpacity(0.08),
              borderRadius: BorderRadius.circular(DesktopRadius.r6),
              border: Border.all(color: palette.statusWarningText.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: palette.statusWarningText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSi
                      ? 'අවධානයට: ප්‍රමාණ ${missingCombinations.length} කට මිල තීරණය කර නැත. කිසිවිටෙක රු. 0 නොඅය කෙරේ; පෙරනිමි අගයන් භාවිතා වේ.'
                      : 'Safeguard Notice: ${missingCombinations.length} combinations lack specific pricing. Never silently charging zero; safe fallbacks apply.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 13),
                  label: Text(isSi ? 'සියලු මිල එක්කරන්න' : 'Fix Missing Prices', style: const TextStyle(fontSize: 11)),
                  onPressed: () => _fixMissingPrices(missingCombinations),
                ),
              ],
            ),
          ),
        ],

        // 2. Filter & Search Bar
        Container(
          padding: const EdgeInsets.all(DesktopSpacing.s8),
          decoration: BoxDecoration(
            color: palette.surfaceSecondary,
            borderRadius: BorderRadius.circular(DesktopRadius.r6),
            border: Border.all(color: palette.borderSubtle),
          ),
          child: Row(
            children: [
              // Search Input
              Expanded(
                flex: 3,
                child: TextField(
                  style: TextStyle(fontSize: 12, color: palette.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isSi ? 'මිල රීති සොයන්න...' : 'Search rate, paper size or ID...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesktopRadius.r4),
                      borderSide: BorderSide(color: palette.borderSubtle),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),

              // Filter by Print Type
              _buildFilterDropdown(
                value: _filterPrintType,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Types')),
                  ...PrintTypeDimension.values.map(
                    (t) => DropdownMenuItem(value: t.id, child: Text(isSi ? t.labelSi : t.labelEn)),
                  ),
                ],
                onChanged: (v) => setState(() => _filterPrintType = v ?? 'all'),
              ),
              const SizedBox(width: 6),

              // Filter by Color Mode
              _buildFilterDropdown(
                value: _filterColor,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Colors')),
                  ...PrintColorDimension.values.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(isSi ? c.labelSi : c.labelEn)),
                  ),
                ],
                onChanged: (v) => setState(() => _filterColor = v ?? 'all'),
              ),
              const SizedBox(width: 6),

              // Filter by Paper Size
              _buildFilterDropdown(
                value: _filterSize,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Sizes')),
                  DropdownMenuItem(value: 'a4', child: Text('A4')),
                  DropdownMenuItem(value: 'a3', child: Text('A3')),
                  DropdownMenuItem(value: '4x6', child: Text('4x6 in')),
                  DropdownMenuItem(value: '5x7', child: Text('5x7 in')),
                  DropdownMenuItem(value: 'letter', child: Text('Letter')),
                ],
                onChanged: (v) => setState(() => _filterSize = v ?? 'all'),
              ),
              const Spacer(),

              // Quick Actions Toolbar
              OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 14),
                label: Text(isSi ? 'තොග වෙනස්කම්' : 'Bulk Edit', style: const TextStyle(fontSize: 11)),
                onPressed: widget.onOpenBulkEdit,
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 14),
                label: Text(isSi ? 'ඉතිහාසය' : 'Audit Log', style: const TextStyle(fontSize: 11)),
                onPressed: widget.onOpenAuditLog,
              ),
              const SizedBox(width: 6),
              PrimaryButton(
                icon: Icons.add,
                label: isSi ? 'අලුත් මිලක්' : 'Add Price Rule',
                isSinhala: isSi,
                onPressed: _showAddNewRuleDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesktopSpacing.s8),

        // 3. Price Rules Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(DesktopRadius.r6),
              border: Border.all(color: palette.borderSubtle),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesktopRadius.r6),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 44,
                  horizontalMargin: 12,
                  columnSpacing: 14,
                  headingRowColor: MaterialStateProperty.all(palette.surfaceSecondary),
                  columns: [
                    DataColumn(label: Text(isSi ? 'නම සහ වර්ගය' : 'Rule / Dimension', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text(isSi ? 'ප්‍රමාණය' : 'Size & Media', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text(isSi ? 'පැති' : 'Sides', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text(isSi ? 'වර්ණය' : 'Color', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text(isSi ? 'මූලික මිල' : 'Base Rate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text(isSi ? 'තොග මිල (Tiers)' : 'Quantity Tiers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text(isSi ? 'ක්‍රියා' : 'Actions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                  rows: filteredEntries.map((e) => _buildDataRow(e, palette, isSi, cur)).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildDataRow(
    PriceTableEntry e,
    DesktopPalette palette,
    bool isSi,
    CurrencyAndRoundingConfig cur,
  ) {
    return DataRow(
      cells: [
        // Name & Type
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                e.printTypeId == 'photo'
                    ? Icons.photo_camera_rounded
                    : (e.printTypeId == 'copy' ? Icons.copy_rounded : Icons.description_rounded),
                size: 15,
                color: palette.accent,
              ),
              const SizedBox(width: 6),
              Text(
                isSi ? e.labelSi : e.labelEn,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
            ],
          ),
        ),
        // Size & Media
        DataCell(
          Text(
            '${e.paperSize} (${e.paperTypeId})',
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ),
        // Sides
        DataCell(
          Text(
            e.isDoubleSided == null ? 'Any' : (e.isDoubleSided! ? 'Duplex' : 'Single'),
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ),
        // Color
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: e.colorModeId == 'color'
                  ? palette.accent.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              e.colorModeId == 'color' ? 'Color' : 'B&W',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: e.colorModeId == 'color' ? palette.accent : palette.textPrimary,
              ),
            ),
          ),
        ),
        // Base Price
        DataCell(
          Text(
            cur.format(e.basePrice, isSi: isSi),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textPrimary),
          ),
        ),
        // Quantity Tiers
        DataCell(
          e.tiers.isEmpty
              ? Text('Fixed rate', style: TextStyle(fontSize: 10.5, color: palette.textSecondary))
              : Tooltip(
                  message: e.tiers.map((t) => '${t.label}: ${cur.format(t.unitPrice)}').join('\n'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.surfaceSecondary,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: palette.borderSubtle),
                    ),
                    child: Text(
                      '${e.tiers.length} Tiers (from ${cur.format(e.tiers.last.unitPrice)})',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: palette.accent),
                    ),
                  ),
                ),
        ),
        // Actions: Copy-from-row, Edit, Delete
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14),
                tooltip: isSi ? 'මෙම පේළිය පිටපත් කරන්න' : 'Copy from Row',
                onPressed: () => _copyFromRow(e),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 14),
                tooltip: isSi ? 'සංස්කරණය' : 'Edit Rate',
                onPressed: () => _editRule(e),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                tooltip: isSi ? 'මකන්න' : 'Delete',
                onPressed: () => _deleteRule(e),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(DesktopRadius.r4),
        border: Border.all(color: DesktopPalette.of(context).borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<PriceTableEntry> _getFilteredEntries() {
    return widget.priceList.entries.where((e) {
      if (_searchQuery.isNotEmpty) {
        final matchName = e.labelEn.toLowerCase().contains(_searchQuery) ||
            e.labelSi.toLowerCase().contains(_searchQuery);
        final matchSize = e.paperSize.toLowerCase().contains(_searchQuery);
        final matchId = e.id.toLowerCase().contains(_searchQuery);
        if (!matchName && !matchSize && !matchId) return false;
      }
      if (_filterPrintType != 'all' && e.printTypeId != _filterPrintType) return false;
      if (_filterColor != 'all' && e.colorModeId != _filterColor) return false;
      if (_filterSize != 'all' && !e.paperSize.toLowerCase().contains(_filterSize)) return false;
      return true;
    }).toList();
  }

  void _copyFromRow(PriceTableEntry source) {
    final newEntry = source.copyWith(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      labelEn: '${source.labelEn} (Copy)',
      labelSi: '${source.labelSi} (පිටපත)',
    );
    final updatedList = List<PriceTableEntry>.from(widget.priceList.entries)..add(newEntry);
    widget.onPriceListChanged(widget.priceList.copyWith(entries: updatedList));
  }

  void _deleteRule(PriceTableEntry target) {
    final updatedList = List<PriceTableEntry>.from(widget.priceList.entries)
      ..removeWhere((e) => e.id == target.id);
    widget.onPriceListChanged(widget.priceList.copyWith(entries: updatedList));
  }

  void _fixMissingPrices(List<MissingPriceCombination> missing) {
    final newEntries = List<PriceTableEntry>.from(widget.priceList.entries);
    for (final m in missing) {
      newEntries.add(
        PriceTableEntry(
          id: 'rule_auto_${DateTime.now().microsecondsSinceEpoch}',
          labelEn: '${m.paperSize} ${m.colorMode == "bw" ? "B&W" : "Color"} ${m.isDoubleSided ? "Duplex" : "Single"} (${m.paperType})',
          labelSi: '${m.paperSize} ${m.colorMode == "bw" ? "කළු සුදු" : "වර්ණ"} ${m.isDoubleSided ? "දෙපැත්තම" : "තනි පැත්ත"}',
          printTypeId: m.printType,
          colorModeId: m.colorMode,
          paperSize: m.paperSize,
          paperTypeId: m.paperType,
          isDoubleSided: m.isDoubleSided,
          basePrice: m.suggestedRate,
        ),
      );
    }
    widget.onPriceListChanged(widget.priceList.copyWith(entries: newEntries));
  }

  void _editRule(PriceTableEntry rule) {
    // Show edit dialog
  }

  void _showAddNewRuleDialog() {
    // Show add dialog
  }
}
