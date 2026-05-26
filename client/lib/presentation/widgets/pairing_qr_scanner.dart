import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_code_dart_decoder/qr_code_dart_decoder.dart' as dart_qr;

import '../../core/pairing/pairing_payload.dart';

bool get isPairingQrScanningSupported {
  if (kIsWeb) {
    return true;
  }
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;
}

class PairingQrScannerScreen extends StatelessWidget {
  const PairingQrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isWindows) {
      return const _WindowsPairingQrScannerScreen();
    }
    return const _MobilePairingQrScannerScreen();
  }
}

class _MobilePairingQrScannerScreen extends StatefulWidget {
  const _MobilePairingQrScannerScreen();

  @override
  State<_MobilePairingQrScannerScreen> createState() =>
      _MobilePairingQrScannerScreenState();
}

class _MobilePairingQrScannerScreenState
    extends State<_MobilePairingQrScannerScreen> {
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

    if (!mounted) {
      return;
    }
    setState(() {
      _message = 'This QR code is not an AZMusic pairing code.';
    });
  }
}

class _WindowsPairingQrScannerScreen extends StatefulWidget {
  const _WindowsPairingQrScannerScreen();

  @override
  State<_WindowsPairingQrScannerScreen> createState() =>
      _WindowsPairingQrScannerScreenState();
}

class _WindowsPairingQrScannerScreenState
    extends State<_WindowsPairingQrScannerScreen> {
  final dart_qr.QrCodeDartDecoder _decoder = dart_qr.QrCodeDartDecoder(
    formats: const [dart_qr.BarcodeFormat.qrCode],
  );
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  Timer? _scanTimer;
  int _cameraIndex = 0;
  String? _message;
  bool _initializing = true;
  bool _scanning = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
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
                    child: ready
                        ? CameraPreview(controller)
                        : Center(
                            child: _initializing
                                ? const CircularProgressIndicator()
                                : const Icon(Icons.no_photography_outlined),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _message ??
                    'Point the Windows tablet camera at the AZMusic pairing QR. The app scans snapshots automatically.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: ready && !_scanning ? _scanOnce : null,
                    icon: _scanning
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_scanner_outlined),
                    label: const Text('Scan now'),
                  ),
                  if (_cameras.length > 1)
                    OutlinedButton.icon(
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.cameraswitch_outlined),
                      label: const Text('Switch camera'),
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Use manual entry instead'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _initializing = true;
      _message = 'Looking for Windows cameras...';
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _setCameraFailure('No Windows camera was found.');
        return;
      }

      final preferredIndex = _preferredCameraIndex(_cameras);
      await _openCamera(preferredIndex);
      _startAutoScan();
    } on CameraException catch (error) {
      _setCameraFailure('Camera unavailable: ${error.description ?? error.code}');
    } catch (error) {
      _setCameraFailure('Camera unavailable: $error');
    }
  }

  Future<void> _openCamera(int index) async {
    _scanTimer?.cancel();
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraIndex = index;
      _controller = controller;
      _initializing = false;
      _message = 'Camera ready. Hold the QR steady in view.';
    });
  }

  int _preferredCameraIndex(List<CameraDescription> cameras) {
    final backIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    if (backIndex >= 0) {
      return backIndex;
    }

    final externalIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.external,
    );
    if (externalIndex >= 0) {
      return externalIndex;
    }

    return 0;
  }

  void _startAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_scanOnce());
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _scanning) {
      return;
    }

    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() {
      _initializing = true;
      _message = 'Switching camera...';
    });
    try {
      await _openCamera(nextIndex);
      _startAutoScan();
    } catch (error) {
      _setCameraFailure('Unable to switch camera: $error');
    }
  }

  Future<void> _scanOnce() async {
    final controller = _controller;
    if (_handled ||
        _scanning ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _scanning = true;
      _message = 'Scanning camera image...';
    });

    XFile? photo;
    try {
      photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final decoded = await _decoder.decodeFile(bytes);
      final rawValue = decoded?.text;
      if (rawValue != null) {
        final payload = PairingPayload.tryParse(rawValue);
        if (payload != null) {
          _handled = true;
          _scanTimer?.cancel();
          if (mounted) {
            Navigator.of(context).pop(payload);
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _message = 'No AZMusic QR found yet. Hold the QR steady and closer.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = 'Scan failed: $error';
        });
      }
    } finally {
      if (photo != null) {
        unawaited(_deleteTemporaryPhoto(photo.path));
      }
      if (mounted && !_handled) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  void _setCameraFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _initializing = false;
      _message = message;
    });
  }

  Future<void> _deleteTemporaryPhoto(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Best-effort cleanup for camera snapshots.
    }
  }
}
