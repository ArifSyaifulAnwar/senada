// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

String _getMimeType(String fileName) {
  final ext = fileName.toLowerCase().split('.').last;

  switch (ext) {
    case 'pdf':
      return 'application/pdf';

    case 'png':
      return 'image/png';

    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';

    case 'gif':
      return 'image/gif';

    case 'webp':
      return 'image/webp';

    case 'bmp':
      return 'image/bmp';

    case 'txt':
      return 'text/plain';

    case 'csv':
      return 'text/csv';

    case 'doc':
      return 'application/msword';

    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    case 'xls':
      return 'application/vnd.ms-excel';

    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    default:
      return 'application/octet-stream';
  }
}

web.Blob _createBlob(List<int> bytes, String fileName) {
  final uint8list = Uint8List.fromList(bytes);
  final jsArray = uint8list.toJS;

  return web.Blob(
    [jsArray].toJS,
    web.BlobPropertyBag(type: _getMimeType(fileName)),
  );
}

void downloadFileWeb(List<int> bytes, String fileName) {
  final blob = _createBlob(bytes, fileName);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
}

void previewFileWeb(List<int> bytes, String fileName) {
  final blob = _createBlob(bytes, fileName);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener'
    ..style.display = 'none';

  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Jangan langsung revoke.
  // Kalau langsung revoke, tab preview kadang gagal baca object URL.
  Timer(const Duration(minutes: 1), () {
    web.URL.revokeObjectURL(url);
  });
}
