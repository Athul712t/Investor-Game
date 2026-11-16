import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';

/// Placeholder: tap to score. Replaced by the real game.
class MergeGame extends ArcadeGame with TapCallbacks {
  MergeGame(super.config);

  @override
  List<PowerupType> get boosts => const [PowerupType.doubleScore];

  int _step = 1;

  @override
  Future<void> onLoad() async {
    add(TextComponent(text: 'Tap to score', anchor: Anchor.center, position: size / 2));
  }

  @override
  void onTapDown(TapDownEvent event) {
    score.value += _step;
    if (score.value % 3 == 0) coins.value++;
    if (score.value == 5) requestBoost();
    if (score.value >= 20) gameOver();
  }

  @override
  void applyPowerup(PowerupType type) => _step = 2;

  @override
  void revive() => score.value = 10;
}
