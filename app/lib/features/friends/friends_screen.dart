import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/social/models.dart';
import '../../data/social/social_repository.dart';
import '../../games/common/game_strings.dart';
import '../../games/game_registry.dart';
import '../home/today_controller.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'phone.dart';

final friendsProvider = FutureProvider<List<Friend>>(
  (ref) => ref.watch(socialRepositoryProvider).friends(),
);

final feedProvider = FutureProvider.family<Feed, String>((ref, dayKey) {
  ref.watch(todayProvider);
  return ref.watch(socialRepositoryProvider).feed(dayKey);
});

/// Link encoded in the QR code / shared text.
String inviteLink(String code) => 'onegame://invite/$code';

/// Friends feed (9.6) + friends management (9.7).
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.friendsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.feedTitle),
              Tab(text: l10n.friendsTitle),
            ],
          ),
        ),
        body: const TabBarView(children: [_FeedTab(), _FriendsTab()]),
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dayKey = currentDayKey(ref);
    final async = ref.watch(feedProvider(dayKey));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.homeError)),
      data: (feed) {
        if (feed.locked) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(l10n.feedLocked, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        if (feed.items.isEmpty) return Center(child: Text(l10n.feedEmpty));
        return RefreshIndicator(
          onRefresh: () => ref.refresh(feedProvider(dayKey).future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final i in feed.items) _FeedCard(item: i, dayKey: dayKey),
            ],
          ),
        );
      },
    );
  }
}

class _FeedCard extends ConsumerWidget {
  const _FeedCard({required this.item, required this.dayKey});

  final FeedItem item;
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final game = item.gameId == null ? null : GameRegistry.byId(item.gameId!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.pseudo ?? '?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (!item.onTime)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.late,
                    label: Text(
                      l10n.lbLate,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${game?.emoji ?? ''} ${item.score}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ],
            ),
            if (item.highlights.isNotEmpty)
              Text(
                item.highlights
                    .map((h) => GameStrings.highlight(l10n, h))
                    .join(' · '),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final e in reactionEmojis)
                  ChoiceChip(
                    selected: item.myReaction == e,
                    label: Text('$e ${item.reactions[e] ?? ''}'.trim()),
                    onSelected: (sel) async {
                      await ref
                          .read(socialRepositoryProvider)
                          .react(dayKey, item.uid, sel ? e : null);
                      ref.invalidate(feedProvider(dayKey));
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab();

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  final _pseudo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _add() async {
    final l10n = context.l10n;
    try {
      final accepted = await _repo.sendRequest(_pseudo.text.trim());
      setState(() => _error = null);
      _pseudo.clear();
      _toast(accepted ? l10n.friendsNowFriends : l10n.friendsRequestSent);
      ref.invalidate(friendsProvider);
    } on PseudoRejected catch (e) {
      setState(() => _error = pseudoError(l10n, e.reason));
    }
  }

  Future<void> _invite() async {
    final l10n = context.l10n;
    final code = await _repo.createInvite();
    if (!mounted) return;
    final link = inviteLink(code);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: link, size: 200, backgroundColor: Colors.white),
              const SizedBox(height: 8),
              SelectableText(
                l10n.friendsInviteCode(code),
                style: const TextStyle(fontFamily: AppFonts.display),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: l10n.friendsInviteText(link)),
                ),
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.homeShare),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enterCode() async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.friendsEnterCode),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    await acceptInviteCode(context, ref, code);
  }

  Future<void> _contacts() async {
    final l10n = context.l10n;
    final mine = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.friendsContacts),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.friendsContactsConsent),
              const SizedBox(height: 12),
              TextField(
                controller: mine,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.friendsContactsMine,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    final myNumber = mine.text;
    mine.dispose();
    if (go != true || !mounted) return;
    final country = Localizations.localeOf(context).countryCode;
    if (myNumber.trim().isNotEmpty) {
      final e164 = normalizePhone(myNumber, country);
      if (e164 != null) await _repo.registerPhone(hashPhone(e164));
    }
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      _toast(l10n.friendsContactsDenied);
      return;
    }
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final hashes = <String>{
      for (final c in contacts)
        for (final p in c.phones)
          if (normalizePhone(p.normalizedNumber ?? p.number, country)
              case final n?)
            hashPhone(n),
    }.toList();
    final n = await _repo.matchContacts(hashes);
    _toast(l10n.friendsContactsFound(n));
    ref.invalidate(friendsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friends = ref.watch(friendsProvider).value ?? const [];
    final incoming = friends.where(
      (f) => f.status == FriendStatus.pending && f.incoming,
    );
    final outgoing = friends.where(
      (f) => f.status == FriendStatus.pending && !f.incoming,
    );
    final accepted = friends.where((f) => f.status == FriendStatus.accepted);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_repo.isDemo)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.friendsDemo,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        TextField(
          controller: _pseudo,
          decoration: InputDecoration(
            labelText: l10n.friendsAddByPseudo,
            errorText: _error,
            suffixIcon: IconButton(
              tooltip: l10n.friendsAdd,
              icon: const Icon(Icons.person_add),
              onPressed: _add,
            ),
          ),
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _invite,
              icon: const Icon(Icons.qr_code),
              label: Text(l10n.friendsInvite),
            ),
            OutlinedButton.icon(
              onPressed: _enterCode,
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(l10n.friendsEnterCode),
            ),
            OutlinedButton.icon(
              onPressed: _contacts,
              icon: const Icon(Icons.contacts_outlined),
              label: Text(l10n.friendsContacts),
            ),
          ],
        ),
        if (incoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.friendsRequests,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final f in incoming)
            ListTile(
              title: Text(f.pseudo ?? '?'),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: l10n.friendsAccept,
                    icon: const Icon(Icons.check, color: AppColors.onTime),
                    onPressed: () async {
                      await _repo.respond(f.uid, accept: true);
                      ref.invalidate(friendsProvider);
                    },
                  ),
                  IconButton(
                    tooltip: l10n.friendsDecline,
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await _repo.respond(f.uid, accept: false);
                      ref.invalidate(friendsProvider);
                    },
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(l10n.friendsTitle, style: Theme.of(context).textTheme.titleMedium),
        if (accepted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.friendsNone),
          ),
        for (final f in accepted)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(f.pseudo ?? '?'),
            trailing: IconButton(
              tooltip: l10n.friendsRemove,
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () async {
                await _repo.removeFriend(f.uid);
                ref.invalidate(friendsProvider);
              },
            ),
          ),
        for (final f in outgoing)
          ListTile(
            leading: const Icon(Icons.hourglass_empty),
            title: Text(f.pseudo ?? '?'),
            subtitle: Text(l10n.friendsPendingOut),
          ),
      ],
    );
  }
}

/// Accepts an invite code (from the code dialog or a deep link).
Future<void> acceptInviteCode(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final pseudo = await ref.read(socialRepositoryProvider).acceptInvite(code);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.friendsCodeAccepted(pseudo ?? '?'))),
    );
    ref.invalidate(friendsProvider);
  } on PseudoRejected {
    messenger.showSnackBar(SnackBar(content: Text(l10n.accountLocalOnly)));
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.commonError)));
  }
}

/// SHA-256 of an E.164 number (only hashes leave the phone).
String hashPhone(String e164) => sha256.convert(utf8.encode(e164)).toString();
