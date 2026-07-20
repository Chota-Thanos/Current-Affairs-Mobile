import '../../features/workspace/models/workspace_models.dart';

/// Reduces htmlToMarkdown() output to clean, readable plain text so it can be
/// shown in a SelectableText for annotation. Character offsets computed against
/// this output are stable across reloads since it's a pure function of the body.
String markdownToPlainText(String markdown) {
  var text = markdown;

  // Highlight spans -> inner text only
  text = text.replaceAllMapped(RegExp(r'::#[0-9a-fA-F]{6}::((?:(?!::).)+)::'), (m) => m.group(1) ?? '');
  // Links -> label text only
  text = text.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '');
  // Heading markers
  text = text.replaceAllMapped(RegExp(r'^#{1,6}\s+', multiLine: true), (_) => '');
  // Bullet markers -> a plain dot, consumed before generic asterisk stripping below
  text = text.replaceAllMapped(RegExp(r'^\*\s+', multiLine: true), (_) => '• ');
  // Remaining bold/italic markers
  text = text.replaceAll('**', '');
  text = text.replaceAll('*', '');
  // Underline markers
  text = text.replaceAll('_', '');

  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

const int _contextLength = 32;

/// Builds a resilient anchor (quote + surrounding context) from a selection's
/// start/end offsets within [fullText]. Mirrors the web app's text-anchor.ts so
/// highlight/note data is interchangeable across platforms.
TextAnchor? computeAnchorFromSelection(String fullText, int start, int end) {
  if (start < 0 || end > fullText.length || start >= end) return null;
  final quote = fullText.substring(start, end).trim();
  if (quote.isEmpty) return null;

  final prefix = fullText.substring((start - _contextLength).clamp(0, fullText.length), start);
  final suffixEnd = (start + quote.length + _contextLength).clamp(0, fullText.length);
  final suffixStart = (start + quote.length).clamp(0, fullText.length);
  final suffix = suffixStart <= suffixEnd ? fullText.substring(suffixStart, suffixEnd) : '';

  return TextAnchor(quote: quote, prefix: prefix, suffix: suffix, start: start);
}

/// Finds the best-matching [start, end) range for a stored anchor within
/// [fullText], tolerant of minor body edits since the anchor was created.
(int, int)? locateAnchor(String fullText, TextAnchor anchor) {
  if (anchor.quote.isEmpty) return null;

  int matchStart = -1;

  if (anchor.prefix.isNotEmpty || anchor.suffix.isNotEmpty) {
    final withContext = '${anchor.prefix}${anchor.quote}${anchor.suffix}';
    final contextIndex = fullText.indexOf(withContext);
    if (contextIndex != -1) matchStart = contextIndex + anchor.prefix.length;
  }

  if (matchStart == -1) {
    final nearStart = anchor.start < 0 ? 0 : anchor.start;
    final searchFrom = (nearStart - anchor.quote.length).clamp(0, fullText.length);
    final around = fullText.indexOf(anchor.quote, searchFrom);
    matchStart = around != -1 ? around : fullText.indexOf(anchor.quote);
  }

  if (matchStart == -1) return null;
  final matchEnd = matchStart + anchor.quote.length;
  if (matchEnd > fullText.length) return null;
  return (matchStart, matchEnd);
}
