import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// A report image that has been normalised for redaction: EXIF baked in and
/// stripped, downscaled, re-encoded. Its [size] is the coordinate space every
/// [PiiFinding] rect is expressed in.
class PreparedImage {
  const PreparedImage({required this.path, required this.size});

  final String path;
  final Size size;
}

/// Longest edge of the image we work with. Keeps OCR and the redaction pass
/// fast, keeps the upload well under the API's 10 MB limit, and is still far
/// more resolution than Gemini needs to read a lab report.
const int _maxDimension = 2000;

const int _jpegQuality = 90;

/// Step 1 of the privacy pipeline: normalise the picked/cropped photo before
/// anything else touches it.
///
/// Doing this up front matters for three reasons:
///  * **EXIF is destroyed here** — GPS coordinates, device serial and capture
///    time are dropped because the pixels are re-encoded into a brand new JPEG.
///    That happens whether or not a single box is ever drawn.
///  * `bakeOrientation` applies the rotation flag to the pixels, so ML Kit and
///    the redaction pass agree on where a given rectangle is. The `image`
///    package does not honour EXIF orientation on decode, so without this the
///    boxes would land sideways on rotated camera photos.
///  * Everything downstream — OCR, the review screen, the final upload —
///    then works on one identical file.
Future<PreparedImage> prepareReportImage(String sourcePath) async {
  final bytes = await File(sourcePath).readAsBytes();
  final result = await compute(_prepare, bytes);
  final path = await _writeTemp(result.bytes, 'prepared');
  return PreparedImage(path: path, size: Size(result.width.toDouble(), result.height.toDouble()));
}

/// Step 2: paint [rects] out of the prepared image and write the result.
///
/// The rectangles are filled with opaque black **before** encoding, so the
/// covered pixels are gone from the file rather than hidden behind an overlay.
/// That is the difference between this and blurring or pixelating: there is
/// nothing left for a vision model — or anyone else — to recover.
Future<String> redactReportImage({required String preparedPath, required List<Rect> rects}) async {
  final bytes = await File(preparedPath).readAsBytes();
  final flat = <double>[
    for (final rect in rects) ...[rect.left, rect.top, rect.right, rect.bottom],
  ];
  final redacted = await compute(_redact, _RedactJob(bytes: bytes, flatRects: flat));
  return _writeTemp(redacted, 'redacted');
}

Future<String> _writeTemp(Uint8List bytes, String prefix) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/healthmate_${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

class _PreparedBytes {
  const _PreparedBytes({required this.bytes, required this.width, required this.height});

  final Uint8List bytes;
  final int width;
  final int height;
}

class _RedactJob {
  const _RedactJob({required this.bytes, required this.flatRects});

  final Uint8List bytes;

  /// Rects flattened to `[l, t, r, b, l, t, r, b, …]` — plain doubles travel
  /// between isolates without any assumptions about `Rect`.
  final List<double> flatRects;
}

_PreparedBytes _prepare(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const ImagePreparationException();

  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > _maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: _maxDimension, maintainAspect: true)
        : img.copyResize(image, height: _maxDimension, maintainAspect: true);
  }

  return _PreparedBytes(
    bytes: img.encodeJpg(image, quality: _jpegQuality),
    width: image.width,
    height: image.height,
  );
}

Uint8List _redact(_RedactJob job) {
  final image = img.decodeImage(job.bytes);
  if (image == null) throw const ImagePreparationException();

  final black = img.ColorRgb8(0, 0, 0);
  for (var i = 0; i + 3 < job.flatRects.length; i += 4) {
    final left = job.flatRects[i].floor().clamp(0, image.width - 1);
    final top = job.flatRects[i + 1].floor().clamp(0, image.height - 1);
    final right = job.flatRects[i + 2].ceil().clamp(0, image.width - 1);
    final bottom = job.flatRects[i + 3].ceil().clamp(0, image.height - 1);
    if (right <= left || bottom <= top) continue;
    img.fillRect(image, x1: left, y1: top, x2: right, y2: bottom, color: black);
  }

  return img.encodeJpg(image, quality: _jpegQuality);
}

class ImagePreparationException implements Exception {
  const ImagePreparationException();

  @override
  String toString() => "That image couldn't be read.";
}
