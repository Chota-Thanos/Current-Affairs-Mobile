import '../../current_affairs/models/article_models.dart';

class StudentMasterArticle {
  final int id;
  final String contentKind;
  final String articleRole;
  final String title;
  final String slug;
  final String body;
  final CategoryNode? category;
  final String? sourceName;
  final String? sourceUrl;
  final String? publicationDate;
  final List<String> instituteTags;
  final List<ArticleSection> sections;
  final List<OutgoingRelation> outgoingRelations;
  final List<IncomingRelation> incomingRelations;
  final int appearanceCount;
  final List<ArticleUpdateEntry> updates;

  StudentMasterArticle({
    required this.id,
    required this.contentKind,
    this.articleRole = 'event',
    required this.title,
    required this.slug,
    required this.body,
    this.category,
    this.sourceName,
    this.sourceUrl,
    this.publicationDate,
    required this.instituteTags,
    this.sections = const [],
    this.outgoingRelations = const [],
    this.incomingRelations = const [],
    this.appearanceCount = 0,
    this.updates = const [],
  });

  factory StudentMasterArticle.fromJson(Map<String, dynamic> json) {
    return StudentMasterArticle(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      contentKind: json['content_kind'] ?? '',
      articleRole: json['article_role'] ?? 'event',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      body: json['body'] ?? '',
      category: json['category'] != null ? CategoryNode.fromJson(json['category'] as Map<String, dynamic>) : null,
      sourceName: json['source_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      publicationDate: json['publication_date'] as String?,
      instituteTags: (json['institute_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sections: (json['sections'] as List?)?.map((e) => ArticleSection.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      outgoingRelations: (json['outgoing_relations'] as List?)?.map((e) => OutgoingRelation.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      incomingRelations: (json['incoming_relations'] as List?)?.map((e) => IncomingRelation.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      appearanceCount: int.tryParse(json['appearance_count']?.toString() ?? '') ?? 0,
      updates: (json['updates'] as List?)?.map((e) => ArticleUpdateEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class TextAnchor {
  final String quote;
  final String prefix;
  final String suffix;
  final int start;

  TextAnchor({
    required this.quote,
    required this.prefix,
    required this.suffix,
    required this.start,
  });

  factory TextAnchor.fromJson(Map<String, dynamic> json) {
    return TextAnchor(
      quote: json['quote'] ?? '',
      prefix: json['prefix'] ?? '',
      suffix: json['suffix'] ?? '',
      start: int.tryParse(json['start']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'quote': quote,
        'prefix': prefix,
        'suffix': suffix,
        'start': start,
      };
}

class StudentHighlight {
  final int id;
  final int forkId;
  final TextAnchor anchor;
  final String color;
  final String? note;

  StudentHighlight({
    required this.id,
    required this.forkId,
    required this.anchor,
    required this.color,
    this.note,
  });

  factory StudentHighlight.fromJson(Map<String, dynamic> json) {
    return StudentHighlight(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      forkId: int.tryParse(json['fork_id']?.toString() ?? '') ?? 0,
      anchor: TextAnchor.fromJson((json['anchor_json'] as Map?)?.cast<String, dynamic>() ?? {}),
      color: json['color'] ?? 'yellow',
      note: json['note'] as String?,
    );
  }
}

class StudentNote {
  final int id;
  final int forkId;
  final TextAnchor anchor;
  final String note;

  StudentNote({
    required this.id,
    required this.forkId,
    required this.anchor,
    required this.note,
  });

  factory StudentNote.fromJson(Map<String, dynamic> json) {
    return StudentNote(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      forkId: int.tryParse(json['fork_id']?.toString() ?? '') ?? 0,
      anchor: TextAnchor.fromJson((json['anchor_json'] as Map?)?.cast<String, dynamic>() ?? {}),
      note: json['note'] ?? '',
    );
  }
}

class StudentFork {
  final int id;
  final int masterArticleId;
  final List<String> personalTags;
  final String? personalSummary;
  final String? forkedTitle;
  final String? forkedBody;
  final String? customFolder;
  final String readStatus; // unread, read, needs_revision
  final String? scheduledRevisionAt;
  final List<int> collectionIds;
  final List<String> collectionNames;
  final StudentMasterArticle? masterArticle;
  final int progressPercent;
  final int readingSeconds;
  final List<StudentHighlight> highlights;
  final List<StudentNote> notes;

  StudentFork({
    required this.id,
    required this.masterArticleId,
    required this.personalTags,
    this.personalSummary,
    this.forkedTitle,
    this.forkedBody,
    this.customFolder,
    required this.readStatus,
    this.scheduledRevisionAt,
    required this.collectionIds,
    required this.collectionNames,
    this.masterArticle,
    required this.progressPercent,
    required this.readingSeconds,
    this.highlights = const [],
    this.notes = const [],
  });

  factory StudentFork.fromJson(Map<String, dynamic> json) {
    final progress = json['reading_progress'] as Map<String, dynamic>?;
    final collectionIdsRaw = json['collection_ids'] as List?;
    final collectionNamesRaw = json['collection_names'] as List?;
    
    // Parse progress percentage safely
    int progVal = 0;
    if (progress != null && progress['progress_percent'] != null) {
      progVal = double.tryParse(progress['progress_percent'].toString())?.round() ?? 0;
    }

    // Parse reading seconds
    int readSecVal = 0;
    if (progress != null && progress['reading_seconds'] != null) {
      readSecVal = double.tryParse(progress['reading_seconds'].toString())?.round() ?? 0;
    }

    return StudentFork(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      masterArticleId: int.tryParse(json['master_article_id']?.toString() ?? '') ?? 0,
      personalTags: (json['personal_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      personalSummary: json['personal_summary'] as String?,
      forkedTitle: json['forked_title'] as String?,
      forkedBody: json['forked_body'] as String?,
      customFolder: json['custom_folder'] as String?,
      readStatus: json['read_status'] ?? 'unread',
      scheduledRevisionAt: json['scheduled_revision_at'] as String?,
      collectionIds: collectionIdsRaw?.map((e) => int.parse(e.toString())).toList() ?? [],
      collectionNames: collectionNamesRaw?.map((e) => e.toString()).toList() ?? [],
      masterArticle: json['master_article'] != null
          ? StudentMasterArticle.fromJson(json['master_article'] as Map<String, dynamic>)
          : null,
      progressPercent: progVal,
      readingSeconds: readSecVal,
      highlights: (json['highlights'] as List?)?.map((e) => StudentHighlight.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      notes: (json['notes'] as List?)?.map((e) => StudentNote.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class StudentArticle {
  final int id;
  final String title;
  final String slug;
  final String body;
  final int? categoryNodeId;
  final String? sourceUrl;
  final List<String> personalTags;
  final String status; // draft, published, archived
  final String createdAt;
  final String updatedAt;

  StudentArticle({
    required this.id,
    required this.title,
    required this.slug,
    required this.body,
    this.categoryNodeId,
    this.sourceUrl,
    required this.personalTags,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentArticle.fromJson(Map<String, dynamic> json) {
    return StudentArticle(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      body: json['body'] ?? '',
      categoryNodeId: json['category_node_id'] != null ? int.tryParse(json['category_node_id'].toString()) : null,
      sourceUrl: json['source_url'] as String?,
      personalTags: (json['personal_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status'] ?? 'draft',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class StudentCollection {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final List<String> customTags;
  final int itemCount;

  StudentCollection({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.customTags,
    required this.itemCount,
  });

  factory StudentCollection.fromJson(Map<String, dynamic> json) {
    return StudentCollection(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] as String?,
      customTags: (json['custom_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      itemCount: json['item_count'] ?? 0,
    );
  }
}

class StudentCollectionItem {
  final int id;
  final int? forkId;
  final int? studentArticleId;
  final int displayOrder;
  final StudentFork? fork;
  final StudentMasterArticle? masterArticle;
  final StudentArticle? studentArticle;

  StudentCollectionItem({
    required this.id,
    this.forkId,
    this.studentArticleId,
    required this.displayOrder,
    this.fork,
    this.masterArticle,
    this.studentArticle,
  });

  factory StudentCollectionItem.fromJson(Map<String, dynamic> json) {
    return StudentCollectionItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      forkId: json['fork_id'] != null ? int.tryParse(json['fork_id'].toString()) : null,
      studentArticleId: json['student_article_id'] != null ? int.tryParse(json['student_article_id'].toString()) : null,
      displayOrder: json['display_order'] ?? 0,
      fork: json['fork'] != null ? StudentFork.fromJson(json['fork'] as Map<String, dynamic>) : null,
      masterArticle: json['master_article'] != null ? StudentMasterArticle.fromJson(json['master_article'] as Map<String, dynamic>) : null,
      studentArticle: json['student_article'] != null ? StudentArticle.fromJson(json['student_article'] as Map<String, dynamic>) : null,
    );
  }
}

class StudentCollectionDetail {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final List<String> customTags;
  final List<StudentCollectionItem> items;

  StudentCollectionDetail({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.customTags,
    required this.items,
  });

  factory StudentCollectionDetail.fromJson(Map<String, dynamic> json) {
    return StudentCollectionDetail(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] as String?,
      customTags: (json['custom_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      items: (json['items'] as List?)?.map((e) => StudentCollectionItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class ReadingDashboard {
  final int savedArticles;
  final int completedArticles;
  final int dueRevisions;
  final int readingSeconds7d;
  final List<StudentFork> continueReading;
  final List<StudentFork> dueRevisionsQueue;
  final List<StudentFork> latestUnread;
  final List<StudentMasterArticle> recommendedArticles;

  ReadingDashboard({
    required this.savedArticles,
    required this.completedArticles,
    required this.dueRevisions,
    required this.readingSeconds7d,
    required this.continueReading,
    required this.dueRevisionsQueue,
    required this.latestUnread,
    required this.recommendedArticles,
  });

  factory ReadingDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    return ReadingDashboard(
      savedArticles: stats['saved_articles'] ?? 0,
      completedArticles: stats['completed_articles'] ?? 0,
      dueRevisions: stats['due_revisions'] ?? 0,
      readingSeconds7d: stats['reading_seconds_7d'] ?? 0,
      continueReading: (json['continue_reading'] as List?)?.map((e) => StudentFork.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      dueRevisionsQueue: (json['due_revisions'] as List?)?.map((e) => StudentFork.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      latestUnread: (json['latest_unread'] as List?)?.map((e) => StudentFork.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      recommendedArticles: (json['recommended_articles'] as List?)?.map((e) => StudentMasterArticle.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
