import 'package:flutter/material.dart';

/// Placeholder screen. Replaced by the real one; keep the class name and the const constructor.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Album')),
    body: const Center(child: Text('Album')),
  );
}
