import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/premium_lock_overlay.dart';
import '../../../../core/utils/html_to_markdown.dart';
import '../../workspace/data/workspace_service.dart';
import '../data/article_service.dart';
import '../models/article_models.dart';
import 'widgets/interactive_pyq_widget.dart';

class ArticleDetailScreen extends StatefulWidget {
  final String slug;
  const ArticleDetailScreen({super.key, required this.slug});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late ArticleService _service;
  late WorkspaceService _workspaceService;
  bool _loading = true;
  String? _error;
  ArticleDetail? _article;
  bool _isLocked = false;
  String _lockReason = 'mains'; // mains vs limit

  // Student tools state
  bool _saving = false;
  bool _markingRead = false;
  String? _statusMessage;
  int? _existingForkId; // cached fork if already saved
  int? _todayReadCount;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = ArticleService(apiClient: apiClient);
    _workspaceService = WorkspaceService(apiClient: apiClient);
    _loadArticleDetails();
  }

  Future<void> _loadArticleDetails() async {
    setState(() {
      _loading = true;
      _error = null;
      _isLocked = false;
    });

    try {
      final detail = await _service.getArticleBySlug(widget.slug);
      
      // Gating checks
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final isMains = detail.contentFamily == 'mains';
      final hasCAPro = apiClient.hasEntitlement('current_affairs.editorial_access');
      bool locked = false;
      String lockReason = 'mains';
      int? todayReadCount;

      if (isMains) {
        if (!hasCAPro) {
          locked = true;
          lockReason = 'mains';
        }
      } else {
        final hasDailyReads = apiClient.hasEntitlement('current_affairs.daily_reads');
        if (!hasCAPro && !hasDailyReads) {
          final prefs = await SharedPreferences.getInstance();
          final todayStr = DateTime.now().toIso8601String().substring(0, 10);
          final rawData = prefs.getString('coaching_hub_reads');
          
          Map<String, dynamic> readData = {
            'date': todayStr,
            'count': 0,
            'readSlugs': <String>[],
          };
          
          if (rawData != null) {
            try {
              final Map<String, dynamic> decoded = jsonDecode(rawData);
              if (decoded['date'] == todayStr) {
                readData['date'] = decoded['date'];
                readData['count'] = decoded['count'] ?? 0;
                readData['readSlugs'] = List<String>.from(decoded['readSlugs'] ?? []);
              }
            } catch (_) {}
          }
          
          final readSlugs = List<String>.from(readData['readSlugs']);
          int count = readData['count'] as int;
          
          if (readSlugs.contains(detail.slug)) {
            locked = false;
            todayReadCount = count;
          } else if (count >= 5) {
            locked = true;
            lockReason = 'limit';
          } else {
            count += 1;
            readSlugs.add(detail.slug);
            readData['count'] = count;
            readData['readSlugs'] = readSlugs;
            await prefs.setString('coaching_hub_reads', jsonEncode(readData));
            locked = false;
            todayReadCount = count;
          }
        }
      }

      if (locked) {
        setState(() {
          _article = detail;
          _isLocked = true;
          _lockReason = lockReason;
          _loading = false;
        });
        return;
      }
      
      // Check if this article is already in student's workspace
      int? forkId;
      try {
        final forks = await _workspaceService.getForks();
        final match = forks.firstWhere((f) => f.masterArticleId == detail.id);
        forkId = match.id;
      } catch (_) {}

      setState(() {
        _article = detail;
        _existingForkId = forkId;
        _todayReadCount = todayReadCount;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _saveArticle() async {
    if (_article == null) return;
    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      final fork = await _workspaceService.saveArticle(_article!.id);
      setState(() {
        _existingForkId = fork.id;
        _statusMessage = "Saved to Notes Space.";
      });
      _triggerSnackbar("Saved to Notes Space successfully!", AppColors.emerald);
    } catch (e) {
      setState(() {
        _statusMessage = "Could not save article.";
      });
      _triggerSnackbar("Failed to save article", AppColors.berry);
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  Future<void> _markAsRead() async {
    if (_article == null) return;
    
    int? forkId = _existingForkId;
    setState(() {
      _markingRead = true;
      _statusMessage = null;
    });

    try {
      // Fork first if not already saved
      if (forkId == null) {
        final fork = await _workspaceService.saveArticle(_article!.id);
        forkId = fork.id;
        _existingForkId = forkId;
      }

      await _workspaceService.updateForkProgress(forkId);
      setState(() {
        _statusMessage = "Marked read. A revision reminder is scheduled.";
      });
      _triggerSnackbar("Marked as read successfully!", AppColors.emerald);
    } catch (e) {
      setState(() {
        _statusMessage = "Could not update progress.";
      });
      _triggerSnackbar("Failed to update progress", AppColors.berry);
    } finally {
      setState(() {
        _markingRead = false;
      });
    }
  }

  void _triggerSnackbar(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null) return "Undated";
    try {
      final date = DateTime.parse(value);
      final monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
      ];
      return "${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}";
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.civic)),
      );
    }

    if (_error != null && _article == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.berry, size: 44),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadArticleDetails, child: const Text("RETRY")),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLocked) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          title: Text(
            "Article Reader",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: PremiumLockOverlay(
            title: _lockReason == 'mains' ? "Unlock Premium Mains Editorial Analysis" : "Daily Free Reading Limit Reached",
            description: _lockReason == 'mains'
                ? "Get access to daily editorial summaries, GS topic-wise mains analysis, issue briefs, and integrated answer writing exercises with Current Affairs Pro."
                : "You have read your 5 free articles for today. Upgrade to Current Affairs Pro for unlimited access to all articles, editorial summaries, and notes workspace.",
            planName: "Current Affairs Pro",
            ctaText: "Upgrade to CA Pro",
          ),
        ),
      );
    }

    final article = _article!;
    final kindLabel = article.contentKind.replaceAll('_', ' ').toUpperCase();
    final heroAsset = article.assets.firstWhere(
      (a) => a.assetType == "thumbnail" || a.assetType == "image",
      orElse: () => ArticleAsset(id: 0, articleId: 0, assetType: '', fileName: '', fileUrl: ''),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          "Article Reader",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_todayReadCount != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD8A8)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: const Color(0xFFEA580C), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Free daily read: $_todayReadCount of 5 used today. Upgrade to Current Affairs Pro for unlimited access.",
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7C2D12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Title Header Card
                  DecoratedBox(
                    decoration: AppTheme.cardDecoration,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.civic.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    kindLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.civic,
                                    ),
                                  ),
                                ),
                              ),
                              if (article.category != null) ...[
                                const SizedBox(width: 6),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.paper,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(
                                      article.category!.name.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 12),
                        Text(
                          article.title,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: AppColors.line),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(article.publicationDate),
                              style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold),
                            ),
                            if (article.sourceName != null) ...[
                              const SizedBox(width: 16),
                              const Icon(Icons.link_outlined, size: 14, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  article.sourceName!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                  // Hero Image
                  if (heroAsset.fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DecoratedBox(
                        decoration: AppTheme.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Image.network(
                              heroAsset.fileUrl,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[200]),
                            ),
                            if (heroAsset.caption != null && heroAsset.caption!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  heroAsset.caption!,
                                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Interactive PYQ section if PYQ hub
                  if (article.contentKind == "prelims_pyq" && article.bodyJson != null)
                    InteractivePrelimsPyqWidget(data: Map<String, dynamic>.from(article.bodyJson))
                  else if (article.contentKind == "mains_pyq" && article.bodyJson != null)
                    InteractiveMainsPyqWidget(data: Map<String, dynamic>.from(article.bodyJson))
                  else ...[
                    // Standard Article Body Paragraphs
                    DecoratedBox(
                      decoration: AppTheme.cardDecoration,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Base Body markdown
                            MarkdownBody(
                              data: htmlToMarkdown(article.body),
                              inlineSyntaxes: [HighlightSyntax()],
                              builders: {'highlight': HighlightBuilder()},
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.inter(fontSize: 14.5, color: AppColors.ink, height: 1.5, fontWeight: FontWeight.w400),
                              ),
                            ),

                            // Sections
                            ...article.sections.map((section) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                Text(
                                  section.heading,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                                const SizedBox(height: 8),
                                MarkdownBody(
                                  data: htmlToMarkdown(section.body),
                                  inlineSyntaxes: [HighlightSyntax()],
                                  builders: {'highlight': HighlightBuilder()},
                                  styleSheet: MarkdownStyleSheet(
                                    p: GoogleFonts.inter(fontSize: 14.5, color: AppColors.ink, height: 1.5, fontWeight: FontWeight.w400),
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Related Readings list
                  if (article.outgoingRelations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      "Related reading",
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: article.outgoingRelations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final rel = article.outgoingRelations[index];
                        return DecoratedBox(
                          decoration: AppTheme.cardDecoration,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              rel.label ?? rel.targetArticle.title,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.civic),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArticleDetailScreen(slug: rel.targetArticle.slug),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Student Tools persistence bottom tray
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, -2))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_statusMessage != null) ...[
                    Center(
                      child: Text(
                        _statusMessage!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.civic, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _saving 
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(
                                  _existingForkId != null ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                  color: AppColors.civic,
                                ),
                          label: Text(
                            _existingForkId != null ? "SAVED COPY" : "SAVE ARTICLE",
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.civic),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppColors.civic, width: 1.5),
                          ),
                          onPressed: _saving || _existingForkId != null ? null : _saveArticle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _markingRead
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                          label: Text(
                            "MARK READ",
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: AppColors.civic,
                          ),
                          onPressed: _markingRead ? null : _markAsRead,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
