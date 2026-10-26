import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:print_helper/core/l10n/app_strings.dart';
import 'package:print_helper/core/router/app_router.dart';
import 'package:print_helper/core/theme/desktop_design_system.dart';

void main() {
  group('Sinhala Localization & Spoken-Style Vocabulary Audit', () {
    late Map<String, dynamic> enJson;
    late Map<String, dynamic> siJson;

    setUpAll(() {
      final enFile = File('lib/core/l10n/app_en.arb');
      final siFile = File('lib/core/l10n/app_si.arb');

      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
      expect(siFile.existsSync(), isTrue, reason: 'app_si.arb must exist');

      enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      siJson = jsonDecode(siFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('exact 1:1 key parity between English and Sinhala ARB files', () {
      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
      final siKeys = siJson.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInSi = enKeys.difference(siKeys);
      final missingInEn = siKeys.difference(enKeys);

      expect(
        missingInSi,
        isEmpty,
        reason: 'Sinhala ARB missing keys: $missingInSi',
      );
      expect(
        missingInEn,
        isEmpty,
        reason: 'English ARB missing keys: $missingInEn',
      );
      expect(enKeys.length, equals(siKeys.length));
      expect(enKeys.length, greaterThanOrEqualTo(140));
    });

    test('prohibited formal, literary and textbook Sinhala terms are completely absent', () {
      final prohibitedTerms = [
        'මුද්‍රණ යන්ත්‍රය', // Textbook for printer -> must use ප්‍රින්ටර්
        'ලේඛන', // Formal literary for documents -> must use ෆයිල් / PDF
        'පත්ති', // Obsolete formal for paper -> must use කඩදාසි
        'පසුරු පුවරුවෙන්', // Textbook for clipboard -> spoken loanwords
        'ආදාන තැටිය', // Formal for paper tray -> must use කඩදාසි තැටිය
        'ද්විත්ව මුද්‍රණය', // Formal for two-sided -> must use දෙපැත්තෙන්ම
      ];

      final violations = <String, List<String>>{};

      for (final entry in siJson.entries) {
        if (entry.key.startsWith('@')) continue;
        final val = entry.value.toString();
        for (final prohibited in prohibitedTerms) {
          if (val.contains(prohibited)) {
            violations.putIfAbsent(prohibited, () => []).add('${entry.key}: "$val"');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Prohibited formal Sinhala terms detected: $violations',
      );
    });

    test('natural everyday loanwords in Sinhala script are consistently used', () {
      final requiredSpokenTerms = [
        'ප්‍රින්ටර්', // printer
        'ෆයිල්', // file
        'PDF', // pdf
        'කඩදාසි', // paper
        'කොපි', // copies
      ];

      final allSiText = siJson.values.map((v) => v.toString()).join(' ');

      for (final term in requiredSpokenTerms) {
        expect(
          allSiText.contains(term),
          isTrue,
          reason: 'Everyday spoken term "$term" must be present in Sinhala ARB',
        );
      }
    });

    test('numbers and page count interpolations use standard digits', () {
      // Numbers in ARB messages should use standard digits, not Sinhala archaic numerals
      final archaicNumerals = RegExp(r'[\u0DE6-\u0DEF]');
      for (final entry in siJson.entries) {
        if (entry.key.startsWith('@')) continue;
        final val = entry.value.toString();
        expect(
          archaicNumerals.hasMatch(val),
          isFalse,
          reason: 'Archaic numerals found in ${entry.key}: "$val"',
        );
      }
    });

    test('AppStrings resolves both English and Sinhala locales seamlessly', () {
      final enStrings = AppStrings.forTesting(const Locale('en'));
      final siStrings = AppStrings.forTesting(const Locale('si'));

      expect(enStrings.isSi, isFalse);
      expect(siStrings.isSi, isTrue);

      expect(enStrings.appTitle, equals('Print Helper'));
      expect(siStrings.appTitle, equals('Print Helper'));

      expect(enStrings.printAction, equals('Print'));
      expect(siStrings.printAction, equals('ප්‍රින්ට් කරන්න'));

      expect(enStrings.paperSize, equals('Paper Size'));
      expect(siStrings.paperSize, equals('කඩදාසි ප්‍රමාණය'));
    });
  });

  group('Responsive Navigation Rail & App Shell Layout', () {
    testWidgets('navigation rail has exactly 6 destinations in correct order', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      expect(router, isNotNull);

      // Verify shell route structure
      final shellRoute = router.configuration.routes.first as StatefulShellRoute;
      expect(shellRoute.branches.length, equals(6));

      // Branch 0: /print
      expect(shellRoute.branches[0].routes.first, isA<GoRoute>());
      expect((shellRoute.branches[0].routes.first as GoRoute).path, equals('/print'));

      // Branch 1: /printers
      expect((shellRoute.branches[1].routes.first as GoRoute).path, equals('/printers'));

      // Branch 2: /jobs
      expect((shellRoute.branches[2].routes.first as GoRoute).path, equals('/jobs'));

      // Branch 3: /tools
      expect((shellRoute.branches[3].routes.first as GoRoute).path, equals('/tools'));

      // Branch 4: /shop
      expect((shellRoute.branches[4].routes.first as GoRoute).path, equals('/shop'));

      // Branch 5: /settings
      expect((shellRoute.branches[5].routes.first as GoRoute).path, equals('/settings'));
    });

    test('desktop spacing and layout tokens meet responsive standards', () {
      expect(DesktopSpacing.s8, equals(8.0));
      expect(DesktopSpacing.s16, equals(16.0));
      expect(DesktopSpacing.s24, equals(24.0));
      expect(DesktopRadius.r6, equals(const Radius.circular(6.0)));
      expect(DesktopRadius.r8, equals(const Radius.circular(8.0)));
    });
  });
}
