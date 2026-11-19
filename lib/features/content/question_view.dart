import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/question.dart';
import 'match_question.dart';
import 'myth_fact_card.dart';
import 'question_parts.dart';

/// Renders one question, shows feedback and the explanation, then reports the
/// result through [onAnswered] (exactly once) when the player taps Continue.
class QuestionView extends StatefulWidget {
  QuestionView({required this.question, required this.onAnswered, this.compact = false})
    : super(key: ValueKey(question.id));
  final Question question;
  final ValueChanged<bool> onAnswered;
  final bool compact; // true inside the in-game boost sheet

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  bool? _result;
  String? _note;
  bool _sent = false;

  void _record(bool correct, [String? note]) {
    if (_result != null) return;
    // Sound and haptic on the same frame as the visual change.
    Sound.play(correct ? Sfx.correct : Sfx.wrong);
    correct ? Haptics.medium() : Haptics.heavy();
    setState(() {
      _result = correct;
      _note = note;
    });
  }

  void _continue() {
    if (_sent) return;
    _sent = true;
    widget.onAnswered(_result!);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final p = q.payload;
    final gap = widget.compact ? AppSpace.sm : AppSpace.md;
    Widget prompt(String s, {String? kicker}) => Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kicker != null) Text(kicker, style: context.text.labelSmall),
          Text(s, style: widget.compact ? context.text.titleMedium : context.text.titleLarge),
        ],
      ),
    );
    final body = switch (q.type) {
      QuestionType.mcq => _Choices(
        options: [for (final o in p['options']! as List) o as String],
        correctIndex: p['correctIndex']! as int,
        prompt: prompt(p['prompt']! as String),
        compact: widget.compact,
        onResult: (c, _) => _record(c),
      ),
      QuestionType.trueFalse => _Choices(
        options: const ['True', 'False'],
        correctIndex: p['answer'] == true ? 0 : 1,
        prompt: prompt(p['statement']! as String, kicker: 'TRUE OR FALSE?'),
        big: true,
        compact: widget.compact,
        onResult: (c, _) => _record(c),
      ),
      QuestionType.scenario => _Choices(
        options: [for (final o in p['options']! as List) (o as Map)['text'] as String],
        outcomes: [for (final o in p['options']! as List) (o as Map)['outcome'] as String],
        correctIndex: p['correctIndex']! as int,
        prompt: prompt(p['prompt']! as String, kicker: 'WHAT WOULD YOU DO?'),
        roomy: !widget.compact,
        compact: widget.compact,
        onResult: _record,
      ),
      QuestionType.mythFact => MythFactBody(
        statement: p['statement']! as String,
        isFact: p['answer'] == 'fact',
        compact: widget.compact,
        onResult: _record,
      ),
      QuestionType.match => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          prompt(p['prompt']! as String),
          MatchBody(
            pairs: [for (final e in p['pairs']! as List) ((e as Map)['left'] as String, e['right'] as String)],
            compact: widget.compact,
            onResult: _record,
          ),
        ],
      ),
    };
    final r = _result;
    final title = switch ((q.type, r)) {
      (QuestionType.scenario, true) => 'Wise choice!',
      (QuestionType.scenario, _) => 'Not the wisest choice',
      (QuestionType.match, false) => 'All matched, with a few slips',
      (QuestionType.match, _) => 'Perfect match!',
      (_, true) => 'Correct!',
      _ => 'Not quite',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        if (r != null) ...[
          SizedBox(height: gap),
          FeedbackPanel(correct: r, title: title, explanation: q.explanation, note: _note),
          SizedBox(height: gap),
          ChunkyButton(label: 'Continue', color: r ? AppColors.green : AppColors.card, onPressed: _continue),
        ],
      ],
    );
  }
}

/// mcq, true/false and scenario share this: option pieces that lock after one pick.
class _Choices extends StatefulWidget {
  const _Choices({
    required this.options,
    required this.correctIndex,
    required this.prompt,
    required this.onResult,
    required this.compact,
    this.outcomes,
    this.big = false,
    this.roomy = false,
  });
  final List<String> options;
  final List<String>? outcomes;
  final int correctIndex;
  final Widget prompt;
  final bool big, roomy, compact;
  final void Function(bool correct, String? note) onResult;

  @override
  State<_Choices> createState() => _ChoicesState();
}

class _ChoicesState extends State<_Choices> {
  int? _chosen;

  void _pick(int i) {
    if (_chosen != null) return;
    setState(() => _chosen = i);
    final ok = i == widget.correctIndex;
    final o = widget.outcomes;
    final note = o == null
        ? null
        : ok
        ? o[i]
        : '${o[i]}\n\nThe wiser choice: ${widget.options[widget.correctIndex]}';
    widget.onResult(ok, note);
  }

  OptState _state(int i) {
    final c = _chosen;
    if (c == null) return OptState.idle;
    if (i == c) return i == widget.correctIndex ? OptState.right : OptState.wrong;
    if (i == widget.correctIndex) return OptState.missed;
    return OptState.dim;
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(int i) => OptionTile(
      label: widget.options[i],
      state: _state(i),
      center: widget.big,
      dense: widget.compact,
      roomy: widget.roomy,
      tone: widget.big ? (i == 0 ? AppColors.blue : AppColors.orange) : null,
      leading: widget.big ? null : String.fromCharCode(65 + i),
      onTap: _chosen == null ? () => _pick(i) : null,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.prompt,
        if (widget.big)
          Row(
            children: [
              for (var i = 0; i < widget.options.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: tile(i)),
              ],
            ],
          )
        else
          for (var i = 0; i < widget.options.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: widget.compact ? 6 : 8),
              child: tile(i),
            ),
      ],
    );
  }
}
