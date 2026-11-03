import 'dart:typed_data';

/// Mengembalikan false bila platform belum mendukung unduhan (mis. Android pada prototype).
bool downloadTextFile(String filename, String content, {String mime = 'text/csv'}) => false;

bool downloadBytes(String filename, Uint8List bytes, {required String mime}) => false;

/// Bagikan teks lewat menu berbagi perangkat. False bila tidak didukung.
Future<bool> shareText(String title, String text) async => false;
