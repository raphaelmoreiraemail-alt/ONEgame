import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/placeholder_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.trainingTitle);
}
