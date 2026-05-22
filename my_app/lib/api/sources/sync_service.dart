import 'package:flutter/material.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';

class SyncService {
  final UserRemoteDataSource remote;
  final LocalStorageService local;

  SyncService(this.remote, this.local);

  Future<void> syncBillData(int billId) async {
    try {
      debugPrint("SYNC: Проверка оффлайн-изменений для счета $billId...");

      List<dynamic> localTxList = await local.getTransactions(billId);
      if (localTxList.isEmpty) {
        return;
      }

      List<dynamic> updatedLocalTxList = List.from(localTxList);
      bool hasChanges = false;

      for (var tx in localTxList) {
        final dynamic currentId = tx['idTransaction'] ?? tx['id'];

        if (tx['isNewOffline'] == true) {
          try {
            final Map<String, dynamic> body = Map.from(tx)
              ..remove('id')
              ..remove('idTransaction')
              ..remove('isSynced')
              ..remove('isNewOffline')
              ..remove('categoryName');

            body['billId'] = billId;

            await remote.addTransaction(body);
            updatedLocalTxList.removeWhere(
              (t) => (t['idTransaction'] ?? t['id']) == currentId,
            );
            hasChanges = true;
          } catch (e) {
            debugPrint(
              "SYNC ERROR: Ошибка отправки новой транзакции $currentId: $e",
            );
          }
        } else if (tx['isUpdatedOffline'] == true) {
          try {
            final Map<String, dynamic> body = Map.from(tx)
              ..remove('isSynced')
              ..remove('isUpdatedOffline')
              ..remove('categoryName');

            await remote.updateTransaction(currentId, body);

            final idx = updatedLocalTxList.indexWhere(
              (t) => (t['idTransaction'] ?? t['id']) == currentId,
            );
            if (idx != -1) {
              updatedLocalTxList[idx]['isUpdatedOffline'] = false;
              updatedLocalTxList[idx]['isSynced'] = true;
            }
            hasChanges = true;
          } catch (e) {
            debugPrint(
              "SYNC ERROR: Ошибка обновления транзакции $currentId: $e",
            );
          }
        } else if (tx['isDeletedOffline'] == true) {
          try {
            await remote.deleteTransaction(currentId);
            updatedLocalTxList.removeWhere(
              (t) => (t['idTransaction'] ?? t['id']) == currentId,
            );
            hasChanges = true;
          } catch (e) {
            debugPrint(
              "SYNC ERROR: Ошибка удаления транзакции $currentId на сервере: $e",
            );
          }
        }
      }

      if (hasChanges) {
        await local.saveTransactions(billId, updatedLocalTxList);
      }

      debugPrint("SYNC: Синхронизация счета $billId завершена.");
    } catch (e) {
      debugPrint("SYNC: Критическая ошибка в процессе синхронизации: $e");
    }
  }
}
