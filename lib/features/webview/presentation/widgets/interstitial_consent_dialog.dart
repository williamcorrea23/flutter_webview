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
        'Would you like to watch a full-screen ad to support the app?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Watch ad'),
        ),
      ],
    );
  }
}
