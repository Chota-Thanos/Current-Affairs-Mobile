import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class FlashcardCardWidget extends StatefulWidget {
  final String question;
  final String answer;
  final String source;
  final int index;
  final int total;

  const FlashcardCardWidget({
    super.key,
    required this.question,
    required this.answer,
    required this.source,
    required this.index,
    required this.total,
  });

  @override
  State<FlashcardCardWidget> createState() => _FlashcardCardWidgetState();
}

class _FlashcardCardWidgetState extends State<FlashcardCardWidget> {
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant FlashcardCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      setState(() {
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.civic.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "CARD ${widget.index + 1} OF ${widget.total}",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.civic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.question,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          
          if (!_revealed)
            InkWell(
              onTap: () {
                setState(() {
                  _revealed = true;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.civic.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.civic.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology_alt_rounded, color: AppColors.civic, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "TAP TO REVEAL ANSWER",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.civic,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.saffron.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ANSWER",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.saffron),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.answer,
                    style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.ink.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Source: ${widget.source}",
              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}
