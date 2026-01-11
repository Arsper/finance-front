import 'package:dio/dio.dart';
import 'package:my_app/helpers/StorageService.dart';
import 'package:my_app/main.dart'; // <--- 1. ИМПОРТИРУЕМ MAIN, ЧТОБЫ ВИДЕТЬ navigatorKey

class Dioclient {
  static Dio? _dio;

  static Dio get instance {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          // baseUrl: "http://10.0.2.2:8080", // Раскомментируйте и проверьте IP, если нужно
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              final token = await StorageService.getToken(); // Проверьте, нужен ли тут await (зависит от StorageService)
              // Если StorageService.getToken() возвращает просто String, уберите await

              if (token != null && token.toString().isNotEmpty) {
                 // Иногда token может прийти как Object, лучше привести к строке
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              print("Error getting token: $e");
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
                (route) => false
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