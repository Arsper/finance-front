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
      final int oldBillId =
          int.tryParse(wallet['billId']?.toString() ?? '0') ?? 0;

      if (wallet['isDeletedOffline'] == true) {
        if (oldBillId > 0) {
          try {
            final success = await remoteDataSource.deleteWallet(oldBillId);
            if (success) {
              updatedLocalList.removeWhere((w) => w['billId'] == oldBillId);
            }
          } catch (_) {}
        } else {
          updatedLocalList.removeWhere((w) => w['billId'] == oldBillId);
        }
        continue;
      }

      if (wallet['isNewOffline'] == true) {
        try {
          final Map<String, dynamic> serverData = {
            "name": wallet['name'],
            "type": wallet['type'] ?? 'Debit',
            "startBalance":
                wallet['startBalance'] ?? wallet['currentBalance'] ?? 0.0,
            "currencyId": wallet['currencyId'],
          };

          final success = await remoteDataSource.addWallet(serverData);
          if (success) {
            final freshRemoteWallets = await remoteDataSource.getWallets();

            Map<String, dynamic>? serverWallet;
            final String localName =
                wallet['name']?.toString().trim().toLowerCase() ?? '';

            for (var rw in freshRemoteWallets) {
              final String rwName = (rw['name'] ?? rw['billName'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

              if (rwName == localName) {
                serverWallet = Map<String, dynamic>.from(rw as Map);
                break;
              }
            }

            if (serverWallet != null) {
              final int newServerId =
                  int.tryParse(
                    serverWallet['billId']?.toString() ??
                        serverWallet['idBills']?.toString() ??
                        serverWallet['id']?.toString() ??
                        '0',
                  ) ??
                  0;

              if (newServerId > 0) {
                await localDataSource.migrateOfflineTransactions(
                  oldTemporaryId: oldBillId,
                  newServerId: newServerId,
                );

                updatedLocalList.removeWhere((w) => w['billId'] == oldBillId);
                continue;
              }
            }
          }
        } catch (e) {
          debugPrint("Ошибка при отправке оффлайн кошелька: $e");
        }
        continue;
      }

      if (wallet['isWalletEditedOffline'] == true && oldBillId > 0) {
        try {
          final Map<String, dynamic> serverData = {
            "name": wallet['name'],
            "type": wallet['type'] ?? 'Debit',
            "startBalance":
                wallet['startBalance'] ?? wallet['currentBalance'] ?? 0.0,
            "currencyId": wallet['currencyId'],
          };

          final success = await remoteDataSource.updateWallet(
            oldBillId,
            serverData,
          );
          if (success) {
            final idx = updatedLocalList.indexWhere(
              (w) => w['billId'] == oldBillId,
            );
            if (idx != -1) {
              updatedLocalList[idx]['isWalletEditedOffline'] = false;
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
              int.tryParse(lw['billId']?.toString() ?? '0') ?? 0;
          return localId == remoteId &&
              lw['isSynced'] == false &&
              lw['isDeletedOffline'] != true;
        }, orElse: () => null);

        if (locallyEdited != null) return locallyEdited;

        final double serverBalance =
            double.tryParse(
              (remote['currentBalance'] ??
                      remote['balance'] ??
                      remote['startBalance'] ??
                      '0.0')
                  .toString(),
            ) ??
            0.0;
        return {
          ...remote,
          'billId': remoteId,
          'currentBalance': serverBalance,
          'isSynced': true,
        };
      }).toList();

      final totalList = [...updatedWallets, ...offlineCreated];
      final visibleList = totalList
          .where((w) => w['isDeletedOffline'] != true)
          .toList();

      await localDataSource.saveWallets(totalList);
      return visibleList;
    } catch (e) {
      debugPrint("Сеть недоступна. Читаем кэш: $e");
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

      final Map<String, dynamic> serverData = {
        "name": data['name'],
        "type": data['type'] ?? 'Debit',
        "startBalance": data['startBalance'] ?? 0.0,
        "currencyId": data['currencyId'],
      };
      final success = await remoteDataSource.updateWallet(billId, serverData);

      if (success) {
        data['isWalletEditedOffline'] = false;
        data['isSynced'] = true;
        data['billId'] = billId;
        await localDataSource.updateWalletOffline(billId, data);
        await getWallets();
        return true;
      }
      data['isWalletEditedOffline'] = true;
      await localDataSource.updateWalletOffline(billId, data);
      return true;
    } catch (e) {
      debugPrint("Ошибка при обновлении кошелька: $e");
      data['isWalletEditedOffline'] = true;
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
