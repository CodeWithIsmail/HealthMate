import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Renders an analysis summary generated in both English and Bangla (one
/// Gemini call, `##ENGLISH##`/`##BANGLA##` split server-side — see
/// `ANALYSIS_PROMPT` on the API) as two tabs. Used by both the capture
/// review screen (before saving) and the report detail screen (after).
///
/// Expects to sit inside a scrollable ancestor: markdown content can be
/// long, and this widget doesn't scroll itself.
class BilingualSummary extends StatefulWidget {
  const BilingualSummary({super.key, required this.textEn, required this.textBn, this.loading = false});

  final String? textEn;
  final String? textBn;
  final bool loading;

  @override
  State<BilingualSummary> createState() => _BilingualSummaryState();
}

class _BilingualSummaryState extends State<BilingualSummary> with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.indexIsChanging) return;
      setState(() => _index = _controller.index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.textEn == null && widget.textBn == null) {
      return const Text('Reading your report…');
    }
    if (widget.textEn == null && widget.textBn == null) {
      return const Text('No analysis available.');
    }

    final current = _index == 0 ? widget.textEn : widget.textBn;
    final missingLabel = _index == 0 ? 'English' : 'Bangla';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [Tab(text: 'English'), Tab(text: 'বাংলা')],
        ),
        const SizedBox(height: 12),
        if (current == null || current.isEmpty)
          Text('$missingLabel summary not available for this report.')
        else
          MarkdownBody(data: current),
      ],
    );
  }
}
