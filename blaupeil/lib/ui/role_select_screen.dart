import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'device_list_screen.dart';
import 'sender_screen.dart';

enum Role { sender, seeker }

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  Future<void> _choose(BuildContext context, Role role) async {
    final ok = await ensurePermissions(context, role);
    if (!ok || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => role == Role.sender
            ? const SenderScreen()
            : const DeviceListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.explore,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'BlauPeil',
                textAlign: TextAlign.center,
                style: t.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Handys per Bluetooth finden, nach Art der Fuchsjagd. '
                'Richtung auf etwa 20 bis 45 Grad genau, Entfernung nur grob.',
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
              const Spacer(),
              _BigRoleButton(
                icon: Icons.wifi_tethering,
                label: 'Ich will gefunden werden',
                onPressed: () => _choose(context, Role.sender),
              ),
              const SizedBox(height: 20),
              _BigRoleButton(
                icon: Icons.travel_explore,
                label: 'Ich suche',
                onPressed: () => _choose(context, Role.seeker),
              ),
              const Spacer(),
              Text(
                'Gefunden werden nur Geräte, auf denen BlauPeil im '
                'Sendermodus läuft.',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigRoleButton extends StatelessWidget {
  const _BigRoleButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(96)),
      onPressed: onPressed,
      icon: Icon(icon, size: 32),
      label: Text(label, style: const TextStyle(fontSize: 20)),
    );
  }
}

/// Fragt die für die Rolle nötigen Berechtigungen an, jeweils erst nach einer
/// kurzen Begründung im Klartext.
Future<bool> ensurePermissions(BuildContext context, Role role) async {
  final List<Permission> required;
  final List<Permission> optional;
  final String why;

  if (Platform.isAndroid) {
    if (role == Role.sender) {
      // BLUETOOTH_CONNECT braucht der Sender, weil er den Bluetooth-Namen
      // kurzzeitig auf „BP-…“ setzt (siehe BeaconAdvertiserService.kt).
      required = [Permission.bluetoothAdvertise, Permission.bluetoothConnect];
      // Ohne Benachrichtigungsrecht läuft der Foreground Service trotzdem,
      // nur die Notification bleibt unsichtbar.
      optional = [Permission.notification];
      why =
          'Damit andere dich finden können, sendet BlauPeil ein '
          'Bluetooth-Signal. Dafür braucht die App die Erlaubnis für '
          '„Geräte in der Nähe“. Eine Benachrichtigung zeigt dir, solange '
          'du sichtbar bist.';
    } else {
      required = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      optional = [];
      why =
          'Zum Suchen misst BlauPeil, wie stark die Bluetooth-Signale '
          'anderer BlauPeil-Geräte ankommen. Android wertet das als '
          'Standortbestimmung, deshalb fragt die App nach „Geräte in der '
          'Nähe“ und nach deinem Standort. Standortdaten werden nicht '
          'gespeichert und nicht übertragen.';
    }
  } else {
    required = role == Role.sender
        ? [Permission.bluetooth]
        : [Permission.bluetooth, Permission.locationWhenInUse];
    optional = [];
    why = role == Role.sender
        ? 'Damit andere dich finden können, sendet BlauPeil ein '
              'Bluetooth-Signal. Dafür fragt iOS gleich nach Bluetooth.'
        : 'Zum Suchen misst BlauPeil die Stärke von Bluetooth-Signalen und '
              'liest den Kompass. Dafür fragt iOS nach Bluetooth und nach '
              'dem Standort (nur für die Himmelsrichtung, nichts wird '
              'gespeichert).';
  }

  final statuses = await Future.wait(required.map((p) => p.status));
  if (statuses.every((s) => s.isGranted)) return true;
  if (!context.mounted) return false;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kurz um Erlaubnis fragen'),
      content: Text(why),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Weiter'),
        ),
      ],
    ),
  );
  if (go != true) return false;

  final result = await [...required, ...optional].request();
  final denied = required.where((p) => !(result[p]?.isGranted ?? false));
  if (denied.isEmpty) return true;

  if (!context.mounted) return false;
  final permanently = denied.any(
    (p) => result[p]?.isPermanentlyDenied ?? false,
  );
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ohne Erlaubnis geht es nicht'),
      content: Text(
        permanently
            ? 'Die Berechtigung wurde dauerhaft abgelehnt. Du kannst sie in '
                  'den Systemeinstellungen freigeben.'
            : 'Ohne diese Berechtigung kann BlauPeil in dieser Rolle nicht '
                  'arbeiten.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Schließen'),
        ),
        if (permanently)
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Einstellungen'),
          ),
      ],
    ),
  );
  if (open == true) await openAppSettings();
  return false;
}
