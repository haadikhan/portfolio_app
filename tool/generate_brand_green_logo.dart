// One-off generator: dart run tool/generate_brand_green_logo.dart
// Uses transitive `image` from package_config (pdf / image_picker).
// ignore_for_file: depend_on_referenced_packages

import "dart:io";
import "dart:typed_data";

import "package:image/image.dart" as img;

const _brandGreenR = 15;
const _brandGreenG = 122;
const _brandGreenB = 44;

Uint8List tintToBrandGreen(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) {
    throw StateError("Failed to decode app_brand.png");
  }
  final tinted = img.Image.from(decoded);
  for (var y = 0; y < tinted.height; y++) {
    for (var x = 0; x < tinted.width; x++) {
      final p = tinted.getPixel(x, y);
      final a = p.a.toInt();
      if (a < 20) continue;
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
      if (luminance > 120 || (r > 200 && g > 200 && b > 200)) {
        tinted.setPixelRgba(x, y, _brandGreenR, _brandGreenG, _brandGreenB, a);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(tinted));
}

void main() {
  final src = File("assets/branding/app_brand.png");
  final out = File("assets/branding/app_brand_green.png");
  final green = tintToBrandGreen(src.readAsBytesSync());
  out.writeAsBytesSync(green);
  // ignore: avoid_print
  print("Wrote ${out.path} (${green.length} bytes)");
}
