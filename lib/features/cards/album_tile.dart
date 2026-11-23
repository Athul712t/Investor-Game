import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Placeholder tile on Home. Replaced by the real one; keep the class name and the const constructor.
class AlbumTile extends StatelessWidget {
  const AlbumTile({super.key});

  @override
  Widget build(BuildContext context) => Panel(
    onTap: () => context.push('/album'),
    child: Text('Album', style: context.text.titleLarge),
  );
}
