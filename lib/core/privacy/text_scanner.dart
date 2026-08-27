import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_line.dart';

/// Reads the text off a report image **on the device**. ML Kit's bundled model
/// runs locally — nothing is uploaded to perform this scan, which is the whole
/// point: the image has to be inspected before it is allowed onto the network.
///
/// The only file in the app that knows ML Kit exists. Everything downstream
/// works on [OcrPage].
///
/// Limitation worth knowing: the Latin recogniser reads Latin script only, so
/// Bangla-script text (`রোগীর নাম`) is not detected. The letterhead rule and
/// the user's own boxes on the review screen are the backstop for that.
class TextScanner {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// [imageSize] comes from `prepareReportImage`, so the boxes ML Kit returns
  /// and the pixels the redactor writes share one coordinate space.
  Future<OcrPage> scan({required String imagePath, required Size imageSize}) async {
    final recognised = await _recognizer.processImage(InputImage.fromFilePath(imagePath));

    final lines = <OcrLine>[];
    for (final block in recognised.blocks) {
      for (final line in block.lines) {
        if (line.text.trim().isEmpty) continue;
        lines.add(OcrLine(text: line.text, box: _clamp(line.boundingBox, imageSize)));
      }
    }

    return OcrPage(lines: lines, imageSize: imageSize);
  }

  Future<void> dispose() => _recognizer.close();

  static Rect _clamp(Rect box, Size size) {
    if (size.isEmpty) return box;
    return Rect.fromLTRB(
      box.left.clamp(0.0, size.width),
      box.top.clamp(0.0, size.height),
      box.right.clamp(0.0, size.width),
      box.bottom.clamp(0.0, size.height),
    );
  }
}
