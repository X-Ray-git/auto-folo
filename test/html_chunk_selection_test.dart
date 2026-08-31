import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fourier/pages/article/widgets/html_chunk_card.dart';
import 'package:fourier/utils/html_chunk_parser.dart';

void main() {
  testWidgets('macOS mouse drag selects rendered article paragraph', (
    tester,
  ) async {
    SelectedContent? selected;
    final chunk = HtmlChunkParser.parseSync(
      '<p>Fourier article selection remains available on macOS.</p>',
    ).single;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value,
            child: SizedBox(
              width: 600,
              child: HtmlChunkCard(
                chunk: chunk,
                articleId: 'selection-test',
                maxWidth: 600,
              ),
            ),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).last,
    );
    Offset textPosition(int offset) => paragraph.localToGlobal(
      paragraph.getOffsetForCaret(
            TextPosition(offset: offset),
            const Rect.fromLTWH(0, 0, 2, 20),
          ) +
          Offset(0, paragraph.preferredLineHeight - 2),
    );

    final mouse = await tester.startGesture(
      textPosition(2),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await mouse.moveTo(textPosition(26));
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(selected?.plainText, contains('urier article selection'));
  });

  testWidgets('macOS mouse drag selects rendered article heading', (
    tester,
  ) async {
    SelectedContent? selected;
    final chunk = HtmlChunkParser.parseSync(
      '<h2>Selectable Fourier heading</h2>',
    ).single;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value,
            child: SizedBox(
              width: 600,
              child: HtmlChunkCard(
                chunk: chunk,
                articleId: 'selection-test',
                maxWidth: 600,
              ),
            ),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).last,
    );
    Offset textPosition(int offset) => paragraph.localToGlobal(
      paragraph.getOffsetForCaret(
            TextPosition(offset: offset),
            const Rect.fromLTWH(0, 0, 2, 20),
          ) +
          Offset(0, paragraph.preferredLineHeight - 2),
    );
    final mouse = await tester.startGesture(
      textPosition(1),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await mouse.moveTo(textPosition(18));
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(selected?.plainText, contains('electable Fourier'));
  });

  for (final sample in <String, String>{
    'blockquote': '<blockquote><p>Fourier quoted selection remains available.</p></blockquote>',
    'list': '<ul><li>Fourier listed selection remains available.</li></ul>',
  }.entries) {
    testWidgets('macOS mouse drag selects rendered ${sample.key}', (
      tester,
    ) async {
      SelectedContent? selected;
      final chunk = HtmlChunkParser.parseSync(sample.value).single;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (value) => selected = value,
              child: SizedBox(
                width: 600,
                child: HtmlChunkCard(
                  chunk: chunk,
                  articleId: 'selection-test',
                  maxWidth: 600,
                ),
              ),
            ),
          ),
        ),
      );

      final target = find.byType(RichText).evaluate().firstWhere((element) {
        final paragraph = element.renderObject as RenderParagraph;
        return paragraph.text.toPlainText().contains('Fourier');
      });
      final paragraph = target.renderObject as RenderParagraph;
      Offset textPosition(int offset) => paragraph.localToGlobal(
        paragraph.getOffsetForCaret(
              TextPosition(offset: offset),
              const Rect.fromLTWH(0, 0, 2, 20),
            ) +
            Offset(0, paragraph.preferredLineHeight - 2),
      );
      final mouse = await tester.startGesture(
        textPosition(2),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveTo(textPosition(20));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(selected?.plainText, contains('urier'));
    });
  }

  testWidgets('Android long press still selects rendered article text', (
    tester,
  ) async {
    SelectedContent? selected;
    final chunk = HtmlChunkParser.parseSync(
      '<p>Fourier Android article selection remains available.</p>',
    ).single;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value,
            child: SizedBox(
              width: 600,
              child: HtmlChunkCard(
                chunk: chunk,
                articleId: 'selection-test',
                maxWidth: 600,
              ),
            ),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText).last,
    );
    final wordPosition = paragraph.localToGlobal(
      paragraph.getOffsetForCaret(
            const TextPosition(offset: 25),
            const Rect.fromLTWH(0, 0, 2, 20),
          ) +
          Offset(0, paragraph.preferredLineHeight - 2),
    );
    await tester.longPressAt(wordPosition);
    await tester.pump();

    expect(selected?.plainText, contains('selection'));
  });

  testWidgets('Android long press selects rendered list text', (tester) async {
    SelectedContent? selected;
    final chunk = HtmlChunkParser.parseSync(
      '<ol><li>Fourier Android listed selection remains available.</li></ol>',
    ).single;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value,
            child: SizedBox(
              width: 600,
              child: HtmlChunkCard(
                chunk: chunk,
                articleId: 'selection-test',
                maxWidth: 600,
              ),
            ),
          ),
        ),
      ),
    );

    final target = find.byType(RichText).evaluate().firstWhere((element) {
      final paragraph = element.renderObject as RenderParagraph;
      return paragraph.text.toPlainText().contains('Fourier');
    });
    final paragraph = target.renderObject as RenderParagraph;
    final wordPosition = paragraph.localToGlobal(
      paragraph.getOffsetForCaret(
            const TextPosition(offset: 28),
            const Rect.fromLTWH(0, 0, 2, 20),
          ) +
          Offset(0, paragraph.preferredLineHeight - 2),
    );
    await tester.longPressAt(wordPosition);
    await tester.pump();

    expect(selected?.plainText, contains('selection'));
  });
}
