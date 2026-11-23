import 'dart:async';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Global test setup: the native Box2D backend must be initialised once.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeForge2D();
  tzdata.initializeTimeZones();
  await testMain();
}
