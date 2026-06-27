import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/workspace_models.dart';
import '../../data/workspace_service.dart';

class OwnArticleDialog extends StatefulWidget {
  final List<StudentCollection> collections;
  final StudentArticle? article; // if editing
  final VoidCallback onSaved;

  const OwnArticleDialog({
    super.key,
    required this.collections,
    this.article,
    required this.onSaved,
  });

  @override
  State<OwnArticleDialog> createState() => _OwnArticleDialogState();
}

class _OwnArticleDialogState extends State<OwnArticleDialog> {
  final _formKey = GlobalKey<FormState>();
  late WorkspaceService _service;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _sourceController = TextEditingController();
  List<String> _selectedTags = [];
  String? _selectedCollectionId;
  bool _submitting = false;

  StudentCollection? get _selectedCollection {
    if (_selectedCollectionId == null) return null;
    final id = int.tryParse(_selectedCollectionId!);
    if (id == null) return null;
    try {
      return widget.collections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = WorkspaceService(apiClient: apiClient);

    if (widget.collections.isNotEmpty) {
      _selectedCollectionId = widget.collections.first.id.toString();
    }

    if (widget.article != null) {
      _titleController.text = widget.article!.title;
      _bodyController.text = widget.article!.body;
      _sourceController.text = widget.article!.sourceUrl ?? '';
      _selectedTags = List<String>.from(widget.article!.personalTags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();
      final source = _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim();
      final List<String> tags = _selectedTags;

      if (widget.article != null) {
        // Edit own article
        await _service.updatePersonalArticle(widget.article!.id, {
          'title': title,
          'body': body,
          'source_url': source,
          'personal_tags': tags,
          'status': 'published',
        });
      } else {
        // Create own article
        final slug = "${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
        final created = await _service.createPersonalArticle(
          title: title,
          slug: slug,
          body: body,
          sourceUrl: source,
          personalTags: tags,
          status: 'published',
        );

        // Link to collection repository folder
        if (_selectedCollectionId != null) {
          final repoId = int.parse(_selectedCollectionId!);
          await _service.addCollectionItem(repoId, studentArticleId: created.id);
        }
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e")),
      );
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  Widget _buildTagsSelectionSection() {
    final repo = _selectedCollection;
    final repoTags = repo?.customTags ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Tags",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        if (repoTags.isEmpty)
          Text(
            "No tags defined in this repository folder.",
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: repoTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
                selectedColor: AppColors.civic,
                checkmarkColor: Colors.white,
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppColors.civic : AppColors.line,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.article != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEditing ? "Edit own article" : "Write personal note",
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: "Title"),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Title is required";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: "Article body text, facts, or outline..."),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Body content is required";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(hintText: "Source URL (optional)"),
                ),
                if (!isEditing && widget.collections.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCollectionId,
                    decoration: const InputDecoration(labelText: "Add to Repository", contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: widget.collections.map((c) => DropdownMenuItem(
                      value: c.id.toString(),
                      child: Text(c.name, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCollectionId = val;
                        _selectedTags.clear();
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                _buildTagsSelectionSection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _submitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("SAVE NOTE"),
        ),
      ],
    );
  }
}

// Fallback tags extension helper filter
extension StringFilter<T> on List<String> {
  List<String> filter(bool Function(String) test) {
    return where(test).toList();
  }
}
