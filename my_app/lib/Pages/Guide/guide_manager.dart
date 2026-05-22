import 'package:flutter/material.dart';
import 'package:my_app/api/sources/local_storage_service.dart';

class GuideManager {
  final LocalStorageService _localStorage = LocalStorageService();

  static const String _skipAllKey = 'pref_skip_all_guides';

  Future<bool> shouldSkipAllGuides() async {
    try {
      final prefs = await _localStorage.sharedPreferences;
      return prefs.getBool(_skipAllKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableAllGuidesForever() async {
    try {
      final prefs = await _localStorage.sharedPreferences;
      await prefs.setBool(_skipAllKey, true);
    } catch (e) {
      debugPrint("Ошибка при сохранении флага отключения гидов: $e");
    }
  }

  Future<void> runGuide({
    required VoidCallback showGuide,
    required VoidCallback onSkippedOrFinished,
  }) async {
    final bool skipAll = await shouldSkipAllGuides();

    if (skipAll) {
      onSkippedOrFinished();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showGuide();
    });
  }

  Future<void> resetAllGuides() async {
    final prefs = await _localStorage.sharedPreferences;
    await prefs.remove(_skipAllKey);
  }

  Future<bool> hasSeenGuide(String guideId) async {
    try {
      final prefs = await _localStorage.sharedPreferences;
      return prefs.getBool('seen_guide_$guideId') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markGuideAsSeen(String guideId) async {
    try {
      final prefs = await _localStorage.sharedPreferences;
      await prefs.setBool('seen_guide_$guideId', true);
    } catch (e) {
      debugPrint("Ошибка сохранения статуса гида: $e");
    }
  }
}
