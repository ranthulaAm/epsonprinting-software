import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'desktop_design_system.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

abstract final class AppTheme {
  static ThemeData light({
    bool highContrast = false,
    bool isSinhala = false,
  }) {
    return DesktopTheme.light(isSinhala: isSinhala);
  }

  static ThemeData dark({
    bool highContrast = false,
    bool isSinhala = false,
  }) {
    return DesktopTheme.dark(isSinhala: isSinhala);
  }
}
