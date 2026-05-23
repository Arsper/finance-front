import 'package:flutter/material.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class FinancialGoalsGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    GlobalKey? tabBarKey,
    GlobalKey? calcButtonKey,
    GlobalKey? createGoalButtonKey,
    GlobalKey? targetKey,
    required VoidCallback onSkipCurrent,
    required VoidCallback onSkipAll,
  }) {
    final screenSize = MediaQuery.of(context).size;

    Widget buildGuideCard({
      required String title,
      required String body,
      bool isLast = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: onSkipAll,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    "НЕ ПОКАЗЫВАТЬ БОЛЬШЕ",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onSkipCurrent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isLast ? "ЗАВЕРШИТЬ" : "ДАЛЕЕ",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final List<Map<String, dynamic>> targetConfigs = [];

    // 1. Вкладки
    if (tabBarKey != null && tabBarKey.currentContext != null) {
      targetConfigs.add({
        "identify": "tabs",
        "keyTarget": tabBarKey,
        "align": ContentAlign.custom,
        "customPosition": CustomTargetContentPosition(
          top: screenSize.height * 0.5,
        ),
        "paddingFocus": 8.0,
        "title": "Навигация",
        "body": "Переключайтесь между режимом расчета и списком ваших целей.",
      });
    }

    // 2. Карточка цели
    if (targetKey != null && targetKey.currentContext != null) {
      targetConfigs.add({
        "identify": "goal_item",
        "keyTarget": targetKey,
        "align": ContentAlign.custom,
        "customPosition": CustomTargetContentPosition(
          top: screenSize.height * 0.75,
        ),
        "title": "Управление целью",
        "body": "Нажмите на карточку, чтобы изменить или пополнить вашу цель.",
      });
    }

    // 3. Кнопка расчета
    if (calcButtonKey != null && calcButtonKey.currentContext != null) {
      targetConfigs.add({
        "identify": "calc_button",
        "keyTarget": calcButtonKey,
        "align": ContentAlign.custom,
        "customPosition": CustomTargetContentPosition(
          top: screenSize.height * 0.1,
        ),
        "paddingFocus": 4.0,
        "title": "Расчет",
        "body": "Введите параметры и нажмите здесь, чтобы рассчитать ваш план.",
      });
    }

    // 4. Кнопка создания новой цели
    if (createGoalButtonKey != null &&
        createGoalButtonKey.currentContext != null) {
      targetConfigs.add({
        "identify": "create_goal_button",
        "keyTarget": createGoalButtonKey,
        "align": ContentAlign.top,
        "paddingContent": const EdgeInsets.only(bottom: 24),
        "paddingFocus": 4.0,
        "title": "Новая цель",
        "body": "Нажмите на плюс, чтобы добавить новую финансовую цель.",
      });
    }

    final List<TargetFocus> targets = [];

    for (int i = 0; i < targetConfigs.length; i++) {
      final config = targetConfigs[i];
      final bool isLast = i == targetConfigs.length - 1;

      targets.add(
        TargetFocus(
          identify: config["identify"],
          keyTarget: config["keyTarget"],
          paddingFocus: config["paddingFocus"] ?? 10.0,
          contents: [
            TargetContent(
              align: config["align"],
              padding: config["paddingContent"] ?? EdgeInsets.zero,
              customPosition: config["customPosition"],
              builder: (context, controller) => buildGuideCard(
                title: config["title"],
                body: config["body"],
                isLast: isLast,
              ),
            ),
          ],
        ),
      );
    }

    return targets;
  }

  static Future<void> show({
    required BuildContext context,
    GlobalKey? tabBarKey,
    GlobalKey? calcButtonKey,
    GlobalKey? createGoalButtonKey,
    GlobalKey? targetKey,
    required VoidCallback onFinish,
    required VoidCallback onSkipAll,
  }) async {
    final guideManager = GuideManager();
    final skipAll = await guideManager.shouldSkipAllGuides();

    if (!context.mounted) {
      onFinish();
      return;
    }

    if (skipAll) {
      onFinish();
      return;
    }

    late TutorialCoachMark tutorial;

    final targets = _createTargets(
      context: context,
      tabBarKey: tabBarKey,
      calcButtonKey: calcButtonKey,
      createGoalButtonKey: createGoalButtonKey,
      targetKey: targetKey,
      onSkipCurrent: () => tutorial.next(),
      onSkipAll: () {
        onSkipAll();
        tutorial.finish();
      },
    );

    if (targets.isEmpty) {
      onFinish();
      return;
    }

    tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 8,
      hideSkip: true,
      onFinish: onFinish,
      onSkip: () {
        onFinish();
        return true;
      },
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!context.mounted) return;
      tutorial.show(context: context);
    });
  }
}
