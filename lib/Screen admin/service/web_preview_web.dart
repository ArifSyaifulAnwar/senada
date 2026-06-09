// ignore: deprecated_member_use
// ignore_for_file: duplicate_ignore, deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

void openBytesInBrowser(List<int> bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Pakai anchor + target _blank: ramah user-gesture dan tidak mudah
  // diblokir popup blocker dibanding window.open.
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Revoke setelah jeda agar tab sempat memuat.
  Future.delayed(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(url);
  });
}
