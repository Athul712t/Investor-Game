import 'package:flutter/foundation.dart';

/// Draws Flutter's frame-time graphs over the app (Profile > Performance graph).
/// Lets a player on a real phone show whether the UI or the raster thread is slow.
final showPerfOverlay = ValueNotifier<bool>(false);
