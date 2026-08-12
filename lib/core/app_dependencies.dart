import 'api/api_client.dart';
import 'storage/token_storage.dart';
import '../repositories/auth_repository.dart';
import '../repositories/connections_repository.dart';
import '../repositories/news_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/tests_repository.dart';
import '../repositories/trends_repository.dart';
import '../repositories/user_repository.dart';

/// Wires the singletons (API client, token storage, repositories) used
/// throughout the app. Constructed once in `main()` and handed down via a
/// plain `Provider<AppDependencies>` — these are stateless service objects,
/// not UI state, so they don't need `ChangeNotifierProvider`.
class AppDependencies {
  factory AppDependencies() {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    return AppDependencies._(
      tokenStorage: tokenStorage,
      apiClient: apiClient,
      authRepository: AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage),
      userRepository: UserRepository(apiClient: apiClient),
      reportRepository: ReportRepository(apiClient: apiClient),
      newsRepository: NewsRepository(apiClient: apiClient),
      connectionsRepository: ConnectionsRepository(apiClient: apiClient),
      testsRepository: TestsRepository(apiClient: apiClient),
      trendsRepository: TrendsRepository(apiClient: apiClient),
    );
  }

  AppDependencies._({
    required this.tokenStorage,
    required this.apiClient,
    required this.authRepository,
    required this.userRepository,
    required this.reportRepository,
    required this.newsRepository,
    required this.connectionsRepository,
    required this.testsRepository,
    required this.trendsRepository,
  });

  final TokenStorage tokenStorage;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final ReportRepository reportRepository;
  final NewsRepository newsRepository;
  final ConnectionsRepository connectionsRepository;
  final TestsRepository testsRepository;
  final TrendsRepository trendsRepository;
}
