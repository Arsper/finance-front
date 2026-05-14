import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:my_app/helpers/StorageService.dart';
import 'package:my_app/main.dart'; // <--- 1. ИМПОРТИРУЕМ MAIN, ЧТОБЫ ВИДЕТЬ navigatorKey

class Dioclient {
  static Dio? _dio;

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
            try {
              // 1. Добавляем проверку: если это запрос на логин или регистрацию, токен не нужен
              if (options.path.contains('/auth/')) {
                return handler.next(options);
              }

              final token = await StorageService.getToken();
              if (token != null && token.toString().trim().isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              debugPrint("Interceptor Error: $e");
              // Если произошла ошибка при получении токена, всё равно пускаем запрос дальше
              // (сервер сам вернет 401, если токен обязателен)
            }
            return handler.next(options);
          },

          // ОБРАБОТКА ОШИБКИ
          onError: (DioException e, handler) {
            if (e.response?.statusCode == 401) {
              print("Токен истек (401). Выполняем выход...");

              // 2. Чистим хранилище
              StorageService.clear();

              // 3. Используем глобальный ключ для навигации БЕЗ контекста
              // pushNamedAndRemoveUntil удаляет историю переходов, чтобы кнопка "Назад" не возвращала на защищенный экран
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
            return handler.next(e);
          },
        ),
      );
    }
    return _dio!;
  }
}
