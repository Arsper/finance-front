import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _walletsKey = 'offline_wallets';

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

  static const String _categoriesKey = 'cached_categories';

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
}
