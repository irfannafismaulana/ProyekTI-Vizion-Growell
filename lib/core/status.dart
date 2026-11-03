import 'zscore.dart';

/// Status warna di Beranda (desain Figma: Normal / Waspada / Kurang).
///
/// Aturan tampilan prototype — perlu ditinjau tenaga kesehatan:
/// - Kurang (merah): salah satu indikator TB/U, BB/U, BB/TB < -2 SD
///   (pendek/stunting, berat badan kurang, atau gizi kurang menurut Permenkes 2/2020).
/// - Gizi lebih (merah): BB/TB > +2 SD.
/// - Waspada (kuning): salah satu indikator di antara -2 dan -1 SD, atau
///   BB/TB > +1 SD (berisiko gizi lebih, Permenkes 2/2020).
/// - Normal (hijau): selain itu.
/// Batas memakai z yang dibulatkan 2 desimal, sama dengan peringatan stunting (TC-02).
enum GrowthStatus { normal, waspada, kurang, lebih }

extension GrowthStatusLabel on GrowthStatus {
  String get label => switch (this) {
        GrowthStatus.normal => 'Normal',
        GrowthStatus.waspada => 'Waspada',
        GrowthStatus.kurang => 'Kurang',
        GrowthStatus.lebih => 'Gizi lebih',
      };

  String get colorName => switch (this) {
        GrowthStatus.normal => 'HIJAU',
        GrowthStatus.waspada => 'KUNING',
        GrowthStatus.kurang || GrowthStatus.lebih => 'MERAH',
      };
}

class StatusInfo {
  const StatusInfo(this.status, this.reasons);
  final GrowthStatus status;

  /// Penyebab status, mis. "panjang badan di bawah standar (TB/U -2,30 SD)".
  final List<String> reasons;
}

StatusInfo statusOf(GrowthResult r) {
  final h = roundZ(r.zHeightForAge);
  final w = roundZ(r.zWeightForAge);
  final wh = r.zWeightForHeight == null ? null : roundZ(r.zWeightForHeight!);

  final kurang = <String>[
    if (h < -2) 'panjang/tinggi badan di bawah standar usia (risiko stunting)',
    if (w < -2) 'berat badan di bawah standar usia',
    if (wh != null && wh < -2) 'berat badan kurang untuk panjang badannya',
  ];
  if (kurang.isNotEmpty) return StatusInfo(GrowthStatus.kurang, kurang);

  if (wh != null && wh > 2) return const StatusInfo(GrowthStatus.lebih, ['berat badan berlebih untuk panjang badannya']);

  final waspada = <String>[
    if (h < -1) 'panjang/tinggi badan mendekati batas bawah',
    if (w < -1) 'berat badan mendekati batas bawah',
    if (wh != null && wh < -1) 'berat badan mendekati batas bawah untuk panjang badannya',
    if (wh != null && wh > 1) 'berisiko gizi lebih',
  ];
  if (waspada.isNotEmpty) return StatusInfo(GrowthStatus.waspada, waspada);
  return const StatusInfo(GrowthStatus.normal, []);
}

/// SIMULASI pengukuran dari foto. Prototype belum memiliki model AI, jadi angka
/// diproyeksikan dari pengukuran terakhir: z-score TB/U dan BB/U dipertahankan
/// lalu dikonversi ke umur sekarang memakai tabel WHO. Tanpa riwayat → median WHO.
/// Hasil wajib diperiksa orang tua dan dapat dikoreksi sebelum disimpan.
(double heightCm, double weightKg) simulatePhotoEstimate({
  required Sex sex,
  required int ageDaysNow,
  GrowthResult? last,
}) {
  final days = ageDaysNow.clamp(0, maxAgeDays).toDouble();
  final zh = last?.zHeightForAge ?? 0;
  final zw = last?.zWeightForAge ?? 0;
  final h = lmsFor(Indicator.heightForAge, sex, days).valueAt(zh);
  final w = lmsFor(Indicator.weightForAge, sex, days).valueAt(zw);
  return ((h * 10).round() / 10, (w * 10).round() / 10);
}
