import 'basket/basket.dart';
import 'common/mini_game_definition.dart';
import 'minigolf/minigolf.dart';
import 'penalty/penalty.dart';
import 'survival/survival.dart';

/// All mini-games. Adding a game = create its folder + add it here.
abstract final class GameRegistry {
  static const List<MiniGameDefinition> all = [
    SurvivalGame(),
    MinigolfGame(),
    PenaltyGame(),
    BasketGame(),
  ];

  static MiniGameDefinition? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }
}
