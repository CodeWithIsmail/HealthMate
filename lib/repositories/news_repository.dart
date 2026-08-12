import '../core/api/api_client.dart';
import '../models/news_article.dart';

class NewsHeadlines {
  const NewsHeadlines({required this.articles, required this.live});
  final List<NewsArticle> articles;
  final bool live;
}

class NewsRepository {
  NewsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<NewsHeadlines> headlines() async {
    final json = await _api.get<Map<String, dynamic>>('/news');
    return NewsHeadlines(
      articles: (json['articles'] as List).map((e) => NewsArticle.fromJson(e as Map<String, dynamic>)).toList(),
      live: json['live'] as bool? ?? false,
    );
  }
}
