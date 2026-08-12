enum MatchedBy {
  exact,
  alias,
  llm,
  created;

  static MatchedBy fromApi(String value) => MatchedBy.values.firstWhere(
    (m) => m.name == value,
    orElse: () => MatchedBy.created,
  );
}

/// One row returned by `POST /reports/extract`.
class ExtractedValue {
  const ExtractedValue({
    required this.rawName,
    required this.value,
    this.unit,
    required this.testId,
    required this.canonicalName,
    this.refLow,
    this.refHigh,
    required this.matchedBy,
  });

  final String rawName;
  final double value;
  final String? unit;
  final String testId;
  final String canonicalName;
  final double? refLow;
  final double? refHigh;
  final MatchedBy matchedBy;

  factory ExtractedValue.fromJson(Map<String, dynamic> json) => ExtractedValue(
    rawName: json['rawName'] as String,
    value: (json['value'] as num).toDouble(),
    unit: json['unit'] as String?,
    testId: json['testId'] as String,
    canonicalName: json['canonicalName'] as String,
    refLow: (json['refLow'] as num?)?.toDouble(),
    refHigh: (json['refHigh'] as num?)?.toDouble(),
    matchedBy: MatchedBy.fromApi(json['matchedBy'] as String),
  );
}

/// `provider: 'stub'` means Gemini was unavailable and the values are
/// **fabricated placeholders** — the UI must show a prominent warning and
/// keep that fact visible all the way to the saved report; never let a stub
/// reading be mistaken for a real one.
class ExtractionResponse {
  const ExtractionResponse({
    required this.imageUrl,
    required this.provider,
    this.degradedReason,
    required this.values,
  });

  final String imageUrl;
  final String provider; // 'gemini' | 'stub'
  final String? degradedReason;
  final List<ExtractedValue> values;

  bool get isStub => provider == 'stub';

  factory ExtractionResponse.fromJson(Map<String, dynamic> json) => ExtractionResponse(
    imageUrl: json['imageUrl'] as String,
    provider: json['provider'] as String,
    degradedReason: json['degradedReason'] as String?,
    values: (json['values'] as List).map((e) => ExtractedValue.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class AnalyzeResponse {
  const AnalyzeResponse({required this.text, required this.provider});

  final String text;
  final String provider;

  bool get isStub => provider == 'stub';

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) =>
      AnalyzeResponse(text: json['text'] as String, provider: json['provider'] as String);
}

class ChatTurn {
  const ChatTurn({required this.role, required this.text});

  /// 'user' | 'model' — note: 'model', not 'assistant'.
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class ChatResponse {
  const ChatResponse({required this.text});
  final String text;

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(text: json['text'] as String);
}
