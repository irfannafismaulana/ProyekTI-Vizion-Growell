import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void _save(web.Blob blob, String filename) {
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

bool downloadTextFile(String filename, String content, {String mime = 'text/csv'}) {
  // BOM agar Excel membaca UTF-8 dengan benar.
  _save(web.Blob(['﻿$content'.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8')), filename);
  return true;
}

bool downloadBytes(String filename, Uint8List bytes, {required String mime}) {
  _save(web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime)), filename);
  return true;
}

/// Web Share API bila tersedia (HP), selain itu salin ke clipboard.
Future<bool> shareText(String title, String text) async {
  final nav = web.window.navigator;
  try {
    await nav.share(web.ShareData(title: title, text: text)).toDart;
    return true;
  } catch (_) {
    try {
      await nav.clipboard.writeText(text).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }
}
