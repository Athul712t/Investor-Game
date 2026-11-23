import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/notifications.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/profile/notify_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeScheduler implements ReminderScheduler {
  FakeScheduler(this.grant);
  final bool grant;
  final calls = <String>[];
  DateTime? at;
  String? body;
  @override
  Future<bool> requestPermission() async {
    calls.add('ask');
    return grant;
  }

  @override
  Future<void> schedule(DateTime at, String title, String body) async {
    calls.add('schedule');
    this.at = at;
    this.body = body;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');
}

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, ReminderScheduler s, {String profile = '{"streak":4}'}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({'profile_v1': profile});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs), reminderSchedulerProvider.overrideWithValue(s)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: NotifySection()),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('on schedules, off cancels, subtitle follows', (tester) async {
    final s = FakeScheduler(true);
    final hours = List.filled(24, 0);
    hours[7] = 5;
    final c = await pump(tester, s, profile: '{"streak":4,"playHours":$hours}');
    expect(find.text('Off'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(c.read(profileProvider).notify, isTrue);
    expect(s.calls, ['ask', 'schedule']);
    expect(s.at!.hour, 7);
    expect(s.body, 'A minute of play keeps your 4 day streak going.');
    expect(find.text('At 7 am, about when you usually play'), findsOneWidget);

    await tester.tap(find.text('Daily reminder'));
    await tester.pumpAndSettle();
    expect(c.read(profileProvider).notify, isFalse);
    expect(s.calls.last, 'cancel');
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('denied permission keeps it off and says so calmly', (tester) async {
    final s = FakeScheduler(false);
    final c = await pump(tester, s);
    await tester.tap(find.text('Daily reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(profileProvider).notify, isFalse);
    expect(s.calls, ['ask']);
    expect(find.textContaining('No problem'), findsOneWidget);
  });

  test('default scheduler path does not throw without a plugin', () async {
    SharedPreferences.setMockInitialValues({'profile_v1': '{"notify":true}'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    await c.read(reminderServiceProvider).sync();
    expect(await LocalReminderScheduler().requestPermission(), isFalse);
    expect(await const NoopReminderScheduler().requestPermission(), isFalse);
  });

  testWidgets('semantics and target size at 360x640, scale 1.3', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, FakeScheduler(true));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.byType(NotifySection)).getSemanticsData().hasFlag(SemanticsFlag.hasToggledState),
      isTrue,
    );
    expect(tester.getSize(find.byType(NotifySection)).height, greaterThanOrEqualTo(48));
    handle.dispose();
  });
}
