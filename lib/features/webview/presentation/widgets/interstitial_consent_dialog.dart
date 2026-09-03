import 'package:flutter/material.dart';

class InterstitialConsentDialog extends StatelessWidget {
  const InterstitialConsentDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => const InterstitialConsentDialog(),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Optional ad'),
      content: const Text(
        'A full-screen advertisement may appear between practice sessions. '
        'You can continue without it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
