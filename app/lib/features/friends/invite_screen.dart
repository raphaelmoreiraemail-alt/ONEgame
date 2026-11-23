import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import 'friends_screen.dart';

/// Opened by `onegame://invite/CODE` (QR code / shared link).
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await acceptInviteCode(context, ref, widget.code);
      if (mounted) context.go(Routes.friends);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
