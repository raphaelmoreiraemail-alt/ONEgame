import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/game_registry.dart';

/// Visual preview tool (not a regular test): renders games to PNG.
/// `PREVIEW_DIR=/tmp/out PREVIEW_GAMES=minigolf,bowling PREVIEW_STEPS=240 flutter test test/render/preview_test.dart`
void main() {
  final dir = Platform.environment['PREVIEW_DIR'];
  test('preview', () async {
    if (dir == null) return;
    final games = (Platform.environment['PREVIEW_GAMES'] ?? 'minigolf').split(
      ',',
    );
    final steps = int.parse(Platform.environment['PREVIEW_STEPS'] ?? '120');
    for (final id in games) {
      final def = GameRegistry.byId(id)!;
      final sim = def.createSim(
        GameContext(
          seed: 2938471923,
          modifierId: Platform.environment['PREVIEW_MOD'],
        ),
      );
      for (var i = 0; i < steps && !sim.over; i++) {
        sim.tick();
        sim.step++;
        sim.cues.clear();
      }
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec)..scale(2);
      canvas.drawRect(Arena.rect, ui.Paint()..color = sim.backgroundColor);
      sim.render(canvas);
      sim.particles.render(canvas);
      final img = await rec.endRecording().toImage(720, 1280);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$id.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      sim.dispose();
    }
  });
}
