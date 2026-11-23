// Membuat gambar sumber ikon aplikasi dari assets/logo_icon.png.
// Jalankan: dart run tool/make_icon.dart  lalu  dart run flutter_launcher_icons
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final logo = img.decodePng(File('assets/logo_icon.png').readAsBytesSync())!;
  Directory('assets/icon').createSync(recursive: true);

  img.Image compose({required int size, required double logoWidth, required bool background}) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: background ? img.ColorRgba8(255, 255, 255, 255) : img.ColorRgba8(0, 0, 0, 0));
    final w = (size * logoWidth).round();
    final h = (logo.height * w / logo.width).round();
    final scaled = img.copyResize(logo, width: w, height: h, interpolation: img.Interpolation.cubic);
    img.compositeImage(canvas, scaled, dstX: (size - w) ~/ 2, dstY: (size - h) ~/ 2);
    return canvas;
  }

  // Ikon biasa (Android lama, web, favicon): latar putih, logo 72% lebar.
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(compose(size: 1024, logoWidth: 0.72, background: true)));
  // Adaptive icon Android: latar diatur terpisah (putih); logo 56% agar aman dari potongan bentuk ikon.
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(compose(size: 1024, logoWidth: 0.56, background: false)));
  stdout.writeln('Ikon dibuat di assets/icon/');
}
