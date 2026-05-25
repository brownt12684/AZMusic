import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.serverBaseUrl,
        connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
        receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AppConfig.serverPairingToken;
          if (token != null && token.isNotEmpty) {
            options.headers['X-AZMusic-Device-Token'] = token;
          }
          handler.next(options);
        },
      ),
    );

    if (AppConfig.debugLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  Dio get client => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }
}
