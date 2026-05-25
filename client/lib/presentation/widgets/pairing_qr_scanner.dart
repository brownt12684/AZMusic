import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/pairing/pairing_payload.dart';

bool get isPairingQrScanningSupported {
  if (kIsWeb) {
    return true;
  }
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

class PairingQrScannerScreen extends StatefulWidget {
  const PairingQrScannerScreen({super.key});

  @override
  State<PairingQrScannerScreen> createState() => _PairingQrScannerScreenState();
}

class _PairingQrScannerScreenState extends State<PairingQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  String? _message;
  bool _handled = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan AZMusic QR'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _handleDetection,
                      errorBuilder: (context, error) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Camera scanner unavailable: ${error.errorCode.name}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _message ??
                    'Point the camera at the QR code on the server setup page or parent device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Use manual entry instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) {
        continue;
      }

      final payload = PairingPayload.tryParse(rawValue);
      if (payload == null) {
        continue;
      }

      _handled = true;
      unawaited(_controller.stop());
      Navigator.of(context).pop(payload);
      return;
    }

    setState(() {
      _message = 'This QR code is not an AZMusic pairing code.';
    });
  }
}

