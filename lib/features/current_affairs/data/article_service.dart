import '../../../core/network/api_client.dart';
import '../models/article_models.dart';

class ArticleService {
  final ApiClient apiClient;

  ArticleService({required this.apiClient});

  // Fetch articles from the feed
  Future<Map<String, dynamic>> getArticles({
    required String contentKind,
    String? articleRole,
    String? category,
    String? month,
    String? year,
    int page = 1,
    int limit = 12,
  }) async {
    final queryParams = <String, String>{
      'content_kind': contentKind,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (articleRole != null && articleRole.isNotEmpty) {
      queryParams['article_role'] = articleRole;
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (month != null && month.isNotEmpty && month != 'all') {
      queryParams['month'] = month;
    }
    if (year != null && year.isNotEmpty && year != 'all') {
      queryParams['year'] = year;
    }

    final queryString = Uri(queryParameters: queryParams).query;
    final response = await apiClient.get('/api/v1/current-affairs/frontend/articles?$queryString');

    if (response is Map<String, dynamic>) {
      final itemsRaw = response['items'] as List?;
      final items = itemsRaw?.map((item) => ArticleSummary.fromJson(item as Map<String, dynamic>)).toList() ?? [];
      
      return {
        'items': items,
        'page': response['page'] ?? 1,
        'limit': response['limit'] ?? 12,
        'total': response['total'] ?? 0,
        'totalPages': response['total_pages'] ?? 1,
      };
    }
    throw Exception('Invalid articles response from API');
  }

  // Fetch categories, months, and years list
  Future<ArticleFilters> getFilters(String contentKind, String contentFamily) async {
    final response = await apiClient.get(
      '/api/v1/current-affairs/frontend/filters?content_kind=$contentKind&content_family=$contentFamily',
    );
    if (response is Map<String, dynamic>) {
      return ArticleFilters.fromJson(response);
    }
    throw Exception('Invalid filters response from API');
  }

  // Fetch single article detail by slug
  Future<ArticleDetail> getArticleBySlug(String slug) async {
    final response = await apiClient.get('/api/v1/current-affairs/articles/slug/$slug');
    if (response is Map<String, dynamic>) {
      return ArticleDetail.fromJson(response);
    }
    throw Exception('Invalid article detail response from API');
  }
}
