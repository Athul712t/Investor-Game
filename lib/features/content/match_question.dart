import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'question_parts.dart';

/// Two columns: tap a left item, then its partner on the right.
class MatchBody extends StatefulWidget {
  const MatchBody({super.key, required this.pairs, required this.onResult});
  final List<(String, String)> pairs;
  final ValueChanged<bool> onResult;

  @override
  State<MatchBody> createState() => _MatchBodyState();
}

class _MatchBodyState extends State<MatchBody> {
  late final List<int> _rightOrder = List.generate(widget.pairs.length, (i) => i)..shuffle(Random());
  final Set<int> _matched = {};
  int? _selected; // left index
  int? _wrongRight; // right pair index flashing red
  int _mistakes = 0;
  int _shakes = 0;

  bool get _done => _matched.length == widget.pairs.length;

  void _tapLeft(int i) {
    if (_matched.contains(i) || _done) return;
    setState(() => _selected = _selected == i ? null : i);
  }

  void _tapRight(int pairIndex) {
    final s = _selected;
    if (s == null || _matched.contains(pairIndex) || _done) return;
    if (s == pairIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _matched.add(s);
        _selected = null;
      });
      if (_done) widget.onResult(_mistakes == 0);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _mistakes++;
        _shakes++;
        _wrongRight = pairIndex;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongRight = null);
      });
    }
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Shake(
                      shakes: _selected == i ? _shakes : 0,
                      child: OptionTile(
                        label: widget.pairs[i].$1,
                        state: _matched.contains(i)
                            ? OptState.right
                            : _selected == i
                            ? (_wrongRight != null ? OptState.wrong : OptState.selected)
                            : OptState.idle,
                        onTap: () => _tapLeft(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (final p in _rightOrder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Shake(
                      shakes: _wrongRight == p ? _shakes : 0,
                      child: OptionTile(
                        label: widget.pairs[p].$2,
                        state: _matched.contains(p)
                            ? OptState.right
                            : _wrongRight == p
                            ? OptState.wrong
                            : OptState.idle,
                        onTap: () => _tapRight(p),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      if (!_done)
        Text(
          _selected == null ? 'Tap an item on the left' : 'Now tap its match on the right',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
    ],
  );
}
