import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const String appName = 'Print Helper';
  static const String appVersion = '1.0.0';

  // Smooth, subtle animation durations (150-250 ms, 60 fps)
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMedium = Duration(milliseconds: 200);
  static const Duration animSlow = Duration(milliseconds: 250);

  static const Curve animCurve = Curves.easeOutCubic;

  // Window constraints (Minimum 900x600)
  static const Size minWindowSize = Size(900, 600);
  static const Size defaultWindowSize = Size(1280, 720);

  // Supported file extensions (PDF, Images, Plain Text, Markdown)
  static const Set<String> supportedExtensions = {
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'bmp',
    'tif',
    'tiff',
    'webp',
    'txt',
    'md',
    'markdown',
  };

  static const Set<String> imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'bmp',
    'tif',
    'tiff',
    'webp',
  };

  static const Set<String> textAndMarkdownExtensions = {
    'txt',
    'md',
    'markdown',
  };
}
