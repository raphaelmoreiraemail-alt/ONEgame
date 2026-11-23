import 'dart:async';

import 'dart:io';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:onegame/games/motflash/motflash.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Global test setup: the native Box2D backend must be initialised once.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeForge2D();
  tzdata.initializeTimeZones();
  for (final lang in ['fr', 'en']) {
    Dictionary.register(
      lang,
      File('assets/data/words_$lang.txt').readAsLinesSync(),
    );
  }
  await testMain();
}
