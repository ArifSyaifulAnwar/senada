// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadFileWeb(List<int> bytes, String fileName) {
  // 1. Konversi List<int> → Uint8List → JSUint8Array
  final uint8list = Uint8List.fromList(bytes);
  final jsArray = uint8list.toJS;

  // 2. Buat Blob dari JSArray
  final blob = web.Blob(
    [jsArray].toJS,
    web.BlobPropertyBag(
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );

  // 3. Buat object URL
  final url = web.URL.createObjectURL(blob);

  // 4. Buat anchor, trigger click, cleanup
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
}
