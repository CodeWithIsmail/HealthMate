import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/privacy/image_redactor.dart';
import '../../core/privacy/pii_detector.dart';
import '../../core/privacy/pii_patterns.dart';
import '../../core/privacy/redaction_outcome.dart';
import '../../core/privacy/text_scanner.dart';
import '../../widgets/error_view.dart';

/// The gate between picking a report photo and uploading it.
///
/// Everything here happens on the device: the image is normalised (EXIF
/// stripped), scanned with on-device OCR, and personal details are proposed
/// for masking. The user confirms — or corrects — before anything is sent, so
/// a detector miss is recoverable rather than a privacy leak.
///
/// Pops a [RedactionOutcome], or null if the user backs out.
class RedactionScreen extends StatefulWidget {
  const RedactionScreen({super.key, required this.sourceImagePath, this.catalogueNames = const []});

  /// The picked-and-cropped photo. Never uploaded.
  final String sourceImagePath;

  /// Canonical test names, used to stop the detector masking a result row.
  final List<String> catalogueNames;

  @override
  State<RedactionScreen> createState() => _RedactionScreenState();
}

class _RedactionScreenState extends State<RedactionScreen> {
  PreparedImage? _prepared;
  List<PiiFinding> _findings = [];

  bool _loading = true;
  bool _redacting = false;
  bool _scanFailed = false;
  bool _acknowledged = false;
  String? _loadError;

  Offset? _dragStart;
  Rect? _draftRect;

  @override
  void initState() {
    super.initState();
    _prepareAndScan();
  }

  Future<void> _prepareAndScan() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _scanFailed = false;
    });

    try {
      final prepared = await prepareReportImage(widget.sourceImagePath);
      var findings = <PiiFinding>[];
      var scanFailed = false;

      final scanner = TextScanner();
      try {
        final page = await scanner.scan(imagePath: prepared.path, imageSize: prepared.size);
        findings = PiiDetector(catalogueNames: widget.catalogueNames).detect(page);
        scanFailed = page.isEmpty;
      } catch (_) {
        // ML Kit unavailable or the model failed to load. Fall through to the
        // manual-only path rather than letting an unscanned image continue.
        scanFailed = true;
      } finally {
        await scanner.dispose();
      }

      if (!mounted) return;
      setState(() {
        _prepared = prepared;
        _findings = findings;
        _scanFailed = scanFailed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = "That image couldn't be read. Try another photo.";
        _loading = false;
      });
    }
  }

  Map<PiiCategory, int> get _detectedCounts {
    final counts = <PiiCategory, int>{};
    for (final finding in _findings) {
      counts.update(finding.category, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  int get _maskedCount => _findings.where((f) => f.masked).length;

  void _toggleCategory(PiiCategory category) {
    if (!category.canReveal) return;
    final anyUnmasked = _findings.any((f) => f.category == category && !f.masked);
    setState(() {
      for (final finding in _findings) {
        if (finding.category == category) finding.masked = anyUnmasked;
      }
    });
  }

  void _handleTap(Offset imagePoint) {
    for (var i = _findings.length - 1; i >= 0; i--) {
      final finding = _findings[i];
      if (!finding.rect.contains(imagePoint)) continue;

      // A box the user drew disappears on tap. A detected one can only be
      // revealed if it is age/sex — names, addresses, contacts, ID numbers,
      // doctors and the letterhead are locked, so there is no way to talk
      // yourself into uploading them.
      if (finding.userDrawn) {
        setState(() => _findings.removeAt(i));
      } else if (finding.category.canReveal) {
        setState(() => finding.masked = !finding.masked);
      } else {
        _showLocked(finding.category);
      }
      return;
    }
  }

  void _showLocked(PiiCategory category) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('${category.label} always stays hidden — it identifies you.'),
        ),
      );
  }

  void _addManualRect(Rect drawn) {
    final size = _prepared?.size;
    if (size == null) return;

    // A drag can run off the image into the letterboxed area either side of it.
    final rect = Rect.fromLTRB(
      drawn.left.clamp(0.0, size.width),
      drawn.top.clamp(0.0, size.height),
      drawn.right.clamp(0.0, size.width),
      drawn.bottom.clamp(0.0, size.height),
    );
    if (rect.width < 8 || rect.height < 8) return;

    setState(() {
      _findings.add(
        PiiFinding(rect: rect, category: PiiCategory.manual, matchedText: '', masked: true, userDrawn: true),
      );
      _findings.sort((a, b) => a.rect.top.compareTo(b.rect.top));
    });
  }

  void _blockHeader() {
    final size = _prepared?.size;
    if (size == null) return;
    _addManualRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.15));
  }

  Future<void> _confirm() async {
    final prepared = _prepared;
    if (prepared == null) return;

    setState(() => _redacting = true);
    try {
      final rects = _findings.where((f) => f.masked).map((f) => f.rect).toList();

      // With nothing to mask the prepared file is already the safe one — it
      // was re-encoded from scratch, so its EXIF (GPS, device, timestamp) is
      // gone regardless.
      final path = rects.isEmpty
          ? prepared.path
          : await redactReportImage(preparedPath: prepared.path, rects: rects);

      final summary = <PiiCategory, int>{};
      for (final finding in _findings.where((f) => f.masked)) {
        summary.update(finding.category, (value) => value + 1, ifAbsent: () => 1);
      }

      if (!mounted) return;
      Navigator.of(context).pop(RedactionOutcome(imagePath: path, hiddenByCategory: summary));
    } catch (_) {
      if (!mounted) return;
      setState(() => _redacting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't hide those areas. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAcknowledgement = _scanFailed && _maskedCount == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Hide personal details')),
      body: _loading
          ? const _PreparingView()
          : _loadError != null
          ? ErrorView(message: _loadError!, onRetry: _prepareAndScan)
          : Column(
              children: [
                Expanded(child: _buildCanvas(context)),
                _buildControls(context, needsAcknowledgement),
              ],
            ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final prepared = _prepared!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitted = applyBoxFit(BoxFit.contain, prepared.size, constraints.biggest);
          final destination = Alignment.center.inscribe(fitted.destination, Offset.zero & constraints.biggest);
          final scale = prepared.size.width == 0 ? 1.0 : destination.width / prepared.size.width;

          Offset toImage(Offset local) => (local - destination.topLeft) / scale;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(toImage(details.localPosition)),
            onPanStart: (details) {
              _dragStart = toImage(details.localPosition);
              setState(() => _draftRect = null);
            },
            onPanUpdate: (details) {
              final start = _dragStart;
              if (start == null) return;
              setState(() => _draftRect = Rect.fromPoints(start, toImage(details.localPosition)));
            },
            onPanEnd: (_) {
              final draft = _draftRect;
              setState(() => _draftRect = null);
              _dragStart = null;
              if (draft != null) _addManualRect(draft);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: destination,
                  child: Image.file(File(prepared.path), fit: BoxFit.fill),
                ),
                Positioned.fromRect(
                  rect: destination,
                  child: CustomPaint(
                    painter: _RedactionPainter(
                      findings: _findings,
                      draftRect: _draftRect,
                      scale: scale,
                      outline: colorScheme.primary,
                      unmaskedOutline: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(BuildContext context, bool needsAcknowledgement) {
    final theme = Theme.of(context);
    final counts = _detectedCounts;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_scanFailed) ...[
                const _ScanFailedBanner(),
                const SizedBox(height: 12),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _maskedCount == 0
                              ? 'Nothing is hidden yet'
                              : '$_maskedCount ${_maskedCount == 1 ? 'area' : 'areas'} will be blacked out before upload',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Personal details stay hidden and cannot be shown. '
                'Drag anywhere on the image to hide something we missed.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in counts.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        // Locked categories are shown as a plain chip with a
                        // padlock rather than a switch you can flip.
                        child: entry.key.canReveal
                            ? FilterChip(
                                label: Text('${entry.key.label} (${entry.value})'),
                                selected: _findings.any((f) => f.category == entry.key && f.masked),
                                onSelected: (_) => _toggleCategory(entry.key),
                              )
                            : Chip(
                                avatar: const Icon(Icons.lock_outline, size: 16),
                                label: Text('${entry.key.label} (${entry.value})'),
                              ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.vertical_align_top, size: 18),
                      label: const Text('Block header'),
                      onPressed: _blockHeader,
                    ),
                  ],
                ),
              ),
              if (needsAcknowledgement)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _acknowledged,
                  onChanged: (value) => setState(() => _acknowledged = value ?? false),
                  title: Text(
                    "I've checked this image myself — there are no personal details left on it.",
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _redacting || (needsAcknowledgement && !_acknowledged) ? null : _confirm,
                icon: _redacting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_outline),
                label: Text(_redacting ? 'Hiding details…' : 'Confirm and continue'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Checking the image on your phone…', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'This runs offline. Nothing has been uploaded yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFailedBanner extends StatelessWidget {
  const _ScanFailedBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 18, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't read this image automatically, so nothing was detected. "
              'Drag over any personal details yourself before continuing.',
              style: TextStyle(color: colorScheme.onTertiaryContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the boxes over the image in widget space. Masked regions are filled
/// solid so the preview matches what will actually be written into the file;
/// unmasked detections keep an outline plus a hatch-free translucent tint so
/// they read as "found but visible" without relying on colour alone.
class _RedactionPainter extends CustomPainter {
  const _RedactionPainter({
    required this.findings,
    required this.draftRect,
    required this.scale,
    required this.outline,
    required this.unmaskedOutline,
  });

  final List<PiiFinding> findings;
  final Rect? draftRect;
  final double scale;
  final Color outline;
  final Color unmaskedOutline;

  @override
  void paint(Canvas canvas, Size size) {
    for (final finding in findings) {
      final rect = _scaled(finding.rect);
      if (finding.masked) {
        canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = outline,
        );
      } else {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = unmaskedOutline,
        );
      }
    }

    final draft = draftRect;
    if (draft != null) {
      canvas.drawRect(
        _scaled(draft),
        Paint()..color = const Color(0x66000000),
      );
    }
  }

  Rect _scaled(Rect rect) => Rect.fromLTRB(
    rect.left * scale,
    rect.top * scale,
    rect.right * scale,
    rect.bottom * scale,
  );

  @override
  bool shouldRepaint(_RedactionPainter oldDelegate) => true;
}
