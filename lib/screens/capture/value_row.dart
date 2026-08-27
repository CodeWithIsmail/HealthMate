import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../providers/capture_provider.dart';
import '../../widgets/status_pill.dart';

/// One editable test result on the "Review and save" step.
///
/// Deliberately takes callbacks rather than reading [CaptureProvider] itself,
/// so it can be pumped straight into a widget test — the layout here is what
/// broke on a real phone, and a `RenderFlex` overflow in a test is the only way
/// to catch that without a device.
///
/// The name owns a full row of its own because it is the thing the user checks
/// first; the unit sits *outside* the input rather than as a `suffixText`,
/// which is what previously squeezed values like `3800 cells/uL` out of the
/// field entirely.
class CaptureValueRow extends StatefulWidget {
  const CaptureValueRow({super.key, required this.row, required this.onChanged, required this.onRemove});

  final CaptureRow row;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  State<CaptureValueRow> createState() => _CaptureValueRowState();
}

class _CaptureValueRowState extends State<CaptureValueRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.row.valueText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    widget.onChanged(value);
    // Local rebuild only: the status pill is the sole thing that reacts to a
    // keystroke, and rebuilding the whole list per character is visibly slow
    // on a long report.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = widget.row;
    final text = _controller.text.trim();
    final parsed = double.tryParse(text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    row.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Remove ${row.name}',
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: widget.onRemove,
              ),
            ],
          ),
          Text(
            referenceLabel(row.refLow, row.refHigh),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // A Wrap rather than a Row: at a large system font size the status
          // pill drops onto its own line instead of overflowing the screen.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 116,
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  textAlign: TextAlign.right,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '—',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  onChanged: _handleChanged,
                ),
              ),
              if (row.unit != null && row.unit!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: Text(
                    row.unit!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              if (text.isEmpty || parsed == null)
                const _NotEnteredChip()
              else
                StatusPill(status: rangeStatus(parsed, row.refLow, row.refHigh)),
            ],
          ),
        ],
      ),
    );
  }
}

/// An empty field is not "no reference range" — it is a value the user has yet
/// to type, and saying so is what stops a blank row reading as a real result.
class _NotEnteredChip extends StatelessWidget {
  const _NotEnteredChip();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            'Not entered',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A one-sided range is still a range. The old label collapsed anything without
/// both bounds to "No reference range" while the pill went on reporting "Below
/// range" from the single bound it did have — the two contradicted each other.
String referenceLabel(double? low, double? high) {
  if (low != null && high != null) return 'Reference ${formatValue(low)} – ${formatValue(high)}';
  if (low != null) return 'Reference from ${formatValue(low)}';
  if (high != null) return 'Reference up to ${formatValue(high)}';
  return 'No reference range';
}
