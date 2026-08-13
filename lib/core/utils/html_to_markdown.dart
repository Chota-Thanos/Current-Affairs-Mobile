import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

// Delimiters for the pointer-detail marker htmlToMarkdown() emits and
// PointerDetailSyntax matches. Unlikely to collide with real article text —
// exported so text_anchor.dart's markdownToPlainText() can flatten the same
// marker for the non-interactive (search/annotation) text view.
const String pointerMarkerStart = '§POINTER§';
const String pointerMarkerMid = '§POINTER_DETAIL§';
const String pointerMarkerEnd = '§POINTER_END§';

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

  // Links: <a href="url">text</a> -> [text](url), so flutter_markdown keeps them tappable
  mdText = mdText.replaceAllMapped(
    RegExp(r'<a\b[^>]*href="([^"]*)"[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true),
    (match) => '[${match.group(2)}](${match.group(1)})',
  );

  // Mains Note "pointer" blocks — a short always-visible label with a fuller
  // explanation hidden until tapped, matching the web's magnifying-glass
  // <details>/<summary> disclosure. Must run after the conversions above (so
  // the captured label/detail already carry proper markdown for bold/links)
  // but before the generic tag-stripper below, which would otherwise merge
  // the label and detail together with no separator and no way to hide
  // either — every point in a section running together into one unreadable
  // block. PointerDetailSyntax/PointerDetailBuilder turn this marker into a
  // real tap-to-expand widget; see PointerDetailSyntax/PointerDetailBuilder below.
  mdText = mdText.replaceAllMapped(
    RegExp(
      r'<details[^>]*>\s*<summary[^>]*>(.*?)</summary>\s*<div[^>]*data-type="detailsContent"[^>]*>(.*?)</div>\s*</details>',
      caseSensitive: false,
      dotAll: true,
    ),
    (match) => '\n\n$pointerMarkerStart${(match.group(1) ?? '').trim()}$pointerMarkerMid${(match.group(2) ?? '').trim()}$pointerMarkerEnd\n\n',
  );

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

/// Custom inline syntax matching the pointer-detail marker htmlToMarkdown()
/// emits for a Mains Note "point": `§POINTER§label§POINTER_DETAIL§detail§POINTER_END§`.
class PointerDetailSyntax extends md.InlineSyntax {
  // md.InlineSyntax's constructor always builds its RegExp with
  // multiLine: true and offers no dotAll option, so `.` alone would stop at
  // the first newline inside a multi-line detail (e.g. one containing its own
  // markdown bullet list). `[\s\S]` matches any character including
  // newlines without needing the dotAll flag at all.
  PointerDetailSyntax()
      : super('$pointerMarkerStart([\\s\\S]*?)$pointerMarkerMid([\\s\\S]*?)$pointerMarkerEnd');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final label = match.group(1) ?? '';
    final detail = match.group(2) ?? '';

    final element = md.Element('pointerDetail', [md.Text(label)]);
    element.attributes['detail'] = detail;

    parser.addNode(element);
    return true;
  }
}

/// Renders a `pointerDetail` element as a tap-to-expand row — the label stays
/// always visible with a 🔍 marker after it; tapping reveals the fuller
/// explanation below. Mirrors the web's native `<details>`/`<summary>` disclosure,
/// just implemented as a stateful widget since Flutter has no equivalent
/// built-in element. Label and detail are themselves still markdown (bold,
/// links already converted by htmlToMarkdown before this marker is matched),
/// so each is rendered through a nested MarkdownBody rather than plain Text,
/// reusing the same formatting pipeline instead of re-implementing it.
class PointerDetailBuilder extends MarkdownElementBuilder {
  final MarkdownTapLinkCallback? onTapLink;
  PointerDetailBuilder({this.onTapLink});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final label = element.textContent;
    final detail = element.attributes['detail'] ?? '';
    return _PointerDetail(
      label: label,
      detail: detail,
      baseStyle: preferredStyle,
      onTapLink: onTapLink,
    );
  }
}

class _PointerDetail extends StatefulWidget {
  final String label;
  final String detail;
  final TextStyle? baseStyle;
  final MarkdownTapLinkCallback? onTapLink;

  const _PointerDetail({
    required this.label,
    required this.detail,
    this.baseStyle,
    this.onTapLink,
  });

  @override
  State<_PointerDetail> createState() => _PointerDetailState();
}

class _PointerDetailState extends State<_PointerDetail> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.baseStyle ?? const TextStyle();
    final muted = base.color?.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -16,
                    top: 1,
                    child: Text('→', style: base.copyWith(color: muted, fontWeight: FontWeight.bold)),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MarkdownBody(
                          data: widget.label,
                          onTapLink: widget.onTapLink,
                          styleSheet: MarkdownStyleSheet(p: base),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '🔍',
                          style: TextStyle(
                            fontSize: (base.fontSize ?? 14) * 0.8,
                            color: base.color?.withValues(alpha: _open ? 1 : 0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: MarkdownBody(
                data: widget.detail,
                onTapLink: widget.onTapLink,
                styleSheet: MarkdownStyleSheet(p: base.copyWith(color: base.color?.withValues(alpha: 0.75))),
              ),
            ),
        ],
      ),
    );
  }
}
