import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/status.dart';
import '../data/foods.dart';
import '../models.dart';

/// Kegagalan AI dengan pesan yang bisa ditampilkan ke pengguna.
class AiUnavailable implements Exception {
  AiUnavailable(this.message, {this.code = 'error'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

class AiFoodItem {
  const AiFoodItem(this.foodId, this.grams, this.confidence);
  final String foodId;
  final double grams;
  final double confidence;
}

/// Klien Edge Function `ai` (PRD F6 & F7). Kunci NanoGPT hanya ada di server.
class AiClient {
  AiClient(this.client);
  final SupabaseClient client;

  static Map<String, dynamic> childJson(Child? c, GrowthStatus? status) => {
        if (c != null) ...{
          'name': c.name,
          'age_months': double.parse(c.ageMonths.toStringAsFixed(1)),
          'sex': c.sex.name,
        },
        'status': status?.label ?? 'belum diukur',
      };

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final r = await client.functions.invoke('ai', body: body);
      return (r.data as Map).cast<String, dynamic>();
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map ? d['error'] as String? : null;
      final code = d is Map ? (d['code'] as String? ?? 'error') : 'error';
      throw AiUnavailable(msg ?? 'Layanan AI tidak tersedia (${e.status}).', code: code);
    } catch (e) {
      if (e is AiUnavailable) rethrow;
      throw AiUnavailable('Tidak dapat menghubungi layanan AI. Periksa koneksi internet.', code: 'network');
    }
  }

  /// [history]: (dari pengguna?, teks), urut lama → baru; pesan terakhir = pertanyaan.
  Future<String> chat(List<(bool, String)> history, {Child? child, GrowthStatus? status}) async {
    final r = await _call({
      'action': 'chat',
      'messages': [
        for (final (mine, text) in history) {'role': mine ? 'user' : 'assistant', 'content': text},
      ],
      'child': childJson(child, status),
    });
    final reply = (r['reply'] as String?)?.trim() ?? '';
    if (reply.isEmpty) throw AiUnavailable('AI tidak memberi jawaban.');
    return reply;
  }

  Future<({List<AiFoodItem> items, String note})> detectFood(Uint8List bytes, String mime, {Child? child}) async {
    final r = await _call({
      'action': 'food_photo',
      'image': 'data:$mime;base64,${base64Encode(bytes)}',
      'foods': [for (final f in foods) {'id': f.id, 'name': f.name}],
      'child': childJson(child, null),
    });
    final items = [
      for (final i in (r['items'] as List? ?? const []).cast<Map>())
        if (foods.any((f) => f.id == i['food_id']))
          AiFoodItem(i['food_id'] as String, (i['grams'] as num).toDouble(), ((i['confidence'] as num?) ?? 0.5).toDouble()),
    ];
    return (items: items, note: (r['note'] as String?) ?? '');
  }
}
