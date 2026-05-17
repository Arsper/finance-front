import 'package:flutter/material.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/api/data/сurrency.dart';

class WalletRepository {
  final UserRemoteDataSource remoteDataSource;
  final LocalStorageService localDataSource;

  WalletRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<List<Currency>> getCurrencies() async {
    try {
      return await remoteDataSource.getCurrencies();
    } catch (_) {
      return [];
    }
  }

  Future<void> syncOfflineWallets() async {
    final localWallets = await localDataSource.getWallets();
    if (localWallets.isEmpty) return;

    debugPrint("=== Начало синхронизации оффлайн данных ===");
    List<dynamic> updatedLocalList = List.from(localWallets);

    for (var i = 0; i < localWallets.length; i++) {
      final wallet = localWallets[i];
      final int billId = int.tryParse(wallet['billId']?.toString() ?? '0') ?? 0;

      if (wallet['isDeletedOffline'] == true) {
        if (billId > 0) {
          try {
            final success = await remoteDataSource.deleteWallet(billId);
            if (success) {
              updatedLocalList.removeWhere((w) => w['billId'] == billId);
            }
          } catch (_) {}
        } else {
          updatedLocalList.removeWhere((w) => w['billId'] == billId);
        }
        continue;
      }

      if (wallet['isNewOffline'] == true) {
        try {
          final Map<String, dynamic> serverData = {
            "name": wallet['name'],
            "type": wallet['type'] ?? 'Debit',
            "startBalance": wallet['startBalance'] ?? 0.0,
            "currencyId": wallet['currencyId'],
          };

          final success = await remoteDataSource.addWallet(serverData);
          if (success) {
            final idx = updatedLocalList.indexWhere(
              (w) => w['billId'] == billId,
            );
            if (idx != -1) {
              updatedLocalList[idx]['isNewOffline'] = false;
              updatedLocalList[idx]['isSynced'] = true;
            }
            debugPrint(
              "Кошелек '${wallet['name']}' успешно синхронизирован с сервером.",
            );
          }
        } catch (e) {
          debugPrint("Ошибка при отправке оффлайн кошелька: $e");
        }
        continue;
      }

      if (wallet['isSynced'] == false && billId > 0) {
        try {
          final Map<String, dynamic> serverData = {
            "name": wallet['name'],
            "type": wallet['type'] ?? 'Debit',
            "startBalance": wallet['startBalance'] ?? 0.0,
            "currencyId": wallet['currencyId'],
          };

          final success = await remoteDataSource.updateWallet(
            billId,
            serverData,
          );
          if (success) {
            final idx = updatedLocalList.indexWhere(
              (w) => w['billId'] == billId,
            );
            if (idx != -1) {
              updatedLocalList[idx]['isSynced'] = true;
            }
          }
        } catch (_) {}
      }
    }

    await localDataSource.saveWallets(updatedLocalList);
    debugPrint("=== Синхронизация завершена ===");
  }

  Future<List<dynamic>> getWallets() async {
    try {
      await remoteDataSource.getCurrencies();

      await syncOfflineWallets();

      final remoteWallets = await remoteDataSource.getWallets();
      final localWallets = await localDataSource.getWallets();

      final offlineCreated = localWallets
          .where((w) => w['isNewOffline'] == true)
          .toList();

      final updatedWallets = remoteWallets.map((remote) {
        final int remoteId =
            int.tryParse(
              remote['billId']?.toString() ??
                  remote['idBills']?.toString() ??
                  remote['id']?.toString() ??
                  '0',
            ) ??
            0;

        final locallyEdited = localWallets.firstWhere((lw) {
          final int localId =
              int.tryParse(
                lw['billId']?.toString() ??
                    lw['idBills']?.toString() ??
                    lw['id']?.toString() ??
                    '0',
              ) ??
              0;
          return localId == remoteId &&
              lw['isSynced'] == false &&
              lw['isDeletedOffline'] != true;
        }, orElse: () => null);

        if (locallyEdited != null) return locallyEdited;
        return {...remote, 'isSynced': true};
      }).toList();

      final totalList = [...updatedWallets, ...offlineCreated];
      final visibleList = totalList
          .where((w) => w['isDeletedOffline'] != true)
          .toList();

      await localDataSource.saveWallets(totalList);
      return visibleList;
    } catch (e) {
      debugPrint(
        "Сеть недоступна или произошла ошибка. Читаем данные только из локального кэша: $e",
      );

      final localWallets = await localDataSource.getWallets();

      return localWallets.where((w) => w['isDeletedOffline'] != true).toList();
    }
  }

  Future<bool> addWallet(Map<String, dynamic> data) async {
    try {
      final success = await remoteDataSource.addWallet(data);
      if (success) {
        await getWallets();
        return true;
      }
      await localDataSource.addWalletOffline(data);
      return true;
    } catch (e) {
      await localDataSource.addWalletOffline(data);
      return true;
    }
  }

  Future<bool> updateWallet(int billId, Map<String, dynamic> data) async {
    try {
      if (billId < 0) {
        await localDataSource.updateWalletOffline(billId, data);
        return true;
      }
      final success = await remoteDataSource.updateWallet(billId, data);
      if (success) {
        await getWallets();
        return true;
      }
      await localDataSource.updateWalletOffline(billId, data);
      return true;
    } catch (e) {
      await localDataSource.updateWalletOffline(billId, data);
      return true;
    }
  }

  Future<bool> deleteWallet(int billId) async {
    try {
      if (billId < 0) {
        await localDataSource.deleteWalletOffline(billId);
        return true;
      }
      final success = await remoteDataSource.deleteWallet(billId);
      if (success) {
        await getWallets();
        return true;
      }
      await localDataSource.deleteWalletOffline(billId);
      return true;
    } catch (e) {
      await localDataSource.deleteWalletOffline(billId);
      return true;
    }
  }
}
