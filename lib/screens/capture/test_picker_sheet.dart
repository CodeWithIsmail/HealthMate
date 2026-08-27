import 'package:flutter/material.dart';

import '../../models/catalogue_test.dart';

/// Picks a test from the full `GET /tests` catalogue.
///
/// A dropdown was the wrong control here: the catalogue runs to dozens of
/// entries, and a menu with no search means scrolling blind past names you
/// half-remember. Returns the chosen test id, or null if dismissed.
Future<String?> showTestPickerSheet({
  required BuildContext context,
  required List<CatalogueTest> catalogue,
  required Set<String> excludedIds,
}) {
  final available = catalogue.where((test) => !excludedIds.contains(test.id)).toList();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TestPickerSheet(tests: available),
  );
}

class _TestPickerSheet extends StatefulWidget {
  const _TestPickerSheet({required this.tests});

  final List<CatalogueTest> tests;

  @override
  State<_TestPickerSheet> createState() => _TestPickerSheetState();
}

class _TestPickerSheetState extends State<_TestPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CatalogueTest> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.tests;
    return widget.tests.where((test) {
      return test.name.toLowerCase().contains(query) ||
          test.slug.toLowerCase().contains(query) ||
          (test.category?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;

    return Padding(
      // Lift the sheet clear of the keyboard the search field summons.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Add a test', style: theme.textTheme.titleMedium)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search tests',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.tests.isEmpty
                              ? 'Every test in the catalogue is already on this report.'
                              : 'No test matches “${_query.trim()}”.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final test = results[index];
                        return ListTile(
                          title: Text(test.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: test.unit != null && test.unit!.isNotEmpty
                              ? Text(test.unit!, maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: const Icon(Icons.add, size: 20),
                          onTap: () => Navigator.pop(context, test.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
