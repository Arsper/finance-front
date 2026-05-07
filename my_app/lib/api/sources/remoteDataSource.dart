import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:my_app/api/data/%D1%81ategoryStat.dart';
import 'package:my_app/api/data/%D1%81urrency.dart';
import 'package:my_app/api/data/dailyStat.dart';
import 'package:my_app/api/data/ratePoint.dart';
import 'package:my_app/api/url/urlParametrs.dart';
import 'package:my_app/helpers/StorageService.dart';

class UserRemoteDataSource {
  final Dio dio;

  UserRemoteDataSource({required this.dio});

  Future<bool> loginUser(String pas, String email) async {
    try {
      final response = await dio.post(
        UrlParameters.loginUrl,
        data: {'login': email, 'password': pas},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];

        if (token != null) {
          await StorageService.saveToken(token);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  Future<bool> sendRegistrationCode(String email) async {
    try {
      final response = await dio.post(
        UrlParameters.registerSendCode,
        queryParameters: {'email': email},
        options: Options(
          responseType: ResponseType.plain,
        ), // Добавьте это, если бэк шлет текст
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyRegistrationCode(String email, String code) async {
    try {
      final response = await dio.post(
        UrlParameters.verifyCode,
        queryParameters: {'email': email, 'code': code},
        // Указываем, что сервер возвращает текст, а не JSON
        options: Options(responseType: ResponseType.plain),
      );

      // Теперь Dio корректно получит "Код верный" и вернет 200
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Ошибка верификации (сервер): ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('Неизвестная ошибка верификации: $e');
      return false;
    }
  }

  // --- МЕТОДЫ ДЛЯ СБРОСА ПАРОЛЯ ---

  Future<bool> sendForgotPasswordCode(String email) async {
    try {
      final response = await dio.post(
        UrlParameters.forgotSendCode,
        // Используем queryParameters, так как в Java стоит @RequestParam
        queryParameters: {'email': email},
        // Указываем, что ждем обычную строку, если сервер шлет текст
        options: Options(responseType: ResponseType.plain),
      );

      // Если бэкенд вернул 200, значит всё успешно
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Ошибка в источнике данных (sendForgotPasswordCode): $e');
      return false;
    }
  }

  Future<bool> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      final response = await dio.post(
        UrlParameters.forgotReset,
        // ИЗМЕНЕНО: используем data вместо queryParameters
        data: {'email': email, 'code': code, 'newPassword': newPassword},
        options: Options(
          responseType: ResponseType.plain,
          // Убедись, что заголовок установлен (хотя Dio делает это сам для Map)
          contentType: 'application/json',
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Reset Password Error (Dio): ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('Reset Password Unknown Error: $e');
      return false;
    }
  }

  Future<List<Currency>> getCurrencies() async {
    final response = await dio.get(UrlParameters.currenciesUrl);
    return (response.data as List).map((e) => Currency.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getWallets() async {
    try {
      final response = await dio.get(UrlParameters.billsUrl);
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint("Error fetching wallets: $e");
      return [];
    }
  }

  Future<bool> addWallet(Map<String, dynamic> walletData) async {
    try {
      final response = await dio.post(UrlParameters.billsUrl, data: walletData);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteWallet(int id) async {
    try {
      final response = await dio.delete('${UrlParameters.billsUrl}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateWallet(int id, Map<String, dynamic> walletData) async {
    try {
      final response = await dio.put(
        '${UrlParameters.billsUrl}/$id',
        data: walletData,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getCategories() async {
    try {
      final response = await dio.get(UrlParameters.categoriesUrl);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> addCategory(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(UrlParameters.categoriesUrl, data: data);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      final response = await dio.delete('${UrlParameters.categoriesUrl}/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    try {
      final response = await dio.put(
        '${UrlParameters.categoriesUrl}/$id',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getTransactions({int? billId}) async {
    try {
      final response = await dio.get(
        UrlParameters.transactionsUrl,
        queryParameters: billId != null ? {'billId': billId} : null,
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> addTransaction(Map<String, dynamic> data) async {
    try {
      final response = await dio.post(
        UrlParameters.transactionsUrl,
        data: data,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final response = await dio.delete('${UrlParameters.transactionsUrl}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTransaction(int id, Map<String, dynamic> data) async {
    try {
      final response = await dio.put(
        '${UrlParameters.transactionsUrl}/$id',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getRecurringPayments() async {
    try {
      final response = await dio.get(UrlParameters.recurringPaymentsUrl);
      return response.data;
    } catch (e) {
      debugPrint("Error getRecurringPayments: $e");
      return [];
    }
  }

  Future<bool> addRecurringPayment(Map<String, dynamic> data) async {
    try {
      await dio.post(UrlParameters.recurringPaymentsUrl, data: data);
      return true;
    } catch (e) {
      debugPrint("Error addRecurringPayment: $e");
      return false;
    }
  }

  Future<bool> updateRecurringPayment(int id, Map<String, dynamic> data) async {
    try {
      await dio.put('${UrlParameters.recurringPaymentsUrl}/$id', data: data);
      return true;
    } catch (e) {
      debugPrint("Error updateRecurringPayment: $e");
      return false;
    }
  }

  Future<bool> deleteRecurringPayment(int id) async {
    try {
      await dio.delete('${UrlParameters.recurringPaymentsUrl}/$id');
      return true;
    } catch (e) {
      debugPrint("Error deleteRecurringPayment: $e");
      return false;
    }
  }

  Future<List<dynamic>> getGoals() async {
    try {
      final response = await dio.get(UrlParameters.goalsUrl);
      return response.data;
    } catch (e) {
      debugPrint("Error getGoals: $e");
      return [];
    }
  }

  Future<bool> addGoal(Map<String, dynamic> data) async {
    try {
      await dio.post(UrlParameters.goalsUrl, data: data);
      return true;
    } catch (e) {
      debugPrint("Error addGoal: $e");
      return false;
    }
  }

  Future<bool> updateGoal(int id, Map<String, dynamic> data) async {
    try {
      await dio.put('${UrlParameters.goalsUrl}/$id', data: data);
      return true;
    } catch (e) {
      debugPrint("Error updateGoal: $e");
      return false;
    }
  }

  Future<bool> deleteGoal(int id) async {
    try {
      await dio.delete('${UrlParameters.goalsUrl}/$id');
      return true;
    } catch (e) {
      debugPrint("Error deleteGoal: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> calculateAccumulation(
    double monthlyDeposit,
    int months,
  ) async {
    try {
      final response = await dio.post(
        UrlParameters.calcAccumulationUrl,
        data: {"monthlyDeposit": monthlyDeposit, "totalMonths": months},
      );
      return response.data;
    } catch (e) {
      debugPrint("Error calculateAccumulation: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> calculateDeposit(
    double targetAmount,
    String date,
  ) async {
    try {
      final response = await dio.post(
        UrlParameters.calcDepositUrl,
        data: {"targetAmount": targetAmount, "targetDate": date},
      );
      return response.data;
    } catch (e) {
      debugPrint("Error calculateDeposit: $e");
      return null;
    }
  }

  Future<List<CategoryStat>> getCategoryStats(
    int billId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];

      final response = await dio.get(
        UrlParameters.statsCategoriesUrl,
        queryParameters: {
          'billId': billId,
          'startDate': startStr,
          'endDate': endStr,
        },
      );

      return (response.data as List)
          .map((e) => CategoryStat.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint("Error fetching category stats: $e");
      return [];
    }
  }

  Future<List<DailyStat>> getDailyStats(
    int billId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];

      final response = await dio.get(
        UrlParameters.statsDailyUrl,
        queryParameters: {
          'billId': billId,
          'startDate': startStr,
          'endDate': endStr,
        },
      );

      return (response.data as List).map((e) => DailyStat.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetching daily stats: $e");
      return [];
    }
  }

  Future<double?> convertCurrency({
    required int fromId,
    required int toId,
    required double amount,
  }) async {
    try {
      final response = await dio.get(
        UrlParameters.exchangeConvertUrl,
        queryParameters: {'from': fromId, 'to': toId, 'amount': amount},
      );
      // Бэкенд возвращает просто число (BigDecimal), например 95.50
      return (response.data as num).toDouble();
    } catch (e) {
      debugPrint("Error converting currency: $e");
      return null;
    }
  }

  // 2. Получение истории для графика
  Future<List<RatePoint>> getExchangeHistory({
    required int fromId,
    required int toId,
    required String period, // "week" или "month"
  }) async {
    try {
      final response = await dio.get(
        UrlParameters.exchangeHistoryUrl,
        queryParameters: {'from': fromId, 'to': toId, 'period': period},
      );

      return (response.data as List).map((e) => RatePoint.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }
}
