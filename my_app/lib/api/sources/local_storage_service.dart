import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _walletsKey = 'offline_wallets';
  static const String _categoriesKey = 'cached_categories';

  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();

  Future<void> saveWallets(List<dynamic> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_walletsKey, jsonEncode(wallets));
  }

  Future<List<dynamic>> getWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_walletsKey);
    if (cached == null) return [];
    return jsonDecode(cached) as List<dynamic>;
  }

  Future<void> addWalletOffline(Map<String, dynamic> walletData) async {
    final wallets = await getWallets();
    final int temporaryId = DateTime.now().millisecondsSinceEpoch * -1;

    final newWallet = {
      ...walletData,
      'billId': temporaryId,
      'currentBalance':
          double.tryParse(walletData['currentBalance']?.toString() ?? '0') ??
          0.0,
      'isSynced': false,
      'isNewOffline': true,
    };

    wallets.add(newWallet);
    await saveWallets(wallets);
  }

  Future<void> updateWalletOffline(
    int billId,
    Map<String, dynamic> updatedData,
  ) async {
    final wallets = await getWallets();
    final index = wallets.indexWhere((w) => w['billId'] == billId);

    if (index != -1) {
      wallets[index] = {...wallets[index], ...updatedData, 'isSynced': false};
      await saveWallets(wallets);
    }
  }

  Future<void> deleteWalletOffline(int billId) async {
    final wallets = await getWallets();
    final index = wallets.indexWhere((w) => w['billId'] == billId);

    if (index != -1) {
      if (wallets[index]['isNewOffline'] == true) {
        wallets.removeAt(index);
      } else {
        wallets[index]['isDeletedOffline'] = true;
        wallets[index]['isSynced'] = false;
      }
      await saveWallets(wallets);
    }
  }

  Future<void> _updateWalletBalanceLocally(int billId, double delta) async {
    final wallets = await getWallets();
    final index = wallets.indexWhere(
      (w) => w['billId'].toString() == billId.toString(),
    );
    if (index != -1) {
      double current = (wallets[index]['currentBalance'] as num? ?? 0.0)
          .toDouble();
      wallets[index]['currentBalance'] = current + delta;
      await saveWallets(wallets);
      debugPrint(
        "STORAGE: Локальный баланс кошелька $billId обновлен на $delta. Новый: ${wallets[index]['currentBalance']}",
      );
    }
  }

  // --- КАТЕГОРИИ ---

  Future<void> saveCategories(List<dynamic> categories) async {
    debugPrint(
      "STORAGE: Сохраняю ${categories.length} категорий в SharedPreferences...",
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(categories));
  }

  Future<List<dynamic>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_categoriesKey);

    if (cached == null) {
      debugPrint("STORAGE: Кэш пуст (null).");
      return [];
    }

    final List<dynamic> decoded = jsonDecode(cached);
    debugPrint("STORAGE: Прочитано ${decoded.length} категорий из кэша.");
    return decoded;
  }

  // --- ТРАНЗАКЦИИ ---

  String _getTransactionsKey(int billId) => 'cached_transactions_bill_$billId';

  Future<void> saveTransactions(int billId, List<dynamic> transactions) async {
    debugPrint(
      "STORAGE: Сохраняю ${transactions.length} транзакций для счета $billId в кэш...",
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _getTransactionsKey(billId),
      jsonEncode(transactions),
    );
  }

  Future<List<dynamic>> getTransactions(int billId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_getTransactionsKey(billId));

    if (cached == null) {
      debugPrint("STORAGE: Кэш транзакций для счета $billId пуст.");
      return [];
    }

    final List<dynamic> decoded = jsonDecode(cached);
    debugPrint(
      "STORAGE: Прочитано ${decoded.length} транзакций из кэша для счета $billId.",
    );
    return decoded;
  }

  Future<void> addTransactionOffline(
    int billId,
    Map<String, dynamic> txData,
  ) async {
    final transactions = await getTransactions(billId);
    final int temporaryTxId = DateTime.now().millisecondsSinceEpoch * -1;

    final num amount = txData['amount'] ?? 0.0;

    final newTx = {
      ...txData,
      'id': temporaryTxId,
      'idTransaction': temporaryTxId,
      'transactionId': temporaryTxId,
      'billId': billId,
      'isSynced': false,
      'isNewOffline': true,
      'transactionDate':
          txData['transactionDate'] ??
          DateTime.now().toIso8601String().split('T')[0],
    };

    transactions.insert(0, newTx);
    await saveTransactions(billId, transactions);

    await _updateWalletBalanceLocally(billId, amount.toDouble());
  }

  Future<void> updateTransactionOffline(
    int billId,
    dynamic txId,
    Map<String, dynamic> updatedData,
  ) async {
    final List<dynamic> list = await getTransactions(billId);

    List<dynamic> localCategories = [];
    try {
      localCategories = await getCategories();
    } catch (e) {
      debugPrint(
        "STORAGE Error: Не удалось загрузить категории для обогащения: $e",
      );
    }

    for (int i = 0; i < list.length; i++) {
      final currentId =
          list[i]['idTransaction'] ?? list[i]['id'] ?? list[i]['transactionId'];

      if (currentId?.toString() == txId.toString()) {
        final double oldAmount = (list[i]['amount'] ?? list[i]['sum'] ?? 0.0)
            .toDouble();

        double newAmount = (updatedData['amount'] ?? updatedData['sum'] ?? 0.0)
            .toDouble();
        final bool isIncome = updatedData['isIncome'] ?? (newAmount > 0);
        if (!isIncome && newAmount > 0) newAmount = -newAmount;

        String? newCategoryName = list[i]['categoryName'];
        final int? newCategoryId = updatedData['categoryId'];

        if (newCategoryId != null && localCategories.isNotEmpty) {
          final foundCat = localCategories.firstWhere((c) {
            final dynamic rawId = c['categoryId'] ?? c['id'] ?? c['idCategory'];
            if (rawId == null) return false;
            return rawId.toString() == newCategoryId.toString();
          }, orElse: () => null);

          if (foundCat != null) {
            newCategoryName =
                (foundCat['name'] ??
                        foundCat['categoryName'] ??
                        foundCat['title'])
                    ?.toString();
          } else {
            debugPrint(
              "STORAGE [WARN]: Категория с ID $newCategoryId не найдена в кэше! Искали по categoryId/id/idCategory. Всего категорий в кэше: ${localCategories.length}",
            );
          }
        }

        list[i] = {
          ...list[i],
          ...updatedData,
          'amount': newAmount,
          'sum': newAmount,
          if (newCategoryName != null) 'categoryName': newCategoryName,
          'localUpdated': true,
          'isSynced': false,
        };

        final double delta = newAmount - oldAmount;
        await _updateWalletBalanceLocally(billId, delta);
        break;
      }
    }

    await saveTransactions(billId, list);
    await _queueForSync(billId, txId, 'UPDATE');
  }

  Future<void> deleteTransactionOffline(int billId, dynamic txId) async {
    final List<dynamic> list = await getTransactions(billId);
    final int originalLength = list.length;
    double amountToRemove = 0.0;

    for (int i = 0; i < list.length; i++) {
      final currentId =
          list[i]['idTransaction'] ?? list[i]['id'] ?? list[i]['transactionId'];

      if (currentId?.toString() == txId.toString()) {
        amountToRemove = (list[i]['amount'] ?? list[i]['sum'] ?? 0.0)
            .toDouble();

        if (list[i]['isNewOffline'] == true) {
          list.removeAt(i);
        } else {
          list[i]['localDeleted'] = true;
          list[i]['isSynced'] = false;
        }
        break;
      }
    }

    if (amountToRemove != 0.0) {
      await _updateWalletBalanceLocally(billId, -amountToRemove);
    }

    debugPrint(
      "STORAGE: Перезаписываю кэш после удаления для счета $billId. Было: $originalLength, стало: ${list.length}",
    );
    await saveTransactions(billId, list);
    await _queueForSync(billId, txId, 'DELETE');
  }

  Future<void> _queueForSync(int billId, dynamic txId, String action) async {
    debugPrint(
      "STORAGE: Действие $action для ID $txId поставлено в очередь синхронизации.",
    );
  }

  Future<void> migrateOfflineTransactions({
    required int oldTemporaryId,
    required int newServerId,
  }) async {
    final transactions = await getTransactions(oldTemporaryId);
    if (transactions.isEmpty) {
      debugPrint(
        "STORAGE [MIGRATION]: Офлайн транзакций для временного ID $oldTemporaryId не найдено.",
      );
      return;
    }

    final migratedTransactions = transactions.map((tx) {
      return {...tx, 'billId': newServerId};
    }).toList();

    await saveTransactions(newServerId, migratedTransactions);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getTransactionsKey(oldTemporaryId));

    debugPrint(
      "STORAGE [MIGRATION]: Успешно перенесено ${migratedTransactions.length} транзакций с ID $oldTemporaryId на реальный ID $newServerId",
    );
  }
}
