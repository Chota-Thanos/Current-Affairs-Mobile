import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../workspace/data/workspace_service.dart';
import '../../workspace/models/workspace_models.dart';
import '../data/article_service.dart';
import '../models/article_models.dart';
import 'article_detail_screen.dart';
import '../../workspace/presentation/notes_space_dashboard_screen.dart';

class DailyNewsFeedScreen extends StatefulWidget {
  final int initialTab;
  final int initialPrelimsSubTab;
  final int initialMainsSubTab;
  final String? initialCategoryName;

  const DailyNewsFeedScreen({
    super.key,
    required this.initialTab,
    this.initialPrelimsSubTab = 0,
    this.initialMainsSubTab = 0,
    this.initialCategoryName,
  });

  @override
  State<DailyNewsFeedScreen> createState() => DailyNewsFeedScreenState();
}

class DailyNewsFeedScreenState extends State<DailyNewsFeedScreen> {
  late ArticleService _service;
  late WorkspaceService _workspaceService;
  bool _loading = true;
  String? _error;

  void applyExternalFilters({
    String? subjectName,
    int? mainTab,
    int? prelimsSubTab,
    int? mainsSubTab,
  }) {
    setState(() {
      if (mainTab != null) _selectedMainTab = mainTab;
      if (prelimsSubTab != null) _selectedPrelimsSubTab = prelimsSubTab;
      if (mainsSubTab != null) _selectedMainsSubTab = mainsSubTab;
      _pendingSubjectName = subjectName;
      _currentPage = 1;
    });
    _updateHubFromTabs();
  }

  // Selected Hub
  String _selectedHubKind = "daily_current_affairs";
  String _selectedHubFamily = "prelims";
  String _selectedHubFilterMode = "month"; // month vs year
  String _selectedHubRole = "event"; // event vs concept

  // Main Tabs State
  int _selectedMainTab = 0; // 0: Prelims, 1: Mains
  int _selectedPrelimsSubTab = 0; // 0: Daily News, 1: Prelims PYQs, 2: Concepts
  int _selectedMainsSubTab = 0; // 0: Summaries, 1: Mains Notes, 2: Mains PYQs

  // Filters
  ArticleFilters? _filters;
  String? _pendingSubjectName;
  String? _selectedGsPaperId;
  String? _selectedSubjectId;
  String? _selectedTopicId;
  String? _selectedSubtopicId;
  String? _selectedMonth;
  String? _selectedYear;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Data
  List<ArticleSummary> _articles = [];
  List<StudentCollection> _collections = [];
  int _currentPage = 1;
  int _totalPages = 1;

  final List<Map<String, String>> _hubs = [
    {
      'path': 'daily-news',
      'label': 'Prelims Current Affairs',
      'shortLabel': 'Daily News',
      'kind': 'daily_current_affairs',
      'family': 'prelims',
      'filterMode': 'month',
      'icon': '📰',
    },
    {
      'path': 'editorial-summary',
      'label': 'Editorial Summary',
      'shortLabel': 'Editorials',
      'kind': 'daily_editorial_summary',
      'family': 'mains',
      'filterMode': 'month',
      'icon': '📝',
    },
    {
      'path': 'mains-topic-notes',
      'label': 'Mains Topic Notes',
      'shortLabel': 'Mains Notes',
      'kind': 'mains_topic_note',
      'family': 'mains',
      'filterMode': 'month',
      'icon': '💡',
    },
    {
      'path': 'prelims-pyq',
      'label': 'Prelims PYQ',
      'shortLabel': 'Prelims PYQ',
      'kind': 'prelims_pyq',
      'family': 'prelims',
      'filterMode': 'year',
      'icon': '⚡',
    },
    {
      'path': 'concepts',
      'label': 'Prelims Concepts',
      'shortLabel': 'Concepts',
      'kind': 'daily_current_affairs',
      'family': 'prelims',
      'filterMode': 'month',
      'role': 'concept',
      'icon': '🧩',
    },
    {
      'path': 'mains-pyq',
      'label': 'Mains PYQ',
      'shortLabel': 'Mains PYQ',
      'kind': 'mains_pyq',
      'family': 'mains',
      'filterMode': 'year',
      'icon': '✍️',
    },
  ];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = ArticleService(apiClient: apiClient);
    _workspaceService = WorkspaceService(apiClient: apiClient);
    _selectedMainTab = widget.initialTab;
    _selectedPrelimsSubTab = widget.initialPrelimsSubTab;
    _selectedMainsSubTab = widget.initialMainsSubTab;
    _pendingSubjectName = widget.initialCategoryName;
    _updateHubFromTabs();
    _loadCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    try {
      final cols = await _workspaceService.getCollections();
      setState(() {
        _collections = cols;
      });
    } catch (_) {}
  }

  Future<void> _loadFiltersAndArticles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Fetch filters
      final filters = await _service.getFilters(_selectedHubKind, _selectedHubFamily);

      // Resolve a category requested from outside this screen (e.g. the home page or
      // the category browser) by name against this family's freshly loaded categories,
      // since prelims and mains have entirely separate category trees with different ids.
      if (_pendingSubjectName != null) {
        final wanted = _pendingSubjectName!.toLowerCase();
        final subjectMatch = filters.categories.where((c) => c.nodeType == "subject" && c.name.toLowerCase() == wanted);
        final gsPaperMatch = filters.categories.where((c) => c.nodeType == "gs_paper" && c.name.toLowerCase() == wanted);
        if (subjectMatch.isNotEmpty) {
          final subject = subjectMatch.first;
          _selectedSubjectId = subject.id.toString();
          final parentPaper = filters.categories.where((c) => c.nodeType == "gs_paper" && c.id == subject.parentId);
          if (parentPaper.isNotEmpty) _selectedGsPaperId = parentPaper.first.id.toString();
        } else if (gsPaperMatch.isNotEmpty) {
          _selectedGsPaperId = gsPaperMatch.first.id.toString();
        }
        _pendingSubjectName = null;
      }

      // 2. Fetch articles
      final categoryId = _selectedSubtopicId ?? _selectedTopicId ?? _selectedSubjectId;
      final response = await _service.getArticles(
        contentKind: _selectedHubKind,
        articleRole: _selectedHubRole,
        category: categoryId,
        month: _selectedHubFilterMode == "month" ? _selectedMonth : null,
        year: _selectedHubFilterMode == "year" ? _selectedYear : null,
        page: _currentPage,
      );

      setState(() {
        _filters = filters;
        _articles = response['items'] as List<ArticleSummary>;
        _currentPage = response['page'] as int;
        _totalPages = response['totalPages'] as int;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadOnlyArticles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categoryId = _selectedSubtopicId ?? _selectedTopicId ?? _selectedSubjectId;
      final response = await _service.getArticles(
        contentKind: _selectedHubKind,
        articleRole: _selectedHubRole,
        category: categoryId,
        month: _selectedHubFilterMode == "month" ? _selectedMonth : null,
        year: _selectedHubFilterMode == "year" ? _selectedYear : null,
        page: _currentPage,
      );

      setState(() {
        _articles = response['items'] as List<ArticleSummary>;
        _currentPage = response['page'] as int;
        _totalPages = response['totalPages'] as int;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _selectMainTab(int index) {
    if (_selectedMainTab == index) return;
    setState(() {
      _selectedMainTab = index;
    });
    _updateHubFromTabs();
  }

  void _updateHubFromTabs() {
    Map<String, String> hub;
    if (_selectedMainTab == 0) {
      if (_selectedPrelimsSubTab == 0) {
        hub = _hubs.firstWhere((h) => h['path'] == 'daily-news');
      } else if (_selectedPrelimsSubTab == 1) {
        hub = _hubs.firstWhere((h) => h['path'] == 'prelims-pyq');
      } else {
        hub = _hubs.firstWhere((h) => h['path'] == 'concepts');
      }
    } else {
      if (_selectedMainsSubTab == 0) {
        hub = _hubs.firstWhere((h) => h['path'] == 'editorial-summary');
      } else if (_selectedMainsSubTab == 1) {
        hub = _hubs.firstWhere((h) => h['path'] == 'mains-topic-notes');
      } else {
        hub = _hubs.firstWhere((h) => h['path'] == 'mains-pyq');
      }
    }

    setState(() {
      _selectedHubKind = hub['kind']!;
      _selectedHubFamily = hub['family']!;
      _selectedHubFilterMode = hub['filterMode']!;
      _selectedHubRole = hub['role'] ?? 'event';

      // Reset filters
      _selectedGsPaperId = null;
      _selectedSubjectId = null;
      _selectedTopicId = null;
      _selectedSubtopicId = null;
      _selectedMonth = null;
      _selectedYear = null;
      _currentPage = 1;
    });
    _loadFiltersAndArticles();
  }

  IconData _getSubjectIcon(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains("polity") || nameLower.contains("constitution")) {
      return Icons.account_balance_rounded;
    } else if (nameLower.contains("economy")) {
      return Icons.trending_up_rounded;
    } else if (nameLower.contains("history") || nameLower.contains("culture")) {
      return Icons.museum_rounded;
    } else if (nameLower.contains("geography")) {
      return Icons.public_rounded;
    } else if (nameLower.contains("environment") || nameLower.contains("ecology")) {
      return Icons.eco_rounded;
    } else if (nameLower.contains("science") || nameLower.contains("technology") || nameLower.contains("s&t")) {
      return Icons.science_rounded;
    } else if (nameLower.contains("international") || nameLower.contains("relations")) {
      return Icons.language_rounded;
    } else if (nameLower.contains("security") || nameLower.contains("internal")) {
      return Icons.shield_rounded;
    } else if (nameLower.contains("disaster")) {
      return Icons.tsunami_rounded;
    } else if (nameLower.contains("ethics")) {
      return Icons.psychology_rounded;
    }
    return Icons.menu_book_rounded;
  }

  Color _getSubjectColor(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains("polity")) {
      return const Color(0xFF1E3A8A); // Blue
    } else if (nameLower.contains("economy")) {
      return const Color(0xFFC2410C); // Orange-red
    } else if (nameLower.contains("history")) {
      return const Color(0xFF9D174D); // Pink/Red
    } else if (nameLower.contains("geography")) {
      return const Color(0xFF0F766E); // Teal
    } else if (nameLower.contains("environment")) {
      return const Color(0xFF15803D); // Green
    } else if (nameLower.contains("science") || nameLower.contains("technology")) {
      return const Color(0xFF6B21A8); // Purple
    } else if (nameLower.contains("international")) {
      return const Color(0xFF0369A1); // Light Blue
    }
    return const Color(0xFF475569); // Slate
  }

  Future<void> _openCreateRepository() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotesSpaceDashboardScreen(autoOpenCreateForm: true)),
    );
    if (mounted) _loadCollections();
  }

  void _showSaveToRepoDialog(int articleId) {
    if (_collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("You don't have a repository yet."),
          action: SnackBarAction(
            label: "CREATE ONE",
            onPressed: () => _openCreateRepository(),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        String selectedRepoId = _collections.first.id.toString();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Add to Notes", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Select a repository to save this article:"),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRepoId,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: _collections.map((c) => DropdownMenuItem(
                      value: c.id.toString(),
                      child: Text(c.name),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedRepoId = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final repoId = int.parse(selectedRepoId);
                      await _workspaceService.saveArticle(articleId, collectionId: repoId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Saved successfully!"), backgroundColor: AppColors.emerald),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to save: $e")),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyCategories = _filters?.categories ?? [];
    final gsPapers = familyCategories.where((c) => c.nodeType == "gs_paper").toList();
    final allSubjects = familyCategories.where((c) => c.nodeType == "subject").toList();
    final subjects = _selectedGsPaperId == null
        ? allSubjects
        : allSubjects.where((c) => c.parentId.toString() == _selectedGsPaperId).toList();
    final allTopics = familyCategories.where((c) => c.nodeType == "topic").toList();
    final topics = _selectedSubjectId == null
        ? <CategoryNode>[]
        : allTopics.where((c) => c.parentId.toString() == _selectedSubjectId).toList();
    final allSubtopics = familyCategories.where((c) => c.nodeType == "subtopic").toList();
    final subtopics = _selectedTopicId == null
        ? <CategoryNode>[]
        : allSubtopics.where((c) => c.parentId.toString() == _selectedTopicId).toList();

    // Filter articles locally based on search query
    final filteredArticles = _articles.where((article) {
      if (_searchQuery.isEmpty) return true;
      return article.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             article.body.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.brandNavy,
        onRefresh: _loadFiltersAndArticles,
        child: CustomScrollView(
          slivers: [
            // 1. Search Bar at the Top
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search topics, articles, or notes...",
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    fillColor: AppColors.paper,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.brandNavy, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox.shrink()),

            // 4b. GS Paper Pills Container (mains only)
            if (gsPapers.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gsPapers.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedGsPaperId == null;
                          return ChoiceChip(
                            label: const Text("All Papers"),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE11D48),
                            backgroundColor: AppColors.paper,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                            side: BorderSide.none,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedGsPaperId = null;
                                  _selectedSubjectId = null;
                                  _selectedTopicId = null;
                                  _selectedSubtopicId = null;
                                  _currentPage = 1;
                                });
                                _loadOnlyArticles();
                              }
                            },
                          );
                        }

                        final paper = gsPapers[index - 1];
                        final isSelected = _selectedGsPaperId == paper.id.toString();
                        return ChoiceChip(
                          label: Text(paper.name),
                          selected: isSelected,
                          selectedColor: const Color(0xFFE11D48),
                          backgroundColor: AppColors.paper,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                          side: BorderSide.none,
                          onSelected: (val) {
                            setState(() {
                              _selectedGsPaperId = val ? paper.id.toString() : null;
                              _selectedSubjectId = null;
                              _selectedTopicId = null;
                              _selectedSubtopicId = null;
                              _currentPage = 1;
                            });
                            _loadOnlyArticles();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

            // 5. Subject Pills Container
            if (subjects.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: subjects.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedSubjectId == null;
                          return ChoiceChip(
                            avatar: Icon(Icons.apps_rounded, size: 14, color: isSelected ? Colors.white : AppColors.muted),
                            label: const Text("All"),
                            selected: isSelected,
                            selectedColor: AppColors.brandNavy,
                            backgroundColor: AppColors.paper,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                            side: BorderSide.none,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedSubjectId = null;
                                  _selectedTopicId = null;
                                  _selectedSubtopicId = null;
                                  _currentPage = 1;
                                });
                                _loadOnlyArticles();
                              }
                            },
                          );
                        }

                        final subject = subjects[index - 1];
                        final isSelected = _selectedSubjectId == subject.id.toString();
                        final subjColor = _getSubjectColor(subject.name);

                        return ChoiceChip(
                          avatar: Icon(
                            _getSubjectIcon(subject.name),
                            size: 14,
                            color: isSelected ? Colors.white : subjColor,
                          ),
                          label: Text(subject.name),
                          selected: isSelected,
                          selectedColor: subjColor,
                          backgroundColor: AppColors.paper,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                          side: BorderSide.none,
                          onSelected: (val) {
                            setState(() {
                              _selectedSubjectId = val ? subject.id.toString() : null;
                              _selectedTopicId = null;
                              _selectedSubtopicId = null;
                              _currentPage = 1;
                            });
                            _loadOnlyArticles();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

            // 5b. Topic Pills Container
            if (topics.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topics.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedTopicId == null;
                          return ChoiceChip(
                            label: const Text("All Topics"),
                            selected: isSelected,
                            selectedColor: AppColors.brandNavy,
                            backgroundColor: AppColors.paper,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                            side: BorderSide.none,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedTopicId = null;
                                  _selectedSubtopicId = null;
                                  _currentPage = 1;
                                });
                                _loadOnlyArticles();
                              }
                            },
                          );
                        }

                        final topic = topics[index - 1];
                        final isSelected = _selectedTopicId == topic.id.toString();
                        return ChoiceChip(
                          label: Text(topic.name),
                          selected: isSelected,
                          selectedColor: AppColors.brandNavy,
                          backgroundColor: AppColors.paper,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                          side: BorderSide.none,
                          onSelected: (val) {
                            setState(() {
                              _selectedTopicId = val ? topic.id.toString() : null;
                              _selectedSubtopicId = null;
                              _currentPage = 1;
                            });
                            _loadOnlyArticles();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

            // 5c. Subtopic Pills Container
            if (subtopics.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: subtopics.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedSubtopicId == null;
                          return ChoiceChip(
                            label: const Text("All Subtopics"),
                            selected: isSelected,
                            selectedColor: AppColors.brandNavy,
                            backgroundColor: AppColors.paper,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                            side: BorderSide.none,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedSubtopicId = null;
                                  _currentPage = 1;
                                });
                                _loadOnlyArticles();
                              }
                            },
                          );
                        }

                        final subtopic = subtopics[index - 1];
                        final isSelected = _selectedSubtopicId == subtopic.id.toString();
                        return ChoiceChip(
                          label: Text(subtopic.name),
                          selected: isSelected,
                          selectedColor: AppColors.brandNavy,
                          backgroundColor: AppColors.paper,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                          side: BorderSide.none,
                          onSelected: (val) {
                            setState(() {
                              _selectedSubtopicId = val ? subtopic.id.toString() : null;
                              _currentPage = 1;
                            });
                            _loadOnlyArticles();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

            // 3. Sub-toggles
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Row(
                  children: [
                    if (_selectedMainTab == 0) ...[
                      ChoiceChip(
                        label: const Text("Daily News"),
                        selected: _selectedPrelimsSubTab == 0,
                        selectedColor: AppColors.brandNavy.withValues(alpha: 0.08),
                        backgroundColor: AppColors.surface,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _selectedPrelimsSubTab == 0 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedPrelimsSubTab == 0 ? AppColors.brandNavy : AppColors.muted,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedPrelimsSubTab = 0);
                            _updateHubFromTabs();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Prelims PYQ"),
                        selected: _selectedPrelimsSubTab == 1,
                        selectedColor: AppColors.brandNavy.withValues(alpha: 0.08),
                        backgroundColor: AppColors.surface,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _selectedPrelimsSubTab == 1 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedPrelimsSubTab == 1 ? AppColors.brandNavy : AppColors.muted,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedPrelimsSubTab = 1);
                            _updateHubFromTabs();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Concepts"),
                        selected: _selectedPrelimsSubTab == 2,
                        selectedColor: AppColors.brandNavy.withValues(alpha: 0.08),
                        backgroundColor: AppColors.surface,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _selectedPrelimsSubTab == 2 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedPrelimsSubTab == 2 ? AppColors.brandNavy : AppColors.muted,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedPrelimsSubTab = 2);
                            _updateHubFromTabs();
                          }
                        },
                      ),
                    ] else if (_selectedMainTab == 1) ...[
                      ChoiceChip(
                        label: const Text("Summaries"),
                        selected: _selectedMainsSubTab == 0,
                        selectedColor: AppColors.brandNavy.withValues(alpha: 0.08),
                        backgroundColor: AppColors.surface,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _selectedMainsSubTab == 0 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedMainsSubTab == 0 ? AppColors.brandNavy : AppColors.muted,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedMainsSubTab = 0);
                            _updateHubFromTabs();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Mains Notes"),
                        selected: _selectedMainsSubTab == 1,
                        selectedColor: AppColors.brandNavy.withValues(alpha: 0.08),
                        backgroundColor: AppColors.surface,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _selectedMainsSubTab == 1 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedMainsSubTab == 1 ? AppColors.brandNavy : AppColors.muted,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedMainsSubTab = 1);
                            _updateHubFromTabs();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Mains PYQ"),
                        selected: _selectedMainsSubTab == 2,
                        selectedColor: AppColors.brandNavy.withValues(alpha: 0.08),
                        backgroundColor: AppColors.surface,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: _selectedMainsSubTab == 2 ? FontWeight.bold : FontWeight.normal,
                          color: _selectedMainsSubTab == 2 ? AppColors.brandNavy : AppColors.muted,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedMainsSubTab = 2);
                            _updateHubFromTabs();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 6. Total Count Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      "Showing ${filteredArticles.length} articles",
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted),
                    ),
                    const Spacer(),
                    if (_totalPages > 1)
                      Text(
                        "Page $_currentPage of $_totalPages",
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
            ),

            // 7. Feed list
            _loading && filteredArticles.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: AppColors.brandNavy),
                      ),
                    ),
                  )
                : _error != null
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildErrorWidget(),
                      )
                    : filteredArticles.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyWidget(),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index == filteredArticles.length) {
                                    return _buildLoadMoreButton();
                                  }
                                  final article = filteredArticles[index];
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: index == filteredArticles.length - 1 ? 0 : 14.0),
                                    child: _buildRedesignedCard(article),
                                  );
                                },
                                childCount: filteredArticles.length + (_totalPages > _currentPage ? 1 : 0),
                              ),
                            ),
                          ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTabButton(int index, String label) {
    final isSelected = _selectedMainTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectMainTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.brandNavy : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRedesignedCard(ArticleSummary article) {
    final hasThumbnail = article.primaryAsset != null;
    final catName = article.category?.name ?? _selectedHubFamily;
    final subjColor = _getSubjectColor(catName);

    // Simple reading time estimator (1 minute per 150 words)
    final wordsCount = article.body.split(RegExp(r'\s+')).length;
    final readTime = (wordsCount / 150).ceil().clamp(2, 12);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.line), // thin border
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(slug: article.slug),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasThumbnail)
              Image.network(
                article.primaryAsset!.fileUrl,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 140, color: AppColors.paper),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic Badge & Bookmark Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: subjColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          catName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: subjColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.bookmark_outline_rounded, color: AppColors.muted, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showSaveToRepoDialog(article.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    article.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Snippet/Body
                  Text(
                    article.body.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),

                  // Metadata bottom row
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        article.publicationDate != null 
                            ? "${_formatDate(article.publicationDate!)} • $readTime min read"
                            : "$readTime min read",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Add to Notes Button
                      TextButton.icon(
                        icon: Icon(Icons.note_add_outlined, size: 14, color: AppColors.brandNavy),
                        label: Text(
                          "Add to Notes",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandNavy,
                          ),
                        ),
                        onPressed: () => _showSaveToRepoDialog(article.id),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: AppColors.brandNavy.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);
      final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}";
    } catch (_) {
      return value;
    }
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed_outlined, color: AppColors.muted, size: 44),
          const SizedBox(height: 12),
          Text(
            "No articles found.",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AppColors.berry, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFiltersAndArticles,
              child: const Text("RETRY"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentPage++;
          });
          _loadOnlyArticles();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.brandNavy,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.brandNavy.withValues(alpha: 0.15)),
          ),
        ),
        child: const Text("LOAD MORE ARTICLES"),
      ),
    );
  }
}
