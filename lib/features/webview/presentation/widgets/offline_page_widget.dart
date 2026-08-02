import 'package:flutter/material.dart';

class OfflinePageWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const OfflinePageWidget({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.signal_wifi_connected_no_internet_4,
              size: 64,
              color: theme.colorScheme.primary,
              semanticLabel: 'No internet connection',
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re Offline',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
