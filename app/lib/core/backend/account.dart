import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import 'backend.dart';

/// Account linking (Apple / Google / e-mail) and deletion (section 9.10).
class AccountService {
  AccountService(this._ref);

  final Ref _ref;

  bool get canLink => _ref.read(backendProvider).usesFirebase;

  Future<void> linkGoogle() =>
      FirebaseAuth.instance.currentUser!.linkWithProvider(GoogleAuthProvider());

  Future<void> linkApple() =>
      FirebaseAuth.instance.currentUser!.linkWithProvider(AppleAuthProvider());

  Future<void> linkEmail(String email, String password) =>
      FirebaseAuth.instance.currentUser!.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );

  /// Deletes everything (server data + auth user, or the local data).
  Future<void> deleteAccount() async {
    if (canLink) {
      await FirebaseFunctions.instance
          .httpsCallable('deleteAccount')
          .call<Object?>();
      await FirebaseAuth.instance.signOut();
    }
    await _ref.read(sharedPrefsProvider).clear();
  }
}

final accountServiceProvider = Provider<AccountService>(AccountService.new);
