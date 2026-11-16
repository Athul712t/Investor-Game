import 'package:flutter/material.dart';

/// Placeholder for Story Mode (chapter map). Full screen route at /story.
class StoryMapScreen extends StatelessWidget {
  const StoryMapScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('Story')),
  );
}
