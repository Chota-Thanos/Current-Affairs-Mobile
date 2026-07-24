import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../current_affairs/data/article_service.dart';
import '../../current_affairs/models/article_models.dart';
import '../../current_affairs/presentation/article_detail_screen.dart';
import '../../workspace/data/workspace_service.dart';
import '../../workspace/models/workspace_models.dart';
import 'onboarding_tour_widget.dart';

class DashboardHomeScreen extends StatefulWidget {
  final Function(int index, {String? subjectName}) onNavigate;

  const DashboardHomeScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  late ArticleService _articleService;
  late WorkspaceService _workspaceService;

  bool _loading = true;
  String? _error;

  // Loaded data
  List<ArticleSummary> _highlightArticles = [];
  List<ArticleSummary> _latestUpdates = [];
  StudentFork? _continueReadingFork;
  List<CategoryNode> _prelimsSubjects = [];

  // Onboarding Guided Tour Keys & States
  final GlobalKey _keyBanner = GlobalKey();
  final GlobalKey _keySubjects = GlobalKey();
  final GlobalKey _keyHighlights = GlobalKey();
  final GlobalKey _keyContinueReading = GlobalKey();

  bool _showTour = false;
  bool _dismissedTourBanner = false;
  List<TourStep> _tourSteps = [];

  void _startTour() {
    setState(() {
      _showTour = true;
    });
  }

  GlobalKey? _getGlobalKeyBySelector(String selector) {
    final clean = selector.replaceAll('#', '').trim().toLowerCase();
    switch (clean) {
      case 'banner':
      case 'tour-banner':
        return _keyBanner;
      case 'subjects':
      case 'tour-subjects':
        return _keySubjects;
      case 'highlights':
      case 'tour-highlights':
        return _keyHighlights;
      case 'continue_reading':
      case 'continue-reading':
      case 'tour-continue-reading':
        return _keyContinueReading;
      default:
        return null;
    }
  }

  Future<void> _fetchTourSteps() async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    try {
      final res = await apiClient.get('/api/v1/onboarding/tours?key=mobile_home_tour');
      if (res != null && res['steps'] is List) {
        final List<TourStep> fetched = [];
        for (var step in res['steps']) {
          final selector = step['selector'] as String? ?? '';
          final key = _getGlobalKeyBySelector(selector);
          if (key != null) {
            fetched.add(
              TourStep(
                targetKey: key,
                title: step['title'] ?? '',
                body: step['body'] ?? '',
                badge: step['badge'] ?? '',
              ),
            );
          }
        }
        if (mounted && fetched.isNotEmpty) {
          setState(() {
            _tourSteps = fetched;
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch dynamic tour steps: $e");
    }
  }

  // Selected quote
  late final String _quote;

  final List<String> _quotes = [
    "\"The beautiful thing about learning is that no one can take it away from you.\" — B.B. King",
    "\"Success is not final, failure is not fatal: it is the courage to continue that counts.\" — Winston Churchill",
    "\"Arise, awake, and stop not till the goal is reached.\" — Swami Vivekananda",
    "\"The best way to predict your future is to create it.\" — Abraham Lincoln",
    "\"Believe you can and you're halfway there.\" — Theodore Roosevelt",
  ];

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];

    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _articleService = ArticleService(apiClient: apiClient);
    _workspaceService = WorkspaceService(apiClient: apiClient);

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      
      // Fetch tour steps
      _fetchTourSteps();

      // 1. Fetch reading dashboard data for continue reading and statistics (skip in guest mode)
      dynamic dashboard;
      if (!apiClient.isGuestMode) {
        dashboard = await _workspaceService.getReadingDashboard(limit: 5);
      }
      
      // 2. Fetch daily current affairs for highlights
      final highlightRes = await _articleService.getArticles(
        contentKind: 'daily_current_affairs',
        limit: 2,
      );

      // 3. Fetch latest updates (e.g. editorial summaries & topic notes)
      final updatesRes = await _articleService.getArticles(
        contentKind: 'daily_editorial_summary',
        limit: 2,
      );

      final notesRes = await _articleService.getArticles(
        contentKind: 'mains_topic_note',
        limit: 1,
      );

      // 4. Fetch real prelims subjects for the "Explore by subject" row
      final prelimsFilters = await _articleService.getFilters('daily_current_affairs', 'prelims');
      final realSubjects = prelimsFilters.categories
          .where((c) => c.nodeType == 'subject' && !c.name.toLowerCase().startsWith('test current affairs'))
          .toList();

      if (!mounted) return;
      setState(() {
        if (dashboard != null && dashboard.continueReading != null && dashboard.continueReading.isNotEmpty) {
          _continueReadingFork = dashboard.continueReading.first;
        } else {
          _continueReadingFork = null;
        }

        _highlightArticles = highlightRes['items'] as List<ArticleSummary>;

        final editorialItems = updatesRes['items'] as List<ArticleSummary>;
        final notesItems = notesRes['items'] as List<ArticleSummary>;
        _latestUpdates = [...editorialItems, ...notesItems];

        _prelimsSubjects = realSubjects;

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

  String _todayLabel() {
    final now = DateTime.now();
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${monthNames[now.month - 1]} ${now.day}, ${now.year}";
  }

  String _relativeTime(String? isoDate) {
    if (isoDate == null) return "";
    final date = DateTime.tryParse(isoDate);
    if (date == null) return "";
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes.clamp(0, 59)}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${monthNames[date.month - 1]} ${date.day}";
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning, Aspirant";
    } else if (hour < 17) {
      return "Good Afternoon, Aspirant";
    }
    return "Good Evening, Aspirant";
  }

  IconData _getSubjectIcon(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains("polity")) return Icons.account_balance_rounded;
    if (nameLower.contains("economy")) return Icons.trending_up_rounded;
    if (nameLower.contains("history")) return Icons.museum_rounded;
    if (nameLower.contains("geography")) return Icons.public_rounded;
    if (nameLower.contains("science") || nameLower.contains("technology")) return Icons.science_rounded;
    if (nameLower.contains("environment")) return Icons.eco_rounded;
    return Icons.menu_book_rounded;
  }

  Color _getSubjectColor(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains("polity")) return const Color(0xFFE0E7FF); // Light Indigo
    if (nameLower.contains("economy")) return const Color(0xFFFFE4E6); // Light Rose
    if (nameLower.contains("history")) return const Color(0xFFFFEDD5); // Light Orange
    if (nameLower.contains("geography")) return const Color(0xFFD1FAE5); // Light Emerald
    if (nameLower.contains("science") || nameLower.contains("technology")) return const Color(0xFFF3E8FF); // Light Purple
    if (nameLower.contains("environment")) return const Color(0xFFECFCCB); // Light Lime
    return const Color(0xFFF1F5F9); // Slate-100
  }

  Color _getSubjectTextColor(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains("polity")) return const Color(0xFF4F46E5); // Indigo
    if (nameLower.contains("economy")) return const Color(0xFFE11D48); // Rose
    if (nameLower.contains("history")) return const Color(0xFFD97706); // Amber
    if (nameLower.contains("geography")) return const Color(0xFF059669); // Emerald
    if (nameLower.contains("science") || nameLower.contains("technology")) return const Color(0xFF9333EA); // Purple
    if (nameLower.contains("environment")) return const Color(0xFF65A30D); // Lime
    return AppColors.ink;
  }

  void _onSubjectTapped(CategoryNode subject) {
    final subjectName = subject.name;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Explore $subjectName", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: Text("Do you want to check $subjectName in Prelims or Mains?"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onNavigate(1, subjectName: subjectName); // 1 = Prelims
              },
              child: const Text("PRELIMS"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onNavigate(2, subjectName: subjectName); // 2 = Mains
              },
              child: const Text("MAINS"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = Provider.of<ApiClient>(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.brandNavy,
            onRefresh: _loadDashboardData,
            child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.brandNavy))
            : _error != null
                ? _buildErrorWidget()
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. GREETING & QUOTE
                        Text(
                          _getGreeting(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _quote,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSubscriptionBanner(apiClient),
                        const SizedBox(height: 16),
                        if (!_dismissedTourBanner) ...[
                          _buildTourBanner(),
                          const SizedBox(height: 24),
                        ],

                        // 2. EXPLORE BY SUBJECT
                        _buildSectionHeader("EXPLORE BY SUBJECT"),
                        const SizedBox(height: 10),
                        Container(
                          key: _keySubjects,
                          child: _buildExploreSubjectsRow(),
                        ),
                        const SizedBox(height: 24),

                        // 3. DAILY HIGHLIGHTS
                        _buildSectionHeader("DAILY HIGHLIGHTS", rightWidget: Text(
                          _todayLabel(),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted),
                        )),
                        const SizedBox(height: 10),
                        Container(
                          key: _keyHighlights,
                          child: _buildDailyHighlightsCarousel(),
                        ),
                        const SizedBox(height: 24),

                        // 4. CONTINUE READING
                        _buildSectionHeader("CONTINUE READING"),
                        const SizedBox(height: 10),
                        Container(
                          key: _keyContinueReading,
                          child: _buildContinueReadingCard(),
                        ),
                        const SizedBox(height: 24),

                        // 5. LATEST UPDATES
                        _buildSectionHeader("LATEST UPDATES"),
                        const SizedBox(height: 10),
                        _buildLatestUpdatesList(),
                        const SizedBox(height: 24),

                        // 8. RETENTION TIP
                        _buildRetentionTipCard(),
                      ],
                    ),
                  ),
      ),
      if (_showTour)
        OnboardingTourWidget(
          steps: _tourSteps.isNotEmpty
              ? _tourSteps
              : [
                  TourStep(
                    targetKey: _keyBanner,
                    badge: "Step 1 of 4: Member Center",
                    title: "Subscription Status Tracker",
                    body: "View your active daily reading tier, validation tokens, and plan tier limits here at the top of your dashboard.",
                  ),
                  TourStep(
                    targetKey: _keySubjects,
                    badge: "Step 2 of 4: Subject Explorer",
                    title: "Explore UPSC Syllabus Subjects",
                    body: "Tap any subject icon to jump directly into category-filtered Prelims mock tests or Mains writing boards.",
                  ),
                  TourStep(
                    targetKey: _keyHighlights,
                    badge: "Step 3 of 4: Daily News Feed",
                    title: "Curated Current Affairs Editorials",
                    body: "Read unlimited daily current affairs analysis. Tap any editorial card to open the reader and tag revision notes.",
                  ),
                  TourStep(
                    targetKey: _keyContinueReading,
                    badge: "Step 4 of 4: Active Prep Tracker",
                    title: "Resume Where You Left Off",
                    body: "Instantly resume reading your last opened article or view notes repositories that you modified recently.",
                  ),
                ],
          onClose: () => setState(() => _showTour = false),
          themeColor: AppColors.brandNavy,
        ),
      ],
    ),
  );
}

  Widget _buildSectionHeader(String title, {Widget? rightWidget}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.ink.withOpacity(0.6),
            letterSpacing: 0.8,
          ),
        ),
        if (rightWidget != null) ...[
          const Spacer(),
          rightWidget,
        ],
      ],
    );
  }

  Widget _buildExploreSubjectsRow() {
    if (_prelimsSubjects.isEmpty) {
      return Container(
        height: 76,
        alignment: Alignment.centerLeft,
        child: Text(
          "No subjects available yet.",
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _prelimsSubjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final subject = _prelimsSubjects[index];
          final sName = subject.name;
          final bgColor = _getSubjectColor(sName);
          final txtColor = _getSubjectTextColor(sName);
          return GestureDetector(
            onTap: () => _onSubjectTapped(subject),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: bgColor,
                  child: Icon(
                    _getSubjectIcon(sName),
                    color: txtColor,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sName,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyHighlightsCarousel() {
    if (_highlightArticles.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: const Center(child: Text("No daily highlights today.")),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _highlightArticles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final art = _highlightArticles[index];
          final cat = art.category?.name ?? "Current Affairs";
          final subjColor = _getSubjectTextColor(cat);

          return Container(
            width: MediaQuery.of(context).size.width * 0.78,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: art.slug)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      color: const Color(0xFFE2E8F0),
                      child: art.primaryAsset != null
                          ? Image.network(art.primaryAsset!.fileUrl, fit: BoxFit.cover)
                          : Stack(
                              children: [
                                Positioned.fill(child: Container(color: AppColors.brandNavy)),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: subjColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          cat.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "HOT",
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          art.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          art.body.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinueReadingCard() {
    if (_continueReadingFork == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                "No articles in progress.",
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => widget.onNavigate(1), // Go to Prelims
                child: const Text("START READING"),
              ),
            ],
          ),
        ),
      );
    }

    final fork = _continueReadingFork!;
    final title = fork.masterArticle?.title ?? fork.forkedTitle ?? "IAS Article";
    final category = fork.masterArticle?.category?.name ?? "General Studies";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x03000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (fork.masterArticle?.slug != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: fork.masterArticle!.slug)),
            );
          }
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: AppColors.brandNavy,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history_rounded, size: 13, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  "GS PAPER • ${category.toUpperCase()}",
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Simple mock linear progress
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (fork.progressPercent / 100.0).clamp(0.1, 1.0),
                                backgroundColor: AppColors.paper,
                                color: AppColors.brandNavy,
                                minHeight: 3.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, color: AppColors.brandNavy, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestUpdatesList() {
    if (_latestUpdates.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: const Center(child: Text("No new updates.")),
      );
    }

    return Column(
      children: _latestUpdates.map((art) {
        final isSummary = art.contentKind == "daily_editorial_summary";
        final tagLabel = isSummary ? "MAINS SUMMARY" : "MAINS NOTES";
        final tagBg = isSummary ? const Color(0xFFEEF2F6) : const Color(0xFFFFEDD5);
        final tagIcon = isSummary ? "📄" : "📖";

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: AppColors.surface,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: tagBg,
              child: Text(tagIcon, style: const TextStyle(fontSize: 14)),
            ),
            title: Row(
              children: [
                Text(
                  tagLabel,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isSummary ? Colors.indigo : Colors.orange,
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeTime(art.publicationDate),
                  style: GoogleFonts.inter(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                art.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: art.slug)),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRetentionTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6), // Very light warm orange
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEAE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFFECE8),
            child: Text("💡", style: GoogleFonts.inter(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Retention Tip",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Summarizing your recent reading into notes can improve recall by up to 50%.",
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.ink.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => widget.onNavigate(3), // Go to My Notes tab
            child: Text(
              "START",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFC2410C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner(ApiClient apiClient) {
    final hasCAPro = apiClient.hasEntitlement('current_affairs.editorial_access');
    final isPremium = hasCAPro;

    return Container(
      key: _keyBanner,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium 
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
              : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? const Color(0xFF334155) : const Color(0xFFFFD8A8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isPremium ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF97316).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.verified_user_rounded : Icons.info_outline_rounded,
              color: isPremium ? const Color(0xFF10B981) : const Color(0xFFF97316),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? "Premium Account Active" : "Free Tier Account",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: isPremium ? Colors.white : const Color(0xFF7C2D12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium 
                      ? "Unlimited Daily News & Mains Editorial summaries unlocked." 
                      : "Daily limit: 5 Prelims reads. Mains editorial analysis is locked.",
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isPremium ? const Color(0xFFCBD5E1) : const Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse("${ApiConstants.webAppUrl}/pricing");
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  debugPrint("Could not launch $url");
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                "Upgrade",
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
              onPressed: _loadDashboardData,
              child: const Text("RETRY"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.brandNavy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Interactive Product Tour",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Let us show you how mock tests and mentors work.",
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF4338CA),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _startTour,
            child: Text(
              "Start",
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, color: Color(0xFF4338CA), size: 18),
            onPressed: () => setState(() => _dismissedTourBanner = true),
          ),
        ],
      ),
    );
  }
}
