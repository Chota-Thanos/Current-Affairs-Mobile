import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

import '../../current_affairs/presentation/article_detail_screen.dart';
import '../data/workspace_service.dart';
import '../models/workspace_models.dart';
import 'repository_detail_screen.dart';
import 'workspace_ai_helper_screen.dart';
import 'widgets/own_article_dialog.dart';
import 'widgets/bulk_import_dialog.dart';

class NotesSpaceDashboardScreen extends StatefulWidget {
  const NotesSpaceDashboardScreen({super.key});

  @override
  State<NotesSpaceDashboardScreen> createState() => _NotesSpaceDashboardScreenState();
}

class _NotesSpaceDashboardScreenState extends State<NotesSpaceDashboardScreen> {
  late WorkspaceService _service;
  bool _loading = true;
  String? _error;

  ReadingDashboard? _dashboard;
  List<StudentCollection> _collections = [];

  // Create repository folder form controllers
  final _createFormKey = GlobalKey<FormState>();
  final _repoNameController = TextEditingController();
  final _repoDescController = TextEditingController();
  final _repoTagsController = TextEditingController();
  bool _creatingRepo = false;
  bool _showCreateForm = false;

  // Add suggested article states
  int? _addingSuggestedId;
  String? _selectedSuggestRepoId;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = WorkspaceService(apiClient: apiClient);
    _loadAllWorkspaceData();
  }

  @override
  void dispose() {
    _repoNameController.dispose();
    _repoDescController.dispose();
    _repoTagsController.dispose();
    super.dispose();
  }

  Future<void> _loadAllWorkspaceData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dashboard = await _service.getReadingDashboard();
      final collections = await _service.getCollections();

      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _collections = collections;

        // Auto-select first repository as target suggested repository
        if (collections.isNotEmpty && _selectedSuggestRepoId == null) {
          _selectedSuggestRepoId = collections.first.id.toString();
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _createRepository() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() {
      _creatingRepo = true;
    });

    try {
      final name = _repoNameController.text.trim();
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      final tagsText = _repoTagsController.text.trim();
      final List<String> tags = tagsText.isNotEmpty
          ? tagsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : [];

      await _service.createCollection(
        name: name,
        slug: slug.isEmpty ? 'repository' : slug,
        description: _repoDescController.text.trim().isEmpty ? null : _repoDescController.text.trim(),
        customTags: tags,
      );

      _repoNameController.clear();
      _repoDescController.clear();
      _repoTagsController.clear();
      setState(() {
        _showCreateForm = false;
      });
      _loadAllWorkspaceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create repository: $e')),
      );
    } finally {
      setState(() {
        _creatingRepo = false;
      });
    }
  }

  Future<void> _addSuggestedArticle(StudentMasterArticle article) async {
    if (_selectedSuggestRepoId == null) return;
    setState(() {
      _addingSuggestedId = article.id;
    });

    try {
      final repoId = int.parse(_selectedSuggestRepoId!);
      await _service.saveArticle(article.id, collectionId: repoId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to repository!'), backgroundColor: AppColors.emerald),
      );
      _loadAllWorkspaceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add article: $e')),
      );
    } finally {
      setState(() {
        _addingSuggestedId = null;
      });
    }
  }

  String _formatReadingSeconds(int seconds) {
    if (seconds <= 0) return '0 min';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _dashboard == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF101E60))),
      );
    }

    if (_error != null && _dashboard == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadAllWorkspaceData, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      );
    }

    final dash = _dashboard!;
    final apiClient = Provider.of<ApiClient>(context);
    final username = apiClient.user?['username'] ?? 'Aspirant';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: const Color(0xFF101E60),
        onRefresh: _loadAllWorkspaceData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Notes Space Header
              _buildNotesSpaceHeader(username),
              const SizedBox(height: 20),

              // 2. Stats Grid
              _buildStatsGrid(dash),
              const SizedBox(height: 20),

              // 3. Reading Queues (Continue Reading + Due Revisions)
              if (dash.continueReading.isNotEmpty || dash.dueRevisionsQueue.isNotEmpty) ...[
                _buildReadingQueuesSection(dash),
                const SizedBox(height: 20),
              ],

              // 4. Repositories
              _buildRepositoriesSection(),
              const SizedBox(height: 20),

              // 5. Suggestions for your notes
              if (dash.recommendedArticles.isNotEmpty) ...[
                _buildRecommendationsPanel(dash),
                const SizedBox(height: 20),
              ],

              // 6. Bulk Import + Write Own Note (collapsible)
              _buildCollapsibleTools(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Builders ───────────────────────────────────────────────────────

  Widget _buildNotesSpaceHeader(String username) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101E60), Color(0xFF1B3A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101E60).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_rounded, color: Colors.white60, size: 14),
              const SizedBox(width: 6),
              Text(
                'NOTES SPACE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white60,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Organize current affairs\nlike a notes app',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Save articles into repositories, add personal notes and import in bulk.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: const Text('AI Notes Helper', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WorkspaceAiHelperScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF101E60),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: _loading
                    ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                label: const Text('Refresh', style: TextStyle(fontSize: 12, color: Colors.white)),
                onPressed: _loading ? null : _loadAllWorkspaceData,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ReadingDashboard dash) {
    final timeStr = _formatReadingSeconds(dash.readingSeconds7d);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard('Saved Notes', dash.savedArticles.toString(), Icons.bookmark_rounded, const Color(0xFF101E60)),
        _buildStatCard('Completed', dash.completedArticles.toString(), Icons.check_circle_rounded, AppColors.emerald),
        _buildStatCard('Due Revisions', dash.dueRevisions.toString(), Icons.history_rounded, AppColors.saffron),
        _buildStatCard('Read Time (7d)', timeStr, Icons.timer_rounded, AppColors.ink),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingQueuesSection(ReadingDashboard dash) {
    final continueItems = dash.continueReading.take(3).toList();
    final revisionItems = dash.dueRevisionsQueue.take(3).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (continueItems.isNotEmpty)
          Expanded(child: _buildQueuePanel('Continue Reading', Icons.play_circle_outline_rounded, const Color(0xFF101E60), continueItems)),
        if (continueItems.isNotEmpty && revisionItems.isNotEmpty)
          const SizedBox(width: 12),
        if (revisionItems.isNotEmpty)
          Expanded(child: _buildQueuePanel('Revision Due', Icons.schedule_rounded, AppColors.saffron, revisionItems)),
      ],
    );
  }

  Widget _buildQueuePanel(String title, IconData icon, Color color, List<StudentFork> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((fork) {
            final articleTitle = fork.forkedTitle ?? fork.masterArticle?.title ?? 'Saved Article';
            return GestureDetector(
              onTap: () {
                if (fork.masterArticle?.slug != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: fork.masterArticle!.slug)),
                  ).then((_) => _loadAllWorkspaceData());
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 32,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        articleTitle,
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRepositoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_shared_rounded, color: Color(0xFF101E60), size: 18),
            const SizedBox(width: 6),
            Text(
              'Repositories',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const Spacer(),
            TextButton.icon(
              icon: Icon(_showCreateForm ? Icons.close_rounded : Icons.add_rounded, size: 14),
              label: Text(
                _showCreateForm ? 'Close' : 'New Repository',
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () {
                setState(() {
                  _showCreateForm = !_showCreateForm;
                });
              },
            ),
          ],
        ),

        // Create Repository Form
        if (_showCreateForm) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Form(
              key: _createFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _repoNameController,
                    decoration: const InputDecoration(hintText: 'Repository name', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _repoDescController,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Description (optional)', contentPadding: EdgeInsets.all(10)),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _repoTagsController,
                    decoration: const InputDecoration(
                      hintText: 'Custom Tags (comma separated)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _creatingRepo ? null : _createRepository,
                    child: _creatingRepo
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('CREATE REPOSITORY'),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Folders list
        _collections.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.folder_open_rounded, size: 32, color: AppColors.muted),
                    const SizedBox(height: 8),
                    Text(
                      'Create repositories for syllabus topics, practice, or monthly notes.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _collections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final col = _collections[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RepositoryDetailScreen(collectionId: col.id)),
                      ).then((_) => _loadAllWorkspaceData());
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  col.name,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${col.itemCount} items${col.description != null ? ' • ${col.description}' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                                if (col.customTags.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: col.customTags.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF101E60).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(tag, style: const TextStyle(fontSize: 9, color: Color(0xFF101E60), fontWeight: FontWeight.bold)),
                                    )).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF101E60)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildRecommendationsPanel(ReadingDashboard dash) {
    final firstColId = _collections.isNotEmpty ? _collections.first.id.toString() : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_outlined, color: Color(0xFF101E60), size: 16),
              const SizedBox(width: 6),
              Text(
                'SUGGESTIONS FOR YOUR NOTES',
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF101E60)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a target repository and add recommended articles directly.',
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),

          // Repository select
          if (_collections.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _selectedSuggestRepoId ?? firstColId,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: _collections.map((c) => DropdownMenuItem(
                value: c.id.toString(),
                child: Text(c.name, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedSuggestRepoId = val;
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // Recommendations list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dash.recommendedArticles.take(3).length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rec = dash.recommendedArticles[index];
              final isAdding = _addingSuggestedId == rec.id;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.contentKind.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF101E60)),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: rec.slug)),
                              );
                            },
                            child: Text(
                              rec.title,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _collections.isEmpty || isAdding
                          ? null
                          : () => _addSuggestedArticle(rec),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isAdding
                          ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                          : const Text('ADD', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleTools() {
    return Column(
      children: [
        // Bulk import collapsible
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: ExpansionTile(
            title: Text(
              'Bulk import articles',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
            ),
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Filter and fork multiple institute articles into your repository folder in one action.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _collections.isEmpty
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (_) => BulkImportDialog(
                            collections: _collections,
                            onImportCompleted: _loadAllWorkspaceData,
                          ),
                        );
                      },
                child: const Text('LAUNCH BULK IMPORT'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Write own article collapsible
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: ExpansionTile(
            title: Text(
              'Write your own note',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
            ),
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Write and save custom syllabus summaries, facts, or revision cues directly inside your library.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _collections.isEmpty
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (_) => OwnArticleDialog(
                            collections: _collections,
                            onSaved: _loadAllWorkspaceData,
                          ),
                        );
                      },
                child: const Text('ADD NEW PERSONAL NOTE'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom tag list filters/checks
extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) {
    return where(test).toList();
  }
}
