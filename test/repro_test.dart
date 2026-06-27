import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:current_affairs_pro/core/utils/html_to_markdown.dart';

void main() {
  test('htmlToMarkdown test', () {
    const htmlInput = '<p><span>The Union government has amended the FCRA Rules, 2011, introducing <mark style="background-color: #fef08a">sweeping changes</mark> to tighten norms for NGOs.</span></p>'
        '<p><strong>Aim or Objective:</strong> To enhance transparency.</p>'
        '<ul><li><p><span><strong>Activity Schedule:</strong> Applicants must choose their activities.</span></p></li></ul>';
    
    final markdownOutput = htmlToMarkdown(htmlInput);
    
    expect(markdownOutput, contains('The Union government has amended the FCRA Rules, 2011, introducing ::#fef08a::sweeping changes:: to tighten norms for NGOs.'));
    expect(markdownOutput, contains('**Aim or Objective:** To enhance transparency.'));
    expect(markdownOutput, contains('* **Activity Schedule:** Applicants must choose their activities.'));
  });

  testWidgets('Markdown rendering with highlight support', (WidgetTester tester) async {
    const markdownData = 'Hello ::#bbf7d0::green highlight:: and standard text.';
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownBody(
            data: markdownData,
            inlineSyntaxes: [HighlightSyntax()],
            builders: {'highlight': HighlightBuilder()},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify text renders
    expect(find.textContaining('green highlight'), findsOneWidget);
  });
}
