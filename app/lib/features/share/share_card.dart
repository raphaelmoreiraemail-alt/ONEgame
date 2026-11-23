import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/alarm_clock.dart';
import '../../games/common/game_strings.dart';
import '../../games/game_registry.dart';

/// Content of the 1080 × 1350 share card (section 9.4).
class ShareCardData {
  const ShareCardData({
    required this.dayKey,
    required this.gameId,
    required this.score,
    required this.shareLine,
    this.modifierId,
    this.streak = 0,
    this.highlights = const [],
    this.late = false,
  });

  final String dayKey;
  final String gameId;
  final int score;
  final String shareLine;
  final String? modifierId;
  final int streak;
  final List<String> highlights;
  final bool late;
}

/// Drawn at 360 × 450 logical pixels and exported at 3x = 1080 × 1350.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  static const Size logicalSize = Size(360, 450);
  static const double exportRatio = 3;

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = GameRegistry.byId(data.gameId);
    const bone = TextStyle(color: AppColors.bone);
    return SizedBox.fromSize(
      size: logicalSize,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.night, Color(0xFF3A1414)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AlarmClock(size: 44, semanticLabel: l10n.alarmClockSemantics),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'OneGame',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 28,
                          color: AppColors.alarmRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(data.dayKey, style: bone.copyWith(fontSize: 14)),
                ],
              ),
              const Spacer(),
              Text(
                '${game?.emoji ?? ''} ${game?.name(l10n) ?? data.gameId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bone.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (data.modifierId != null)
                Text(
                  '${GameStrings.modifierEmoji(data.modifierId!)} '
                  '${GameStrings.modifierName(l10n, data.modifierId!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.yellow, fontSize: 14),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${data.score}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 84,
                    color: AppColors.yellow,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ),
              Text(
                data.shareLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bone.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final h in data.highlights.toSet())
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.alarmRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        GameStrings.highlight(l10n, h),
                        style: const TextStyle(
                          color: AppColors.yellow,
                          fontFamily: AppFonts.display,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (data.streak > 0)
                Text(
                  l10n.shareCardStreak(data.streak),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bone.copyWith(fontSize: 16),
                ),
              Text(
                l10n.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0x99F4ECE4), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders [data] off-screen to a 1080 × 1350 PNG.
Future<Uint8List> renderShareCard(
  BuildContext context,
  ShareCardData data,
) async {
  final boundary = RenderRepaintBoundary();
  final view = View.of(context);
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(ShareCard.logicalSize),
      devicePixelRatio: 1,
    ),
  );
  final owner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations(
        locale: Localizations.localeOf(context),
        delegates: appLocalizationsDelegates,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: ShareCard(data: data),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  // Localizations load asynchronously: let them resolve.
  await Future<void>.delayed(Duration.zero);
  buildOwner
    ..buildScope(root)
    ..finalizeTree();
  owner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: ShareCard.exportRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Shares the image card + the Wordle-like text.
Future<void> shareResult(
  BuildContext context,
  ShareCardData data,
  String text,
) async {
  final png = await renderShareCard(context, data);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [
        XFile.fromData(
          png,
          mimeType: 'image/png',
          name: 'onegame-${data.dayKey}.png',
        ),
      ],
      fileNameOverrides: ['onegame-${data.dayKey}.png'],
    ),
  );
}
