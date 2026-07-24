import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../current_affairs/presentation/article_detail_screen.dart';
import '../../models/workspace_models.dart';

String _formatUpdateDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return "${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}";
}

/// Pulled live from the master article each time this renders, not frozen at save time -
/// so a student's saved copy still reflects new updates/links the admin adds later.
class SourceArticleConnections extends StatelessWidget {
  final StudentMasterArticle? article;

  const SourceArticleConnections({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final article = this.article;
    if (article == null) return const SizedBox.shrink();

    final updates = article.updates;
    final outgoing = article.outgoingRelations;
    final incoming = article.incomingRelations;
    final appearanceCount = article.appearanceCount > 0 ? article.appearanceCount : incoming.length;

    if (updates.isEmpty && outgoing.isEmpty && incoming.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: AppTheme.innerCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link_rounded, size: 15, color: AppColors.civic),
                const SizedBox(width: 6),
                Text(
                  "From the source article",
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              "Live from the published article - updates automatically if the source changes.",
              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted),
            ),

            if (updates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.berry),
                  const SizedBox(width: 4),
                  Text(
                    "CONCEPT UPDATES TIMELINE",
                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.berry, letterSpacing: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < updates.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Text(
                  _formatUpdateDate(updates[i].createdAt),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.berry),
                ),
                const SizedBox(height: 2),
                Text(
                  updates[i].body,
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink, height: 1.5),
                ),
              ],
            ],

            if (outgoing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              Text(
                "RELATED READING",
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              for (final relation in outgoing) ...[
                _ConnectionLinkTile(
                  label: relation.label ?? relation.targetArticle.title,
                  slug: relation.targetArticle.slug,
                ),
                if (relation != outgoing.last) const SizedBox(height: 6),
              ],
            ],

            if (incoming.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              Text(
                "APPEARS IN $appearanceCount ARTICLE${appearanceCount == 1 ? '' : 'S'}",
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              for (final relation in incoming) ...[
                _ConnectionLinkTile(
                  label: relation.label ?? relation.sourceArticle.title,
                  slug: relation.sourceArticle.slug,
                ),
                if (relation != incoming.last) const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionLinkTile extends StatelessWidget {
  final String label;
  final String slug;

  const _ConnectionLinkTile({required this.label, required this.slug});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(slug: slug)));
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.civic),
            ],
          ),
        ),
      ),
    );
  }
}
