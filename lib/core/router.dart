import 'package:go_router/go_router.dart';

import '../features/content/lesson_screen.dart';
import '../features/games/_shared/game_host.dart';
import '../features/home_hub/shell.dart';
import '../features/story/story_map_screen.dart';

/// Pushed routes return a value:
///   `context.push<bool>('/lesson/$lessonId')` gives true when completed
///   `context.push<GameResult>('/play/$gameId?target=N')` gives the last run
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Shell()),
    GoRoute(
      path: '/lesson/:id',
      builder: (_, s) => LessonScreen(lessonId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/play/:id',
      builder: (_, s) => GameHostScreen(
        gameId: s.pathParameters['id']!,
        targetScore: int.tryParse(s.uri.queryParameters['target'] ?? ''),
      ),
    ),
    GoRoute(path: '/story', builder: (_, _) => const StoryMapScreen()),
  ],
);
