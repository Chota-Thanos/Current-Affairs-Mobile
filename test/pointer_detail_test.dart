import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:current_affairs_pro/core/utils/html_to_markdown.dart';
import 'package:current_affairs_pro/core/utils/text_anchor.dart';

/// Mains Note "pointer" blocks (`<details><summary>label</summary>`
/// `<div data-type="detailsContent">detail</div></details>`) used to hit the
/// generic "strip unknown tags but keep the text" fallback in
/// htmlToMarkdown(), which merged the label and detail together with no
/// separator and no way to hide either — every point in a section ran
/// together into one unreadable block. These tests cover the fix: the HTML
/// -> marker conversion, the marker -> tap-to-expand widget, and the
/// marker -> plain text flattening used by the Notes Workspace's
/// non-interactive annotation view.
void main() {
  test('a pointer block converts to the marker, not the generic tag-strip fallback', () {
    const html = '<details><summary>1952: First Delimitation Commission Act</summary>'
        '<div data-type="detailsContent">Parliament enacted the first Delimitation Commission Act.</div></details>';

    final markdown = htmlToMarkdown(html);

    expect(markdown, contains('§POINTER§1952: First Delimitation Commission Act§POINTER_DETAIL§'
        'Parliament enacted the first Delimitation Commission Act.§POINTER_END§'));
    // The old fallback would have concatenated label and detail directly —
    // guard against that regression explicitly.
    expect(markdown, isNot(contains('Act.Parliament')));
  });

  test('stacked pointers stay separated, not merged into one block', () {
    const html = '<details><summary>Point One</summary><div data-type="detailsContent">Detail one.</div></details>'
        '<details><summary>Point Two</summary><div data-type="detailsContent">Detail two.</div></details>';

    final markdown = htmlToMarkdown(html);

    expect(markdown, contains('§POINTER§Point One§POINTER_DETAIL§Detail one.§POINTER_END§'));
    expect(markdown, contains('§POINTER§Point Two§POINTER_DETAIL§Detail two.§POINTER_END§'));
  });

  test('bold and links inside label/detail are already markdown by the time the marker is built', () {
    const html = '<details><summary><strong>1976:</strong> 42nd Amendment</summary>'
        '<div data-type="detailsContent">Froze seats. <a href="https://waytoias.com/x">Source</a></div></details>';

    final markdown = htmlToMarkdown(html);

    expect(markdown, contains('§POINTER§**1976:** 42nd Amendment§POINTER_DETAIL§'
        'Froze seats. [Source](https://waytoias.com/x)§POINTER_END§'));
  });

  test('a multi-line detail (its own bullet list) is captured whole, not cut at the first line', () {
    // md.InlineSyntax hardcodes multiLine and has no dotAll option, so this
    // guards the [\s\S] workaround actually spans newlines.
    const html = '<details><summary>Composition</summary><div data-type="detailsContent">'
        '<ul><li>A retired judge.</li><li>The CEC.</li></ul></div></details>';

    final markdown = htmlToMarkdown(html);

    expect(markdown, contains('* A retired judge.'));
    expect(markdown, contains('* The CEC.'));
    expect(markdown, contains('§POINTER_END§'));
  });

  test('markdownToPlainText flattens the marker to readable text, not raw delimiters', () {
    const markdown = 'Intro line.\n\n§POINTER§1952: First Act§POINTER_DETAIL§Parliament enacted it.§POINTER_END§\n\nOutro.';

    final plain = markdownToPlainText(markdown);

    expect(plain, contains('1952: First Act — Parliament enacted it.'));
    expect(plain, isNot(contains('§POINTER§')));
    expect(plain, isNot(contains('§POINTER_DETAIL§')));
  });

  testWidgets('the detail stays hidden until the label is tapped, then reveals', (WidgetTester tester) async {
    const markdown = '§POINTER§1952: First Delimitation Commission Act§POINTER_DETAIL§'
        'Parliament enacted the first Delimitation Commission Act.§POINTER_END§';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownBody(
            data: markdown,
            inlineSyntaxes: [PointerDetailSyntax()],
            builders: {'pointerDetail': PointerDetailBuilder()},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Label always visible; detail hidden until opened.
    expect(find.textContaining('1952: First Delimitation Commission Act'), findsOneWidget);
    expect(find.textContaining('Parliament enacted the first Delimitation Commission Act.'), findsNothing);

    await tester.tap(find.textContaining('1952: First Delimitation Commission Act'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Parliament enacted the first Delimitation Commission Act.'), findsOneWidget);
  });
}
