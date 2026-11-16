import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/stack/stack_game.dart';
import 'package:investor_game/features/games/stack/stack_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sliceBlock', () {
    test('perfect within tolerance snaps to the tower', () {
      final r = sliceBlock(prevCenter: 0, prevWidth: 1, center: 0.01, width: 1, tolerance: 0.02);
      expect(r.perfect, isTrue);
      expect(r.center, 0);
      expect(r.width, 1);
      expect(r.cutWidth, 0);
    });

    test('partial overlap to the right trims the overhang', () {
      final r = sliceBlock(prevCenter: 0, prevWidth: 1, center: 0.3, width: 1, tolerance: 0.02);
      expect(r.perfect, isFalse);
      expect(r.width, closeTo(0.7, 1e-9));
      expect(r.center, closeTo(0.15, 1e-9));
      expect(r.cutWidth, closeTo(0.3, 1e-9));
      expect(r.cutCenter, closeTo(0.65, 1e-9));
    });

    test('partial overlap to the left', () {
      final r = sliceBlock(prevCenter: 0, prevWidth: 1, center: -0.4, width: 1, tolerance: 0.02);
      expect(r.width, closeTo(0.6, 1e-9));
      expect(r.center, closeTo(-0.2, 1e-9));
      expect(r.cutCenter, closeTo(-0.7, 1e-9));
    });

    test('no overlap is a miss', () {
      final r = sliceBlock(prevCenter: 0, prevWidth: 1, center: 1.5, width: 1, tolerance: 0.02);
      expect(r.miss, isTrue);
    });
  });

  group('StackGame', () {
    test('runs 600 frames without throwing', () async {
      final g = StackGame(const GameConfig(seed: 1))..onGameResize(Vector2(390, 844));
      await g.onLoad();
      for (var i = 0; i < 600; i++) {
        g.update(1 / 60);
      }
      expect(g.score.value, 0);
    });

    test('sloppy drops eventually end the game', () async {
      final g = StackGame(const GameConfig(seed: 3))..onGameResize(Vector2(390, 844));
      await g.onLoad();
      var over = false;
      g.onGameOver = () => over = true;
      for (var i = 0; i < 6000 && !over; i++) {
        g.update(1 / 60);
        if (i % 7 == 0) g.drop();
      }
      expect(over, isTrue);
    });
  });
}
