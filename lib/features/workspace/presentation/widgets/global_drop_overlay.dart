import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_strings.dart';

class GlobalDropOverlay extends StatelessWidget {
  const GlobalDropOverlay({
    super.key,
    required this.isVisible,
    required this.strings,
  });

  final bool isVisible;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: AppConstants.animMedium,
        curve: AppConstants.animCurve,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: colorScheme.surface.withOpacity(0.84),
            padding: const EdgeInsets.all(32),
            child: Center(
              child: AnimatedScale(
                scale: isVisible ? 1.0 : 0.94,
                duration: AppConstants.animMedium,
                curve: AppConstants.animCurve,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560, maxHeight: 340),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colorScheme.primary,
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.file_download_rounded,
                          size: 56,
                          color: colorScheme.primary,
                        ),
                      )
                          .animate(
                            target: isVisible ? 1 : 0,
                          )
                          .scaleXY(
                            begin: 0.9,
                            end: 1.05,
                            duration: AppConstants.animSlow,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: 20),
                      Text(
                        strings.dropOverlayHeadline,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          strings.dropOverlaySub,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
