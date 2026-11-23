import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/audio/feedback.dart';
import '../../core/config/tuning.dart';
import '../../core/l10n/l10n.dart';
import '../../core/settings/settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../games/common/game_sim.dart';
import '../../games/common/game_strings.dart';
import '../../games/common/game_types.dart';
import '../../games/common/mini_game.dart';
import '../../games/common/mini_game_definition.dart';
import '../../games/game_registry.dart';
import 'hud.dart';
import 'play_request.dart';
import 'rule_intro.dart';

/// Hook called with the final result of every game (official results are
/// submitted to the server by the daily feature, Phase 3).
typedef ResultSink = Future<void> Function(PlayRequest req, GameResult result);

final resultSinkProvider = Provider<ResultSink>((ref) => (_, _) async {});

enum _Phase { intro, playing, ending }

/// Runs a mini-game: rule + 3-2-1-GO, game with common HUD, FIN, results.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.request});

  final PlayRequest request;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with WidgetsBindingObserver {
  late final MiniGameDefinition _def;
  late final MiniGame _game;
  _Phase _phase = _Phase.intro;
  int _count = 3;
  Timer? _timer;
  DateTime? _backgroundedAt;
  int _lastTick = 999;
  bool _showGo = false;

  FeedbackService get _fx => ref.read(feedbackProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _def = GameRegistry.byId(widget.request.gameId)!;
    final ctx = GameContext(
      seed: widget.request.seed,
      modifierId: widget.request.modifierId,
      official: widget.request.official,
      tuning: ref.read(tuningProvider).forGame(_def.id),
    );
    _game = MiniGame(
      sim: _def.createSim(ctx),
      maxDuration: _def.maxDuration,
      showDebug: widget.request.debug,
      onCue: (c) => _fx.cue(c),
      onFinished: _onFinished,
    );
    _game.remainingSeconds.addListener(_onSecond);
    unawaited(FeedbackService.preload());
    _fx.play(Sfx.countdown);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _countdown());
  }

  void _countdown() {
    if (!mounted) return;
    setState(() => _count--);
    if (_count > 0) {
      _fx.play(Sfx.countdown);
      return;
    }
    _timer?.cancel();
    _fx
      ..play(Sfx.go)
      ..vibrate(Haptic.medium);
    setState(() {
      _phase = _Phase.playing;
      _showGo = true;
    });
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showGo = false);
    });
  }

  /// Last 10 seconds: tick-tock + light vibration every second.
  void _onSecond() {
    final s = _game.remainingSeconds.value;
    if (s < _lastTick && s <= 10 && s > 0 && _phase == _Phase.playing) {
      _fx
        ..play(Sfx.tick)
        ..vibrate(Haptic.selection);
    }
    _lastTick = s;
  }

  void _onFinished() {
    if (_phase == _Phase.ending) return;
    _fx
      ..play(Sfx.fin)
      ..vibrate(Haptic.heavy);
    setState(() => _phase = _Phase.ending);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), _goToResults);
  }

  Future<void> _goToResults() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final sim = _game.sim;
    final stats = sim.stats;
    final result = GameResult(
      gameId: _def.id,
      seed: widget.request.seed,
      modifierId: widget.request.modifierId,
      official: widget.request.official,
      score: _def.scoreBounds.clamp(sim.finalScore),
      playedTime: Duration(microseconds: sim.step * 1000000 ~/ stepsPerSecond),
      stats: stats,
      inputLog: List.unmodifiable(_game.inputLog),
      highlights: List.unmodifiable(sim.highlights),
      shareLine: _def.shareLine(l10n, stats),
      timedOut: _game.timedOut,
    );
    final sink = ref.read(resultSinkProvider);
    unawaited(sink(widget.request, result));
    if (!mounted) return;
    context.pushReplacement(Routes.results, extra: (widget.request, result));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _Phase.playing) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      // No pause: the timer kept running while away (section 5.2 step 5).
      _game.fastForward(DateTime.now().difference(_backgroundedAt!));
      _backgroundedAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _game.remainingSeconds.removeListener(_onSecond);
    super.dispose();
  }

  void _quit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;
    return PopScope(
      canPop: !widget.request.official,
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: _phase == _Phase.intro
            ? RuleIntro(
                def: _def,
                count: _count,
                official: widget.request.official,
                modifierId: widget.request.modifierId,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    onPointerDown: (e) => _game.pointer(
                      PointerPhase.down,
                      e.pointer,
                      e.localPosition,
                    ),
                    onPointerMove: (e) => _game.pointer(
                      PointerPhase.move,
                      e.pointer,
                      e.localPosition,
                    ),
                    onPointerUp: (e) => _game.pointer(
                      PointerPhase.up,
                      e.pointer,
                      e.localPosition,
                    ),
                    onPointerCancel: (e) => _game.pointer(
                      PointerPhase.up,
                      e.pointer,
                      e.localPosition,
                    ),
                    child: GameWidget(game: _game),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: GameHud(
                        remaining: _game.remainingSeconds,
                        score: _game.scoreListenable,
                        modifierId: widget.request.modifierId,
                      ),
                    ),
                  ),
                  if (!widget.request.official)
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: IconButton(
                          tooltip: context.l10n.playQuit,
                          onPressed: _quit,
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: _HighlightBanner(
                      listenable: _game.highlightListenable,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  if (_showGo) const IgnorePointer(child: _BigWord(word: null)),
                  if (_phase == _Phase.ending)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black54,
                        child: _BigWord(word: context.l10n.playEnd),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _BigWord extends StatelessWidget {
  const _BigWord({required this.word});

  /// null = "GO !".
  final String? word;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      word ?? context.l10n.playGo,
      style: const TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 80,
        color: AppColors.yellow,
        shadows: [Shadow(blurRadius: 12, color: Colors.black)],
      ),
    ),
  );
}

/// Big animated "coup d'éclat" banner.
class _HighlightBanner extends StatefulWidget {
  const _HighlightBanner({
    required this.listenable,
    required this.reduceMotion,
  });

  final ValueListenable<String?> listenable;
  final bool reduceMotion;

  @override
  State<_HighlightBanner> createState() => _HighlightBannerState();
}

class _HighlightBannerState extends State<_HighlightBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  String? _text;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_show);
  }

  void _show() {
    final id = widget.listenable.value;
    if (id == null) return;
    setState(() => _text = GameStrings.highlight(context.l10n, id));
    unawaited(_c.forward(from: 0));
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_show);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_text == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final opacity = t < 0.8 ? 1.0 : (1 - t) / 0.2;
        final scale = widget.reduceMotion
            ? 1.0
            : (t < 0.2 ? 0.5 + t * 2.5 : 1.0 + (t - 0.2) * 0.1);
        return Center(
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.rotate(
              angle: widget.reduceMotion ? 0 : -0.08,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.alarmRed,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.yellow, width: 4),
                  ),
                  child: Text(
                    _text!,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 40,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
