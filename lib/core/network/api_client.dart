import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static Dio? _instance;
  static const _storage = FlutterSecureStorage();

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Options authHeader(String token) =>
      Options(headers: {'Authorization': 'Bearer \$token'});

  static void reset() => _instance = null;

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    dio.interceptors.add(_AuthInterceptor());
    if (kDebugMode) dio.interceptors.add(_LoggingInterceptor());
    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) options.headers['Authorization'] = 'Bearer \$token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          final plain = Dio();
          final res = await plain.post(
            '\${ApiConstants.baseUrl}\${ApiConstants.refresh}',
            data: {'refresh_token': refreshToken},
          );
          final newAccess  = res.data['data']['access_token'] as String;
          final newRefresh = res.data['data']['refresh_token'] as String;
          await _storage.write(key: 'jwt_token', value: newAccess);
          await _storage.write(key: 'refresh_token', value: newRefresh);
          err.requestOptions.headers['Authorization'] = 'Bearer \$newAccess';
          return handler.resolve(await plain.fetch(err.requestOptions));
        }
      } catch (_) {
        await _storage.deleteAll();
      }
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[API] \${options.method} \${options.uri}');
    handler.next(options);
  }
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[API ERR] \${err.response?.statusCode} \${err.message}');
    handler.next(err);
  }
}
