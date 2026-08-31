import 'dart:typed_data';

Future<void> downloadReportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) {
  throw UnsupportedError(
    'Direct report downloads are currently available in Flutter Web.',
  );
}
