import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../games/common/game_strings.dart';
import '../../games/common/mini_game_definition.dart';
import '../../games/game_registry.dart';
import '../play/play_request.dart';

/// Games available in training. Phase 3 restricts this to released games.
final trainingGamesProvider = Provider<List<MiniGameDefinition>>(
  (ref) => GameRegistry.all,
);

/// Training (section 9.9): released games, random seed, local score only.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final games = ref.watch(trainingGamesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.trainingSubtitle, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          for (final g in games)
            Card(
              child: ListTile(
                minVerticalPadding: 12,
                leading: Text(g.emoji, style: const TextStyle(fontSize: 32)),
                title: Text(g.name(l10n)),
                subtitle: Text(
                  '${GameStrings.category(l10n, g.category)} · ${g.rule(l10n)}',
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => context.push(
                  Routes.play,
                  extra: PlayRequest(
                    gameId: g.id,
                    seed: math.Random().nextInt(0x7FFFFFFF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
