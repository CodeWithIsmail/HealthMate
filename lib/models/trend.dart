import 'report.dart';

/// A test with existing data for a user — `GET /trends/tests`. This is the
/// list behind the *trends* test picker; it is scoped to tests the user
/// already has readings for. For the manual-entry catalogue (every known
/// test), use `CatalogueTest` / `GET /tests` instead.
class TrendTest {
  const TrendTest({
    required this.id,
    required this.name,
    required this.slug,
    this.unit,
    this.refLow,
    this.refHigh,
    required this.pointCount,
  });

  final String id;
  final String name;
  final String slug;
  final String? unit;
  final double? refLow;
  final double? refHigh;
  final int pointCount;

  factory TrendTest.fromJson(Map<String, dynamic> json) => TrendTest(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    unit: json['unit'] as String?,
    refLow: (json['refLow'] as num?)?.toDouble(),
    refHigh: (json['refHigh'] as num?)?.toDouble(),
    pointCount: json['pointCount'] as int? ?? 0,
  );
}

class TrendsAvailableResponse {
  const TrendsAvailableResponse({required this.owner, required this.tests});

  final OwnerRef owner;
  final List<TrendTest> tests;

  factory TrendsAvailableResponse.fromJson(Map<String, dynamic> json) => TrendsAvailableResponse(
    owner: OwnerRef.fromJson(json['owner'] as Map<String, dynamic>),
    tests: (json['tests'] as List).map((e) => TrendTest.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class TrendTestRef {
  const TrendTestRef({required this.id, required this.name, this.unit, this.refLow, this.refHigh});

  final String id;
  final String name;
  final String? unit;
  final double? refLow;
  final double? refHigh;

  factory TrendTestRef.fromJson(Map<String, dynamic> json) => TrendTestRef(
    id: json['id'] as String,
    name: json['name'] as String,
    unit: json['unit'] as String?,
    refLow: (json['refLow'] as num?)?.toDouble(),
    refHigh: (json['refHigh'] as num?)?.toDouble(),
  );
}

class TrendPoint {
  const TrendPoint({required this.date, required this.value, this.reportId});

  final DateTime date;
  final double value;
  final String? reportId;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
    date: DateTime.parse(json['date'] as String),
    value: (json['value'] as num).toDouble(),
    reportId: json['reportId'] as String?,
  );
}

class TrendStats {
  const TrendStats({
    required this.count,
    required this.latest,
    required this.min,
    required this.max,
    required this.average,
    required this.change,
  });

  final int count;
  final double latest;
  final double min;
  final double max;
  final double average;
  final double change;

  factory TrendStats.fromJson(Map<String, dynamic> json) => TrendStats(
    count: json['count'] as int,
    latest: (json['latest'] as num).toDouble(),
    min: (json['min'] as num).toDouble(),
    max: (json['max'] as num).toDouble(),
    average: (json['average'] as num).toDouble(),
    change: (json['change'] as num).toDouble(),
  );
}

/// `GET /trends/series?testId=<UUID>`.
class TrendSeries {
  const TrendSeries({required this.owner, required this.test, required this.points, this.stats});

  final OwnerRef owner;
  final TrendTestRef test;
  final List<TrendPoint> points;
  final TrendStats? stats;

  factory TrendSeries.fromJson(Map<String, dynamic> json) => TrendSeries(
    owner: OwnerRef.fromJson(json['owner'] as Map<String, dynamic>),
    test: TrendTestRef.fromJson(json['test'] as Map<String, dynamic>),
    points: (json['points'] as List).map((e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList(),
    stats: json['stats'] == null ? null : TrendStats.fromJson(json['stats'] as Map<String, dynamic>),
  );
}
