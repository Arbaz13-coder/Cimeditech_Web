import 'dart:typed_data';

import 'report_file_downloader_stub.dart'
    if (dart.library.html) 'report_file_downloader_web.dart' as platform;

Future<void> downloadReportFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) {
  return platform.downloadReportFile(
    fileName: fileName,
    mimeType: mimeType,
    bytes: bytes,
  );
}
