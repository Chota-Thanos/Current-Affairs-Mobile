import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:current_affairs_pro/features/current_affairs/data/article_service.dart';
import 'package:current_affairs_pro/features/current_affairs/models/article_models.dart' as camodels;
import '../../models/workspace_models.dart';
import '../../data/workspace_service.dart';

class BulkImportDialog extends StatefulWidget {
  final List<StudentCollection> collections;
  final VoidCallback onImportCompleted;

  const BulkImportDialog({
    super.key,
    required this.collections,
    required this.onImportCompleted,
  });

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  late ArticleService _articleService;
  late WorkspaceService _workspaceService;
  bool _loadingFilters = true;
  bool _searching = false;
  bool _importing = false;
  String? _message;

  // Selected Repository
  String? _selectedCollectionId;

  // Filters state
  String _selectedHubPath = "daily-news";
  String _selectedHubKind = "daily_current_affairs";
  String _selectedHubFamily = "prelims";
  String _selectedHubFilterMode = "month";

  camodels.ArticleFilters? _filters;
  String? _selectedGsPaperId;
  String? _selectedSubjectId;
  String? _selectedTopicId;
  String? _selectedSubtopicId;
  String? _selectedMonth;
  String? _selectedYear;

  // Search Results
  List<camodels.ArticleSummary> _articlesList = [];
  final Set<int> _selectedIds = {};

  final List<Map<String, String>> _hubs = [
    {'path': 'daily-news', 'shortLabel': 'Daily News', 'kind': 'daily_current_affairs', 'family': 'prelims', 'filterMode': 'month'},
    {'path': 'editorial-summary', 'shortLabel': 'Editorials', 'kind': 'daily_editorial_summary', 'family': 'mains', 'filterMode': 'month'},
    {'path': 'mains-topic-notes', 'shortLabel': 'Mains Notes', 'kind': 'mains_topic_note', 'family': 'mains', 'filterMode': 'month'},
    {'path': 'prelims-pyq', 'shortLabel': 'Prelims PYQ', 'kind': 'prelims_pyq', 'family': 'prelims', 'filterMode': 'year'},
    {'path': 'mains-pyq', 'shortLabel': 'Mains PYQ', 'kind': 'mains_pyq', 'family': 'mains', 'filterMode': 'year'},
  ];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _articleService = ArticleService(apiClient: apiClient);
    _workspaceService = WorkspaceService(apiClient: apiClient);

    if (widget.collections.isNotEmpty) {
      _selectedCollectionId = widget.collections.first.id.toString();
    }
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loadingFilters = true;
      _message = null;
    });

    try {
      final filters = await _articleService.getFilters(_selectedHubKind, _selectedHubFamily);
      setState(() {
        _filters = filters;
        _selectedGsPaperId = null;
        _selectedSubjectId = null;
        _selectedTopicId = null;
        _selectedSubtopicId = null;
        _selectedMonth = null;
        _selectedYear = null;
        _loadingFilters = false;
      });
    } catch (e) {
      setState(() {
        _message = "Failed to load filters: $e";
        _loadingFilters = false;
      });
    }
  }

  Future<void> _searchArticles() async {
    setState(() {
      _searching = true;
      _message = null;
      _articlesList = [];
      _selectedIds.clear();
    });

    try {
      final categoryId = _selectedSubtopicId ?? _selectedTopicId ?? _selectedSubjectId;
      final response = await _articleService.getArticles(
        contentKind: _selectedHubKind,
        category: categoryId,
        month: _selectedHubFilterMode == "month" ? _selectedMonth : null,
        year: _selectedHubFilterMode == "year" ? _selectedYear : null,
        page: 1,
        limit: 30, // show up to 30 bulk results
      );

      final items = response['items'] as List<camodels.ArticleSummary>;
      setState(() {
        _articlesList = items;
        _searching = false;
        if (items.isEmpty) {
          _message = "No articles found matching filters.";
        }
      });
    } catch (e) {
      setState(() {
        _message = "Search failed: $e";
        _searching = false;
      });
    }
  }

  Future<void> _importSelected() async {
    if (_selectedCollectionId == null || _selectedIds.isEmpty) return;
    setState(() {
      _importing = true;
      _message = null;
    });

    try {
      final repoId = int.parse(_selectedCollectionId!);
      int count = 0;
      for (final id in _selectedIds) {
        await _workspaceService.saveArticle(id, collectionId: repoId);
        count++;
      }
      
      widget.onImportCompleted();
      setState(() {
        _message = "Successfully imported $count articles!";
        _selectedIds.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported $count articles successfully!"), backgroundColor: AppColors.emerald),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        _message = "Import failed: $e";
      });
    } finally {
      setState(() {
        _importing = false;
      });
    }
  }

  void _toggleSelectAll() {
    if (_selectedIds.length == _articlesList.length) {
      setState(() {
        _selectedIds.clear();
      });
    } else {
      setState(() {
        _selectedIds.addAll(_articlesList.map((a) => a.id));
      });
    }
  }

  String _formatMonthLabel(String val) {
    if (val.isEmpty || !val.contains('-')) return val;
    try {
      final parts = val.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      final monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      return "${monthNames[date.month - 1]} ${date.year}";
    } catch (_) {
      return val;
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyCategories = _filters?.categories ?? [];
    final gsPapers = familyCategories.where((c) => c.nodeType == "gs_paper").toList();
    final allSubjects = familyCategories.where((c) => c.nodeType == "subject").toList();
    final subjects = _selectedGsPaperId == null
        ? allSubjects
        : allSubjects.where((c) => c.parentId?.toString() == _selectedGsPaperId).toList();
    final topics = familyCategories.where((c) => c.nodeType == "topic" && c.parentId?.toString() == _selectedSubjectId).toList();
    final subtopics = familyCategories.where((c) => c.nodeType == "subtopic" && c.parentId?.toString() == _selectedTopicId).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text("Bulk Import Articles", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Query institute database and fork selected articles in one bulk step.",
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              
              // Target Collection selector
              if (widget.collections.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: _selectedCollectionId,
                  decoration: const InputDecoration(labelText: "Target Repository Folder", contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  items: widget.collections.map((c) => DropdownMenuItem(
                    value: c.id.toString(),
                    child: Text(c.name, style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCollectionId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Hub selector
              DropdownButtonFormField<String>(
                value: _selectedHubPath,
                decoration: const InputDecoration(labelText: "Hub Category", contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                items: _hubs.map((h) => DropdownMenuItem(
                  value: h['path'],
                  child: Text(h['shortLabel']!, style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (val) {
                  final matched = _hubs.firstWhere((h) => h['path'] == val);
                  setState(() {
                    _selectedHubPath = val!;
                    _selectedHubKind = matched['kind']!;
                    _selectedHubFamily = matched['family']!;
                    _selectedHubFilterMode = matched['filterMode']!;
                  });
                  _loadFilters();
                },
              ),
              const SizedBox(height: 12),

              if (_loadingFilters)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              else ...[
                if (gsPapers.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    value: _selectedGsPaperId,
                    hint: const Text("GS Paper", style: TextStyle(fontSize: 11.5)),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All GS Papers", style: TextStyle(fontSize: 11.5))),
                      ...gsPapers.map((g) => DropdownMenuItem(value: g.id.toString(), child: Text(g.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedGsPaperId = val;
                        _selectedSubjectId = null;
                        _selectedTopicId = null;
                        _selectedSubtopicId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // Subject dropdown filter
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedSubjectId,
                        hint: const Text("Subject", style: TextStyle(fontSize: 11.5)),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                        items: [
                          const DropdownMenuItem(value: null, child: Text("All Subjects", style: TextStyle(fontSize: 11.5))),
                          ...subjects.map((s) => DropdownMenuItem(value: s.id.toString(), child: Text(s.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedSubjectId = val;
                            _selectedTopicId = null;
                            _selectedSubtopicId = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Date dropdown filter
                    if (_selectedHubFilterMode == "month")
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedMonth,
                          hint: const Text("Month", style: TextStyle(fontSize: 11.5)),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text("All Months", style: TextStyle(fontSize: 11.5))),
                            ...(_filters?.months ?? []).map((m) => DropdownMenuItem(value: m, child: Text(_formatMonthLabel(m), style: const TextStyle(fontSize: 11.5)))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedMonth = val;
                            });
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedYear,
                          hint: const Text("Year", style: TextStyle(fontSize: 11.5)),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text("All Years", style: TextStyle(fontSize: 11.5))),
                            ...(_filters?.years ?? []).map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 11.5)))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedYear = val;
                            });
                          },
                        ),
                      ),
                  ],
                ),

                if (_selectedSubjectId != null && topics.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedTopicId,
                          hint: const Text("Topic", style: TextStyle(fontSize: 11.5)),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text("All Topics", style: TextStyle(fontSize: 11.5))),
                            ...topics.map((t) => DropdownMenuItem(value: t.id.toString(), child: Text(t.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedTopicId = val;
                              _selectedSubtopicId = null;
                            });
                          },
                        ),
                      ),
                      if (_selectedTopicId != null && subtopics.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _selectedSubtopicId,
                            hint: const Text("Subtopic", style: TextStyle(fontSize: 11.5)),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                            items: [
                              const DropdownMenuItem(value: null, child: Text("All Subtopics", style: TextStyle(fontSize: 11.5))),
                              ...subtopics.map((st) => DropdownMenuItem(value: st.id.toString(), child: Text(st.name, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedSubtopicId = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 14),

              // Search Trigger
              ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text("SEARCH DATABASE"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _loadingFilters || _searching ? null : _searchArticles,
              ),
              const SizedBox(height: 12),

              // Results box
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: CircularProgressIndicator(color: AppColors.civic)),
                )
              else if (_articlesList.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      "Select Articles (${_selectedIds.length}/${_articlesList.length})",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.ink),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _toggleSelectAll,
                      child: Text(_selectedIds.length == _articlesList.length ? "DESELECT ALL" : "SELECT ALL", style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _articlesList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final art = _articlesList[idx];
                      final isSelected = _selectedIds.contains(art.id);
                      return CheckboxListTile(
                        value: isSelected,
                        dense: true,
                        title: Text(art.title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${art.contentKind.replaceAll('_', ' ').toUpperCase()} • ${art.category?.name ?? ''}",
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(art.id);
                            } else {
                              _selectedIds.remove(art.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],

              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _message!.startsWith("Succ") ? AppColors.emerald : AppColors.berry,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text("CLOSE"),
        ),
        if (_articlesList.isNotEmpty)
          ElevatedButton(
            onPressed: _importing || _selectedIds.isEmpty ? null : _importSelected,
            child: _importing
                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                : const Text("IMPORT SELECTED"),
          ),
      ],
    );
  }
}
