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
  static List<dynamic> apply({
    required List<dynamic> transactions,
    required TransactionFilters filters,
  }) {
    final filtered = transactions.where((t) {
      if (t['localDeleted'] == true) return false;

      final tDateRaw = t['transactionDate'];
      final tDate = tDateRaw is DateTime
          ? tDateRaw
          : DateTime.tryParse(tDateRaw?.toString() ?? '');

      final int? tCatId = int.tryParse(t['categoryId']?.toString() ?? '');

      bool dateMatch = true;
      if (filters.dateRange != null && tDate != null) {
        final start = _stripTime(filters.dateRange!.start);
        final end = DateTime(
          filters.dateRange!.end.year,
          filters.dateRange!.end.month,
          filters.dateRange!.end.day,
          23,
          59,
          59,
        );
        dateMatch = !tDate.isBefore(start) && !tDate.isAfter(end);
      }

      bool categoryMatch = true;
      if (filters.categoryIds.isNotEmpty) {
        categoryMatch = filters.categoryIds.contains(tCatId);
      }

      return dateMatch && categoryMatch;
    }).toList();

    filtered.sort((a, b) {
      final dateARaw = a['transactionDate'];
      final dateBRaw = b['transactionDate'];

      DateTime? dateA = dateARaw is DateTime
          ? dateARaw
          : DateTime.tryParse(dateARaw?.toString() ?? '');
      DateTime? dateB = dateBRaw is DateTime
          ? dateBRaw
          : DateTime.tryParse(dateBRaw?.toString() ?? '');

      dateA ??= DateTime(1970);
      dateB ??= DateTime(1970);

      return dateB.millisecondsSinceEpoch.compareTo(
        dateA.millisecondsSinceEpoch,
      );
    });

    return filtered;
  }

  static DateTimeRange? calculateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'day':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
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
