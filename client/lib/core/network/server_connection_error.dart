import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ServerNotPairedException implements Exception {
  const ServerNotPairedException();

  @override
  String toString() {
    return 'This device is not paired with an AZMusic server yet.';
  }
}

bool isServerConnectionError(Object error) {
  if (error is ServerNotPairedException) {
    return true;
  }
  if (error is! DioException) {
    return false;
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.connectionError =>
      true,
    _ => false,
  };
}

String formatServerConnectionError(Object error) {
  if (error is ServerNotPairedException) {
    return 'This device is not paired yet. Open the AZMusic server setup page, scan the QR code, then return here.';
  }

  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return 'The server rejected this device pairing. Re-pair this device from the AZMusic server setup page.';
    }
    if (statusCode != null) {
      final detail = _responseDetail(error.response?.data);
      return 'Server returned HTTP $statusCode: ${detail ?? error.message ?? error.type.name}';
    }
    if (isServerConnectionError(error)) {
      return 'AZMusic cannot reach ${AppConfig.serverBaseUrl}. Make sure the AZMusic Server window is running, this device is on the same network, and the pairing has not changed.';
    }
    return error.message ?? error.type.name;
  }

  return error.toString();
}

String? _responseDetail(Object? data) {
  if (data == null) {
    return null;
  }
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }
    if (detail != null) {
      return detail.toString();
    }
  }
  if (data is String && data.trim().isNotEmpty) {
    return data;
  }
  return data.toString();
}
