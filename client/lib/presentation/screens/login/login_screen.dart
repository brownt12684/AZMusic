import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/pairing/pairing_payload.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/entities/server_pairing.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/pairing_qr_scanner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(availableProfilesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      key: AppKeys.loginScreen,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.2,
                      color: const Color(0xFF111111),
                    ),
                    children: const [
                      TextSpan(text: 'AZ'),
                      TextSpan(
                        text: 'Music',
                        style: TextStyle(color: Color(0xFF1D9E75)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Family music practice',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFAAAAAA),
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 44),
                Text(
                  "Who's practicing today?",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 14),
                ...profiles
                    .where((profile) => profile.role == ProfileRole.student)
                    .map(
                      (profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProfileButton(
                          profile: profile,
                          showDefaultBadge: profile.isDefaultOnDevice,
                          onPressed: () => _activateProfile(profile),
                        ),
                      ),
                    ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 1,
                  color: const Color(0xFFEBEBEB),
                ),
                _ProfileButton(
                  profile: profiles.firstWhere(
                      (profile) => profile.role == ProfileRole.parent),
                  showDefaultBadge: false,
                  onPressed: () => _activateProfile(
                    profiles.firstWhere(
                        (profile) => profile.role == ProfileRole.parent),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.dns_outlined,
                          size: 14,
                          color: Color(0xFF0F6E56),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppConfig.isServerPaired
                              ? 'Paired with ${AppConfig.serverBaseUrl}'
                              : 'Pair this device with your AZMusic server',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF0F6E56),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _promptForPairing,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: Text(
                      AppConfig.isServerPaired
                          ? 'Update server pairing'
                          : 'Pair this device',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activateProfile(Profile profile) async {
    if (profile.requiresPin) {
      final accepted = await _promptForPin(profile);
      if (!accepted || !mounted) {
        return;
      }
    }

    ref.read(selectedProfileIdProvider.notifier).state = profile.id;
    Navigator.of(context).pushReplacementNamed(
      profile.role == ProfileRole.parent
          ? AppRouter.parentHome
          : AppRouter.library,
    );
  }

  Future<bool> _promptForPin(Profile profile) async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter ${profile.displayName} PIN'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN'),
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
    if (accepted != true) {
      return false;
    }
    if (controller.text.trim() == (profile.localPin ?? '')) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incorrect PIN.')),
    );
    return false;
  }

  Future<void> _promptForPairing() async {
    final input = await showDialog<_PairingInput>(
      context: context,
      builder: (context) => const _PairingDialog(),
    );
    if (input == null) {
      return;
    }

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: input.serverUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/pairing/claim',
        data: {
          'pairing_code': input.pairingCode,
          'device_id': 'azmusic-${Platform.localHostname}',
          'device_name': Platform.localHostname,
          'platform': Platform.operatingSystem,
        },
      );
      final claim = ServerPairingClaim.fromJson(response.data!);
      await AppConfig.applyServerPairing(
        serverUrl: claim.serverUrl,
        serverId: claim.serverId,
        pairingToken: claim.deviceToken,
        profileId: claim.profileId,
        profileRole: claim.role,
        profileName: claim.profileName,
      );
      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paired with ${claim.serverName}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pairing failed: $error')),
      );
    }
  }
}

class _PairingDialog extends StatefulWidget {
  const _PairingDialog();

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController(
    text: AppConfig.serverBaseUrl,
  );
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _payloadController.dispose();
    _serverUrlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pair this device'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _payloadController,
              decoration: const InputDecoration(
                labelText: 'QR payload or pairing link',
                helperText: 'Paste the azmusic://pair link from a QR scanner.',
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: _applyPayload,
            ),
            const SizedBox(height: 10),
            if (isPairingQrScanningSupported)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _scanQrCode,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Scan QR code'),
                ),
              )
            else
              Text(
                'Camera QR scanning is not available on this platform yet. Use the QR payload, server URL, and pairing code fields.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Pairing code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final input = _currentInput();
            if (input == null) {
              return;
            }
            Navigator.of(context).pop(input);
          },
          child: const Text('Pair'),
        ),
      ],
    );
  }

  void _applyPayload(String value) {
    final parsed = PairingPayload.tryParse(value);
    if (parsed == null) {
      return;
    }
    _applyPairingPayload(parsed);
  }

  Future<void> _scanQrCode() async {
    final parsed = await Navigator.of(context).push<PairingPayload>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const PairingQrScannerScreen(),
      ),
    );
    if (parsed == null || !mounted) {
      return;
    }
    _payloadController.text = parsed.displayPayload;
    _applyPairingPayload(parsed);
  }

  void _applyPairingPayload(PairingPayload payload) {
    _serverUrlController.text = payload.serverUrl;
    _codeController.text = payload.pairingCode;
  }

  _PairingInput? _currentInput() {
    final parsed = PairingPayload.tryParse(_payloadController.text);
    if (parsed != null) {
      return _PairingInput.fromPayload(parsed);
    }
    final serverUrl = _serverUrlController.text.trim();
    final pairingCode = _codeController.text.trim();
    if (serverUrl.isEmpty || pairingCode.isEmpty) {
      return null;
    }
    return _PairingInput(serverUrl: serverUrl, pairingCode: pairingCode);
  }
}

class _PairingInput {
  const _PairingInput({
    required this.serverUrl,
    required this.pairingCode,
  });

  final String serverUrl;
  final String pairingCode;

  factory _PairingInput.fromPayload(PairingPayload payload) {
    return _PairingInput(
      serverUrl: payload.serverUrl,
      pairingCode: payload.pairingCode,
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.profile,
    required this.showDefaultBadge,
    required this.onPressed,
  });

  final Profile profile;
  final bool showDefaultBadge;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isParent = profile.role == ProfileRole.parent;
    final avatarBackground = isParent
        ? const Color(0xFFFAECE7)
        : profile.id == 'student-zora'
            ? const Color(0xFFE1F5EE)
            : const Color(0xFFEEEDFE);
    final avatarForeground = isParent
        ? const Color(0xFF993C1D)
        : profile.id == 'student-zora'
            ? const Color(0xFF0F6E56)
            : const Color(0xFF3C3489);

    return GestureDetector(
      key: AppKeys.profileButton(profile.id),
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarBackground,
              foregroundColor: avatarForeground,
              child: isParent
                  ? const Icon(Icons.shield_outlined, size: 18)
                  : Text(
                      profile.displayName.substring(0, 2).toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF111111),
                          ),
                        ),
                      ),
                      if (showDefaultBadge) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Default',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (profile.subtitle?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        profile.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isParent ? Icons.lock_outline : Icons.chevron_right,
              size: isParent ? 14 : 16,
              color: const Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}
