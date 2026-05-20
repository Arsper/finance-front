import 'package:flutter/material.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/Pages/Transactions/components/transaction_filter_service.dart';

class TransactionRepository {
  final UserRemoteDataSource remote;
  final LocalStorageService local;

  TransactionRepository(this.remote, this.local);

  Future<void> syncOfflineTransactions() async {
    final bool online = await isServerAvailable();
    if (!online) {
      return;
    }

    try {
      final wallets = await local.getWallets();

      for (var wallet in wallets) {
        final int billId =
            int.tryParse(wallet['billId']?.toString() ?? '0') ?? 0;
        if (billId == 0) continue;

        final List<dynamic> cachedTx = await local.getTransactions(billId);
        if (cachedTx.isEmpty) continue;

        final List<dynamic> updatedList = List.from(cachedTx);
        bool isCacheChanged = false;

        for (var tx in cachedTx) {
          final dynamic txId =
              tx['idTransaction'] ?? tx['id'] ?? tx['transactionId'];

          if (tx['localDeleted'] == true) {
            try {
              if (tx['isNewOffline'] == true) {
                updatedList.removeWhere(
                  (item) =>
                      (item['idTransaction'] ??
                          item['id'] ??
                          item['transactionId']) ==
                      txId,
                );
                isCacheChanged = true;
                continue;
              }
              await remote.deleteTransaction(txId);
              updatedList.removeWhere(
                (item) =>
                    (item['idTransaction'] ??
                        item['id'] ??
                        item['transactionId']) ==
                    txId,
              );
              isCacheChanged = true;
            } catch (e) {
              debugPrint("REPO [TX SYNC] ERROR: Ошибка удаления TX $txId: $e");
            }
          } else if (tx['isNewOffline'] == true) {
            try {
              final Map<String, dynamic> serverData =
                  Map<String, dynamic>.from(tx)
                    ..remove('id')
                    ..remove('idTransaction')
                    ..remove('transactionId')
                    ..remove('isNewOffline')
                    ..remove('isSynced')
                    ..remove('localUpdated');

              await remote.addTransaction({...serverData, "billId": billId});

              final int idx = updatedList.indexWhere(
                (item) =>
                    (item['idTransaction'] ??
                        item['id'] ??
                        item['transactionId']) ==
                    txId,
              );
              if (idx != -1) {
                updatedList[idx]['isNewOffline'] = false;
                updatedList[idx]['isSynced'] = true;
                isCacheChanged = true;
              }
            } catch (e) {
              debugPrint(
                "REPO [TX SYNC] ERROR: Ошибка создания оффлайн TX: $e",
              );
            }
          } else if (tx['localUpdated'] == true) {
            try {
              final Map<String, dynamic> serverData =
                  Map<String, dynamic>.from(tx)
                    ..remove('id')
                    ..remove('idTransaction')
                    ..remove('transactionId')
                    ..remove('localUpdated')
                    ..remove('isSynced')
                    ..remove('isNewOffline')
                    ..remove('categoryName');

              await remote.updateTransaction(txId, serverData);

              final int idx = updatedList.indexWhere(
                (item) =>
                    (item['idTransaction'] ??
                        item['id'] ??
                        item['transactionId']) ==
                    txId,
              );
              if (idx != -1) {
                updatedList[idx]['localUpdated'] = false;
                updatedList[idx]['isSynced'] = true;
                isCacheChanged = true;
              }
            } catch (e) {
              debugPrint(
                "REPO [TX SYNC] ERROR: Ошибка обновления TX $txId: $e",
              );
            }
          }
        }

        if (isCacheChanged) {
          await local.saveTransactions(billId, updatedList);
        }
      }
    } catch (e) {
      debugPrint("REPO [TX SYNC] CRITICAL ERROR: $e");
    }
  }

  Future<List<dynamic>> getTransactions({
    required int billId,
    required int page,
    required int size,
    required TransactionFilters filters,
  }) async {
    if (page == 0 && filters.isEmpty) {
      try {
        await syncOfflineTransactions();
      } catch (e) {
        debugPrint(
          "REPO [SYNC WARN]: Сеть недоступна, пропускаем авто-синхронизацию.",
        );
      }
    }

    try {
      final freshData = await remote.getTransactions(
        billId: billId,
        page: page,
        size: size,
        filters: filters,
      );

      if (page == 0 && filters.isEmpty) {
        await local.saveTransactions(billId, freshData);
      }

      return freshData;
    } catch (e) {
      final List<dynamic> localTx = await local.getTransactions(billId);
      final List<Map<String, dynamic>> enrichedLocalTx = [];

      for (var tx in localTx) {
        final Map<String, dynamic> mutableTx = Map<String, dynamic>.from(
          tx as Map,
        );
        final int? catId = int.tryParse(
          mutableTx['categoryId']?.toString() ?? '',
        );

        if (catId != null) {
          final String? actualCatName = await _getLocalCategoryName(catId);
          if (actualCatName != null) {
            mutableTx['categoryName'] = actualCatName;
          }
        }
        enrichedLocalTx.add(mutableTx);
      }

      final List<dynamic> filteredAndSorted = TransactionFilterService.apply(
        transactions: enrichedLocalTx,
        filters: filters,
      );

      final int startIndex = page * size;
      if (startIndex >= filteredAndSorted.length) {
        return [];
      }

      final int endIndex = (startIndex + size) > filteredAndSorted.length
          ? filteredAndSorted.length
          : (startIndex + size);

      return filteredAndSorted.sublist(startIndex, endIndex);
    }
  }

  Future<void> addTransaction(int billId, Map<String, dynamic> data) async {
    final online = await isServerAvailable();

    final Map<String, dynamic> enrichedData = Map<String, dynamic>.from(data);
    final int? categoryId = enrichedData['categoryId'];
    if (categoryId != null) {
      final String? catName = await _getLocalCategoryName(categoryId);
      if (catName != null) {
        enrichedData['categoryName'] = catName;
      }
    }

    if (online) {
      await remote.addTransaction({...enrichedData, "billId": billId});
    } else {
      await local.addTransactionOffline(billId, enrichedData);
    }
  }

  Future<void> updateTransaction(
    int billId,
    dynamic txId,
    Map<String, dynamic> data,
  ) async {
    final online = await isServerAvailable();

    final Map<String, dynamic> enrichedData = Map<String, dynamic>.from(data);
    final int? categoryId = enrichedData['categoryId'];
    if (categoryId != null) {
      final String? catName = await _getLocalCategoryName(categoryId);
      if (catName != null) {
        enrichedData['categoryName'] = catName;
      }
    }

    if (online) {
      await remote.updateTransaction(txId, enrichedData);
    } else {
      await local.updateTransactionOffline(billId, txId, enrichedData);
    }
  }

  Future<void> deleteTransaction(int billId, dynamic txId) async {
    final online = await isServerAvailable();
    if (online) {
      await remote.deleteTransaction(txId);
    } else {
      await local.deleteTransactionOffline(billId, txId);
    }
  }

  Future<bool> isServerAvailable() async {
    try {
      return await remote.checkServerHealth();
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getLocalCategoryName(int categoryId) async {
    try {
      final List<dynamic> cachedCategories = await local.getCategories();
      if (cachedCategories.isNotEmpty) {
        final found = cachedCategories.firstWhere(
          (c) => c['id']?.toString() == categoryId.toString(),
          orElse: () => null,
        );
        if (found != null && found['name'] != null) {
          return found['name'] as String;
        }
      }
    } catch (e) {
      debugPrint(
        "REPO ERROR [_getLocalCategoryName]: Не удалось прочитать имя категории: $e",
      );
    }
    return null;
  }
}
