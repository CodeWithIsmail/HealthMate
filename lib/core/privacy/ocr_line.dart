import 'dart:ui';

/// One recognised line of text and where it sits on the image, in **image
/// pixel coordinates** (not widget coordinates).
///
/// Deliberately our own type rather than ML Kit's `TextLine`: the detector in
/// `pii_detector.dart` is then pure Dart and can be unit-tested with synthetic
/// pages, with no device, no plugin and no real photo. `text_scanner.dart` is
/// the only place that converts ML Kit's types into these.
class OcrLine {
  const OcrLine({required this.text, required this.box});

  final String text;
  final Rect box;

  @override
  String toString() => 'OcrLine("$text", $box)';
}

/// Everything recognised on one image, plus the size of the image those boxes
/// are measured against. [imageSize] matters: the redactor decodes the file
/// independently and must confirm it is working in the same coordinate space
/// (see `image_redactor.dart` on EXIF orientation).
class OcrPage {
  const OcrPage({required this.lines, required this.imageSize});

  const OcrPage.empty() : lines = const [], imageSize = Size.zero;

  final List<OcrLine> lines;
  final Size imageSize;

  bool get isEmpty => lines.isEmpty;
}
