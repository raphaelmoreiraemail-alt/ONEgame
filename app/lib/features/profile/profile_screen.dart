import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.profileTitle);
}
