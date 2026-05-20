import 'package:flutter/material.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/sources/local_storage_service.dart';

class CategoryRepository {
  final UserRemoteDataSource remote;
  final LocalStorageService local;

  CategoryRepository(this.remote, this.local);

  Future<List<dynamic>> getCategories() async {
    try {
      final data = await remote.getCategories();

      if (data.isEmpty) {
        debugPrint("REPO: Получен пустой список, оставляем старый кэш.");
        return await local.getCategories();
      }

      await local.saveCategories(data);
      return data;
    } catch (e) {
      debugPrint("REPO: ОШИБКА сети: $e");
      return await local.getCategories();
    }
  }

  Future<bool> addCategory(String name) async {
    final success = await remote.addCategory({"name": name});
    if (success) await getCategories();
    return success;
  }

  Future<bool> updateCategory(int id, String name) async {
    final success = await remote.updateCategory(id, {"name": name});
    if (success) await getCategories();
    return success;
  }

  Future<bool> deleteCategory(int id) async {
    final success = await remote.deleteCategory(id);
    if (success) await getCategories();
    return success;
  }

  Future<List<dynamic>> getLimits(int billId) async {
    return await remote.getLimits(billId);
  }

  Future<bool> addLimit(Map<String, dynamic> data) async {
    return await remote.addLimit(data);
  }

  Future<bool> updateLimit(int id, Map<String, dynamic> data) async {
    return await remote.updateLimit(id, data);
  }

  Future<bool> deleteLimit(int id) async {
    return await remote.deleteLimit(id);
  }

  Future<bool> isServerAvailable() async {
    return await remote.checkServerHealth();
  }
}
