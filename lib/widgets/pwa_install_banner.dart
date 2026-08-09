import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services/pwa_install_service.dart';

/// A small, dismissible "Install App" banner. Shown on the dashboard so
/// every employee has an obvious, reliable way to install the PWA to
/// their home screen -- instead of waiting for the browser's own install
/// popup, which many browsers delay or never show automatically.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _dismissed = false;
  bool _installing = false;

  Future<void> _install() async {
    setState(() => _installing = true);
    final outcome = await PwaInstallService.promptInstall();
    if (!mounted) return;
    setState(() => _installing = false);

    if (outcome == 'accepted') {
      setState(() => _dismissed = true);
      return;
    }
    if (outcome == 'unavailable') {
      _showManualInstructions();
    }
  }

  void _showManualInstructions() {
    final isIos = PwaInstallService.isIosSafari;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Install this app'),
        content: Text(
          isIos
              ? 'Tap the Share icon in Safari, then choose "Add to Home Screen".'
              : 'Open your browser menu (⋮) and choose "Install app" or "Add to Home screen".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed || PwaInstallService.isInstalled) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.install_mobile_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Install PlottingBazaar CRM on this device for quick, app-like access.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: _installing ? null : _install,
              child: Text(_installing ? '...' : 'Install'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}
