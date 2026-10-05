import 'package:ancient_anguish_client/services/alias/alias_highlighting_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const keywords = {'fb', 'ga'};

  List<String> hits(String input) => AliasHighlightingController.aliasRanges(
    input,
    keywords,
  ).map((r) => r.textInside(input)).toList();

  test('a bare alias keyword is highlighted', () {
    expect(hits('fb'), ['fb']);
    expect(hits('fb goblin'), ['fb']);
  });

  test('a longer word that starts with the keyword is not', () {
    expect(hits('fbx'), isEmpty);
    expect(hits('fireball'), isEmpty);
  });

  test('only the first word of each command counts', () {
    expect(hits('say fb'), isEmpty);
    expect(hits('fb; ga;say hi'), ['fb', 'ga']);
    expect(AliasHighlightingController.aliasRanges(' n; fb', keywords), [
      const TextRange(start: 4, end: 6),
    ]);
  });

  testWidgets('buildTextSpan colours the keyword and nothing else', (
    tester,
  ) async {
    final controller = AliasHighlightingController(text: 'fb goblin')
      ..aliasKeywords = keywords;
    late TextSpan span;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(),
            withComposing: false,
          );
          return const SizedBox();
        },
      ),
    );
    final children = span.children!.cast<TextSpan>();
    expect(children.map((c) => c.text), ['fb', ' goblin']);
    expect(children.first.style?.color, AliasHighlightingController.aliasColor);
    expect(children.last.style, isNull);
  });

  testWidgets('a real TextField renders the keyword blue, and repaints '
      'when the alias set changes', (tester) async {
    final controller = AliasHighlightingController(text: 'ga sword');
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: TextField(controller: controller)),
      ),
    );

    Color? colourOf(String word) {
      final editable = tester.allRenderObjects
          .whereType<RenderEditable>()
          .single;
      Color? found;
      editable.text!.visitChildren((span) {
        if (span is TextSpan && span.text == word) found = span.style?.color;
        return true;
      });
      return found;
    }

    expect(colourOf('ga'), isNull);
    controller.aliasKeywords = {'ga'};
    await tester.pump();
    expect(colourOf('ga'), AliasHighlightingController.aliasColor);
  });

  testWidgets('the keyword stays blue while the keyboard is composing it, '
      'as Android keyboards do for the word being typed', (tester) async {
    final controller = AliasHighlightingController()
      ..aliasKeywords = {'fb'}
      ..value = const TextEditingValue(
        text: 'fb',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
    late TextSpan span;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(),
            withComposing: true,
          );
          return const SizedBox();
        },
      ),
    );
    final only = span.children!.cast<TextSpan>().single;
    expect(only.text, 'fb');
    expect(only.style?.color, AliasHighlightingController.aliasColor);
    expect(only.style?.decoration, TextDecoration.underline);
  });

  testWidgets('composing over part of a line underlines only that part', (
    tester,
  ) async {
    final controller = AliasHighlightingController()
      ..aliasKeywords = {'fb'}
      ..value = const TextEditingValue(
        text: 'fb gob',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 3, end: 6),
      );
    late TextSpan span;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(),
            withComposing: true,
          );
          return const SizedBox();
        },
      ),
    );
    final parts = span.children!.cast<TextSpan>().toList();
    expect(parts.map((p) => p.text), ['fb', ' ', 'gob']);
    expect(parts[0].style?.color, AliasHighlightingController.aliasColor);
    expect(parts[0].style?.decoration, isNull);
    expect(parts[1].style, isNull);
    expect(parts[2].style?.color, isNull);
    expect(parts[2].style?.decoration, TextDecoration.underline);
  });
}
