import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Converts standard rich text editor HTML to Markdown for rendering in flutter_markdown.
String htmlToMarkdown(String html) {
  if (html.isEmpty) return '';

  String mdText = html;

  // Convert highlights and spans
  // 1. Double span with color and background-color
  mdText = mdText.replaceAllMapped(
    RegExp(r'<span style="background-color:\s*(#[0-9a-fA-F]{6});?\s*color:\s*(#[0-9a-fA-F]{6})[^"]*">(.*?)</span>', caseSensitive: false, dotAll: true),
    (match) => '::${match.group(1)}::**${match.group(3)}**::',
  );
  mdText = mdText.replaceAllMapped(
    RegExp(r'<span style="color:\s*(#[0-9a-fA-F]{6});?\s*background-color:\s*(#[0-9a-fA-F]{6})[^"]*">(.*?)</span>', caseSensitive: false, dotAll: true),
    (match) => '::${match.group(2)}::**${match.group(3)}**::',
  );

  // 2. Mark with style background-color
  mdText = mdText.replaceAllMapped(
    RegExp(r'<mark style="background-color:\s*(#[0-9a-fA-F]{6})[^"]*">(.*?)</mark>', caseSensitive: false, dotAll: true),
    (match) => '::${match.group(1)}::${match.group(2)}::',
  );
  mdText = mdText.replaceAllMapped(
    RegExp(r'<mark[^>]*>(.*?)</mark>', caseSensitive: false, dotAll: true),
    (match) => '::#fef08a::${match.group(1)}::',
  );

  // 3. Span style background-color
  mdText = mdText.replaceAllMapped(
    RegExp(r'<span style="background-color:\s*(#[0-9a-fA-F]{6})[^"]*">(.*?)</span>', caseSensitive: false, dotAll: true),
    (match) => '::${match.group(1)}::${match.group(2)}::',
  );

  // 4. Span style color
  mdText = mdText.replaceAllMapped(
    RegExp(r'<span style="color:\s*(#[0-9a-fA-F]{6})[^"]*">(.*?)</span>', caseSensitive: false, dotAll: true),
    (match) => '**${match.group(2)}**',
  );

  // Remove other spans but keep content
  mdText = mdText.replaceAll(RegExp(r'<span\b[^>]*>', caseSensitive: false), '');
  mdText = mdText.replaceAll(RegExp(r'</span>', caseSensitive: false), '');

  // Paragraphs
  mdText = mdText.replaceAll(RegExp(r'<p\b[^>]*>', caseSensitive: false), '');
  mdText = mdText.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');

  // Headings
  mdText = mdText.replaceAllMapped(RegExp(r'<h1\b[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true), (m) => '# ${m.group(1)}\n\n');
  mdText = mdText.replaceAllMapped(RegExp(r'<h2\b[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true), (m) => '## ${m.group(1)}\n\n');
  mdText = mdText.replaceAllMapped(RegExp(r'<h3\b[^>]*>(.*?)</h3>', caseSensitive: false, dotAll: true), (m) => '### ${m.group(1)}\n\n');
  mdText = mdText.replaceAllMapped(RegExp(r'<h4\b[^>]*>(.*?)</h4>', caseSensitive: false, dotAll: true), (m) => '#### ${m.group(1)}\n\n');

  // Strong / Bold
  mdText = mdText.replaceAll(RegExp(r'<strong\b[^>]*>', caseSensitive: false), '**');
  mdText = mdText.replaceAll(RegExp(r'</strong>', caseSensitive: false), '**');
  mdText = mdText.replaceAll(RegExp(r'<b\b[^>]*>', caseSensitive: false), '**');
  mdText = mdText.replaceAll(RegExp(r'</b>', caseSensitive: false), '**');

  // Emphasis / Italic
  mdText = mdText.replaceAll(RegExp(r'<em\b[^>]*>', caseSensitive: false), '*');
  mdText = mdText.replaceAll(RegExp(r'</em>', caseSensitive: false), '*');
  mdText = mdText.replaceAll(RegExp(r'<i\b[^>]*>', caseSensitive: false), '*');
  mdText = mdText.replaceAll(RegExp(r'</i>', caseSensitive: false), '*');

  // Underline
  mdText = mdText.replaceAll(RegExp(r'<u\b[^>]*>', caseSensitive: false), '_');
  mdText = mdText.replaceAll(RegExp(r'</u>', caseSensitive: false), '_');

  // Lists
  mdText = mdText.replaceAll(RegExp(r'<ul\b[^>]*>', caseSensitive: false), '\n');
  mdText = mdText.replaceAll(RegExp(r'</ul>', caseSensitive: false), '\n');
  mdText = mdText.replaceAll(RegExp(r'<ol\b[^>]*>', caseSensitive: false), '\n');
  mdText = mdText.replaceAll(RegExp(r'</ol>', caseSensitive: false), '\n');

  // Convert list items
  mdText = mdText.replaceAllMapped(RegExp(r'<li\b[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true), (m) => '* ${(m.group(1) ?? "").trim()}\n');

  // Break lines
  mdText = mdText.replaceAll(RegExp(r'<br\b\s*/?>', caseSensitive: false), '\n');

  // Strip other unknown HTML tags but keep their contents
  mdText = mdText.replaceAll(RegExp(r'<[^>]+>'), '');

  // Trim extra spaces and newlines
  mdText = mdText.trim();
  mdText = mdText.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return mdText;
}

/// Custom inline syntax for parsing highlight segments: `::#colorHex::text::`
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'::(#[0-9a-fA-F]{6})::((?:(?!::).)+)::');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final colorHex = match.group(1);
    final text = match.group(2);

    final element = md.Element('highlight', [md.Text(text!)]);
    element.attributes['color'] = colorHex!;

    parser.addNode(element);
    return true;
  }
}

/// Custom builder to render `highlight` tags with their respective background colors.
class HighlightBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final colorHex = element.attributes['color'] ?? '#fef08a';
    final text = element.textContent;

    // Convert hex string to Color
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Text.rich(
      TextSpan(
        text: text,
        style: preferredStyle?.copyWith(
          backgroundColor: color,
        ),
      ),
    );
  }
}
