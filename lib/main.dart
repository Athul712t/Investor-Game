import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/cloud.dart';
import 'core/diagnostics.dart';
import 'core/notifications.dart';
import 'core/profile.dart';
import 'core/router.dart';
import 'core/sfx.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  Sound.init(prefs);
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  container.read(cloudProvider.notifier).start();
  container.read(reminderServiceProvider).sync();
  runApp(UncontrolledProviderScope(container: container, child: const InvestorGameApp()));
}

class InvestorGameApp extends StatelessWidget {
  const InvestorGameApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: showPerfOverlay,
    builder: (_, show, _) => MaterialApp.router(
      title: 'Investor Game',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: show,
      theme: buildTheme(),
      routerConfig: router,
    ),
  );
}
