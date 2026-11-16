import 'package:flutter/material.dart';

/// Placeholder. Pops `true` when the lesson is completed.
class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text('Lesson $lessonId')),
  );
}
