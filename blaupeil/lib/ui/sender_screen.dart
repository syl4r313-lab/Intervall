import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/beacon_payload.dart';
import '../config.dart';
import '../state/providers.dart';

class SenderScreen extends ConsumerStatefulWidget {
  const SenderScreen({super.key});

  @override
  ConsumerState<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends ConsumerState<SenderScreen> {
  late final TextEditingController _idCtrl;
  bool _active = false;
  bool _busy = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: ref.read(settingsProvider).senderId);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final id = BeaconPayload.sanitizeId(_idCtrl.text);
    if (!BeaconPayload.isValidId(id)) {
      setState(
        () => _error =
            'Bitte eine Kennung mit 1 bis $kMaxIdLength '
            'Zeichen eingeben (A bis Z, 0 bis 9).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(settingsProvider.notifier).setSenderId(id);
      await ref.read(advertiserProvider).start(id);
      setState(() => _active = true);
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _checkStatus());
    } on PlatformException catch (e) {
      setState(
        () => _error =
            'Senden ließ sich nicht starten: '
            '${e.message ?? e.code}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Der Sender kann auch von außen enden: Stopp in der Android-Notification
  /// oder ein Fehler im Bluetooth-Stack.
  Future<void> _checkStatus() async {
    final s = await ref.read(advertiserProvider).status();
    if (!mounted || !_active) return;
    if (!s.advertising) {
      _poll?.cancel();
      setState(() {
        _active = false;
        _error = s.error ?? 'Senden wurde beendet. Ist Bluetooth an?';
      });
      await ref.read(advertiserProvider).stop();
    }
  }

  Future<void> _stop() async {
    _poll?.cancel();
    setState(() => _busy = true);
    try {
      await ref.read(advertiserProvider).stop();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _active = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = '$kNamePrefix${BeaconPayload.sanitizeId(_idCtrl.text)}';

    return PopScope(
      // Wer den Bildschirm verlässt, soll nicht unbemerkt weiter funken.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _active) ref.read(advertiserProvider).stop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Gefunden werden')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_active) ...[
                Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.wifi_tethering,
                          size: 56,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dein Gerät ist gerade sichtbar',
                          textAlign: TextAlign.center,
                          style: t.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'als $name',
                          style: t.headlineSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // iOS funkt im Hintergrund die UUID nur noch im
                // Overflow-Bereich und lässt den Namen weg.
                if (Platform.isIOS) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: scheme.tertiaryContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.phone_iphone,
                        color: scheme.onTertiaryContainer,
                      ),
                      title: Text(
                        'Bitte App geöffnet und Bildschirm an lassen, '
                        'sonst bist du schwer zu finden.',
                        style: TextStyle(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: _busy ? null : _stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Senden beenden'),
                ),
              ] else ...[
                Text(
                  'Wähle eine kurze Kennung, an der dich die suchende '
                  'Person erkennt.',
                  style: t.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _idCtrl,
                  maxLength: kMaxIdLength,
                  textCapitalization: TextCapitalization.characters,
                  style: t.headlineSmall,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  decoration: const InputDecoration(
                    prefixText: kNamePrefix,
                    labelText: 'Kennung',
                    helperText: 'Höchstens 5 Zeichen, A bis Z und 0 bis 9',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _start(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Senden starten'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
