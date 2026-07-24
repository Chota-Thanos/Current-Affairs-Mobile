import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../current_affairs/models/article_models.dart' as camodels;
import '../data/workspace_service.dart';
import '../models/workspace_models.dart';

class WorkspaceAiHelperScreen extends StatefulWidget {
  const WorkspaceAiHelperScreen({super.key});

  @override
  State<WorkspaceAiHelperScreen> createState() => _WorkspaceAiHelperScreenState();
}

class _WorkspaceAiHelperScreenState extends State<WorkspaceAiHelperScreen>
    with SingleTickerProviderStateMixin {
  late WorkspaceService _service;
  late TabController _tabController;
  bool _metaLoading = true;

  // Shared metadata
  List<StudentCollection> _collections = [];
  List<camodels.CategoryNode> _categories = [];
  String? _selectedCollectionId;
  String? _selectedSubjectId;

  // Notes state
  final _noteTopicController = TextEditingController();
  bool _generatingGuide = false;
  Map<String, String>? _generatedGuide;
  bool _savingGuide = false;

  // Assessment state
  final _quizTopicController = TextEditingController();
  String _selectedQuizType = 'gk'; // gk vs maths vs passage
  bool _generatingQuiz = false;
  Map<String, dynamic>? _generatedQuiz;

  // Playing state
  final Map<int, String> _userAnswers = {};
  bool _quizSubmitted = false;
  int _activeQuestionIdx = 0;

  // Inline feedback banner
  _FeedbackState? _feedbackState;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = WorkspaceService(apiClient: apiClient);
    _loadMetadata();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteTopicController.dispose();
    _quizTopicController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _triggerFeedback(String text, {bool isError = false}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackState = _FeedbackState(text: text, isError: isError);
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _feedbackState = null;
        });
      }
    });
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _metaLoading = true;
    });

    try {
      final colls = await _service.getCollections();
      final cats = await _service.getCategories();

      setState(() {
        _collections = colls;
        _categories = cats;
        if (colls.isNotEmpty) _selectedCollectionId = colls.first.id.toString();
        if (cats.isNotEmpty) _selectedSubjectId = cats.first.id.toString();
        _metaLoading = false;
      });
    } catch (_) {
      setState(() {
        _metaLoading = false;
      });
    }
  }

  Future<void> _compileCustomNote() async {
    final topic = _noteTopicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _generatingGuide = true;
      _generatedGuide = null;
      _feedbackState = null;
    });

    // Simulate generation delay for UX richness (matches web app)
    await Future.delayed(const Duration(milliseconds: 1200));

    try {
      final subId = _selectedSubjectId != null ? int.parse(_selectedSubjectId!) : null;
      final guide = await _service.generateAiStudyGuide(topic: topic, subjectId: subId);
      setState(() {
        _generatedGuide = guide;
      });
    } catch (e) {
      _triggerFeedback('Error generating note: $e', isError: true);
    } finally {
      setState(() {
        _generatingGuide = false;
      });
    }
  }

  Future<void> _saveGuideToLibrary() async {
    if (_generatedGuide == null) return;
    setState(() {
      _savingGuide = true;
    });

    try {
      final title = _generatedGuide!['title']!;
      final body = _generatedGuide!['body']!;
      final slug =
          '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';

      final subId = _selectedSubjectId != null ? int.parse(_selectedSubjectId!) : null;

      final article = await _service.createPersonalArticle(
        title: title,
        slug: slug,
        body: body,
        categoryNodeId: subId,
        status: 'published',
      );

      if (_selectedCollectionId != null) {
        final colId = int.parse(_selectedCollectionId!);
        await _service.addCollectionItem(colId, studentArticleId: article.id);
        _triggerFeedback('Guide saved and added to your collection!');
      } else {
        _triggerFeedback('Guide saved to your personal articles library.');
      }

      setState(() {
        _generatedGuide = null;
        _noteTopicController.clear();
      });
    } catch (e) {
      _triggerFeedback('Failed to save: $e', isError: true);
    } finally {
      setState(() {
        _savingGuide = false;
      });
    }
  }

  Future<void> _generateQuiz() async {
    final topic = _quizTopicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _generatingQuiz = true;
      _generatedQuiz = null;
      _userAnswers.clear();
      _quizSubmitted = false;
      _activeQuestionIdx = 0;
      _feedbackState = null;
    });

    // Simulate generation delay for UX richness (matches web app)
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final quiz = await _service.generateAiQuiz(topic: topic, quizType: _selectedQuizType);
      setState(() {
        _generatedQuiz = quiz;
      });
    } catch (e) {
      _triggerFeedback('Error generating quiz: $e', isError: true);
    } finally {
      setState(() {
        _generatingQuiz = false;
      });
    }
  }

  int _calculateScore() {
    if (_generatedQuiz == null) return 0;
    final questions = _generatedQuiz!['questions'] as List;
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i] as Map;
      if (_userAnswers[i] == q['correct_answer']) {
        correct++;
      }
    }
    return correct;
  }

  /// Renders text with LaTeX math expressions ($...$) displayed in a styled amber chip.
  List<Widget> _renderMathText(String text, {TextStyle? baseStyle}) {
    final parts = text.split(RegExp(r'(\$[^\$]+\$)'));
    final result = <Widget>[];

    for (final part in parts) {
      if (part.startsWith('\$') && part.endsWith('\$') && part.length > 2) {
        final mathContent = part.substring(1, part.length - 1);
        result.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.saffron.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.saffron.withValues(alpha: 0.2)),
            ),
            child: Text(
              mathContent,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: AppColors.saffron,
              ),
            ),
          ),
        );
      } else if (part.isNotEmpty) {
        result.add(Text(part, style: baseStyle));
      }
    }

    return result;
  }

  Widget _buildMathRichText(String text, {TextStyle? baseStyle}) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _renderMathText(text, baseStyle: baseStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              'AI Notes Helper',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.civic,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.civic,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_rounded, size: 16), text: 'Study Notes'),
                Tab(icon: Icon(Icons.workspace_premium_rounded, size: 16), text: 'Assessments'),
              ],
            ),
          ),
        ),
      ),
      body: _metaLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.civic))
          : Column(
              children: [
                // Inline feedback banner
                if (_feedbackState != null)
                  _buildFeedbackBanner(_feedbackState!),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStudyNotesTab(),
                      _buildAssessmentTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFeedbackBanner(_FeedbackState state) {
    final isError = state.isError;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.berry.withValues(alpha: 0.08)
            : AppColors.civic.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(
            color: isError ? AppColors.berry.withValues(alpha: 0.3) : AppColors.civic.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 16,
            color: isError ? AppColors.berry : AppColors.civic,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isError ? AppColors.berry : AppColors.civic,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _feedbackState = null),
            child: Icon(Icons.close_rounded, size: 14, color: isError ? AppColors.berry : AppColors.civic),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Controls input card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppColors.civic, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Study Guides',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        Text(
                          'AI-structured notes following institute style',
                          style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Syllabus Topic Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteTopicController,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('e.g. Electoral Bonds Supreme Court Ruling'),
                ),
                const SizedBox(height: 12),
                if (_categories.isNotEmpty) ...[
                  _buildFieldLabel('Syllabus Category'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    decoration: _inputDecoration(null),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c.id.toString(),
                      child: Text(c.name, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedSubjectId = val),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFieldLabel('Target Notes Repository'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedCollectionId,
                  decoration: _inputDecoration(null),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Personal articles only', style: TextStyle(fontSize: 13))),
                    ..._collections.map((c) => DropdownMenuItem(
                      value: c.id.toString(),
                      child: Text('Repository: ${c.name}', style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedCollectionId = val),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _generatingGuide || _noteTopicController.text.trim().isEmpty
                        ? null
                        : _compileCustomNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.civic,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _generatingGuide
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text('Generating...', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ])
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.psychology_rounded, size: 16),
                            const SizedBox(width: 8),
                            Text('Compile Custom Note', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Generated note display or loading state
          if (_generatingGuide)
            _buildAnimatedLoadingCard(
              'Compiling UPSC Study Note...',
              'Applying styling layouts and checking syllabus matches.',
            )
          else if (_generatedGuide != null)
            _buildGeneratedNoteCard()
          else
            _buildEmptyPlaceholder(Icons.menu_book_rounded, 'No study notes generated yet.\nEnter a topic above to start.'),
        ],
      ),
    );
  }

  Widget _buildGeneratedNoteCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI GENERATED NOTES',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.civic, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generatedGuide!['title']!,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savingGuide ? null : _saveGuideToLibrary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.civic,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _savingGuide
                      ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.bookmark_add_rounded, size: 13),
                          const SizedBox(width: 5),
                          Text('Save', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                ),
              ],
            ),
          ),
          // Body
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.5)),
            ),
            child: Text(
              _generatedGuide!['body']!,
              style: GoogleFonts.inter(fontSize: 12.5, height: 1.6, color: AppColors.ink.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Controls input card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.civic.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: AppColors.civic, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Self-Assessment',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        Text(
                          'Generate a 2-question test to verify comprehension',
                          style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Test Topic Outline'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _quizTopicController,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('e.g. Monetary Policy Committee Deficit targets'),
                ),
                const SizedBox(height: 12),
                _buildFieldLabel('Quiz Format Type'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedQuizType,
                  decoration: _inputDecoration(null),
                  items: const [
                    DropdownMenuItem(value: 'gk', child: Text('General Knowledge Statements', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'maths', child: Text('Mathematical LaTeX Equations', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'passage', child: Text('Case Study Reading Passage', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) => setState(() => _selectedQuizType = val!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _generatingQuiz || _quizTopicController.text.trim().isEmpty
                        ? null
                        : _generateQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.civic,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _generatingQuiz
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text('Generating Test...', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ])
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.auto_awesome_rounded, size: 16),
                            const SizedBox(width: 8),
                            Text('Generate Assessment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quiz area
          if (_generatingQuiz)
            _buildAnimatedLoadingCard(
              'Formulating assessment questions...',
              'Creating alternative options, explanation feedback, and verifying facts.',
            )
          else if (_generatedQuiz != null)
            _buildQuizPlayArea()
          else
            _buildEmptyPlaceholder(Icons.workspace_premium_rounded, 'No assessment active.\nType a topic above to generate a practice quiz.'),
        ],
      ),
    );
  }

  Widget _buildQuizPlayArea() {
    final quiz = _generatedQuiz!;
    final questions = quiz['questions'] as List;
    final totalQ = questions.length;
    final isPassage = quiz['passage_text'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Passage card for reading passage format
        if (isPassage) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASSAGE: ${quiz['passage_title']?.toString() ?? 'Study Case Material'}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: AppColors.ink),
                ),
                const Divider(height: 14),
                Text(
                  quiz['passage_text']?.toString() ?? '',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.6, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Score banner after submission
        if (_quizSubmitted) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.civic.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.civic.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.done_all_rounded, color: AppColors.civic, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assessment Completed',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.civic),
                      ),
                      Text(
                        'Review solutions for each question below.',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.civic,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_calculateScore()} / $totalQ',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Question cards
        ...List.generate(questions.length, (qIdx) {
          final isCurrent = qIdx == _activeQuestionIdx;
          // Before submission: only show current. After submission: show all.
          if (!isCurrent && !_quizSubmitted) return const SizedBox.shrink();

          final activeQ = questions[qIdx] as Map;
          final options = activeQ['options'] as List;
          final selectedAnswer = _userAnswers[qIdx];
          final correctAnswer = activeQ['correct_answer'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
                boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question number badge + text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: AppColors.civic.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${qIdx + 1}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.civic),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMathRichText(
                              activeQ['question_statement']?.toString() ?? '',
                              baseStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                            ),
                            if (activeQ['supp_question_statement'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.paper,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.line.withValues(alpha: 0.5)),
                                ),
                                child: _buildMathRichText(
                                  activeQ['supp_question_statement'].toString(),
                                  baseStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.ink.withValues(alpha: 0.75), fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                            if (activeQ['question_prompt'] != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                activeQ['question_prompt'].toString().toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.civic, letterSpacing: 0.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Options
                  ...List.generate(options.length, (optIdx) {
                    final opt = options[optIdx] as Map;
                    final label = opt['label']?.toString() ?? '';
                    final text = opt['text']?.toString() ?? '';
                    final isSel = selectedAnswer == label;
                    final isCorr = label == correctAnswer;

                    Color bgCol = AppColors.paper.withValues(alpha: 0.3);
                    Color borderCol = AppColors.line;
                    Color labelBg = AppColors.paper;
                    Color labelText = AppColors.ink;

                    if (!_quizSubmitted) {
                      if (isSel) {
                        bgCol = AppColors.civic.withValues(alpha: 0.07);
                        borderCol = AppColors.civic;
                        labelBg = AppColors.civic;
                        labelText = Colors.white;
                      }
                    } else {
                      if (isCorr) {
                        bgCol = AppColors.emerald.withValues(alpha: 0.07);
                        borderCol = AppColors.emerald;
                        labelBg = AppColors.emerald;
                        labelText = Colors.white;
                      } else if (isSel) {
                        bgCol = AppColors.berry.withValues(alpha: 0.07);
                        borderCol = AppColors.berry;
                        labelBg = AppColors.berry;
                        labelText = Colors.white;
                      }
                    }

                    return GestureDetector(
                      onTap: _quizSubmitted
                          ? null
                          : () {
                              setState(() {
                                _userAnswers[qIdx] = label;
                              });
                            },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bgCol,
                          border: Border.all(color: borderCol),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 22,
                              width: 22,
                              decoration: BoxDecoration(color: labelBg, borderRadius: BorderRadius.circular(6)),
                              child: Center(
                                child: Text(
                                  label,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: labelText),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMathRichText(
                                text,
                                baseStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            // Correct / Incorrect badge after submission
                            if (_quizSubmitted && isCorr)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('CORRECT', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.emerald)),
                              )
                            else if (_quizSubmitted && isSel && !isCorr)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.berry.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('WRONG', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.berry)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Explanation after submission
                  if (_quizSubmitted) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.paper.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXPLANATION & TIPS',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          _buildMathRichText(
                            activeQ['explanation']?.toString() ?? '',
                            baseStyle: GoogleFonts.inter(fontSize: 11.5, height: 1.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        // Navigation controls (only before submission)
        if (!_quizSubmitted) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: _activeQuestionIdx == 0
                    ? null
                    : () => setState(() => _activeQuestionIdx--),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: const Text('Previous'),
              ),
              if (_activeQuestionIdx < ((_generatedQuiz!['questions'] as List).length) - 1)
                ElevatedButton(
                  onPressed: () => setState(() => _activeQuestionIdx++),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.civic,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Next Question'),
                )
              else
                ElevatedButton(
                  onPressed: _userAnswers.length < ((_generatedQuiz!['questions'] as List).length)
                      ? null
                      : () => setState(() => _quizSubmitted = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.civic,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Submit Assessment'),
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _userAnswers.clear();
                _quizSubmitted = false;
                _activeQuestionIdx = 0;
              });
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('RETRY TEST'),
          ),
        ],
      ],
    );
  }

  // ─── Shared UI Helpers ───────────────────────────────────────────────────────

  Widget _buildAnimatedLoadingCard(String title, String subtitle) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 700),
      builder: (context, opacity, child) => AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 700),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(color: AppColors.civic, strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink.withValues(alpha: 0.75)),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.civic, width: 1.5)),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}

class _FeedbackState {
  final String text;
  final bool isError;
  _FeedbackState({required this.text, required this.isError});
}
