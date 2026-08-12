enum ReportSource {
  ocr('OCR'),
  manual('MANUAL');

  const ReportSource(this.apiValue);
  final String apiValue;

  static ReportSource fromApi(String value) => value == 'MANUAL' ? ReportSource.manual : ReportSource.ocr;
}

/// The owner a report/trend list belongs to — `{ username, isSelf }`, always
/// server-decided.
class OwnerRef {
  const OwnerRef({required this.username, required this.isSelf});

  final String username;
  final bool isSelf;

  factory OwnerRef.fromJson(Map<String, dynamic> json) =>
      OwnerRef(username: json['username'] as String, isSelf: json['isSelf'] as bool? ?? false);
}

class ReportSummary {
  const ReportSummary({
    required this.id,
    required this.reportDate,
    this.title,
    this.imageUrl,
    this.summary,
    required this.source,
    required this.valueCount,
    required this.shareCount,
    required this.createdAt,
  });

  final String id;
  final DateTime reportDate;
  final String? title;
  final String? imageUrl;
  final String? summary;
  final ReportSource source;
  final int valueCount;
  final int shareCount;
  final DateTime createdAt;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    id: json['id'] as String,
    reportDate: DateTime.parse(json['reportDate'] as String),
    title: json['title'] as String?,
    imageUrl: json['imageUrl'] as String?,
    summary: json['summary'] as String?,
    source: ReportSource.fromApi(json['source'] as String),
    valueCount: json['valueCount'] as int? ?? 0,
    shareCount: json['shareCount'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class ReportsListResponse {
  const ReportsListResponse({required this.owner, required this.reports});

  final OwnerRef owner;
  final List<ReportSummary> reports;

  factory ReportsListResponse.fromJson(Map<String, dynamic> json) => ReportsListResponse(
    owner: OwnerRef.fromJson(json['owner'] as Map<String, dynamic>),
    reports: (json['reports'] as List).map((e) => ReportSummary.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class ReportValue {
  const ReportValue({
    required this.id,
    required this.testId,
    required this.name,
    this.unit,
    required this.value,
    this.refLow,
    this.refHigh,
  });

  final String id;
  final String testId;
  final String name;
  final String? unit;
  final double value;
  final double? refLow;
  final double? refHigh;

  factory ReportValue.fromJson(Map<String, dynamic> json) => ReportValue(
    id: json['id'] as String,
    testId: json['testId'] as String,
    name: json['name'] as String,
    unit: json['unit'] as String?,
    value: (json['value'] as num).toDouble(),
    refLow: (json['refLow'] as num?)?.toDouble(),
    refHigh: (json['refHigh'] as num?)?.toDouble(),
  );
}

class SharedWithEntry {
  const SharedWithEntry({required this.username, this.imageUrl});

  final String username;
  final String? imageUrl;

  factory SharedWithEntry.fromJson(Map<String, dynamic> json) =>
      SharedWithEntry(username: json['username'] as String, imageUrl: json['imageUrl'] as String?);
}

/// `GET /reports/:id` — flat, not wrapped in a `report` key.
class ReportDetail {
  const ReportDetail({
    required this.id,
    required this.owner,
    required this.isOwner,
    required this.reportDate,
    this.title,
    this.imageUrl,
    this.summary,
    this.summaryBn,
    required this.source,
    required this.createdAt,
    required this.values,
    required this.sharedWith,
  });

  final String id;
  final String owner;
  final bool isOwner;
  final DateTime reportDate;
  final String? title;
  final String? imageUrl;
  final String? summary;
  final String? summaryBn;
  final ReportSource source;
  final DateTime createdAt;
  final List<ReportValue> values;
  final List<SharedWithEntry> sharedWith;

  factory ReportDetail.fromJson(Map<String, dynamic> json) => ReportDetail(
    id: json['id'] as String,
    owner: json['owner'] as String,
    isOwner: json['isOwner'] as bool? ?? false,
    reportDate: DateTime.parse(json['reportDate'] as String),
    title: json['title'] as String?,
    imageUrl: json['imageUrl'] as String?,
    summary: json['summary'] as String?,
    summaryBn: json['summaryBn'] as String?,
    source: ReportSource.fromApi(json['source'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    values: (json['values'] as List).map((e) => ReportValue.fromJson(e as Map<String, dynamic>)).toList(),
    sharedWith: (json['sharedWith'] as List? ?? const [])
        .map((e) => SharedWithEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
