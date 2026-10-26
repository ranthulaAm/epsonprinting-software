import 'package:flutter/material.dart';
import '../theme/desktop_design_system.dart';

// ============================================================================
// PRINT HELPER — REUSABLE DESKTOP WIDGET KIT
// ============================================================================
// Contains the 8 canonical building blocks for all screens:
// 1. PrimaryButton
// 2. SecondaryButton
// 3. StatusBadge
// 4. SupplyBar
// 5. Panel
// 6. EmptyState
// 7. InlineMessage
// 8. FormRow
//
// All widgets strictly consume tokens from `desktop_design_system.dart` with
// flat surfaces, 1px borders, 4–8px corner radius, 8px grid spacing, and
// outlined icons of uniform weight.
// ============================================================================

/// Semantic meaning for `StatusBadge` and `InlineMessage`.
enum DesktopStatusKind {
  ready, // Green: Ready, loaded, verified
  warning, // Amber: Low supply, manual action needed, non-blocking notice
  error, // Red: Paper jam, cover open, offline, blocking failure
  neutral, // Neutral gray: Informational or unreported state
}

// ============================================================================
// 1. PrimaryButton
// ============================================================================

/// Flat, high-contrast primary action button using the single calm accent token.
/// Uses verb-first labels (e.g. "Print", "Add files", "Save preset").
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isSinhala;
  final bool expandWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isSinhala = false,
    this.expandWidth = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final enabled = widget.onPressed != null;

    final bgColor = !enabled
        ? palette.surfaceSecondary
        : (_hovered ? palette.accentHover : palette.accent);
    final fgColor = !enabled ? palette.textMuted : palette.onAccent;
    final borderColor = !enabled ? palette.borderSubtle : bgColor;

    final content = Row(
      mainAxisSize: widget.expandWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: DesktopTypography.scale16,
            color: fgColor,
          ),
          const SizedBox(width: DesktopSpacing.s8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: DesktopTypography.body14(
              palette,
              isSinhala: widget.isSinhala,
              color: fgColor,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: DesktopSpacing.buttonPadding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: DesktopRadius.border4,
            border: Border.all(
              color: borderColor,
              width: DesktopRadius.borderWidth1px,
            ),
            boxShadow: DesktopElevation.flat,
          ),
          child: content,
        ),
      ),
    );
  }
}

// ============================================================================
// 2. SecondaryButton
// ============================================================================

/// Flat neutral button with a 1px border and 4px corner radius.
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isSinhala;
  final bool isSelected;
  final bool expandWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isSinhala = false,
    this.isSelected = false,
    this.expandWidth = false,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final enabled = widget.onPressed != null;

    final bgColor = !enabled
        ? palette.surfaceSecondary
        : widget.isSelected
            ? palette.accentSubtleBg
            : (_hovered ? palette.surfaceHover : palette.surfacePrimary);
    final borderColor = !enabled
        ? palette.borderSubtle
        : widget.isSelected
            ? palette.accent
            : palette.borderStrong;
    final fgColor = !enabled
        ? palette.textMuted
        : widget.isSelected
            ? palette.accent
            : palette.textPrimary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          padding: DesktopSpacing.buttonPadding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: DesktopRadius.border4,
            border: Border.all(
              color: borderColor,
              width: DesktopRadius.borderWidth1px,
            ),
            boxShadow: DesktopElevation.flat,
          ),
          child: Row(
            mainAxisSize:
                widget.expandWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: DesktopTypography.scale16,
                  color: fgColor,
                ),
                const SizedBox(width: DesktopSpacing.s8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: DesktopTypography.body14(
                    palette,
                    isSinhala: widget.isSinhala,
                    color: fgColor,
                    weight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. StatusBadge
// ============================================================================

/// Compact 4px-radius status pill using semantic status colors strictly for
/// meaning (`Ready` = green, `Warning` = amber, `Error` = red, `Neutral` = gray).
class StatusBadge extends StatelessWidget {
  final String label;
  final DesktopStatusKind kind;
  final IconData? icon;
  final bool isSinhala;

  const StatusBadge({
    super.key,
    required this.label,
    required this.kind,
    this.icon,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final (Color bg, Color border, Color fg) = switch (kind) {
      DesktopStatusKind.ready => (
          palette.statusReadyBg,
          palette.statusReadyBorder,
          palette.statusReadyText,
        ),
      DesktopStatusKind.warning => (
          palette.statusWarningBg,
          palette.statusWarningBorder,
          palette.statusWarningText,
        ),
      DesktopStatusKind.error => (
          palette.statusErrorBg,
          palette.statusErrorBorder,
          palette.statusErrorText,
        ),
      DesktopStatusKind.neutral => (
          palette.surfaceSecondary,
          palette.borderSubtle,
          palette.textSecondary,
        ),
    };

    return Container(
      padding: DesktopSpacing.badgePadding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DesktopRadius.border4,
        border: Border.all(
          color: border,
          width: DesktopRadius.borderWidth1px,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: DesktopTypography.scale12,
              color: fg,
            ),
            const SizedBox(width: DesktopSpacing.s4),
          ],
          Text(
            label,
            style: DesktopTypography.caption12(
              palette,
              isSinhala: isSinhala,
              color: fg,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. SupplyBar
// ============================================================================

/// Flat horizontal supply meter for ink, toner, or maintenance box levels.
/// Shows exact percentage when reported, or qualitative status ("OK", "Low",
/// "Empty", "Not reported by this printer") without guessing.
class SupplyBar extends StatelessWidget {
  final String label;
  final int? percentage; // 0..100 when reported; null when not reported
  final String statusText; // e.g. '78%', 'OK', 'Low (12%)', 'Not reported by this printer'
  final Color barColor;
  final DesktopStatusKind statusKind;
  final String? estimateNote; // e.g. '~1,200 pages (estimate)'
  final bool isSinhala;

  const SupplyBar({
    super.key,
    required this.label,
    required this.percentage,
    required this.statusText,
    required this.barColor,
    this.statusKind = DesktopStatusKind.ready,
    this.estimateNote,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);
    final double fillFraction = percentage != null
        ? (percentage!.clamp(0, 100) / 100.0)
        : (statusKind == DesktopStatusKind.ready ? 1.0 : 0.0);

    final Color statusColor = switch (statusKind) {
      DesktopStatusKind.ready => palette.textSecondary,
      DesktopStatusKind.warning => palette.statusWarningText,
      DesktopStatusKind.error => palette.statusErrorText,
      DesktopStatusKind.neutral => palette.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: DesktopSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: DesktopTypography.caption12(
                  palette,
                  isSinhala: isSinhala,
                  color: palette.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                statusText,
                style: DesktopTypography.caption12(
                  palette,
                  isSinhala: isSinhala,
                  color: statusColor,
                  weight: statusKind == DesktopStatusKind.warning ||
                          statusKind == DesktopStatusKind.error
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesktopSpacing.s4),
          Container(
            height: DesktopSpacing.s8,
            decoration: BoxDecoration(
              color: palette.surfaceSecondary,
              borderRadius: DesktopRadius.border4,
              border: Border.all(
                color: palette.borderSubtle,
                width: DesktopRadius.borderWidth1px,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (percentage == null &&
                    statusKind == DesktopStatusKind.neutral) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * fillFraction,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: DesktopRadius.border4,
                    ),
                  ),
                );
              },
            ),
          ),
          if (estimateNote != null && estimateNote!.isNotEmpty) ...[
            const SizedBox(height: DesktopSpacing.s4),
            Text(
              estimateNote!,
              style: DesktopTypography.caption12(
                palette,
                isSinhala: isSinhala,
                color: palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 5. Panel
// ============================================================================

/// Flat desktop container with a thin 1px border, 8px corner radius, zero
/// drop shadow, and an optional structured header row.
class Panel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget child;
  final EdgeInsets padding;
  final bool isSinhala;

  const Panel({
    super.key,
    this.title,
    this.subtitle,
    this.headerTrailing,
    required this.child,
    this.padding = DesktopSpacing.panelPadding,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: DesktopRadius.border8,
        border: Border.all(
          color: palette.borderSubtle,
          width: DesktopRadius.borderWidth1px,
        ),
        boxShadow: DesktopElevation.flat,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesktopSpacing.s16,
                vertical: DesktopSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DesktopRadius.r8 - 1),
                  topRight: Radius.circular(DesktopRadius.r8 - 1),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: palette.borderSubtle,
                    width: DesktopRadius.borderWidth1px,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: DesktopTypography.section16(
                            palette,
                            isSinhala: isSinhala,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: DesktopSpacing.s4),
                          Text(
                            subtitle!,
                            style: DesktopTypography.caption12(
                              palette,
                              isSinhala: isSinhala,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
          ],
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. EmptyState
// ============================================================================

/// Clean, understated empty state with a single outlined icon, plain title,
/// direct instruction, and optional primary action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isSinhala;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(DesktopSpacing.s24),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: DesktopRadius.border6,
        border: Border.all(
          color: palette.borderSubtle,
          width: DesktopRadius.borderWidth1px,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: DesktopTypography.scale24,
            color: palette.textMuted,
          ),
          const SizedBox(height: DesktopSpacing.s8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: DesktopTypography.body14(
              palette,
              isSinhala: isSinhala,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesktopSpacing.s4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DesktopTypography.caption12(
              palette,
              isSinhala: isSinhala,
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: DesktopSpacing.s16),
            SecondaryButton(
              label: actionLabel!,
              icon: Icons.add_outlined,
              isSinhala: isSinhala,
              onPressed: onActionPressed,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 7. InlineMessage
// ============================================================================

/// Plain-language status or validation message box that explains what happened
/// and what to do, with an optional action button (e.g. "Switch to A4").
class InlineMessage extends StatelessWidget {
  final DesktopStatusKind kind;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isSinhala;

  const InlineMessage({
    super.key,
    required this.kind,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onActionPressed,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);

    final (Color bg, Color border, Color fg, IconData icon) = switch (kind) {
      DesktopStatusKind.ready => (
          palette.statusReadyBg,
          palette.statusReadyBorder,
          palette.statusReadyText,
          Icons.check_circle_outline,
        ),
      DesktopStatusKind.warning => (
          palette.statusWarningBg,
          palette.statusWarningBorder,
          palette.statusWarningText,
          Icons.warning_amber_outlined,
        ),
      DesktopStatusKind.error => (
          palette.statusErrorBg,
          palette.statusErrorBorder,
          palette.statusErrorText,
          Icons.error_outline,
        ),
      DesktopStatusKind.neutral => (
          palette.surfaceSecondary,
          palette.borderSubtle,
          palette.textSecondary,
          Icons.info_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(DesktopSpacing.s8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DesktopRadius.border6,
        border: Border.all(
          color: border,
          width: DesktopRadius.borderWidth1px,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: DesktopSpacing.s4 / 2),
            child: Icon(
              icon,
              size: DesktopTypography.scale16,
              color: fg,
            ),
          ),
          const SizedBox(width: DesktopSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesktopTypography.body14(
                    palette,
                    isSinhala: isSinhala,
                    color: fg,
                    weight: FontWeight.w600,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: DesktopSpacing.s4),
                  Text(
                    detail!,
                    style: DesktopTypography.caption12(
                      palette,
                      isSinhala: isSinhala,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(width: DesktopSpacing.s8),
            SecondaryButton(
              label: actionLabel!,
              isSinhala: isSinhala,
              onPressed: onActionPressed,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 8. FormRow
// ============================================================================

/// Aligned horizontal desktop property row (`Label` on the left, `Control` on
/// the right, optional helper/disabled reason underneath) on the 8px grid.
class FormRow extends StatelessWidget {
  final String label;
  final String? helperOrReasonText;
  final Widget control;
  final bool isSinhala;

  const FormRow({
    super.key,
    required this.label,
    required this.control,
    this.helperOrReasonText,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DesktopPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: DesktopSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: DesktopTypography.body14(
                    palette,
                    isSinhala: isSinhala,
                    color: palette.textPrimary,
                    weight: FontWeight.w500,
                  ),
                ),
                if (helperOrReasonText != null &&
                    helperOrReasonText!.isNotEmpty) ...[
                  const SizedBox(height: DesktopSpacing.s4),
                  Text(
                    helperOrReasonText!,
                    style: DesktopTypography.caption12(
                      palette,
                      isSinhala: isSinhala,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DesktopSpacing.s16),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: control,
            ),
          ),
        ],
      ),
    );
  }
}
