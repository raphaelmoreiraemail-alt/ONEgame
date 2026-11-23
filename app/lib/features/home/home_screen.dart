import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/audio/feedback.dart';
import '../../core/l10n/l10n.dart';
import '../../core/settings/settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/alarm_clock.dart';
import '../../data/daily/daily_repository.dart';
import '../../data/daily/models.dart';
import '../../games/common/game_sim.dart';
import '../../games/common/game_strings.dart';
import '../../games/game_registry.dart';
import '../play/hud.dart';
import '../play/play_request.dart';
import '../share/share_card.dart';
import 'day_state.dart';
import 'today_controller.dart';

/// Home (section 9.2): the big alarm clock shows the day state (4.4).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _tick;
  DayState? _lastState;
  int _ringCount = 0;
  bool _starting = false;
  int _waitingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(todayProvider.notifier).refresh());
    }
  }

  void _onTick() {
    if (!mounted) return;
    final today = ref.read(todayProvider).value;
    if (today == null) return;
    final s = dayStateOf(today, ref.read(todayProvider.notifier).now());
    // While waiting, ask the server again regularly: the client never knows
    // the alarm time in advance (section 4.2).
    if (s == DayState.waiting && ++_waitingSeconds >= 30) {
      _waitingSeconds = 0;
      unawaited(ref.read(todayProvider.notifier).refresh());
    }
    if (s == DayState.ringing && _lastState != DayState.ringing) _ringCount = 0;
    if (s == DayState.ringing && _ringCount < 5 && !_starting) {
      // Ring every 4 s for the first 20 s.
      if (_ringCount == 0 || DateTime.now().second % 4 == 0) {
        _ringCount++;
        ref.read(feedbackProvider)
          ..play(Sfx.alarm)
          ..vibrate(Haptic.heavy);
      }
    }
    _lastState = s;
    setState(() {});
  }

  Future<void> _play() async {
    if (_starting) return;
    setState(() => _starting = true);
    final l10n = context.l10n;
    try {
      final a = await ref.read(todayProvider.notifier).start();
      if (!mounted) return;
      await context.push(
        Routes.play,
        extra: PlayRequest(
          gameId: a.gameId,
          seed: a.seed,
          modifierId: a.modifierId,
          official: true,
          dayKey: a.dayKey,
        ),
      );
    } on AttemptAlreadyExists {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.homeAlreadyPlayed)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.homeError)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
      unawaited(ref.read(todayProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(todayProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    final today = async.value;
    final state = today == null
        ? null
        : dayStateOf(today, ref.read(todayProvider.notifier).now());
    final ringing = state == DayState.ringing;
    final theme = Theme.of(context);

    final body = SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(todayProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: ringing ? AppColors.yellow : null,
              ),
            ),
            Text(
              ringing ? l10n.homeRingingTitle : l10n.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ringing ? Colors.white : null,
                fontFamily: ringing ? AppFonts.display : null,
                fontSize: ringing ? 22 : null,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: AlarmClock(
                semanticLabel: l10n.alarmClockSemantics,
                ringing: ringing,
                reduceMotion: reduceMotion,
              ),
            ),
            const SizedBox(height: 24),
            if (async.isLoading && today == null)
              const Center(child: CircularProgressIndicator())
            else if (async.hasError && today == null)
              _Message(
                title: l10n.homeError,
                action: (
                  l10n.homeRetry,
                  () => ref.read(todayProvider.notifier).refresh(),
                ),
              )
            else if (today != null && state != null)
              _StateCard(
                today: today,
                state: state,
                now: ref.read(todayProvider.notifier).now(),
                starting: _starting,
                onPlay: _play,
              ),
            const SizedBox(height: 24),
            if (today != null)
              _StreakRow(profile: today.profile, ringing: ringing),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: ringing
                  ? OutlinedButton.styleFrom(foregroundColor: Colors.white)
                  : null,
              onPressed: () => context.push(Routes.training),
              icon: const Icon(Icons.sports_esports),
              label: Text(l10n.homeTraining),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push(Routes.gameLab),
                icon: const Icon(Icons.science_outlined),
                label: Text(l10n.homeGameLab),
              ),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: ringing
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.alarmRed,
                    Color(0xFFFF8A3D),
                    AppColors.yellow,
                  ],
                )
              : null,
        ),
        child: body,
      ),
    );
  }
}

class _StateCard extends ConsumerWidget {
  const _StateCard({
    required this.today,
    required this.state,
    required this.now,
    required this.starting,
    required this.onPlay,
  });

  final TodayInfo today;
  final DayState state;
  final DateTime now;
  final bool starting;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final game = today.gameId == null ? null : GameRegistry.byId(today.gameId!);
    String gameLabel() {
      if (game == null) return '';
      final mod = today.modifierId == null
          ? ''
          : ' · ${GameStrings.modifierEmoji(today.modifierId!)} '
                '${GameStrings.modifierName(l10n, today.modifierId!)}';
      return '${game.emoji} ${game.name(l10n)}$mod';
    }

    switch (state) {
      case DayState.unavailable:
        return _Message(
          title: l10n.homeUnavailable,
          action: (
            l10n.homeRetry,
            () => ref.read(todayProvider.notifier).refresh(),
          ),
        );
      case DayState.waiting:
        return _Message(
          title: l10n.homeWaitingTitle,
          body: l10n.homeWaitingBody,
        );
      case DayState.ringing:
        final left = ringingSecondsLeft(today, now);
        return Column(
          children: [
            Text(
              l10n.homeTodayGame(gameLabel()),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.night,
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 44,
                  ),
                ),
                onPressed: starting ? null : onPlay,
                child: starting
                    ? const CircularProgressIndicator()
                    : Text(l10n.homePlay),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              formatClock(left),
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 48,
                color: Colors.white,
                fontFeatures: AppFonts.tabular,
              ),
            ),
            Text(
              l10n.homeRingingLeft(formatClock(left)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
      case DayState.late:
        final at = TimeOfDay.fromDateTime(today.alertAt!.toLocal())
            .format(context);
        return Column(
          children: [
            Text(l10n.homeLateTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(gameLabel(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.homeLateBody(at), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: starting ? null : onPlay,
              child: Text(l10n.homePlayAnyway),
            ),
          ],
        );
      case DayState.played:
        final a = today.attempt!;
        return Column(
          children: [
            Text(l10n.homePlayedTitle, style: theme.textTheme.titleLarge),
            Text(gameLabel()),
            Text(
              '${a.score ?? 0}',
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 64,
                color: AppColors.alarmRed,
                fontFeatures: AppFonts.tabular,
              ),
            ),
            Chip(
              backgroundColor: a.onTime ? AppColors.onTime : AppColors.late,
              label: Text(
                a.onTime ? l10n.homePlayedOnTime : l10n.homePlayedLate,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => shareResult(
                context,
                ShareCardData(
                  dayKey: today.dayKey ?? '',
                  gameId: today.gameId!,
                  score: a.score ?? 0,
                  shareLine: gameLabel(),
                  modifierId: today.modifierId,
                  streak: today.profile.streak,
                  late: !a.onTime,
                ),
                'OneGame · ${today.dayKey}\n${gameLabel()} · ${a.score ?? 0}'
                '${today.profile.streak > 0 ? '\n🔥 ${today.profile.streak}' : ''}',
              ),
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.homeShare),
            ),
            const SizedBox(height: 8),
            Text(l10n.homeNextAlarm, textAlign: TextAlign.center),
          ],
        );
      case DayState.inProgressLost:
        return _Message(
          title: l10n.homeLostTitle,
          body: l10n.homeLostBody(today.attempt?.score ?? 0),
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.action});

  final String title;
  final String? body;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!, textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: action!.$2, child: Text(action!.$1)),
        ],
      ],
    );
  }
}

class _StreakRow extends ConsumerWidget {
  const _StreakRow({required this.profile, required this.ringing});

  final ProfileSummary profile;
  final bool ringing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final color = ringing ? Colors.white : null;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: '${l10n.homeStreak} ${profile.streak}',
              child: Text(
                '🔥 ${profile.streak}',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 28,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Semantics(
              label: '${l10n.homeJokers} ${profile.jokers}',
              child: Text(
                '🃏 ${profile.jokers}',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 28,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Text(
          l10n.homeBestStreak(profile.bestStreak),
          style: TextStyle(color: color),
        ),
        if (profile.jokerAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () async {
                await ref.read(todayProvider.notifier).spendJoker();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.homeJokerUsed)));
                }
              },
              icon: const Text('🃏'),
              label: Text(l10n.homeUseJoker),
            ),
          ),
      ],
    );
  }
}
