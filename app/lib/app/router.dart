import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/l10n.dart';
import '../features/game_lab/game_lab_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/play/play_request.dart';
import '../features/play/play_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/results/official_outcome_panel.dart';
import '../features/results/results_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/training/training_screen.dart';
import '../games/common/game_types.dart';

abstract final class Routes {
  static const home = '/';
  static const leaderboard = '/leaderboard';
  static const profile = '/profile';
  static const settings = '/settings';
  static const training = '/training';
  static const gameLab = '/game-lab';
  static const play = '/play';
  static const results = '/results';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ShellScaffold(shell: shell),
        branches: [
          _branch(Routes.home, const HomeScreen()),
          _branch(Routes.leaderboard, const LeaderboardScreen()),
          _branch(Routes.profile, const ProfileScreen()),
          _branch(Routes.settings, const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: Routes.play,
        builder: (context, state) =>
            PlayScreen(request: state.extra! as PlayRequest),
      ),
      GoRoute(
        path: Routes.results,
        builder: (context, state) {
          final (req, result) = state.extra! as (PlayRequest, GameResult);
          return ResultsScreen(
            request: req,
            result: result,
            extra: req.official ? OfficialOutcomePanel(result: result) : null,
          );
        },
      ),
      GoRoute(
        path: Routes.training,
        builder: (context, state) => const TrainingScreen(),
      ),
      // Game Lab is a debug-only tool (section 9.11).
      if (kDebugMode)
        GoRoute(
          path: Routes.gameLab,
          builder: (context, state) => const GameLabScreen(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.alarm),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard_outlined),
            label: l10n.navLeaderboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: l10n.navProfile,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
