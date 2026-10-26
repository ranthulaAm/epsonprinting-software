sealed class AppException implements Exception {
  const AppException({
    required this.userMessageEn,
    required this.userMessageSi,
    this.technicalDetails,
  });

  final String userMessageEn;
  final String userMessageSi;
  final String? technicalDetails;

  String localizedMessage(String languageCode) =>
      languageCode == 'si' ? userMessageSi : userMessageEn;

  @override
  String toString() =>
      'AppException($userMessageEn${technicalDetails != null ? ' - $technicalDetails' : ''})';
}

final class UnsupportedFileException extends AppException {
  UnsupportedFileException(String fileName, String extension)
      : super(
          userMessageEn:
              '"$fileName" (.${extension.isEmpty ? 'unknown' : extension}) is not supported. Supported formats: PDF, PNG, JPG, BMP, TIFF, WebP, and TXT.',
          userMessageSi:
              '"$fileName" (.${extension.isEmpty ? 'නොදන්නා' : extension}) ගොනු වර්ගය සඳහා සහය නොදක්වයි. PDF, PNG, JPG, BMP, TIFF, WebP හෝ TXT ගොනු භාවිතා කරන්න.',
          technicalDetails: 'Unsupported extension: $extension',
        );
}

final class CorruptOrProtectedFileException extends AppException {
  CorruptOrProtectedFileException(String fileName, {String? reason})
      : super(
          userMessageEn:
              'Could not open "$fileName". The file may be corrupted, empty, or password-protected.',
          userMessageSi:
              '"$fileName" විවෘත කළ නොහැක. ගොනුවට හානි වී හෝ මුරපදයකින් ආරක්ෂා කර තිබිය හැක.',
          technicalDetails: reason,
        );
}

final class PrinterCommunicationException extends AppException {
  PrinterCommunicationException(String printerName, {String? reason})
      : super(
          userMessageEn:
              'Printer "$printerName" is unreachable or offline. Please check the cable or network connection.',
          userMessageSi:
              '"$printerName" මුද්‍රණ යන්ත්‍රය සම්බන්ධ වී නොමැත. කරුණාකර කේබලය හෝ ජාල සම්බන්ධතාවය පරීක්ෂා කරන්න.',
          technicalDetails: reason,
        );
}
