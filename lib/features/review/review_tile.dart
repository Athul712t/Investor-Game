import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Placeholder tile on Home. Replaced by the real one; keep the class name and the const constructor.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key});

  @override
  Widget build(BuildContext context) => Panel(
    onTap: () => context.push('/review'),
    child: Text('Review', style: context.text.titleLarge),
  );
}
