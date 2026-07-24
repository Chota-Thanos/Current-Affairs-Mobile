import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/html_to_markdown.dart';
import '../../../core/utils/text_anchor.dart';
import '../../current_affairs/presentation/article_detail_screen.dart';
import '../data/workspace_service.dart';
import '../models/workspace_models.dart';
import 'widgets/source_article_connections.dart';

const Map<String, Color> _highlightColors = {
  'yellow': Color(0xFFFDE047),
  'green': Color(0xFF6EE7B7),
  'blue': Color(0xFF7DD3FC),
  'pink': Color(0xFFF9A8D4),
};

class ForkReaderScreen extends StatefulWidget {
  final int forkId;
  const ForkReaderScreen({super.key, required this.forkId});

  @override
  State<ForkReaderScreen> createState() => _ForkReaderScreenState();
}

class _ForkReaderScreenState extends State<ForkReaderScreen> {
  late WorkspaceService _service;
  bool _loading = true;
  String? _error;
  StudentFork? _fork;
  String _plainBody = '';
  TextSelection? _activeSelection;
  bool _savingAnnotation = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = WorkspaceService(apiClient: apiClient);
    _load();
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _activeSelection = null;
    });
    try {
      final fork = await _service.getFork(widget.forkId);
      final rawBody = fork.forkedBody ?? fork.masterArticle?.body ?? '';
      setState(() {
        _fork = fork;
        _plainBody = markdownToPlainText(htmlToMarkdown(rawBody));
      });
    } catch (e) {
      setState(() => _error = 'Could not load this saved article.');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatDate(String? value) {
    if (value == null) return 'Undated';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}";
  }

  Future<void> _createHighlight(String color) async {
    final selection = _activeSelection;
    if (selection == null || _savingAnnotation) return;
    final anchor = computeAnchorFromSelection(_plainBody, selection.start, selection.end);
    if (anchor == null) return;
    setState(() => _savingAnnotation = true);
    try {
      await _service.createHighlight(widget.forkId, anchor: anchor, color: color);
      await _load();
    } catch (_) {
      if (mounted) _showSnack('Could not save highlight.');
    } finally {
      if (mounted) setState(() => _savingAnnotation = false);
    }
  }

  Future<void> _createNote() async {
    final selection = _activeSelection;
    if (selection == null) return;
    final anchor = computeAnchorFromSelection(_plainBody, selection.start, selection.end);
    if (anchor == null) return;

    final controller = TextEditingController();
    final noteText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${anchor.quote}"', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What should this remind you of?'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save note')),
        ],
      ),
    );

    if (noteText == null || noteText.trim().isEmpty) return;
    setState(() => _savingAnnotation = true);
    try {
      await _service.createNote(widget.forkId, anchor: anchor, note: noteText.trim());
      await _load();
    } catch (_) {
      if (mounted) _showSnack('Could not save note.');
    } finally {
      if (mounted) setState(() => _savingAnnotation = false);
    }
  }

  Future<void> _editAnnotation({required bool isHighlight, required int id, String? currentNote}) async {
    if (isHighlight) {
      final controller = TextEditingController(text: currentNote ?? '');
      final action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Highlight note', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Optional note for this highlight...'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.berry, size: 18),
                    label: const Text('Delete', style: TextStyle(color: AppColors.berry)),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
      if (action == 'delete') {
        await _service.deleteHighlight(id);
        await _load();
      } else if (action == 'save') {
        await _service.updateHighlight(id, note: controller.text.trim().isEmpty ? null : controller.text.trim());
        await _load();
      }
      return;
    }

    final controller = TextEditingController(text: currentNote ?? '');
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Note', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(controller: controller, maxLines: 3),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.berry, size: 18),
                  label: const Text('Delete', style: TextStyle(color: AppColors.berry)),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: controller.text.trim().isEmpty ? null : () => Navigator.pop(context, 'save'),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      await _service.deleteNote(id);
      await _load();
    } else if (action == 'save' && controller.text.trim().isNotEmpty) {
      await _service.updateNote(id, note: controller.text.trim());
      await _load();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<TextSpan> _buildBodySpans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final fork = _fork;
    if (fork == null || _plainBody.isEmpty) return [TextSpan(text: _plainBody)];

    final ranges = <_AnnotationRange>[];
    for (final h in fork.highlights) {
      final loc = locateAnchor(_plainBody, h.anchor);
      if (loc != null) ranges.add(_AnnotationRange(loc.$1, loc.$2, isHighlight: true, color: _highlightColors[h.color] ?? _highlightColors['yellow']!, id: h.id, note: h.note));
    }
    for (final n in fork.notes) {
      final loc = locateAnchor(_plainBody, n.anchor);
      if (loc != null) ranges.add(_AnnotationRange(loc.$1, loc.$2, isHighlight: false, color: null, id: n.id, note: n.note));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    int cursor = 0;
    final bodyStyle = GoogleFonts.inter(fontSize: 14.5, color: AppColors.ink, height: 1.6);
    for (final r in ranges) {
      if (r.start < cursor) continue;
      if (r.start > cursor) {
        spans.add(TextSpan(text: _plainBody.substring(cursor, r.start), style: bodyStyle));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _editAnnotation(isHighlight: r.isHighlight, id: r.id, currentNote: r.note);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: _plainBody.substring(r.start, r.end),
        style: bodyStyle.copyWith(
          backgroundColor: r.isHighlight ? r.color : null,
          decoration: r.isHighlight ? TextDecoration.none : TextDecoration.underline,
          decorationColor: AppColors.saffron,
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2,
        ),
        recognizer: recognizer,
      ));
      cursor = r.end;
    }
    if (cursor < _plainBody.length) {
      spans.add(TextSpan(text: _plainBody.substring(cursor), style: bodyStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Saved Article', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 18)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.civic))
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('RETRY')),
                  ],
                ),
              ),
            )
          else if (_fork != null)
            _buildContent(_fork!),
          if (_activeSelection != null) _buildSelectionToolbar(),
        ],
      ),
    );
  }

  Widget _buildContent(StudentFork fork) {
    final article = fork.masterArticle;
    final title = fork.forkedTitle ?? article?.title ?? 'Saved article';

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: _activeSelection != null ? 100 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: AppTheme.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article != null)
                    DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.civic.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          article.contentKind.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.civic),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(_formatDate(article?.publicationDate), style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold)),
                      if (article?.slug != null) ...[
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: article!.slug)));
                          },
                          child: const Text('View original'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Select any text below to highlight it or attach a note.',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: AppTheme.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SelectableText.rich(
                TextSpan(children: _buildBodySpans()),
                onSelectionChanged: (selection, cause) {
                  setState(() => _activeSelection = selection.isCollapsed ? null : selection);
                },
              ),
            ),
          ),

          if (fork.highlights.isNotEmpty || fork.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: AppTheme.innerCardDecoration,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.border_color_rounded, size: 15, color: AppColors.civic),
                        const SizedBox(width: 6),
                        Text(
                          'Highlights & notes (${fork.highlights.length + fork.notes.length})',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final h in fork.highlights) ...[
                      _AnnotationListTile(
                        quote: h.anchor.quote,
                        note: h.note,
                        dotColor: _highlightColors[h.color] ?? _highlightColors['yellow'],
                        onTap: () => _editAnnotation(isHighlight: true, id: h.id, currentNote: h.note),
                        onDelete: () async {
                          await _service.deleteHighlight(h.id);
                          await _load();
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                    for (final n in fork.notes) ...[
                      _AnnotationListTile(
                        quote: n.anchor.quote,
                        note: n.note,
                        dotColor: null,
                        onTap: () => _editAnnotation(isHighlight: false, id: n.id, currentNote: n.note),
                        onDelete: () async {
                          await _service.deleteNote(n.id);
                          await _load();
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          SourceArticleConnections(article: article),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              for (final entry in _highlightColors.entries) ...[
                GestureDetector(
                  onTap: _savingAnnotation ? null : () => _createHighlight(entry.key),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 2)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _savingAnnotation ? null : _createNote,
                icon: const Icon(Icons.note_add_outlined, size: 16, color: Colors.white),
                label: const Text('Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => setState(() => _activeSelection = null),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnotationRange {
  final int start;
  final int end;
  final bool isHighlight;
  final Color? color;
  final int id;
  final String? note;

  _AnnotationRange(this.start, this.end, {required this.isHighlight, required this.color, required this.id, this.note});
}

class _AnnotationListTile extends StatelessWidget {
  final String quote;
  final String? note;
  final Color? dotColor;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _AnnotationListTile({required this.quote, required this.note, required this.dotColor, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (dotColor != null) ...[
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            '"$quote"',
                            style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (note != null && note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(note!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink)),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () => onDelete(),
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.muted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
