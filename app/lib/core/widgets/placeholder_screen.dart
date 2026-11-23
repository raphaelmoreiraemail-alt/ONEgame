import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';

/// Temporary body for screens implemented in later phases.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(context.l10n.comingSoon)),
    );
  }
}
