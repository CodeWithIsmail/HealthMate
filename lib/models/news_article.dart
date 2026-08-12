class NewsArticle {
  const NewsArticle({
    required this.title,
    this.description,
    required this.url,
    this.imageUrl,
    required this.source,
    required this.publishedAt,
  });

  final String title;
  final String? description;
  final String url;
  final String? imageUrl;
  final String source;
  final DateTime publishedAt;

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'] as String,
    description: json['description'] as String?,
    url: json['url'] as String,
    imageUrl: json['imageUrl'] as String?,
    source: json['source'] as String,
    publishedAt: DateTime.parse(json['publishedAt'] as String),
  );
}
