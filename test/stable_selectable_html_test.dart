import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:fourier/pages/article/widgets/stable_selectable_html.dart';

void main() {
  testWidgets(
    'keeps the parser and selection alive across an unrelated rebuild',
    (tester) async {
      SelectedContent? selected;
      final rebuild = ValueNotifier<int>(0);
      const data =
          'The selected summary stays visible while another article updates.';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (value) => selected = value,
              child: ValueListenableBuilder<int>(
                valueListenable: rebuild,
                builder: (context, _, child) => SizedBox(
                  width: 600,
                  child: StableSelectableHtml(
                    data: data,
                    renderConfigurationKey: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final parserBefore = tester.element(find.byType(HtmlParser));
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
        textPosition(4),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveTo(textPosition(22));
      await tester.pump();
      await mouse.up();
      await tester.pump();
      expect(selected?.plainText, contains('selected summary'));

      rebuild.value++;
      await tester.pump();

      expect(tester.element(find.byType(HtmlParser)), same(parserBefore));
      expect(selected?.plainText, contains('selected summary'));
    },
  );

  testWidgets('replaces the parser when the HTML data changes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StableSelectableHtml(
            data: 'first summary',
            renderConfigurationKey: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final parserBefore = tester.element(find.byType(HtmlParser));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StableSelectableHtml(
            data: 'second summary',
            renderConfigurationKey: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.element(find.byType(HtmlParser)), isNot(same(parserBefore)));
    expect(
      find
          .byType(RichText)
          .evaluate()
          .map((element) => element.renderObject)
          .whereType<RenderParagraph>()
          .any((paragraph) => paragraph.text.toPlainText().contains('second')),
      isTrue,
    );
  });
}
