import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'models.dart';
import 'social_repository.dart';

class FirebaseSocialRepository implements SocialRepository {
  FirebaseSocialRepository(
    this._functions,
    this.uid,
    this._pseudo, [
    this._avatar = 1,
  ]);

  int _avatar;

  @override
  int get avatar => _avatar;

  /// Owners may update their avatar directly (firestore.rules).
  @override
  Future<void> setAvatar(int seed) async {
    _avatar = seed;
    await FirebaseFirestore.instance.doc('users/$uid').update({'avatar': seed});
  }

  final FirebaseFunctions _functions;
  final String uid;
  String? _pseudo;

  Future<Map<String, dynamic>> _call(String name, [Object? data]) async {
    final r = await _functions.httpsCallable(name).call<Object?>(data);
    return Map<String, dynamic>.from(r.data! as Map);
  }

  List<Map<String, dynamic>> _list(Object? v) => [
    for (final e in (v as List<dynamic>? ?? const []))
      Map<String, dynamic>.from(e as Map),
  ];

  @override
  bool get isDemo => false;

  @override
  String? get pseudo => _pseudo;

  @override
  Future<void> claimPseudo(String pseudo) async {
    try {
      await _call('claimPseudo', {'pseudo': pseudo});
      _pseudo = pseudo;
    } on FirebaseFunctionsException catch (e) {
      final m = e.message ?? '';
      throw PseudoRejected(
        m == 'pseudo-taken' ? 'taken' : m.replaceFirst('pseudo-', ''),
      );
    }
  }

  @override
  Future<List<Friend>> friends() async => [
    for (final f in _list((await _call('listFriends'))['friends']))
      Friend(
        uid: f['uid'] as String,
        pseudo: f['pseudo'] as String?,
        status: f['status'] == 'accepted'
            ? FriendStatus.accepted
            : FriendStatus.pending,
        incoming: f['incoming'] as bool? ?? false,
      ),
  ];

  @override
  Future<bool> sendRequest(String pseudo) async {
    try {
      return (await _call('sendFriendRequest', {'pseudo': pseudo}))['status'] ==
          'accepted';
    } on FirebaseFunctionsException catch (e) {
      if (e.message == 'pseudo-not-found') {
        throw const PseudoRejected('not-found');
      }
      rethrow;
    }
  }

  @override
  Future<void> respond(String uid, {required bool accept}) =>
      _call('respondFriendRequest', {'uid': uid, 'accept': accept});

  @override
  Future<void> removeFriend(String uid) => _call('removeFriend', {'uid': uid});

  @override
  Future<String> createInvite() async =>
      (await _call('createInvite'))['code'] as String;

  @override
  Future<String?> acceptInvite(String code) async =>
      (await _call('acceptInvite', {'code': code}))['pseudo'] as String?;

  @override
  Future<void> registerPhone(String hash) =>
      _call('registerPhone', {'hash': hash});

  @override
  Future<int> matchContacts(List<String> hashes) async =>
      ((await _call('matchContacts', {'hashes': hashes}))['matched'] as num)
          .toInt();

  @override
  Future<Board> leaderboard(Scope scope, String dayKey) async {
    final j = await _call('getLeaderboard', {
      'scope': scope.name,
      'dayKey': dayKey,
    });
    final me = j['me'] == null
        ? null
        : Map<String, dynamic>.from(j['me'] as Map);
    return Board(
      top: [for (final r in _list(j['top'])) BoardRow.fromJson(r, uid)],
      me: me == null ? null : BoardRow.fromJson(me, uid),
      total: (j['total'] as num?)?.toInt() ?? 0,
      percentile: (j['percentile'] as num?)?.toInt(),
    );
  }

  @override
  Future<Feed> feed(String dayKey) async {
    final j = await _call('getFeed', {'dayKey': dayKey});
    return Feed(
      locked: j['locked'] as bool? ?? true,
      items: [
        for (final i in _list(j['items']))
          FeedItem(
            uid: i['uid'] as String,
            pseudo: i['pseudo'] as String?,
            score: (i['score'] as num).toInt(),
            onTime: i['onTime'] as bool? ?? true,
            gameId: i['gameId'] as String?,
            highlights: [
              for (final h in (i['highlights'] as List<dynamic>? ?? const []))
                '$h',
            ],
            reactions: {
              for (final e in Map<String, dynamic>.from(
                i['reactions'] as Map? ?? const {},
              ).entries)
                e.key: (e.value as num).toInt(),
            },
            myReaction: i['myReaction'] as String?,
          ),
      ],
    );
  }

  @override
  Future<void> react(String dayKey, String target, String? emoji) =>
      _call('react', {'dayKey': dayKey, 'target': target, 'emoji': emoji});

  @override
  Future<void> report(String dayKey, String target) =>
      _call('reportScore', {'dayKey': dayKey, 'target': target});
}
