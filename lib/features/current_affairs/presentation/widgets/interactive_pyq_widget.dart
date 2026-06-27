import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
class InteractivePrelimsPyqWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  const InteractivePrelimsPyqWidget({super.key, required this.data});

  @override
  State<InteractivePrelimsPyqWidget> createState() => _InteractivePrelimsPyqWidgetState();
}

class _InteractivePrelimsPyqWidgetState extends State<InteractivePrelimsPyqWidget> {
  String? _selectedLabel;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final statement = widget.data['question_statement']?.toString() ?? '';
    final suppStatement = widget.data['supp_question_statement']?.toString();
    final prompt = widget.data['question_prompt']?.toString();
    final optionsRaw = widget.data['options'] as List? ?? [];
    final correctAnswer = widget.data['correct_answer']?.toString() ?? '';
    final explanation = widget.data['explanation']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.civic.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "PRELIMS PYQ PRACTICE",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.civic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Question Statement
          Text(
            statement,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.45),
          ),

          if (suppStatement != null && suppStatement.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                suppStatement,
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted, height: 1.4, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          if (prompt != null && prompt.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              prompt,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.civic),
            ),
          ],
          const SizedBox(height: 18),

          // Options Grid/List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: optionsRaw.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final option = optionsRaw[index];
              final label = option['label']?.toString() ?? '';
              final text = option['text']?.toString() ?? '';

              final isSelected = _selectedLabel == label;
              final isCorrect = label == correctAnswer;

              Color bg = Colors.white;
              Color borderCol = AppColors.line;
              double borderWidth = 1.5;
              Color textCol = AppColors.ink;

              if (!_submitted) {
                if (isSelected) {
                  bg = AppColors.civic.withValues(alpha: 0.05);
                  borderCol = AppColors.civic;
                  borderWidth = 2;
                }
              } else {
                if (isCorrect) {
                  bg = AppColors.emerald.withValues(alpha: 0.08);
                  borderCol = AppColors.emerald;
                  borderWidth = 2;
                  textCol = AppColors.emerald;
                } else if (isSelected) {
                  bg = AppColors.berry.withValues(alpha: 0.08);
                  borderCol = AppColors.berry;
                  borderWidth = 2;
                  textCol = AppColors.berry;
                }
              }

              return InkWell(
                onTap: _submitted
                    ? null
                    : () {
                        setState(() {
                          _selectedLabel = label;
                        });
                      },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderCol, width: borderWidth),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 24,
                        width: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.civic : AppColors.paper,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            text,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textCol,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          // Submit Actions
          if (!_submitted)
            ElevatedButton(
              onPressed: _selectedLabel == null
                  ? null
                  : () {
                      setState(() {
                        _submitted = true;
                      });
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("CHECK ANSWER"),
            )
          else ...[
            // Solution Explanation details
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Solution Explanation:",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    explanation,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedLabel = null;
                  _submitted = false;
                });
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.line),
              ),
              child: const Text("RETRY QUESTION"),
            ),
          ],
        ],
      ),
    );
  }
}

class InteractiveMainsPyqWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  const InteractiveMainsPyqWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final statement = data['question_statement']?.toString() ?? '';
    final modelAnswer = data['model_answer']?.toString();
    final guidelines = data['writing_guidelines']?.toString();
    final tagsRaw = data['mains_syllabus_tags'] as List? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.saffron.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "MAINS PYQ TOPIC",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.saffron,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Question Statement
          Text(
            statement,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.45),
          ),
          const SizedBox(height: 12),

          // Syllabus tags
          if (tagsRaw.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tagsRaw.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag.toString(),
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],

          const Divider(color: AppColors.line),
          const SizedBox(height: 10),

          // Accordion elements for Model Answer Guidelines
          if (modelAnswer != null && modelAnswer.trim().isNotEmpty) ...[
            ExpansionTile(
              title: Text("Model Answer Outline", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              shape: const Border(), // const Border() replaces Border.none
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    modelAnswer,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ],

          if (guidelines != null && guidelines.trim().isNotEmpty) ...[
            ExpansionTile(
              title: Text("Writing Guidelines & Evaluation Standards", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              shape: const Border(),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paper.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    guidelines,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

