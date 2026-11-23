import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Berkas yang dipilih pengguna (dokumen STR, foto) beserta jenisnya.
class PickedBytes {
  const PickedBytes({required this.bytes, required this.name, required this.mime});
  final Uint8List bytes;
  final String name;
  final String mime;

  String get extension {
    final i = name.lastIndexOf('.');
    return i < 0 ? 'bin' : name.substring(i + 1).toLowerCase();
  }
}

const strMaxBytes = 5 * 1024 * 1024;
const _strMimes = {'pdf': 'application/pdf', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png'};

String? mimeOfImage(String name) => switch (name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };

/// Validasi dokumen STR (PRD F2): PDF/JPG/PNG maks. 5 MB.
String? validateStrFile(String name, int size) {
  final ext = name.split('.').last.toLowerCase();
  if (!_strMimes.containsKey(ext)) return 'Dokumen STR harus berformat PDF, JPG, atau PNG.';
  if (size > strMaxBytes) return 'Ukuran dokumen STR maksimal 5 MB.';
  if (size == 0) return 'Berkas kosong. Pilih ulang dokumen STR.';
  return null;
}

/// Memilih dokumen STR. Null bila dibatalkan; melempar [ArgumentError] bila tidak valid.
Future<PickedBytes?> pickStrDocument() async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
  if (files.isEmpty) return null;
  final f = files.first;
  final bytes = await f.readAsBytes();
  final err = validateStrFile(f.name, bytes.length);
  if (err != null) throw ArgumentError(err);
  return PickedBytes(bytes: bytes, name: f.name, mime: _strMimes[f.name.split('.').last.toLowerCase()]!);
}
