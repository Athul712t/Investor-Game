import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'board_tile.dart';

/// The one shape of the four Home loop tiles (chests, album, review, shop): a painted pictogram at the left,
/// title and a one-line status at the right, on a solid tint of [color]. It fills the height its row gives it,
/// so a row of tiles reads as one even block. [pulse] gently scales it while there is something to act on.
class LoopTile extends StatefulWidget {
  const LoopTile({
    super.key,
    required this.color,
    required this.picto,
    required this.title,
    required this.status,
    required this.onTap,
    this.pulse = false,
  });
  final Color color;
  final Widget picto; // 40x40
  final String title, status;
  final VoidCallback onTap;
  final bool pulse;

  @override
  State<LoopTile> createState() => _LoopTileState();
}

class _LoopTileState extends State<LoopTile> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final _scale = Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  void _sync() {
    final on = widget.pulse && !context.reduceMotion;
    if (on && !_c.isAnimating) _c.repeat(reverse: true);
    if (!on && (_c.isAnimating || _c.value != 0)) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LoopTile old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: BoardTile(
      fill: AppColors.tint(widget.color, 0.62),
      onTap: widget.onTap,
      label: '${widget.title}, ${widget.status}',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          ExcludeSemantics(child: SizedBox.square(dimension: 40, child: widget.picto)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(widget.title, style: context.text.titleLarge, maxLines: 1),
                ),
                Text(widget.status, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
