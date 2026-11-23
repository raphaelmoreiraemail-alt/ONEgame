import 'models.dart';

/// Friends, leaderboards and feed (section 9). Firebase or local demo.
abstract class SocialRepository {
  /// True for the local demo (simulated players).
  bool get isDemo;

  String? get pseudo;

  /// Throws [PseudoRejected].
  Future<void> claimPseudo(String pseudo);

  Future<List<Friend>> friends();

  /// Returns true when the request was accepted right away.
  Future<bool> sendRequest(String pseudo);

  Future<void> respond(String uid, {required bool accept});

  Future<void> removeFriend(String uid);

  /// Invite code, shared as a link / QR code.
  Future<String> createInvite();

  /// Returns the inviter's pseudo.
  Future<String?> acceptInvite(String code);

  Future<void> registerPhone(String hash);

  Future<int> matchContacts(List<String> hashes);

  Future<Board> leaderboard(Scope scope, String dayKey);

  Future<Feed> feed(String dayKey);

  Future<void> react(String dayKey, String target, String? emoji);

  Future<void> report(String dayKey, String target);
}

class PseudoRejected implements Exception {
  const PseudoRejected(this.reason);

  /// length | charset | offensive | taken | not-found
  final String reason;
}
