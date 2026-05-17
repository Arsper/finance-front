import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:my_app/helpers/AuthStorageService.dart';
import 'package:my_app/main.dart';

class Dioclient {
  static Dio? _dio;
  static bool _isRefreshing = false;
  static final List<RequestOptions> _failedRequests = [];

  static Dio get instance {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      _dio!.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );

      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path.contains('/auth/')) {
              return handler.next(options);
            }

            final token = await AuthStorageService.getToken();
            if (token != null && token.trim().isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          },

          onError: (DioException e, handler) async {
            if ((e.response?.statusCode == 401 ||
                    e.response?.statusCode == 403) &&
                !e.requestOptions.path.contains('/auth/refresh-token')) {
              if (_isRefreshing) {
                _failedRequests.add(e.requestOptions);
                return handler.next(e);
              }

              _isRefreshing = true;

              try {
                final newToken = await _refreshToken();
                if (newToken != null) {
                  final refreshToken =
                      await AuthStorageService.getRefreshToken();
                  final userId = await AuthStorageService.getUserId();
                  final userLogin = await AuthStorageService.getUserLogin();

                  await AuthStorageService.saveAuthData(
                    token: newToken,
                    refreshToken: refreshToken,
                    userId: userId ?? 0,
                    login: userLogin ?? '',
                  );

                  for (final request in _failedRequests) {
                    request.headers['Authorization'] = 'Bearer $newToken';
                    try {
                      await _dio!.fetch(request);
                    } catch (e) {
                      print("Failed to retry request: $e");
                    }
                  }
                  _failedRequests.clear();

                  final options = e.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newToken';
                  final response = await _dio!.fetch(options);
                  return handler.resolve(response);
                } else {
                  await _logout();
                  return handler.next(e);
                }
              } catch (error) {
                await _logout();
                return handler.next(e);
              } finally {
                _isRefreshing = false;
              }
            }

            return handler.next(e);
          },
        ),
      );
    }
    return _dio!;
  }

  static Future<String?> _refreshToken() async {
    try {
      final refreshToken = await AuthStorageService.getRefreshToken();
      if (refreshToken == null) return null;

      final response = await Dio().post(
        'http://localhost:8080/api/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data['token'];
      }
      return null;
    } catch (e) {
      print("Error refreshing token: $e");
      return null;
    }
  }

  static Future<void> _logout() async {
    print("Выполняем выход из системы");
    await AuthStorageService.clearAuthData();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
}
