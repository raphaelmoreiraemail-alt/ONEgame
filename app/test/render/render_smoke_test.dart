import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/game_registry.dart';

/// Plays every game (plain and with each supported modifier) with a fixed
/// pattern of taps and swipes, rendering frames along the way: any
/// exception in a render path fails here rather than on a phone.
void main() {
  for (final def in GameRegistry.all) {
    for (final mod in <String?>[null, ...def.supportedModifiers]) {
      test('${def.id}${mod == null ? '' : ' +$mod'} renders', () {
        final sim = def.createSim(GameContext(seed: 424242, modifierId: mod));
        var frames = 0;
        for (var i = 0; i < 6 * stepsPerSecond && !sim.over; i++) {
          // A press every 0.75 s, held 0.25 s while sliding down-right.
          final phase = i % 90;
          final at = Offset(120 + (i % 7) * 20.0, 300 + (i % 5) * 50.0);
          if (phase == 0) sim.onPointer(PointerPhase.down, 1, at);
          if (phase > 0 && phase < 30) {
            sim.onPointer(
              PointerPhase.move,
              1,
              at.translate(phase * 2, phase * 3),
            );
          }
          if (phase == 30) {
            sim.onPointer(PointerPhase.up, 1, at.translate(60, 90));
          }
          sim
            ..tick()
            ..step += 1
            ..cues.clear();
          if (i % 40 == 0) {
            _render(sim);
            frames++;
          }
        }
        _render(sim);
        expect(frames, greaterThan(0));
        sim.dispose();
      });
    }
  }
}

void _render(GameSim sim) {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  sim
    ..render(canvas)
    ..particles.render(canvas);
  rec.endRecording().dispose();
}
