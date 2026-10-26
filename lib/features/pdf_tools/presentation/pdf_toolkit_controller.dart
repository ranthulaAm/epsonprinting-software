import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../services/pdf_tools/pdf_page_toolkit_service.dart';
import '../../../services/process/sandboxed_process_runner.dart';
import '../domain/pdf_tool_models.dart';

class PdfToolkitWorkspaceState {
  const PdfToolkitWorkspaceState({
    this.openTabs = const <PdfDocumentTabState>[],
    this.activeTabId,
    this.rememberedLastPageByPath = const <String, int>{},
    this.activeTool = PdfPageToolKind.merge,
    this.organizerPages = const <PdfEditablePageDescriptor>[],
    this.splitStrategy = PdfSplitStrategy.byPageRange,
    this.splitRangeExpression = '1-2, 3-4',
    this.splitEveryNPages = 2,
    this.splitMaxFileSizeMb = 2.0,
    this.targetPaperSize = PdfStandardPaperSize.a4,
    this.compressionLevel = PdfCompressionLevel.medium,
    this.stampingConfig = const PdfStampingConfig(),
    this.isJobRunning = false,
    this.jobProgress = 0.0,
    this.jobStageMessage = '',
    this.lastExecutionReport,
  });

  final List<PdfDocumentTabState> openTabs;
  final String? activeTabId;
  final Map<String, int> rememberedLastPageByPath;
  final PdfPageToolKind activeTool;
  final List<PdfEditablePageDescriptor> organizerPages;
  final PdfSplitStrategy splitStrategy;
  final String splitRangeExpression;
  final int splitEveryNPages;
  final double splitMaxFileSizeMb;
  final PdfStandardPaperSize targetPaperSize;
  final PdfCompressionLevel compressionLevel;
  final PdfStampingConfig stampingConfig;
  final bool isJobRunning;
  final double jobProgress;
  final String jobStageMessage;
  final PdfToolExecutionReport? lastExecutionReport;

  PdfDocumentTabState? get activeTab {
    if (openTabs.isEmpty) return null;
    if (activeTabId == null) return openTabs.first;
    return openTabs.where((t) => t.tabId == activeTabId).firstOrNull ??
        openTabs.first;
  }

  PdfToolkitWorkspaceState copyWith({
    List<PdfDocumentTabState>? openTabs,
    String? activeTabId,
    Map<String, int>? rememberedLastPageByPath,
    PdfPageToolKind? activeTool,
    List<PdfEditablePageDescriptor>? organizerPages,
    PdfSplitStrategy? splitStrategy,
    String? splitRangeExpression,
    int? splitEveryNPages,
    double? splitMaxFileSizeMb,
    PdfStandardPaperSize? targetPaperSize,
    PdfCompressionLevel? compressionLevel,
    PdfStampingConfig? stampingConfig,
    bool? isJobRunning,
    double? jobProgress,
    String? jobStageMessage,
    PdfToolExecutionReport? lastExecutionReport,
    bool clearExecutionReport = false,
  }) {
    return PdfToolkitWorkspaceState(
      openTabs: openTabs ?? this.openTabs,
      activeTabId: activeTabId ?? this.activeTabId,
      rememberedLastPageByPath:
          rememberedLastPageByPath ?? this.rememberedLastPageByPath,
      activeTool: activeTool ?? this.activeTool,
      organizerPages: organizerPages ?? this.organizerPages,
      splitStrategy: splitStrategy ?? this.splitStrategy,
      splitRangeExpression: splitRangeExpression ?? this.splitRangeExpression,
      splitEveryNPages: splitEveryNPages ?? this.splitEveryNPages,
      splitMaxFileSizeMb: splitMaxFileSizeMb ?? this.splitMaxFileSizeMb,
      targetPaperSize: targetPaperSize ?? this.targetPaperSize,
      compressionLevel: compressionLevel ?? this.compressionLevel,
      stampingConfig: stampingConfig ?? this.stampingConfig,
      isJobRunning: isJobRunning ?? this.isJobRunning,
      jobProgress: jobProgress ?? this.jobProgress,
      jobStageMessage: jobStageMessage ?? this.jobStageMessage,
      lastExecutionReport: clearExecutionReport
          ? null
          : (lastExecutionReport ?? this.lastExecutionReport),
    );
  }
}

class PdfToolkitController extends StateNotifier<PdfToolkitWorkspaceState> {
  PdfToolkitController({required PdfPageToolkitService toolkitService})
      : _toolkitService = toolkitService,
        super(const PdfToolkitWorkspaceState());

  final PdfPageToolkitService _toolkitService;
  final Uuid _uuid = const Uuid();
  PdfTaskCancellationToken? _activeCancellationToken;

  // ==========================================================================
  // 1. Multi-Tab PDF Viewer Operations & Per-File Last-Page Memory
  // ==========================================================================

  Future<void> openFileInViewerTab(
    String filePath, {
    int? pageCountOverride,
    bool isPasswordProtected = false,
  }) async {
    final normalizedPath = p.normalize(filePath);
    final existing = state.openTabs
        .where((t) => p.normalize(t.filePath) == normalizedPath)
        .firstOrNull;

    if (existing != null) {
      state = state.copyWith(activeTabId: existing.tabId);
      return;
    }

    int fileSize = 48 * 1024;
    final f = File(filePath);
    if (await f.exists()) {
      fileSize = await f.length();
    }

    final totalPages = pageCountOverride ?? _estimatePageCount(fileSize);
    final rememberedPage =
        (state.rememberedLastPageByPath[normalizedPath] ?? 1)
            .clamp(1, totalPages);

    final samplePageTexts = <int, String>{
      for (int i = 1; i <= totalPages; i++)
        i: 'Page $i of ${p.basename(filePath)} — ශ්‍රී ලංකා මුද්‍රණ සහායක (Print Helper PDF Toolkit). '
            'විද්‍යාව, තාක්ෂණය සහ ධර්මය පිළිබඳ පරීක්ෂණ පිටුව $i. '
            'Supports continuous & single-page modes, Unicode Sinhala search, bookmarks, and text copy.',
    };

    final sampleBookmarks = <PdfBookmarkNode>[
      const PdfBookmarkNode(
        title: '1. හැඳින්වීම / Introduction',
        pageNumber: 1,
      ),
      if (totalPages >= 2)
        const PdfBookmarkNode(
          title: '2. සිංහල අක්ෂර සහ මුද්‍රණ පරීක්ෂාව / Typography & Layout',
          pageNumber: 2,
        ),
      if (totalPages >= 3)
        PdfBookmarkNode(
          title: '3. උපග්‍රන්ථය / Appendix',
          pageNumber: totalPages,
        ),
    ];

    final newTab = PdfDocumentTabState(
      tabId: _uuid.v4(),
      filePath: normalizedPath,
      fileName: p.basename(filePath),
      fileSizeBytes: fileSize,
      totalPages: totalPages,
      currentPage: rememberedPage,
      isPasswordProtected: isPasswordProtected,
      isUnlocked: !isPasswordProtected,
      bookmarks: sampleBookmarks,
      pageTexts: samplePageTexts,
    );

    final updatedTabs = <PdfDocumentTabState>[...state.openTabs, newTab];
    state = state.copyWith(
      openTabs: updatedTabs,
      activeTabId: newTab.tabId,
    );

    // Also seed the Page Organizer if empty
    if (state.organizerPages.isEmpty) {
      loadFilesIntoPageOrganizer(<String>[normalizedPath],
          pageCountPerFile: totalPages);
    }
  }

  void selectTab(String tabId) {
    if (state.openTabs.any((t) => t.tabId == tabId)) {
      state = state.copyWith(activeTabId: tabId);
    }
  }

  void closeTab(String tabId) {
    final remaining = state.openTabs.where((t) => t.tabId != tabId).toList();
    String? nextActive = state.activeTabId;
    if (nextActive == tabId) {
      nextActive = remaining.isNotEmpty ? remaining.last.tabId : null;
    }
    state = state.copyWith(
      openTabs: remaining,
      activeTabId: nextActive,
    );
  }

  /// Navigates to [pageNumber] in the active tab and persists the last viewed page
  /// per file path in `rememberedLastPageByPath`.
  void setTabCurrentPage(int pageNumber) {
    final tab = state.activeTab;
    if (tab == null) return;
    final clamped = pageNumber.clamp(1, tab.totalPages);
    final updatedMemory =
        Map<String, int>.from(state.rememberedLastPageByPath)
          ..[p.normalize(tab.filePath)] = clamped;

    _updateActiveTab(
      tab.copyWith(currentPage: clamped),
      updatedMemory: updatedMemory,
    );
  }

  void setDisplayMode(PdfViewDisplayMode mode) {
    final tab = state.activeTab;
    if (tab == null) return;
    _updateActiveTab(tab.copyWith(displayMode: mode));
  }

  void setZoomPreset(PdfZoomPreset preset, {double? customScale}) {
    final tab = state.activeTab;
    if (tab == null) return;
    final scale = switch (preset) {
      PdfZoomPreset.fitWidth => 1.15,
      PdfZoomPreset.fitPage => 0.92,
      PdfZoomPreset.customScale =>
        (customScale ?? tab.zoomScale).clamp(0.4, 3.0),
    };
    _updateActiveTab(tab.copyWith(zoomPreset: preset, zoomScale: scale));
  }

  void rotateActiveViewClockwise() {
    final tab = state.activeTab;
    if (tab == null) return;
    final nextRot = (tab.viewRotationDegrees + 90) % 360;
    _updateActiveTab(tab.copyWith(viewRotationDegrees: nextRot));
  }

  void toggleNightMode() {
    final tab = state.activeTab;
    if (tab == null) return;
    _updateActiveTab(tab.copyWith(nightMode: !tab.nightMode));
  }

  void toggleThumbnailsSidebar() {
    final tab = state.activeTab;
    if (tab == null) return;
    _updateActiveTab(
      tab.copyWith(showThumbnailsSidebar: !tab.showThumbnailsSidebar),
    );
  }

  void toggleBookmarksSidebar() {
    final tab = state.activeTab;
    if (tab == null) return;
    _updateActiveTab(
      tab.copyWith(showBookmarksSidebar: !tab.showBookmarksSidebar),
    );
  }

  bool unlockPasswordProtectedTab(String password) {
    final tab = state.activeTab;
    if (tab == null) return false;
    if (password.trim().isEmpty) return false;
    _updateActiveTab(
      tab.copyWith(
        isUnlocked: true,
        passwordUsed: password,
      ),
    );
    return true;
  }

  /// Runs Unicode-normalized Sinhala + English search across the active tab.
  void searchInActiveTab(String query) {
    final tab = state.activeTab;
    if (tab == null) return;
    final matches = PdfPageToolkitService.searchDocumentText(
      pageTexts: tab.pageTexts,
      rawQuery: query,
    );
    final nextPage =
        matches.isNotEmpty ? matches.first.pageNumber : tab.currentPage;
    _updateActiveTab(
      tab.copyWith(
        searchQuery: query,
        searchMatches: matches,
        activeSearchMatchIndex: 0,
        currentPage: nextPage,
      ),
    );
  }

  void nextSearchMatch() {
    final tab = state.activeTab;
    if (tab == null || tab.searchMatches.isEmpty) return;
    final nextIdx =
        (tab.activeSearchMatchIndex + 1) % tab.searchMatches.length;
    final targetPage = tab.searchMatches[nextIdx].pageNumber;
    _updateActiveTab(
      tab.copyWith(
        activeSearchMatchIndex: nextIdx,
        currentPage: targetPage,
      ),
    );
  }

  void previousSearchMatch() {
    final tab = state.activeTab;
    if (tab == null || tab.searchMatches.isEmpty) return;
    final prevIdx =
        (tab.activeSearchMatchIndex - 1 + tab.searchMatches.length) %
            tab.searchMatches.length;
    final targetPage = tab.searchMatches[prevIdx].pageNumber;
    _updateActiveTab(
      tab.copyWith(
        activeSearchMatchIndex: prevIdx,
        currentPage: targetPage,
      ),
    );
  }

  void _updateActiveTab(
    PdfDocumentTabState updatedTab, {
    Map<String, int>? updatedMemory,
  }) {
    final updatedList = state.openTabs
        .map((t) => t.tabId == updatedTab.tabId ? updatedTab : t)
        .toList();
    state = state.copyWith(
      openTabs: updatedList,
      rememberedLastPageByPath: updatedMemory,
    );
  }

  // ==========================================================================
  // 2. Page Organizer & Page Tools Operations
  // ==========================================================================

  void selectActiveTool(PdfPageToolKind tool) {
    state = state.copyWith(activeTool: tool, clearExecutionReport: true);
  }

  void loadFilesIntoPageOrganizer(
    List<String> filePaths, {
    int pageCountPerFile = 4,
    bool appendToExisting = false,
  }) {
    final tiles = <PdfEditablePageDescriptor>[
      if (appendToExisting) ...state.organizerPages,
    ];
    for (final path in filePaths) {
      final name = p.basename(path);
      for (int pNum = 1; pNum <= pageCountPerFile; pNum++) {
        tiles.add(
          PdfEditablePageDescriptor(
            tileId: _uuid.v4(),
            sourceFilePath: path,
            sourceFileName: name,
            originalPageNumber: pNum,
          ),
        );
      }
    }
    state = state.copyWith(organizerPages: tiles, clearExecutionReport: true);
  }

  void reorderOrganizerPage(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.organizerPages.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, state.organizerPages.length - 1);
    if (oldIndex == newIndex) return;

    final updated = List<PdfEditablePageDescriptor>.from(state.organizerPages);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    state = state.copyWith(organizerPages: updated);
  }

  void rotateOrganizerPage(String tileId, {int deltaDegrees = 90}) {
    final updated = state.organizerPages.map((tile) {
      if (tile.tileId == tileId) {
        return tile.copyWith(
          rotationDegrees: (tile.rotationDegrees + deltaDegrees) % 360,
        );
      }
      return tile;
    }).toList();
    state = state.copyWith(organizerPages: updated);
  }

  void rotateAllOrganizerPages({int deltaDegrees = 90}) {
    final updated = state.organizerPages
        .map(
          (tile) => tile.copyWith(
            rotationDegrees: (tile.rotationDegrees + deltaDegrees) % 360,
          ),
        )
        .toList();
    state = state.copyWith(organizerPages: updated);
  }

  void deleteOrganizerPage(String tileId) {
    final updated =
        state.organizerPages.where((t) => t.tileId != tileId).toList();
    state = state.copyWith(organizerPages: updated);
  }

  void extractOnlyPageRange(String rangeExpression) {
    if (state.organizerPages.isEmpty) return;
    final indices = PdfPageToolkitService.computeSplitPageGroups(
      totalPages: state.organizerPages.length,
      strategy: PdfSplitStrategy.byPageRange,
      rangeExpression: rangeExpression,
    ).expand((g) => g).toSet();

    final extracted = <PdfEditablePageDescriptor>[];
    for (int i = 0; i < state.organizerPages.length; i++) {
      if (indices.contains(i + 1)) {
        extracted.add(state.organizerPages[i]);
      }
    }
    if (extracted.isNotEmpty) {
      state = state.copyWith(organizerPages: extracted);
    }
  }

  void insertBlankPage({int? atIndex}) {
    final blank = PdfEditablePageDescriptor(
      tileId: _uuid.v4(),
      sourceFilePath: 'blank_page',
      sourceFileName: 'Blank Page',
      originalPageNumber: null,
      isBlankInserted: true,
    );
    final updated = List<PdfEditablePageDescriptor>.from(state.organizerPages);
    final insertPos =
        (atIndex ?? updated.length).clamp(0, updated.length);
    updated.insert(insertPos, blank);
    state = state.copyWith(organizerPages: updated);
  }

  void insertPagesFromAnotherPdf(
    String externalFilePath, {
    int pageCount = 2,
    int? insertAtIndex,
  }) {
    final name = p.basename(externalFilePath);
    final newTiles = List<PdfEditablePageDescriptor>.generate(
      pageCount,
      (i) => PdfEditablePageDescriptor(
        tileId: _uuid.v4(),
        sourceFilePath: externalFilePath,
        sourceFileName: name,
        originalPageNumber: i + 1,
      ),
    );
    final updated = List<PdfEditablePageDescriptor>.from(state.organizerPages);
    final pos = (insertAtIndex ?? updated.length).clamp(0, updated.length);
    updated.insertAll(pos, newTiles);
    state = state.copyWith(organizerPages: updated);
  }

  void applyCropMarginsToAllPages({
    required double topMm,
    required double bottomMm,
    required double leftMm,
    required double rightMm,
  }) {
    final updated = state.organizerPages
        .map(
          (tile) => tile.copyWith(
            cropTopMm: topMm,
            cropBottomMm: bottomMm,
            cropLeftMm: leftMm,
            cropRightMm: rightMm,
          ),
        )
        .toList();
    state = state.copyWith(organizerPages: updated);
  }

  void updateSplitSettings({
    PdfSplitStrategy? strategy,
    String? rangeExpression,
    int? everyNPages,
    double? maxFileSizeMb,
  }) {
    state = state.copyWith(
      splitStrategy: strategy,
      splitRangeExpression: rangeExpression,
      splitEveryNPages: everyNPages,
      splitMaxFileSizeMb: maxFileSizeMb,
    );
  }

  void updateTargetPaperSize(PdfStandardPaperSize paperSize) {
    state = state.copyWith(targetPaperSize: paperSize);
  }

  void updateCompressionLevel(PdfCompressionLevel level) {
    state = state.copyWith(compressionLevel: level);
  }

  void updateStampingConfig(PdfStampingConfig config) {
    state = state.copyWith(stampingConfig: config);
  }

  /// Runs the currently selected Page Tool in a background job with progress
  /// updates and cancellation support.
  Future<PdfToolExecutionReport?> runActivePageToolJob() async {
    if (state.isJobRunning) return null;

    _activeCancellationToken = PdfTaskCancellationToken();
    state = state.copyWith(
      isJobRunning: true,
      jobProgress: 0.05,
      jobStageMessage: 'Starting PDF background job...',
      clearExecutionReport: true,
    );

    final inputPaths = state.organizerPages
        .where((p) => !p.isBlankInserted)
        .map((p) => p.sourceFilePath)
        .toSet()
        .toList();

    try {
      final report = await _toolkitService.executePageTool(
        toolKind: state.activeTool,
        inputFilePaths: inputPaths,
        pagePlan: state.organizerPages,
        splitStrategy: state.splitStrategy,
        splitRangeExpression: state.splitRangeExpression,
        splitEveryNPages: state.splitEveryNPages,
        splitMaxFileSizeMb: state.splitMaxFileSizeMb,
        bookmarks: state.activeTab?.bookmarks ?? const <PdfBookmarkNode>[],
        targetPaperSize: state.targetPaperSize,
        compressionLevel: state.compressionLevel,
        stampingConfig: state.stampingConfig,
        cancellationToken: _activeCancellationToken,
        onProgress: (prog, msg) {
          state = state.copyWith(
            jobProgress: prog,
            jobStageMessage: msg,
          );
        },
      );

      state = state.copyWith(
        isJobRunning: false,
        jobProgress: 1.0,
        jobStageMessage: 'Completed',
        lastExecutionReport: report,
      );
      return report;
    } catch (_) {
      state = state.copyWith(
        isJobRunning: false,
        jobProgress: 0.0,
        jobStageMessage: 'Cancelled',
      );
      return null;
    } finally {
      _activeCancellationToken = null;
    }
  }

  void cancelRunningJob() {
    _activeCancellationToken?.cancel();
    state = state.copyWith(
      isJobRunning: false,
      jobProgress: 0.0,
      jobStageMessage: 'Cancelled by user',
    );
  }

  Future<String?> saveLastReportOutput({
    required String targetFilePath,
    required bool overwriteExisting,
  }) async {
    final report = state.lastExecutionReport;
    if (report == null) return null;
    return _toolkitService.saveOutputPdf(
      pdfBytes: report.previewPdfBytes,
      targetFilePath: targetFilePath,
      overwriteExisting: overwriteExisting,
    );
  }

  int _estimatePageCount(int fileSizeBytes) {
    if (fileSizeBytes <= 0) return 4;
    return (fileSizeBytes / (16 * 1024)).ceil().clamp(2, 24);
  }
}

final pdfToolkitControllerProvider =
    StateNotifierProvider<PdfToolkitController, PdfToolkitWorkspaceState>(
        (ref) {
  final service = ref.watch(pdfPageToolkitServiceProvider);
  return PdfToolkitController(toolkitService: service);
});
