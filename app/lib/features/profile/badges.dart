import '../../core/l10n/l10n.dart';

/// Badge ids awarded by the server (`functions/src/core/badges.ts`).
const allBadges = [
  'first_day',
  'week',
  'month',
  'ace',
  'panenka',
  'carreau',
  'one_eighty',
  'early_bird',
  'all_games',
];

String badgeName(AppLocalizations l, String id) => switch (id) {
  'first_day' => l.badgeFirstDay,
  'week' => l.badgeWeek,
  'month' => l.badgeMonth,
  'ace' => l.badgeAce,
  'panenka' => l.badgePanenka,
  'carreau' => l.badgeCarreau,
  'one_eighty' => l.badgeOneEighty,
  'early_bird' => l.badgeEarlyBird,
  'all_games' => l.badgeAllGames,
  _ => id,
};

String badgeEmoji(String id) => switch (id) {
  'first_day' => '👣',
  'week' => '📅',
  'month' => '🗓️',
  'ace' => '⛳',
  'panenka' => '⚽',
  'carreau' => '🔵',
  'one_eighty' => '🎯',
  'early_bird' => '🐓',
  'all_games' => '🧩',
  _ => '🏅',
};
