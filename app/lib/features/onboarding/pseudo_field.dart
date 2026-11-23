import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import 'onboarding_screen.dart';

/// Pseudo input with server-side validation (unique, filtered).
class PseudoField extends ConsumerStatefulWidget {
  const PseudoField({super.key, required this.onSaved});

  final ValueChanged<String> onSaved;

  @override
  ConsumerState<PseudoField> createState() => _PseudoFieldState();
}

class _PseudoFieldState extends ConsumerState<PseudoField> {
  late final _ctrl = TextEditingController(
    text: ref.read(socialRepositoryProvider).pseudo ?? '',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final err = await savePseudo(ref, context.l10n, _ctrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) widget.onSaved(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        TextField(
          controller: _ctrl,
          maxLength: 16,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: l10n.accountPseudo,
            helperText: l10n.onbPseudoHint,
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const CircularProgressIndicator()
              : Text(l10n.onbStart),
        ),
      ],
    );
  }
}
