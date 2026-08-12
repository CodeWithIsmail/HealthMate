/// A row from the full test catalogue — `GET /tests`. This backs the
/// manual-entry test picker (every known test, not just ones the user
/// already has data for; see `TrendTest` for that).
class CatalogueTest {
  const CatalogueTest({
    required this.id,
    required this.name,
    required this.slug,
    this.unit,
    this.category,
    this.refLow,
    this.refHigh,
  });

  final String id;
  final String name;
  final String slug;
  final String? unit;
  final String? category;
  final double? refLow;
  final double? refHigh;

  factory CatalogueTest.fromJson(Map<String, dynamic> json) => CatalogueTest(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    unit: json['unit'] as String?,
    category: json['category'] as String?,
    refLow: (json['refLow'] as num?)?.toDouble(),
    refHigh: (json['refHigh'] as num?)?.toDouble(),
  );
}
