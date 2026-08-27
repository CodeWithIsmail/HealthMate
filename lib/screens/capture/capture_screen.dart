import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/privacy/redaction_outcome.dart';
import '../../core/utils/formatters.dart';
import '../../models/catalogue_test.dart';
import '../../providers/capture_provider.dart';
import '../../widgets/bilingual_summary.dart';
import '../../widgets/status_pill.dart';
import 'redaction_screen.dart';

const _maxUploadBytes = 10 * 1024 * 1024;

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaptureProvider>().loadCatalogue();
    });
  }

  Future<void> _pickAndCrop(ImageSource source) async {
    final provider = context.read<CaptureProvider>();
    String? croppedPath;

    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;

      final size = await picked.length();
      if (size > _maxUploadBytes) {
        if (mounted) _showSnack('That image is larger than 10 MB. Try a smaller photo.');
        return;
      }

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop report', lockAspectRatio: false),
          IOSUiSettings(title: 'Crop report'),
        ],
      );
      if (cropped == null) return;
      provider.pickImage(cropped.path);
      croppedPath = cropped.path;
    } catch (e) {
      if (mounted) _showSnack("Couldn't open the camera or photo library.");
      return;
    }

    // Outside the try: a failure inside redaction has its own error handling,
    // and must not be reported as a camera problem.
    if (mounted) await _openRedaction(croppedPath);
  }

  /// Every picked image goes through here before it can be uploaded — the
  /// redaction screen is what produces the sanitized file the API sees.
  Future<void> _openRedaction(String sourcePath) async {
    final provider = context.read<CaptureProvider>();
    final navigator = Navigator.of(context);
    final outcome = await navigator.push<RedactionOutcome>(
      MaterialPageRoute(
        builder: (_) => RedactionScreen(sourceImagePath: sourcePath, catalogueNames: provider.catalogueNames),
      ),
    );
    if (outcome != null) provider.applyRedaction(outcome);
  }

  Future<void> _reviewRedaction() async {
    final source = context.read<CaptureProvider>().originalImagePath;
    if (source != null) await _openRedaction(source);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final provider = context.read<CaptureProvider>();
    final id = await provider.save();
    if (id != null && mounted) context.pushReplacement('/reports/$id');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.step == CaptureStep.input ? 'Add a report' : 'Review and save'),
        leading: provider.step == CaptureStep.review
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: provider.backToInput)
            : null,
      ),
      body: provider.step == CaptureStep.input
          ? _InputStep(onPickImage: _pickAndCrop, onReviewRedaction: _reviewRedaction)
          : _ReviewStep(onSave: _save),
    );
  }
}

class _InputStep extends StatelessWidget {
  const _InputStep({required this.onPickImage, required this.onReviewRedaction});

  final Future<void> Function(ImageSource source) onPickImage;
  final Future<void> Function() onReviewRedaction;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<CaptureMode>(
          segments: const [
            ButtonSegment(value: CaptureMode.scan, label: Text('Scan an image'), icon: Icon(Icons.document_scanner_outlined)),
            ButtonSegment(value: CaptureMode.manual, label: Text('Enter manually'), icon: Icon(Icons.keyboard_outlined)),
          ],
          selected: {provider.mode},
          onSelectionChanged: (s) => provider.setMode(s.first),
        ),
        const SizedBox(height: 20),
        if (provider.error != null) ...[
          _ErrorBanner(message: provider.error!),
          const SizedBox(height: 16),
        ],
        if (provider.mode == CaptureMode.scan)
          _ScanInput(onPickImage: onPickImage, onReviewRedaction: onReviewRedaction)
        else
          const _ManualInput(),
      ],
    );
  }
}

class _ScanInput extends StatelessWidget {
  const _ScanInput({required this.onPickImage, required this.onReviewRedaction});

  final Future<void> Function(ImageSource source) onPickImage;
  final Future<void> Function() onReviewRedaction;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (provider.hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // The redacted copy once it exists — what you see here is
                // exactly what gets uploaded.
                child: Image.file(
                  File(provider.sanitizedImagePath ?? provider.originalImagePath!),
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              _PrivacyStatus(onReviewRedaction: onReviewRedaction),
              const SizedBox(height: 4),
              TextButton(onPressed: provider.clearImage, child: const Text('Choose a different image')),
            ] else ...[
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_outlined, size: 32, color: colorScheme.primary),
                    const SizedBox(height: 8),
                    const Text('Choose a report image'),
                    const SizedBox(height: 4),
                    Text('JPEG, PNG or WebP, up to 10 MB', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Personal details are blacked out on your phone before anything is uploaded.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onPickImage(ImageSource.gallery),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Choose file'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onPickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Use camera'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: !provider.isSanitized || provider.busy == 'extract' ? null : provider.extract,
              icon: provider.busy == 'extract'
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(provider.busy == 'extract' ? 'Reading the report…' : 'Extract values'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells the user what happened to their image before it left the phone, and
/// gives them a way back into the redaction screen.
class _PrivacyStatus extends StatelessWidget {
  const _PrivacyStatus({required this.onReviewRedaction});

  final Future<void> Function() onReviewRedaction;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final sanitized = provider.isSanitized;
    final count = provider.hiddenCount;

    final background = sanitized ? colorScheme.secondaryContainer : colorScheme.tertiaryContainer;
    final foreground = sanitized ? colorScheme.onSecondaryContainer : colorScheme.onTertiaryContainer;

    final message = !sanitized
        ? 'Not reviewed yet — check for personal details before uploading.'
        : count == 0
        ? 'Nothing hidden. Location data was still removed.'
        : '$count ${count == 1 ? 'area' : 'areas'} will be blacked out before upload.';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(sanitized ? Icons.shield_outlined : Icons.warning_amber_outlined, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => onReviewRedaction(),
            child: Text(sanitized ? 'Review' : 'Review now'),
          ),
        ],
      ),
    );
  }
}

class _ManualInput extends StatelessWidget {
  const _ManualInput();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick the tests you want to record. You can add as many as you need.'),
            const SizedBox(height: 16),
            if (provider.catalogueLoading)
              const Center(child: CircularProgressIndicator())
            else
              _TestPicker(catalogue: provider.catalogue, rows: provider.rows, onSelect: provider.addRow),
            if (provider.rows.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: provider.goToReview,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text('Continue with ${provider.rows.length} test${provider.rows.length == 1 ? '' : 's'}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TestPicker extends StatelessWidget {
  const _TestPicker({required this.catalogue, required this.rows, required this.onSelect});

  final List<CatalogueTest> catalogue;
  final List<CaptureRow> rows;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final available = catalogue.where((c) => !rows.any((r) => r.testId == c.id)).toList();
    return DropdownButtonFormField<String>(
      key: ValueKey(rows.length),
      initialValue: null,
      decoration: const InputDecoration(labelText: 'Add a test'),
      items: available
          .map(
            (t) => DropdownMenuItem(
              value: t.id,
              child: Text(t.unit != null ? '${t.name} (${t.unit})' : t.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (id) {
        if (id != null) onSelect(id);
      },
    );
  }
}

class _ReviewStep extends StatefulWidget {
  const _ReviewStep({required this.onSave});
  final Future<void> Function() onSave;

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  final _titleController = TextEditingController();
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (provider.isStub) ...[
          _WarningBanner(
            title: 'Values were not read from your image',
            message:
                'No OCR provider is currently available, so these numbers are placeholders. '
                '${provider.degradedReason ?? ''} Everything else on this page works normally.',
          ),
          const SizedBox(height: 16),
        ],
        if (provider.error != null) ...[
          _ErrorBanner(message: provider.error!),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: provider.reportDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) provider.setReportDate(picked);
                    },
                    child: Text(formatDate(provider.reportDate)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title (optional)'),
                    onChanged: provider.setTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${provider.rows.length} tests · edit anything that looks wrong',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (provider.catalogue.isNotEmpty)
                      SizedBox(
                        width: 140,
                        child: _TestPicker(catalogue: provider.catalogue, rows: provider.rows, onSelect: provider.addRow),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (provider.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No values yet. Use "Add test" above to record one.'),
                )
              else
                ...provider.rows.map((row) => _EditableValueRow(key: ValueKey(row.testId), row: row)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: provider.busy == 'save' ? null : widget.onSave,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: provider.busy == 'save'
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save report'),
        ),
        if (provider.mode == CaptureMode.scan && provider.sanitizedImagePath != null) ...[
          const SizedBox(height: 24),
          Text(
            'This is the version that was uploaded and will be stored with the report.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Image.file(File(provider.sanitizedImagePath!), fit: BoxFit.contain),
          ),
        ],
        if (provider.mode == CaptureMode.scan) ...[
          const SizedBox(height: 16),
          _AnalysisCard(questionController: _questionController),
        ],
      ],
    );
  }
}

class _EditableValueRow extends StatefulWidget {
  const _EditableValueRow({super.key, required this.row});
  final CaptureRow row;

  @override
  State<_EditableValueRow> createState() => _EditableValueRowState();
}

class _EditableValueRowState extends State<_EditableValueRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.row.valueText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CaptureProvider>();
    final row = widget.row;
    final parsed = double.tryParse(row.valueText.trim());
    final status = parsed == null ? RangeStatus.unknown : rangeStatus(parsed, row.refLow, row.refHigh);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  row.refLow != null && row.refHigh != null
                      ? 'Reference ${formatValue(row.refLow!)} – ${formatValue(row.refHigh!)}'
                      : 'No reference range',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(isDense: true, suffixText: row.unit),
              onChanged: (v) => provider.updateValue(row.testId, v),
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(status: status),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => provider.removeRow(row.testId),
          ),
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.questionController});
  final TextEditingController questionController;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaptureProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Analysis', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            BilingualSummary(
              textEn: provider.analysisEn,
              textBn: provider.analysisBn,
              loading: provider.busy == 'analyze',
            ),
            ...provider.chat.map(
              (turn) => Align(
                alignment: turn.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  decoration: BoxDecoration(
                    color: turn.role == 'user'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: turn.role == 'user' ? Text(turn.text) : MarkdownBody(data: turn.text),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // The image is redacted, but anything typed here is sent verbatim.
            Text(
              'Questions you type are sent as they are — avoid typing names or ID numbers.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: questionController,
                    decoration: const InputDecoration(hintText: 'Ask about this report…'),
                    onSubmitted: (v) {
                      context.read<CaptureProvider>().ask(v);
                      questionController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: provider.busy == 'chat'
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: provider.busy == 'chat'
                      ? null
                      : () {
                          context.read<CaptureProvider>().ask(questionController.text);
                          questionController.clear();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: colorScheme.onErrorContainer))),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: colorScheme.onTertiaryContainer, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: colorScheme.onTertiaryContainer, fontSize: 13)),
        ],
      ),
    );
  }
}
