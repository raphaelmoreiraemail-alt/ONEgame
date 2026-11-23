import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../games/common/game_strings.dart';
import '../../games/common/mini_game_definition.dart';
import '../../games/game_registry.dart';
import '../play/play_request.dart';

/// Debug-only tool: play any game with any seed and modifier (section 9.11).
class GameLabScreen extends StatefulWidget {
  const GameLabScreen({super.key});

  @override
  State<GameLabScreen> createState() => _GameLabScreenState();
}

class _GameLabScreenState extends State<GameLabScreen> {
  MiniGameDefinition _game = GameRegistry.all.first;
  String? _modifier;
  bool _debug = true;
  final _seed = TextEditingController(text: '2938471923');

  int get _seedValue => (int.tryParse(_seed.text.trim()) ?? 0) & 0xFFFFFFFF;

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  void _play() => context.push(
    Routes.play,
    extra: PlayRequest(
      gameId: _game.id,
      seed: _seedValue,
      modifierId: _modifier,
      debug: _debug,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameLabTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<MiniGameDefinition>(
            initialValue: _game,
            decoration: InputDecoration(labelText: l10n.gameLabGame),
            items: [
              for (final g in GameRegistry.all)
                DropdownMenuItem(
                  value: g,
                  child: Text('${g.emoji} ${g.name(l10n)} (${g.id})'),
                ),
            ],
            onChanged: (g) => setState(() {
              _game = g!;
              if (!_game.supportedModifiers.contains(_modifier)) {
                _modifier = null;
              }
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seed,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.gameLabSeed),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey(_game.id),
            initialValue: _modifier,
            decoration: InputDecoration(labelText: l10n.gameLabModifier),
            items: [
              DropdownMenuItem(child: Text(l10n.gameLabNone)),
              for (final m in _game.supportedModifiers)
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    '${GameStrings.modifierEmoji(m)} '
                    '${GameStrings.modifierName(l10n, m)}',
                  ),
                ),
            ],
            onChanged: (m) => setState(() => _modifier = m),
          ),
          SwitchListTile(
            value: _debug,
            onChanged: (v) => setState(() => _debug = v),
            title: Text(l10n.gameLabDebug),
          ),
          Text(
            l10n.gameLabFingerprint(
              _game.levelFingerprint(_seedValue, _modifier),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _play,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.gameLabPlay),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _seed.text = '${_seedValue + 1}');
                    _play();
                  },
                  child: Text(l10n.gameLabNext),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => _seed.text = '${math.Random().nextInt(0x7FFFFFFF)}',
                  ),
                  child: Text(l10n.gameLabRandom),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
