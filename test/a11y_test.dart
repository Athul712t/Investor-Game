import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/core/widgets.dart';
import 'package:investor_game/features/content/question_parts.dart';

void main() {
  testWidgets('custom buttons can be activated by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              ChunkyButton(label: 'Go', onPressed: () => taps.add('go')),
              OptionTile(label: 'Option', state: OptState.idle, onTap: () => taps.add('option')),
            ],
          ),
        ),
      ),
    );
    for (final label in ['Go', 'Option']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: label);
      tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
    }
    expect(taps, ['go', 'option']);
    handle.dispose();
  });
}
