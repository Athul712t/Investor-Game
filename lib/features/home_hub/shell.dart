import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../content/learn_screen.dart';
import '../games/arcade_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// Selected bottom tab: 0 Home, 1 Learn, 2 Play, 3 Profile.
final tabProvider = NotifierProvider<TabIndex, int>(TabIndex.new);

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return AppScaffold(
      body: IndexedStack(index: tab, children: const [HomeScreen(), LearnScreen(), ArcadeScreen(), ProfileScreen()]),
      bottom: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: ref.read(tabProvider.notifier).go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.sports_esports_rounded), label: 'Play'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
