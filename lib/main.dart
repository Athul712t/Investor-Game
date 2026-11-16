import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runApp(const ProviderScope(child: InvestorGameApp()));

class InvestorGameApp extends StatelessWidget {
  const InvestorGameApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Investor Game',
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const ModeSelectScreen(),
  );
}

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const modes = [
      (
        'Pure Game',
        'Just play. Questions are optional boosts.',
        Icons.sports_esports,
      ),
      (
        'Story Mode',
        'Learn through a story, unlock games.',
        Icons.auto_stories,
      ),
      ('Pure Edu', 'Lessons and quizzes, no game.', Icons.school),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Investor Game')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final m in modes)
            Card(
              child: ListTile(
                leading: Icon(m.$3),
                title: Text(m.$1),
                subtitle: Text(m.$2),
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}
