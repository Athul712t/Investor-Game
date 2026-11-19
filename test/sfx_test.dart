import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/sfx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('throttle: one event per gap per key, keys are independent', () {
    final t = Throttle();
    expect(t.allow('coin', 0, 70), isTrue);
    expect(t.allow('coin', 30, 70), isFalse);
    expect(t.allow('coin', 69, 70), isFalse);
    expect(t.allow('coin', 70, 70), isTrue);
    expect(t.allow('tick', 71, 90), isTrue); // other key is unaffected
    expect(t.allow('coin', 71, 0), isTrue); // a zero gap always passes (heavy haptics)
  });

  test('a flood of calls reaches the player only a few times a second', () {
    final t = Throttle();
    var played = 0;
    for (var ms = 0; ms < 1000; ms++) {
      if (t.allow('coin', ms, 70)) played++; // one call per millisecond
    }
    expect(played, lessThanOrEqualTo(15));
  });

  test('sound is silent before init, so tests and screens never touch the audio plugin', () {
    Sound.play(Sfx.coin);
    Sound.tap();
    Haptics.medium();
  });
}
