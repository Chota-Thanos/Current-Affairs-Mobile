import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../workspace/data/workspace_service.dart';
import '../../workspace/models/workspace_models.dart';

class PersonalArticlesScreen extends StatefulWidget {
  const PersonalArticlesScreen({super.key});

  @override
  State<PersonalArticlesScreen> createState() => _PersonalArticlesScreenState();
}

class _PersonalArticlesScreenState extends State<PersonalArticlesScreen> {
  late WorkspaceService _service;
  bool _loading = true;
  String? _error;

  List<StudentArticle> _articles = [];
  List<StudentCollection> _collections = [];

  // Search and filter states
  String _searchQuery = "";
  String _selectedStatusTab = "All"; // All, Draft, Published, Archived

  // Editor states
  bool _isEditing = false;
  StudentArticle? _editingArticle; // null if creating a new one
  bool _previewMode = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _sourceController = TextEditingController();
  final _tagsController = TextEditingController();
  String _selectedStatus = "draft"; // default
  String? _selectedCollectionId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = WorkspaceService(apiClient: apiClient);
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final articles = await _service.getPersonalArticles();
      final collections = await _service.getCollections();

      setState(() {
        _articles = articles;
        _collections = collections;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _startCreateNote() {
    _titleController.clear();
    _bodyController.clear();
    _sourceController.clear();
    _tagsController.clear();
    setState(() {
      _isEditing = true;
      _editingArticle = null;
      _previewMode = false;
      _selectedStatus = "draft";
      _selectedCollectionId = _collections.isNotEmpty ? _collections.first.id.toString() : null;
    });
  }

  void _startEditNote(StudentArticle article) {
    _titleController.text = article.title;
    _bodyController.text = article.body;
    _sourceController.text = article.sourceUrl ?? '';
    _tagsController.text = article.personalTags.join(', ');
    setState(() {
      _isEditing = true;
      _editingArticle = article;
      _previewMode = false;
      _selectedStatus = article.status;
      _selectedCollectionId = null; // Don't prompt repository if editing (already saved)
    });
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();
      final source = _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim();
      final tagsRaw = _tagsController.text.trim();
      final List<String> tags = tagsRaw.isNotEmpty
          ? tagsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : [];

      if (_editingArticle != null) {
        // Update
        await _service.updatePersonalArticle(_editingArticle!.id, {
          'title': title,
          'body': body,
          'source_url': source,
          'personal_tags': tags,
          'status': _selectedStatus,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Note updated successfully!"), backgroundColor: AppColors.emerald),
        );
      } else {
        // Create
        final slug = "${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
        final created = await _service.createPersonalArticle(
          title: title,
          slug: slug,
          body: body,
          sourceUrl: source,
          personalTags: tags,
          status: _selectedStatus,
        );

        // Assign to Repository folder if selected
        if (_selectedCollectionId != null) {
          final repoId = int.parse(_selectedCollectionId!);
          await _service.addCollectionItem(repoId, studentArticleId: created.id);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Note created successfully!"), backgroundColor: AppColors.emerald),
        );
      }

      setState(() {
        _isEditing = false;
        _editingArticle = null;
      });

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save note: $e"), backgroundColor: AppColors.berry),
      );
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  Future<void> _deleteNote(StudentArticle article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Archive Note"),
        content: Text("Are you sure you want to archive '${article.title}'?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ARCHIVE", style: TextStyle(color: AppColors.berry)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.updatePersonalArticle(article.id, {'status': 'archived'});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Note archived successfully")),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to archive: $e")),
        );
      }
    }
  }

  List<StudentArticle> _getFilteredArticles() {
    return _articles.where((article) {
      final matchesSearch = article.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          article.body.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          article.personalTags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));

      if (!matchesSearch) return false;

      if (_selectedStatusTab == "All") return article.status != "archived"; // Don't show archived by default in "All"
      if (_selectedStatusTab == "Drafts") return article.status == "draft";
      if (_selectedStatusTab == "Published") return article.status == "published";
      if (_selectedStatusTab == "Archived") return article.status == "archived";

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildEditorView();
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startCreateNote,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Write Note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.civic,
        elevation: 4,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.ink)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text("RETRY")),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Search Bar and Header
                    _buildSearchAndFiltersHeader(),
                    
                    // Articles List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.civic,
                        child: _buildArticlesList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchAndFiltersHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search box
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: "Search notes by title, body, or tags...",
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.paper.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                borderSide: const BorderSide(color: AppColors.civic, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters Tab Row
          Row(
            children: ["All", "Drafts", "Published", "Archived"].map((tab) {
              final isSelected = _selectedStatusTab == tab;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStatusTab = tab;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.civic.withValues(alpha: 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.civic.withValues(alpha: 0.2) : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tab,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppColors.civic : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList() {
    final filtered = _getFilteredArticles();

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Icon(Icons.note_alt_outlined, size: 48, color: AppColors.line),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty 
                ? "No notes match your search." 
                : "No notes found in this tab.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.muted, fontSize: 14),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _startCreateNote,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("WRITE FIRST NOTE"),
              ),
            ),
          ]
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final art = filtered[index];
        final formattedDate = art.updatedAt.length > 10 ? art.updatedAt.substring(0, 10) : art.updatedAt;
        
        Color statusColor = AppColors.muted;
        if (art.status == 'published') statusColor = AppColors.emerald;
        if (art.status == 'archived') statusColor = AppColors.saffron;

        return Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        art.status.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Title & Body snippet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      art.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      art.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Tags row
              if (art.personalTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: art.personalTags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        t,
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    )).toList(),
                  ),
                ),

              const Divider(height: 24, color: AppColors.line),

              // Action Buttons Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    if (art.sourceUrl != null && art.sourceUrl!.isNotEmpty)
                      Expanded(
                        child: Text(
                          "Source: ${art.sourceUrl}",
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    
                    TextButton.icon(
                      onPressed: () => _startEditNote(art),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text("Edit", style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (art.status != 'archived')
                      IconButton(
                        onPressed: () => _deleteNote(art),
                        tooltip: "Archive note",
                        icon: const Icon(Icons.archive_outlined, size: 18, color: AppColors.saffron),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorView() {
    final isNew = _editingArticle == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          isNew ? "Create Personal Note" : "Edit Personal Note",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () {
            setState(() {
              _isEditing = false;
            });
          },
        ),
        actions: [
          // Preview Mode Toggle
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              icon: Icon(_previewMode ? Icons.edit_note_rounded : Icons.menu_book_rounded, size: 18, color: AppColors.civic),
              label: Text(_previewMode ? "Editor" : "Preview", style: const TextStyle(fontSize: 12, color: AppColors.civic)),
              onPressed: () {
                setState(() {
                  _previewMode = !_previewMode;
                });
              },
            ),
          ),
          // Save note trigger
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton(
              onPressed: _saving ? null : _saveNote,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save", style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: _previewMode 
            ? _buildMarkdownPreview()
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Note Title
                    Text(
                      "NOTE TITLE",
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: "Enter a descriptive title...",
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Title is required";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Target repository folder selection (Only for new articles)
                    if (isNew && _collections.isNotEmpty) ...[
                      Text(
                        "ADD TO REPOSITORY",
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCollectionId,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text("None (Do not link folder)", style: TextStyle(color: AppColors.muted)),
                          ),
                          ..._collections.map((c) => DropdownMenuItem(
                            value: c.id.toString(),
                            child: Text(c.name),
                          )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCollectionId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Status and Source side-by-side
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "STATUS",
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "draft", child: Text("Draft")),
                                  DropdownMenuItem(value: "published", child: Text("Published")),
                                  DropdownMenuItem(value: "archived", child: Text("Archived")),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedStatus = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SOURCE URL",
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _sourceController,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  hintText: "Optional article link",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tags input
                    Text(
                      "PERSONAL TAGS",
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        hintText: "e.g. Weak Topic, Revise First, GS-III (comma separated)",
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Editor body with markdown note
                    Row(
                      children: [
                        Text(
                          "NOTE CONTENT",
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
                        ),
                        const Spacer(),
                        Text(
                          "Supports Markdown syntax",
                          style: GoogleFonts.inter(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bodyController,
                      maxLines: 12,
                      scrollPhysics: const BouncingScrollPhysics(),
                      style: GoogleFonts.robotoMono(fontSize: 13, color: AppColors.ink),
                      decoration: const InputDecoration(
                        hintText: "Write your UPSC study guide, summaries, bullet points here...\n\nExample:\n# GS-III Technology\n- Nanotech applications in agriculture\n- Drone rules 2021 framework...",
                        contentPadding: EdgeInsets.all(14),
                        alignLabelWithHint: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Content is required";
                        return null;
                      },
                    ),
                    const SizedBox(height: 80), // bottom spacing for keyboard scroll
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMarkdownPreview() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    return ListView(
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.civic.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedStatus.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, color: AppColors.civic, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (_tagsController.text.trim().isNotEmpty)
                Expanded(
                  child: Text(
                    "Tags: ${_tagsController.text.trim()}",
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: AppColors.line),
        ],
        body.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "Nothing to preview yet. Start typing in the Editor tab!",
                    style: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              )
            : MarkdownBody(
                data: body,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h1: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.4),
                  h2: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink, height: 1.3),
                  p: GoogleFonts.inter(fontSize: 14, color: AppColors.ink, height: 1.5),
                  listBullet: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
                  code: GoogleFonts.robotoMono(backgroundColor: AppColors.paper, fontSize: 12),
                  codeblockDecoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                ),
              ),
        const SizedBox(height: 60),
      ],
    );
  }
}
