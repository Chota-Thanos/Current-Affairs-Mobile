import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/export_pdf.dart';
import '../../../../core/utils/html_to_markdown.dart';
import '../../../../core/utils/text_anchor.dart';
import '../../current_affairs/presentation/article_detail_screen.dart';
import '../data/workspace_service.dart';
import '../models/workspace_models.dart';
import 'fork_reader_screen.dart';
import 'widgets/own_article_dialog.dart';
import 'widgets/bulk_import_dialog.dart';
import 'widgets/flashcard_card_widget.dart';

class RepositoryDetailScreen extends StatefulWidget {
  final int collectionId;
  const RepositoryDetailScreen({super.key, required this.collectionId});

  @override
  State<RepositoryDetailScreen> createState() => _RepositoryDetailScreenState();
}

class _RepositoryDetailScreenState extends State<RepositoryDetailScreen> {
  late WorkspaceService _service;
  bool _loading = true;
  String? _error;

  StudentCollectionDetail? _repository;
  
  // Tag / Filter states
  String _selectedTagFilter = "all";
  bool _revisionOnly = false;
  bool _pinnedOnly = false;
  String _searchQuery = "";

  // Collapsible and responsive header state
  bool _isHeaderExpanded = false;
  late ScrollController _scrollController;

  // Flashcards state
  bool _flashcardsActive = false;
  int _activeFlashcardIndex = 0;

  // PDF export state
  int? _downloadingItemId;
  bool _downloadingAll = false;

  // Edit notes states
  final Map<int, bool> _editingNotes = {}; // Key: itemId, Value: isEditing
  final Map<int, TextEditingController> _noteControllers = {};

  // Edit copy states
  final Map<int, bool> _editingCopies = {}; // Key: itemId, Value: isEditing
  final Map<int, TextEditingController> _titleControllers = {};
  final Map<int, TextEditingController> _bodyControllers = {};

  // Body expansion states
  final Map<int, bool> _expandedBodies = {}; // Key: itemId, Value: isExpanded

  // Repository-level tag definitions editing states
  bool _editingRepositoryTags = false;
  final _repositoryTagsController = TextEditingController();
  bool _savingRepositoryTags = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = WorkspaceService(apiClient: apiClient);
    _loadRepositoryDetail();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _repositoryTagsController.dispose();
    for (final ctrl in _noteControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _titleControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _bodyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients && _scrollController.offset > 80 && _isHeaderExpanded) {
      setState(() {
        _isHeaderExpanded = false;
      });
    }
  }

  Future<void> _loadRepositoryDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await _service.getCollectionDetail(widget.collectionId);
      setState(() {
        _repository = detail;
        _repositoryTagsController.text = detail.customTags.join(', ');
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // Toggles pinned state on the item
  Future<void> _togglePinned(StudentCollectionItem item) async {
    final bool isPinned = _isPinned(item);
    List<String> tags = _itemTags(item);
    
    if (isPinned) {
      tags.removeWhere((t) => t.toLowerCase() == "pinned");
    } else {
      tags.add("Pinned");
    }

    try {
      if (item.fork != null) {
        await _service.updateForkProperties(item.fork!.id, {'personal_tags': tags});
      } else if (item.studentArticle != null) {
        await _service.updatePersonalArticle(item.studentArticle!.id, {'personal_tags': tags});
      }
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Mark article read progress
  Future<void> _markRead(StudentCollectionItem item) async {
    if (item.fork == null) return;
    try {
      await _service.updateForkProgress(item.fork!.id);
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Remove item from repository
  Future<void> _removeItem(int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Item"),
        content: const Text("Are you sure you want to remove this article from the repository?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("REMOVE", style: TextStyle(color: AppColors.berry)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.removeCollectionItem(itemId);
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error removing item: $e")));
    }
  }

  // Save personal summary notes
  Future<void> _saveNotes(StudentCollectionItem item, String notesText) async {
    if (item.fork == null) return;
    try {
      await _service.updateForkProperties(item.fork!.id, {
        'personal_summary': notesText.trim().isEmpty ? null : notesText.trim()
      });
      setState(() {
        _editingNotes[item.id] = false;
      });
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving notes: $e")));
    }
  }

  // Generate Flashcards locally
  List<Map<String, String>> _buildFlashcards(List<StudentCollectionItem> items) {
    final List<Map<String, String>> cards = [];
    for (final item in items) {
      final title = _itemTitle(item);
      final body = _itemBody(item);
      final note = _itemNote(item);
      final tags = _itemTags(item);

      if (note.trim().isNotEmpty) {
        cards.add({
          'question': 'What personal note did you add for "$title"?',
          'answer': note.trim(),
          'source': title,
        });
      }

      if (tags.isNotEmpty) {
        cards.add({
          'question': 'Which revision tags are assigned to "$title"?',
          'answer': tags.join(', '),
          'source': title,
        });
      }

      if (body.trim().isNotEmpty) {
        final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
        final preview = compact.length > 300 ? "${compact.substring(0, 300)}..." : compact;
        cards.add({
          'question': 'Recall the key points from "$title".',
          'answer': preview,
          'source': title,
        });
      }
    }
    return cards.take(60).toList();
  }

  // Print revision sheets dialog
  void _showPrintSheetDialog(List<StudentCollectionItem> items) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Revision Sheet", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.line),
            itemBuilder: (context, idx) {
              final item = items[idx];
              final title = _itemTitle(item);
              final note = _itemNote(item);
              final body = _itemBody(item);
              final tags = _itemTags(item);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${idx + 1}. $title", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink)),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text("Tags: ${tags.join(', ')}", style: const TextStyle(fontSize: 11, color: AppColors.civic, fontWeight: FontWeight.bold)),
                    ],
                    if (note.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.amber[50], border: Border.all(color: Colors.orange[200]!), borderRadius: BorderRadius.circular(8)),
                        child: Text("Notes: $note", style: const TextStyle(fontSize: 11.5, color: Colors.brown)),
                      ),
                    ],
                    if (body.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        body.length > 200 ? "${body.substring(0, 200)}..." : body,
                        style: TextStyle(fontSize: 11.5, color: AppColors.ink.withValues(alpha: 0.7)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  // Get properties helper
  String _itemTitle(StudentCollectionItem item) {
    return item.fork?.forkedTitle ?? item.masterArticle?.title ?? item.fork?.masterArticle?.title ?? item.studentArticle?.title ?? 'Untitled item';
  }

  String _itemBody(StudentCollectionItem item) {
    return item.fork?.forkedBody ?? item.masterArticle?.body ?? item.fork?.masterArticle?.body ?? item.studentArticle?.body ?? '';
  }

  String _itemNote(StudentCollectionItem item) {
    return item.fork?.personalSummary ?? '';
  }

  List<String> _itemTags(StudentCollectionItem item) {
    final list = item.fork?.personalTags ?? item.studentArticle?.personalTags ?? [];
    final systemTags = {
      "daily_news",
      "daily current affairs",
      "daily_current_affairs",
      "daily news",
      "editorials",
      "editorial",
      "mains_notes",
      "mains notes",
      "mains_article",
      "mains articles",
      "mains_pyq",
      "prelims_pyq",
      "read",
      "unread",
      "needs_revision",
      "revision due"
    };
    return list.where((t) {
      final normalized = t.trim().toLowerCase();
      return normalized.isNotEmpty && !systemTags.contains(normalized);
    }).toList();
  }

  String? _watermarkText() {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final email = apiClient.user?['email'] as String?;
    return (email != null && email.isNotEmpty) ? 'Personal copy - $email' : null;
  }

  PdfSection _itemToPdfSection(StudentCollectionItem item) {
    return PdfSection(
      title: _itemTitle(item),
      tags: _itemTags(item),
      personalNote: _itemNote(item).isEmpty ? null : _itemNote(item),
      bodyText: markdownToPlainText(htmlToMarkdown(_itemBody(item))),
    );
  }

  Future<void> _downloadItemPdf(StudentCollectionItem item) async {
    setState(() => _downloadingItemId = item.id);
    try {
      final section = _itemToPdfSection(item);
      final watermark = _watermarkText();
      await exportNotesPdf(
        [section],
        section.title,
        watermarkText: watermark ?? 'Personal copy - do not redistribute',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate the PDF: $e')));
    } finally {
      if (mounted) setState(() => _downloadingItemId = null);
    }
  }

  Future<void> _downloadRepositoryPdf(StudentCollectionDetail repo, List<StudentCollectionItem> items) async {
    if (items.isEmpty) return;
    setState(() => _downloadingAll = true);
    try {
      final sections = items.map(_itemToPdfSection).toList();
      final watermark = _watermarkText();
      await exportNotesPdf(sections, repo.name, watermarkText: watermark ?? 'Personal copy - do not redistribute');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate the PDF: $e')));
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }


  // Toggle a tag choice on article card
  Future<void> _toggleQuickTag(StudentCollectionItem item, String tag) async {
    final List<String> currentTags = List.from(item.fork?.personalTags ?? item.studentArticle?.personalTags ?? []);
    final String normalizedTag = tag.trim().toLowerCase();
    
    final bool hasTag = currentTags.any((t) => t.trim().toLowerCase() == normalizedTag);
    if (hasTag) {
      currentTags.removeWhere((t) => t.trim().toLowerCase() == normalizedTag);
    } else {
      currentTags.add(tag);
    }

    try {
      if (item.fork != null) {
        await _service.updateForkProperties(item.fork!.id, {'personal_tags': currentTags});
      } else if (item.studentArticle != null) {
        await _service.updatePersonalArticle(item.studentArticle!.id, {'personal_tags': currentTags});
      }
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error toggling tag: $e")));
    }
  }

  // Save editable article copy for fork
  Future<void> _saveArticleCopy(StudentCollectionItem item, String nextTitle, String nextBody) async {
    if (item.fork == null) return;
    try {
      await _service.updateForkProperties(item.fork!.id, {
        'forked_title': nextTitle.trim(),
        'forked_body': nextBody.trim(),
      });
      setState(() {
        _editingCopies[item.id] = false;
      });
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving article copy: $e")));
    }
  }

  // Save repository tag definitions
  Future<void> _saveRepositoryTags() async {
    if (_repository == null) return;
    setState(() {
      _savingRepositoryTags = true;
    });

    final List<String> nextTags = _repositoryTagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      await _service.updateCollection(_repository!.id, {
        'custom_tags': nextTags,
      });
      setState(() {
        _editingRepositoryTags = false;
      });
      _loadRepositoryDetail();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving repository tags: $e")));
    } finally {
      setState(() {
        _savingRepositoryTags = false;
      });
    }
  }

  // Build repository tag definitions card (matching web layout)
  Widget _buildRepositoryTagsCard(StudentCollectionDetail repo) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.civic.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sell_rounded, color: AppColors.civic, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Repository tag definitions",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "These are the quick-edit tag choices for this repository.",
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_editingRepositoryTags)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _editingRepositoryTags = true;
                      _repositoryTagsController.text = repo.customTags.join(', ');
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.civic,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "Edit tags",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_editingRepositoryTags) ...[
            TextField(
              controller: _repositoryTagsController,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Weak topic, Revise before mock, Done",
                fillColor: AppColors.paper,
                filled: true,
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _savingRepositoryTags
                      ? null
                      : () {
                          setState(() {
                            _editingRepositoryTags = false;
                          });
                        },
                  child: const Text("Cancel", style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savingRepositoryTags ? null : _saveRepositoryTags,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _savingRepositoryTags
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                        )
                      : const Text("Save", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else ...[
            if (repo.customTags.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "No custom tag definitions yet.",
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: repo.customTags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.civic.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.civic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )).toList(),
              ),
          ],
        ],
      ),
    );
  }

  String _progressLabel(StudentFork fork) {
    if (fork.readStatus == "needs_revision") return "Revision due";
    if (fork.readStatus == "read") return "Read";
    final progress = fork.progressPercent;
    return progress > 0 ? "$progress% read" : "Unread";
  }

  String _contentKindLabel(String? value) {
    if (value == "daily_news") return "Daily News";
    if (value == "editorials") return "Editorial";
    if (value == "mains_notes") return "Mains Study Notes";
    if (value == "mains_pyq") return "Mains PYQ";
    if (value == "prelims_pyq") return "Prelims PYQ";
    return "Saved Article";
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool active,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.civic : AppColors.civic.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.civic.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? Colors.white : AppColors.civic,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : AppColors.civic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalNotesSection(
    StudentCollectionItem item,
    bool isEditing,
    String note,
    TextEditingController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: Colors.orange[800]),
              const SizedBox(width: 6),
              Text(
                "PERSONAL NOTE",
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const Spacer(),
              if (!isEditing)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _editingNotes[item.id] = true;
                    });
                  },
                  child: Text(
                    note.isEmpty ? "Add Note" : "Edit Note",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.brown[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing) ...[
            TextField(
              controller: controller,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.brown[900]),
              decoration: InputDecoration(
                hintText: "Add reminder or summary...",
                hintStyle: TextStyle(color: Colors.brown[300]),
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange[400]!, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _editingNotes[item.id] = false;
                      controller.text = note;
                    });
                  },
                  child: const Text("CANCEL", style: TextStyle(fontSize: 11, color: Colors.brown)),
                ),
                ElevatedButton(
                  onPressed: () => _saveNotes(item, controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text("SAVE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else
            Text(
              note.isEmpty ? "No personal notes added yet." : note,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.brown[900],
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(
    StudentCollectionItem item,
    List<String> tags,
  ) {
    final hasRepoTags = _repository != null && _repository!.customTags.isNotEmpty;
    if (tags.isEmpty && !hasRepoTags) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.civic.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.civic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (hasRepoTags)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _repository!.customTags.map((tag) {
              final bool isActive = tags.any((t) => t.trim().toLowerCase() == tag.trim().toLowerCase());
              return GestureDetector(
                onTap: () => _toggleQuickTag(item, tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.civic : Colors.white,
                    border: Border.all(
                      color: isActive ? AppColors.civic : AppColors.civic.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppColors.civic,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildEditCopySection(
    StudentCollectionItem item,
    TextEditingController titleController,
    TextEditingController bodyController,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 14, color: AppColors.civic),
              const SizedBox(width: 6),
              Text(
                "EDITABLE ARTICLE COPY",
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.civic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: "Title Copy",
              fillColor: Colors.white,
              filled: true,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: bodyController,
            maxLines: 8,
            style: GoogleFonts.inter(fontSize: 13, height: 1.5),
            decoration: const InputDecoration(
              labelText: "Body Copy",
              fillColor: Colors.white,
              filled: true,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _editingCopies[item.id] = false;
                    titleController.text = _itemTitle(item);
                    bodyController.text = _itemBody(item);
                  });
                },
                child: const Text("CANCEL", style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: () => _saveArticleCopy(item, titleController.text, bodyController.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text("SAVE COPY", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyViewSection(String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                "ARTICLE BODY PREVIEW",
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.ink.withValues(alpha: 0.75),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  bool _isPinned(StudentCollectionItem item) {
    return _itemTags(item).any((t) => t.toLowerCase() == "pinned");
  }

  bool _isRevision(StudentCollectionItem item) {
    if (item.fork?.readStatus == "needs_revision" || item.fork?.scheduledRevisionAt != null) return true;
    final revTags = {"difficult", "needs revision", "revise", "revise before mock", "revision", "weak topic"};
    return _itemTags(item).any((t) => revTags.contains(t.toLowerCase()));
  }

  Widget _buildActionsToolbar(StudentCollectionDetail repo, List<StudentCollectionItem> filteredItems) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.note_add_outlined, size: 16),
              label: const Text("ADD NOTE"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => OwnArticleDialog(
                    collections: [
                      StudentCollection(
                        id: repo.id,
                        name: repo.name,
                        slug: repo.slug,
                        description: repo.description,
                        customTags: repo.customTags,
                        itemCount: repo.items.length,
                      )
                    ],
                    onSaved: _loadRepositoryDetail,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text("IMPORT"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => BulkImportDialog(
                    collections: [
                      StudentCollection(
                        id: repo.id,
                        name: repo.name,
                        slug: repo.slug,
                        description: repo.description,
                        customTags: repo.customTags,
                        itemCount: repo.items.length,
                      )
                    ],
                    onImportCompleted: _loadRepositoryDetail,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.psychology_rounded, size: 16),
              label: const Text("FLASHCARDS"),
              onPressed: filteredItems.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _flashcardsActive = true;
                        _activeFlashcardIndex = 0;
                      });
                    },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.assignment_rounded, size: 16),
              label: const Text("SHEET"),
              onPressed: filteredItems.isEmpty
                  ? null
                  : () => _showPrintSheetDialog(filteredItems),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: Text(_downloadingAll ? "PREPARING..." : "DOWNLOAD PDF"),
              onPressed: filteredItems.isEmpty || _downloadingAll
                  ? null
                  : () => _downloadRepositoryPdf(repo, filteredItems),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _repository == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null && _repository == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              ElevatedButton(onPressed: _loadRepositoryDetail, child: const Text("RETRY")),
            ],
          ),
        ),
      );
    }

    final repo = _repository!;
    
    // Multi tag compiling
    final Set<String> tagFiltersSet = {"all"};
    repo.customTags.forEach((t) => tagFiltersSet.add(t));
    for (final item in repo.items) {
      _itemTags(item).forEach((t) => tagFiltersSet.add(t));
    }
    final tagFilters = tagFiltersSet.toList();

    // Filter items locally
    final filteredItems = repo.items.where((item) {
      final title = _itemTitle(item).toLowerCase();
      final note = _itemNote(item).toLowerCase();
      final body = _itemBody(item).toLowerCase();
      
      if (_selectedTagFilter != "all" && !_itemTags(item).contains(_selectedTagFilter)) return false;
      if (_revisionOnly && !_isRevision(item)) return false;
      if (_pinnedOnly && !_isPinned(item)) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!title.contains(query) && !note.contains(query) && !body.contains(query)) return false;
      }
      return true;
    }).toList();

    final flashcards = _buildFlashcards(filteredItems);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(repo.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _flashcardsActive 
          ? _buildFlashcardsView(flashcards)
          : Column(
              children: [
                // Collapsible section for repository actions & tags
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Container(
                    height: _isHeaderExpanded ? null : 0,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionsToolbar(repo, filteredItems),
                        _buildRepositoryTagsCard(repo),
                      ],
                    ),
                  ),
                ),

                // Search & Filter options bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Search title, notes, or tags...",
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: _isHeaderExpanded
                                ? AppColors.civic.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: IconButton(
                              icon: Icon(
                                _isHeaderExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.civic,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isHeaderExpanded = !_isHeaderExpanded;
                                });
                              },
                              tooltip: _isHeaderExpanded
                                  ? "Hide repository actions"
                                  : "Show repository actions",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Combined single-row scrollable filters
                      SizedBox(
                        height: 38,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                avatar: const Icon(Icons.psychology_outlined, size: 14),
                                label: Text("Revision Mode (${repo.items.where(_isRevision).length})"),
                                selected: _revisionOnly,
                                onSelected: (val) {
                                  setState(() {
                                    _revisionOnly = val;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                avatar: const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                label: Text("Pinned (${repo.items.where(_isPinned).length})"),
                                selected: _pinnedOnly,
                                onSelected: (val) {
                                  setState(() {
                                    _pinnedOnly = val;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 20,
                                width: 1,
                                color: AppColors.line,
                              ),
                              const SizedBox(width: 8),
                              ...tagFilters.map((tag) {
                                final isSel = _selectedTagFilter == tag;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(tag),
                                    selected: isSel,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedTagFilter = tag;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Listing
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(child: Text("No items found matching filters.", style: GoogleFonts.inter(color: AppColors.muted)))
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildItemCard(item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemCard(StudentCollectionItem item) {
    final title = _itemTitle(item);
    final tags = _itemTags(item);
    final note = _itemNote(item);
    final isPinned = _isPinned(item);
    final body = _itemBody(item);

    final isEditingNote = _editingNotes[item.id] ?? false;
    final isEditingCopy = _editingCopies[item.id] ?? false;
    final isBodyExpanded = _expandedBodies[item.id] ?? false;

    // Init controllers if needed
    if (!_noteControllers.containsKey(item.id)) {
      _noteControllers[item.id] = TextEditingController(text: note);
    }
    final noteController = _noteControllers[item.id]!;

    if (!_titleControllers.containsKey(item.id)) {
      _titleControllers[item.id] = TextEditingController(text: title);
    }
    final titleController = _titleControllers[item.id]!;

    if (!_bodyControllers.containsKey(item.id)) {
      _bodyControllers[item.id] = TextEditingController(text: body);
    }
    final bodyController = _bodyControllers[item.id]!;

    // Category / Kind Badge & Progress Badge
    final String badgeLabel = item.studentArticle != null
        ? "Own Note"
        : _contentKindLabel(item.masterArticle?.contentKind ?? item.fork?.masterArticle?.contentKind);

    String? progressText;
    Color progressBgColor = AppColors.civic.withValues(alpha: 0.08);
    Color progressTextColor = AppColors.civic;
    if (item.fork != null) {
      progressText = _progressLabel(item.fork!);
      if (item.fork!.readStatus == "needs_revision") {
        progressBgColor = Colors.orange[50]!;
        progressTextColor = Colors.orange[800]!;
      } else if (item.fork!.readStatus == "read") {
        progressBgColor = AppColors.emerald.withValues(alpha: 0.08);
        progressTextColor = AppColors.emerald;
      }
    }

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badges Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.studentArticle != null
                      ? Colors.amber[50]
                      : AppColors.civic.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: item.studentArticle != null
                      ? Border.all(color: Colors.amber[200]!)
                      : null,
                ),
                child: Text(
                  badgeLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: item.studentArticle != null ? Colors.brown : AppColors.civic,
                  ),
                ),
              ),
              if (progressText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: progressBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    progressText.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: progressTextColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Star Pin icon button
              GestureDetector(
                onTap: () => _togglePinned(item),
                child: Icon(
                  isPinned ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isPinned ? Colors.amber : AppColors.muted,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          GestureDetector(
            onTap: () {
              if (item.masterArticle?.slug != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: item.masterArticle!.slug)),
                );
              } else if (item.fork?.masterArticle?.slug != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: item.fork!.masterArticle!.slug)),
                );
              }
            },
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action Options Buttons Row (Body preview toggle, edit copy)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (body.isNotEmpty)
                _buildActionChip(
                  icon: isBodyExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  label: isBodyExpanded ? "Hide Body" : "Body Preview",
                  onTap: () {
                    setState(() {
                      _expandedBodies[item.id] = !isBodyExpanded;
                    });
                  },
                  active: isBodyExpanded,
                ),
              if (item.fork != null)
                _buildActionChip(
                  icon: Icons.sticky_note_2_rounded,
                  label: note.isEmpty ? "Add Note" : "Edit Note",
                  onTap: () {
                    setState(() {
                      _editingNotes[item.id] = !isEditingNote;
                    });
                  },
                  active: isEditingNote,
                ),
              if (item.fork != null)
                _buildActionChip(
                  icon: Icons.edit_note_rounded,
                  label: "Edit Copy",
                  onTap: () {
                    setState(() {
                      _editingCopies[item.id] = !isEditingCopy;
                      if (!isEditingCopy) {
                        _expandedBodies[item.id] = true; // Auto-expand body edit view
                      }
                    });
                  },
                  active: isEditingCopy,
                ),
              if (item.fork != null)
                _buildActionChip(
                  icon: Icons.border_color_rounded,
                  label: "Highlight & Annotate",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ForkReaderScreen(forkId: item.fork!.id)),
                    ).then((_) => _loadRepositoryDetail());
                  },
                  active: false,
                ),
              if (item.fork != null)
                _buildActionChip(
                  icon: Icons.file_download_outlined,
                  label: _downloadingItemId == item.id ? "Preparing..." : "Download PDF",
                  onTap: () {
                    if (_downloadingItemId != item.id) _downloadItemPdf(item);
                  },
                  active: false,
                ),
              if (item.studentArticle != null)
                _buildActionChip(
                  icon: Icons.edit_rounded,
                  label: "Edit own article",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => OwnArticleDialog(
                        collections: _repository != null ? [
                          StudentCollection(
                            id: _repository!.id,
                            name: _repository!.name,
                            slug: _repository!.slug,
                            description: _repository!.description,
                            customTags: _repository!.customTags,
                            itemCount: _repository!.items.length,
                          )
                        ] : [],
                        article: item.studentArticle,
                        onSaved: _loadRepositoryDetail,
                      ),
                    );
                  },
                  active: false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.line),
          const SizedBox(height: 8),

          // PERSONAL NOTES SECTION
          if (item.fork != null) ...[
            _buildPersonalNotesSection(item, isEditingNote, note, noteController),
            const SizedBox(height: 12),
          ],

          // TAGS SECTION
          _buildTagsSection(item, tags),
          const SizedBox(height: 12),

          // EXPANDABLE BODY / EDIT COPY SECTION
          if (isEditingCopy && item.fork != null) ...[
            _buildEditCopySection(item, titleController, bodyController),
            const SizedBox(height: 12),
          ] else if (isBodyExpanded && body.isNotEmpty) ...[
            _buildBodyViewSection(body),
            const SizedBox(height: 12),
          ],

          // FOOTER BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.fork != null && item.fork!.readStatus != "read") ...[
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.emerald),
                  label: const Text(
                    "MARK READ",
                    style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _markRead(item),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.berry),
                label: const Text(
                  "REMOVE",
                  style: TextStyle(fontSize: 11, color: AppColors.berry, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _removeItem(item.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardsView(List<Map<String, String>> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.psychology_rounded, color: AppColors.civic),
              const SizedBox(width: 8),
              Text(
                "Revision Flashcards",
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _flashcardsActive = false;
                  });
                },
              ),
            ],
          ),
        ),
        
        Expanded(
          child: cards.isEmpty
              ? Center(child: Text("Add summaries to generate cards.", style: GoogleFonts.inter(color: AppColors.muted)))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: FlashcardCardWidget(
                      question: cards[_activeFlashcardIndex]['question']!,
                      answer: cards[_activeFlashcardIndex]['answer']!,
                      source: cards[_activeFlashcardIndex]['source']!,
                      index: _activeFlashcardIndex,
                      total: cards.length,
                    ),
                  ),
                ),
        ),

        if (cards.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: _activeFlashcardIndex == 0
                      ? null
                      : () {
                          setState(() {
                            _activeFlashcardIndex--;
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("PREVIOUS"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _activeFlashcardIndex = (_activeFlashcardIndex + 1) % cards.length;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("NEXT CARD"),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
