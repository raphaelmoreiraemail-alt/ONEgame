import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/core/l10n/l10n.dart';
import 'package:onegame/games/common/game_strings.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/game_registry.dart';

/// `shared/games.json` is the game catalog used by Cloud Functions (rotation,
/// anti-cheat bounds). It must match the registry.
///
/// To regenerate: `UPDATE_SHARED=1 flutter test test/shared_catalog_test.dart`.
void main() {
  test('shared/games.json matches GameRegistry', () async {
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final catalog = [
      for (final g in GameRegistry.all)
        {
          'id': g.id,
          'category': g.category.name,
          'rulesVersion': g.rulesVersion,
          'maxDurationMs': g.maxDuration.inMilliseconds,
          'modifiers': g.supportedModifiers.toList()..sort(),
          'scoreMin': g.scoreBounds.min,
          'scoreMax': g.scoreBounds.max,
          'name': {'fr': g.name(fr), 'en': g.name(en)},
        },
    ];
    final modifiers = {
      for (final m in Modifiers.all)
        m: {
          'fr': GameStrings.modifierName(fr, m),
          'en': GameStrings.modifierName(en, m),
        },
    };
    final json =
        '${const JsonEncoder.withIndent('  ').convert({'games': catalog, 'modifiers': modifiers})}\n';
    final file = File('../shared/games.json');
    if (Platform.environment['UPDATE_SHARED'] == '1') {
      file.writeAsStringSync(json);
    }
    expect(file.existsSync(), isTrue, reason: 'run with UPDATE_SHARED=1');
    expect(file.readAsStringSync(), json, reason: 'run with UPDATE_SHARED=1');
  });
}
