import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-controlled "Reduce Motion" setting for low-end PCs and motion sensitivity.
class ReduceMotionNotifier extends StateNotifier<bool> {
  ReduceMotionNotifier() : super(false);

  void setReduceMotion(bool value) => state = value;
  void toggle() => state = !state;
}

final reduceMotionProvider =
    StateNotifierProvider<ReduceMotionNotifier, bool>((ref) {
  return ReduceMotionNotifier();
});

/// User-controlled "High Contrast" accessibility setting.
class HighContrastNotifier extends StateNotifier<bool> {
  HighContrastNotifier() : super(false);

  void setHighContrast(bool value) => state = value;
  void toggle() => state = !state;
}

final highContrastProvider =
    StateNotifierProvider<HighContrastNotifier, bool>((ref) {
  return HighContrastNotifier();
});

/// User-controlled UI Text Scale factor (0.85 to 1.45, default 1.0).
class TextScaleFactorNotifier extends StateNotifier<double> {
  TextScaleFactorNotifier() : super(1.0);

  void setScale(double value) => state = value.clamp(0.85, 1.45);
}

final textScaleFactorProvider =
    StateNotifierProvider<TextScaleFactorNotifier, double>((ref) {
  return TextScaleFactorNotifier();
});

/// First-run onboarding completion flag.
class OnboardingCompletedNotifier extends StateNotifier<bool> {
  OnboardingCompletedNotifier() : super(true);

  void markCompleted() => state = true;
  void resetForReplay() => state = false;
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingCompletedNotifier, bool>((ref) {
  return OnboardingCompletedNotifier();
});

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;

  static Duration duration(
    Duration base, {
    required bool reduceMotion,
  }) {
    if (reduceMotion) return Duration.zero;
    return base;
  }

  static Duration effectiveDuration(
    BuildContext context,
    Duration base, {
    required bool reduceMotionSetting,
  }) {
    final osDisableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotionSetting || osDisableAnimations) {
      return Duration.zero;
    }
    return base;
  }
}

/// Lightweight, 60fps-safe skeleton loader that respects Reduce Motion.
class SkeletonBox extends ConsumerWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.65),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
