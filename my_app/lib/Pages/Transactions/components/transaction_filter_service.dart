import 'package:flutter/material.dart';

class TransactionFilters {
  DateTimeRange? dateRange;
  List<int> categoryIds;
  String period;

  TransactionFilters({
    this.dateRange,
    List<int>? categoryIds,
    this.period = 'all',
  }) : this.categoryIds = categoryIds != null
           ? List<int>.from(categoryIds)
           : [];
  bool get isEmpty =>
      period == 'all' && dateRange == null && categoryIds.isEmpty;
}

class TransactionFilterService {
  /// Основной метод фильтрации
  static List<dynamic> apply({
    required List<dynamic> transactions,
    required TransactionFilters filters,
  }) {
    return transactions.where((t) {
      final tDate = DateTime.parse(t['transactionDate']);
      final tCatId = t['categoryId'] as int?;

      // 1. Фильтр по датам
      bool dateMatch = true;
      if (filters.dateRange != null) {
        final start = _stripTime(filters.dateRange!.start);
        final end = _stripTime(filters.dateRange!.end);
        dateMatch = !tDate.isBefore(start) && !tDate.isAfter(end);
      }

      // 2. Фильтр по категориям
      bool categoryMatch = true;
      if (filters.categoryIds.isNotEmpty) {
        categoryMatch = filters.categoryIds.contains(tCatId);
      }

      return dateMatch && categoryMatch;
    }).toList();
  }

  /// Утилита для расчета диапазонов дат (Неделя, Месяц и т.д.)
  static DateTimeRange? calculateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'day':
        return DateTimeRange(start: now, end: now);
      case 'week':
        return DateTimeRange(
          start: now.subtract(Duration(days: now.weekday - 1)),
          end: now.add(Duration(days: 7 - now.weekday)),
        );
      case 'month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      default:
        return null;
    }
  }

  static DateTime _stripTime(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
