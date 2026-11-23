enum Scope { friends, country, region, world, weekly, language }

class BoardRow {
  const BoardRow({
    required this.uid,
    required this.pseudo,
    required this.score,
    required this.rank,
    this.onTime = true,
    this.country,
    this.isMe = false,
    this.demo = false,
  });

  factory BoardRow.fromJson(Map<String, dynamic> j, String myUid) => BoardRow(
    uid: j['uid'] as String,
    pseudo: j['pseudo'] as String?,
    score: (j['score'] as num).toInt(),
    rank: (j['rank'] as num).toInt(),
    onTime: j['onTime'] as bool? ?? true,
    country: j['country'] as String?,
    isMe: j['uid'] == myUid,
  );

  final String uid;
  final String? pseudo;
  final int score;
  final int rank;
  final bool onTime;
  final String? country;
  final bool isMe;
  final bool demo;
}

class Board {
  const Board({required this.top, this.me, this.total = 0, this.percentile});

  final List<BoardRow> top;
  final BoardRow? me;
  final int total;

  /// % of players below (world / region / country), null for friends.
  final int? percentile;
}

enum FriendStatus { accepted, pending }

class Friend {
  const Friend({
    required this.uid,
    required this.pseudo,
    required this.status,
    this.incoming = false,
    this.demo = false,
  });

  final String uid;
  final String? pseudo;
  final FriendStatus status;

  /// For pending requests: true when they asked me.
  final bool incoming;
  final bool demo;
}

class FeedItem {
  const FeedItem({
    required this.uid,
    required this.pseudo,
    required this.score,
    required this.onTime,
    this.gameId,
    this.highlights = const [],
    this.reactions = const {},
    this.myReaction,
  });

  final String uid;
  final String? pseudo;
  final int score;
  final bool onTime;
  final String? gameId;
  final List<String> highlights;
  final Map<String, int> reactions;
  final String? myReaction;
}

class Feed {
  const Feed({required this.locked, this.items = const []});

  /// True until the player has played today (section 9.6).
  final bool locked;
  final List<FeedItem> items;
}

const reactionEmojis = ['🔥', '😂', '😮', '👏', '💀'];
