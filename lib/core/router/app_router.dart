import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/pdf_tools/presentation/pdf_toolkit_controller.dart';
import '../../features/pdf_tools/presentation/pdf_tools_workspace_screen.dart';
import '../../features/presets/presentation/presets_screen.dart';
import '../../features/printers/presentation/printers_screen.dart';
import '../../features/queue/presentation/job_queue_controller.dart';
import '../../features/queue/presentation/jobs_screen.dart';
import '../../features/settings/presentation/shell_sections.dart';
import '../../features/shop_mode/presentation/shop_mode_controller.dart';
import '../../features/shop_mode/presentation/shop_mode_screen.dart';
import '../../features/workspace/presentation/queue_controller.dart';
import '../../features/workspace/presentation/widgets/custom_title_bar.dart';
import '../../features/workspace/presentation/widgets/global_drop_overlay.dart';
import '../../features/workspace/presentation/workspace_screen.dart';
import '../integration/global_command_palette_and_recent_files.dart';
import '../l10n/app_strings.dart';
import '../theme/app_motion.dart';
import '../theme/desktop_design_system.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/print',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainAppShell(navigationShell: navigationShell);
        },
        branches: [
          // 0. Print
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/print',
                builder: (context, state) => const WorkspaceScreen(),
              ),
            ],
          ),
          // 1. Printers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/printers',
                builder: (context, state) => const PrintersScreen(),
              ),
            ],
          ),
          // 2. Jobs
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/jobs',
                builder: (context, state) => const JobsScreen(),
              ),
            ],
          ),
          // 3. Tools
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tools',
                builder: (context, state) => const PdfToolsWorkspaceScreen(),
              ),
            ],
          ),
          // 4. Shop
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shop',
                builder: (context, state) => const ShopModeScreen(),
              ),
            ],
          ),
          // 5. Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: '/presets',
                builder: (context, state) => const PresetsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class MainAppShell extends ConsumerWidget {
  const MainAppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = AppStrings.of(locale);
    final queueState = ref.watch(queueControllerProvider);
    final queueController = ref.read(queueControllerProvider.notifier);
    final jobQueueState = ref.watch(jobQueueControllerProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    final palette = DesktopPalette.of(context);

    return CallbackShortcuts(
      bindings: {
        // Ctrl+K or Cmd+K: Global Tool Search & Command Palette
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            GlobalCommandPaletteDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            GlobalCommandPaletteDialog.show(context),
      },
      child: Scaffold(
        backgroundColor: palette.backgroundCanvas,
        body: Column(
          children: [
            // Custom Frameless Window Title Bar
            const CustomTitleBar(),

            // Main Window DropTarget (drop one or many files ANYWHERE on the window)
            Expanded(
              child: DropTarget(
                onDragEntered: (_) =>
                    queueController.setDraggingOverWindow(true),
                onDragExited: (_) =>
                    queueController.setDraggingOverWindow(false),
                onDragDone: (DropDoneDetails details) async {
                  queueController.setDraggingOverWindow(false);
                  final droppedPaths =
                      details.files.map((xFile) => xFile.path).toList();
                  // Shared Drop Zone: add to Print Queue, Shop Quick Print, PDF Viewer & Recent Files
                  await queueController.addFilePaths(droppedPaths);
                  await ref
                      .read(shopModeControllerProvider.notifier)
                      .addFilesToQuickPrint(droppedPaths);
                  final pdfCtrl =
                      ref.read(pdfToolkitControllerProvider.notifier);
                  final recentCtrl =
                      ref.read(recentFilesRegistryProvider.notifier);
                  for (final path in droppedPaths) {
                    await pdfCtrl.openFileInViewerTab(path);
                    recentCtrl.recordFileTouch(
                      filePath: path,
                      toolLabelEn: 'Dropped in Workspace',
                      toolLabelSi: 'වැඩබිමට එක් කරන ලදී',
                    );
                  }
                  pdfCtrl.loadFilesIntoPageOrganizer(
                    droppedPaths,
                    appendToExisting: true,
                  );
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive window structure:
                    // Compact icon + label >= 1000px, collapses to icons only < 1000px
                    final isCollapsed = constraints.maxWidth < 1000;

                    return Stack(
                      children: [
                        Row(
                          children: [
                            // Left Navigation Rail: 6 exact items in order
                            NavigationRail(
                              backgroundColor: palette.surfacePrimary,
                              selectedIndex: navigationShell.currentIndex,
                              onDestinationSelected: (idx) =>
                                  navigationShell.goBranch(idx),
                              labelType: isCollapsed
                                  ? NavigationRailLabelType.none
                                  : NavigationRailLabelType.all,
                              minWidth: isCollapsed ? 56 : 76,
                              selectedIconTheme: IconThemeData(
                                color: palette.accent,
                                size: 22,
                              ),
                              unselectedIconTheme: IconThemeData(
                                color: palette.textSecondary,
                                size: 22,
                              ),
                              selectedLabelTextStyle:
                                  DesktopTypography.caption12(
                                palette,
                                isSinhala: strings.isSi,
                                color: palette.accent,
                                weight: FontWeight.w600,
                              ),
                              unselectedLabelTextStyle:
                                  DesktopTypography.caption12(
                                palette,
                                isSinhala: strings.isSi,
                                color: palette.textSecondary,
                              ),
                              destinations: [
                                // 0. Print
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: strings.navPrint,
                                    child: Badge(
                                      isLabelVisible: queueState.totalFiles > 0,
                                      label: Text('${queueState.totalFiles}'),
                                      child: const Icon(Icons.print_outlined),
                                    ),
                                  ),
                                  selectedIcon: Badge(
                                    isLabelVisible: queueState.totalFiles > 0,
                                    label: Text('${queueState.totalFiles}'),
                                    child: const Icon(Icons.print_rounded),
                                  ),
                                  label: Text(strings.navPrint),
                                ),
                                // 1. Printers
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: strings.navPrinters,
                                    child: const Icon(Icons.router_outlined),
                                  ),
                                  selectedIcon: const Icon(Icons.router_rounded),
                                  label: Text(strings.navPrinters),
                                ),
                                // 2. Jobs
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: strings.navJobs,
                                    child: Badge(
                                      isLabelVisible: jobQueueState
                                              .runningOrQueuedCount >
                                          0,
                                      label: Text(
                                        '${jobQueueState.runningOrQueuedCount}',
                                      ),
                                      child: const Icon(Icons.layers_outlined),
                                    ),
                                  ),
                                  selectedIcon: Badge(
                                    isLabelVisible: jobQueueState
                                            .runningOrQueuedCount >
                                        0,
                                    label: Text(
                                      '${jobQueueState.runningOrQueuedCount}',
                                    ),
                                    child: const Icon(Icons.layers_rounded),
                                  ),
                                  label: Text(strings.navJobs),
                                ),
                                // 3. Tools
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: strings.navTools,
                                    child: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                    ),
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                  ),
                                  label: Text(strings.navTools),
                                ),
                                // 4. Shop
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: strings.navShop,
                                    child:
                                        const Icon(Icons.storefront_outlined),
                                  ),
                                  selectedIcon:
                                      const Icon(Icons.storefront_rounded),
                                  label: Text(strings.navShop),
                                ),
                                // 5. Settings
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: strings.navSettings,
                                    child: const Icon(Icons.settings_outlined),
                                  ),
                                  selectedIcon:
                                      const Icon(Icons.settings_rounded),
                                  label: Text(strings.navSettings),
                                ),
                              ],
                            ),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: palette.borderSubtle,
                            ),

                            // Active Branch Content with Motion-aware transition
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: AppMotion.duration(
                                  AppMotion.fast,
                                  reduceMotion: reduceMotion,
                                ),
                                switchInCurve: AppMotion.enterCurve,
                                switchOutCurve: AppMotion.exitCurve,
                                child: KeyedSubtree(
                                  key: ValueKey<int>(
                                    navigationShell.currentIndex,
                                  ),
                                  child: navigationShell,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Fixed Print Button pinned at bottom-right on all other screens
                        // (On /print, it is pinned inside the right panel in the exact same position)
                        if (navigationShell.currentIndex != 0)
                          Positioned(
                            right: DesktopSpacing.s16,
                            bottom: DesktopSpacing.s16,
                            child: PrimaryButton(
                              icon: Icons.print_rounded,
                              label: queueState.totalPages > 0
                                  ? strings.actionPrintWithPages(
                                      queueState.totalPages,
                                    )
                                  : strings.actionPrint,
                              isSinhala: strings.isSi,
                              onPressed: () => navigationShell.goBranch(0),
                            ),
                          ),

                        // Animated Full-Window Drag Overlay ("Drop files to print")
                        Positioned.fill(
                          child: GlobalDropOverlay(
                            isVisible: queueState.isDraggingOverWindow,
                            strings: strings,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
