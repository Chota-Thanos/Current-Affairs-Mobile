class CategoryNode {
  final int id;
  final String contentFamily;
  final int? parentId;
  final String nodeType;
  final String name;
  final String slug;
  final String? description;
  final int? articleCount;

  CategoryNode({
    required this.id,
    required this.contentFamily,
    this.parentId,
    required this.nodeType,
    required this.name,
    required this.slug,
    this.description,
    this.articleCount,
  });

  factory CategoryNode.fromJson(Map<String, dynamic> json) {
    return CategoryNode(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      contentFamily: json['content_family'] ?? '',
      parentId: json['parent_id'] != null ? int.tryParse(json['parent_id'].toString()) : null,
      nodeType: json['node_type'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] as String?,
      articleCount: json['article_count'] != null ? int.tryParse(json['article_count'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_family': contentFamily,
      'parent_id': parentId,
      'node_type': nodeType,
      'name': name,
      'slug': slug,
      'description': description,
      'article_count': articleCount,
    };
  }
}

class ArticleAsset {
  final int id;
  final int articleId;
  final String assetType;
  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final String? altText;
  final String? caption;

  ArticleAsset({
    required this.id,
    required this.articleId,
    required this.assetType,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.altText,
    this.caption,
  });

  factory ArticleAsset.fromJson(Map<String, dynamic> json) {
    return ArticleAsset(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      articleId: int.tryParse(json['article_id']?.toString() ?? '') ?? 0,
      assetType: json['asset_type'] ?? '',
      fileName: json['file_name'] ?? '',
      fileUrl: json['file_url'] ?? '',
      mimeType: json['mime_type'] as String?,
      altText: json['alt_text'] as String?,
      caption: json['caption'] as String?,
    );
  }
}

class ArticleSection {
  final int id;
  final String heading;
  final String slug;
  final String body;

  ArticleSection({
    required this.id,
    required this.heading,
    required this.slug,
    required this.body,
  });

  factory ArticleSection.fromJson(Map<String, dynamic> json) {
    return ArticleSection(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      heading: json['heading'] ?? '',
      slug: json['slug'] ?? '',
      body: json['body'] ?? '',
    );
  }
}

class ArticleSummary {
  final int id;
  final String contentFamily;
  final String contentKind;
  final String title;
  final String slug;
  final String body;
  final dynamic bodyJson;
  final CategoryNode? category;
  final String? sourceName;
  final String? sourceUrl;
  final String? publicationDate;
  final List<String> instituteTags;
  final ArticleAsset? primaryAsset;

  ArticleSummary({
    required this.id,
    required this.contentFamily,
    required this.contentKind,
    required this.title,
    required this.slug,
    required this.body,
    this.bodyJson,
    this.category,
    this.sourceName,
    this.sourceUrl,
    this.publicationDate,
    required this.instituteTags,
    this.primaryAsset,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      contentFamily: json['content_family'] ?? '',
      contentKind: json['content_kind'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      body: json['body'] ?? '',
      bodyJson: json['body_json'],
      category: json['category'] != null ? CategoryNode.fromJson(json['category'] as Map<String, dynamic>) : null,
      sourceName: json['source_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      publicationDate: json['publication_date'] as String?,
      instituteTags: (json['institute_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      primaryAsset: json['primary_asset'] != null ? ArticleAsset.fromJson(json['primary_asset'] as Map<String, dynamic>) : null,
    );
  }
}

class ArticleDetail {
  final int id;
  final String contentFamily;
  final String contentKind;
  final String title;
  final String slug;
  final String body;
  final dynamic bodyJson;
  final CategoryNode? category;
  final String? sourceName;
  final String? sourceUrl;
  final String? publicationDate;
  final List<String> instituteTags;
  final List<ArticleAsset> assets;
  final List<ArticleSection> sections;
  final List<OutgoingRelation> outgoingRelations;

  ArticleDetail({
    required this.id,
    required this.contentFamily,
    required this.contentKind,
    required this.title,
    required this.slug,
    required this.body,
    this.bodyJson,
    this.category,
    this.sourceName,
    this.sourceUrl,
    this.publicationDate,
    required this.instituteTags,
    required this.assets,
    required this.sections,
    required this.outgoingRelations,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    return ArticleDetail(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      contentFamily: json['content_family'] ?? '',
      contentKind: json['content_kind'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      body: json['body'] ?? '',
      bodyJson: json['body_json'],
      category: json['category'] != null ? CategoryNode.fromJson(json['category'] as Map<String, dynamic>) : null,
      sourceName: json['source_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      publicationDate: json['publication_date'] as String?,
      instituteTags: (json['institute_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      assets: (json['assets'] as List?)?.map((e) => ArticleAsset.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      sections: (json['sections'] as List?)?.map((e) => ArticleSection.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      outgoingRelations: (json['outgoing_relations'] as List?)?.map((e) => OutgoingRelation.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class OutgoingRelation {
  final int id;
  final String relationType;
  final String? label;
  final ArticleSummary targetArticle;

  OutgoingRelation({
    required this.id,
    required this.relationType,
    this.label,
    required this.targetArticle,
  });

  factory OutgoingRelation.fromJson(Map<String, dynamic> json) {
    return OutgoingRelation(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      relationType: json['relation_type'] ?? '',
      label: json['label'] as String?,
      targetArticle: ArticleSummary.fromJson(json['target_article'] as Map<String, dynamic>),
    );
  }
}

class ArticleFilters {
  final List<CategoryNode> categories;
  final List<String> months;
  final List<String> years;

  ArticleFilters({
    required this.categories,
    required this.months,
    required this.years,
  });

  factory ArticleFilters.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'] as List?;
    final rawYears = json['years'] as List?;

    return ArticleFilters(
      categories: (json['categories'] as List?)?.map((e) => CategoryNode.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      months: rawMonths?.map((e) => (e['month'] ?? '').toString()).toList() ?? [],
      years: rawYears?.map((e) => (e['year'] ?? '').toString()).toList() ?? [],
    );
  }
}
