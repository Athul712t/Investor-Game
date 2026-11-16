import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'question_parts.dart';

const _pairColors = [AppColors.blue, AppColors.yellow, AppColors.teal, AppColors.orange, AppColors.red];

/// Two columns: tap a left item, then its partner on the right. A made pair shares a colour and a number tag.
class MatchBody extends StatefulWidget {
  const MatchBody({super.key, required this.pairs, required this.onResult, this.compact = false});
  final List<(String, String)> pairs;
  final ValueChanged<bool> onResult;
  final bool compact;

  @override
  State<MatchBody> createState() => _MatchBodyState();
}

class _MatchBodyState extends State<MatchBody> {
  late final List<int> _rightOrder = List.generate(widget.pairs.length, (i) => i)..shuffle(Random());
  final List<int> _made = []; // pair indexes in the order they were matched
  int? _selected; // left index
  int? _wrongRight; // right pair index flashing red
  int _mistakes = 0;

  bool get _done => _made.length == widget.pairs.length;

  void _tapLeft(int i) {
    if (_made.contains(i) || _done) return;
    setState(() => _selected = _selected == i ? null : i);
  }

  void _tapRight(int pairIndex) {
    final s = _selected;
    if (s == null || _made.contains(pairIndex) || _done) return;
    if (s == pairIndex) {
      HapticFeedback.selectionClick();
      Sound.play(Sfx.coin);
      setState(() {
        _made.add(s);
        _selected = null;
      });
      if (_done) widget.onResult(_mistakes == 0);
    } else {
      HapticFeedback.heavyImpact();
      Sound.play(Sfx.wrong, volume: 0.7);
      setState(() {
        _mistakes++;
        _wrongRight = pairIndex;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongRight = null);
      });
    }
  }

  Widget _tile(int pair, String label, {required bool left}) {
    final rank = _made.indexOf(pair);
    final made = rank >= 0;
    final OptState state;
    if (made) {
      state = OptState.paired;
    } else if (left && _selected == pair) {
      state = _wrongRight != null ? OptState.wrong : OptState.selected;
    } else if (!left && _wrongRight == pair) {
      state = OptState.wrong;
    } else {
      state = OptState.idle;
    }
    return OptionTile(
      label: label,
      state: state,
      dense: true,
      tone: made ? _pairColors[rank % _pairColors.length] : null,
      tag: made ? '${rank + 1}' : null,
      onTap: made || _done ? null : () => left ? _tapLeft(pair) : _tapRight(pair),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < widget.pairs.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 7, 0, 4),
                    child: _tile(i, widget.pairs[i].$1, left: true),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                for (final p in _rightOrder)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 7, 0, 4),
                    child: _tile(p, widget.pairs[p].$2, left: false),
                  ),
              ],
            ),
          ),
        ],
      ),
      if (!_done)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _selected == null ? 'Tap an item on the left' : 'Now tap its match on the right',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ),
    ],
  );
}
