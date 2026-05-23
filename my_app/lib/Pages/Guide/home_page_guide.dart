import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomePageGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    required GlobalKey networkStatusKey,
    required GlobalKey themeMenuKey,
    required GlobalKey logoutKey,
    required GlobalKey bottomNavKey,
    required VoidCallback onSkipCurrent,
    required VoidCallback onSkipAll,
  }) {
    List<TargetFocus> targets = [];
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

    // 1. Статус сети
    targets.add(
      TargetFocus(
        identify: "network_status",
        keyTarget: networkStatusKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.10,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Мониторинг соединения",
              body:
                  "Этот индикатор показывает состояние сети. Зеленый — всё отлично, красный — приложение в офлайн-режиме.",
            ),
          ),
        ],
      ),
    );

    // 2. Смена темы
    targets.add(
      TargetFocus(
        identify: "theme_menu",
        keyTarget: themeMenuKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.10,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Кастомизация",
              body:
                  "Переключайте тему оформления: светлая, темная или системная.",
            ),
          ),
        ],
      ),
    );

    // 3. Выход из аккаунта
    targets.add(
      TargetFocus(
        identify: "logout_button",
        keyTarget: logoutKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.10,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Выход из системы",
              body: "Безопасное завершение сессии и возврат на экран входа.",
            ),
          ),
        ],
      ),
    );

    // 4. Нижнее меню
    targets.add(
      TargetFocus(
        identify: "bottom_navigation",
        keyTarget: bottomNavKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top:
                  screenSize.height *
                  0.3,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Навигация",
              body:
                  "«Баланс» работает автономно. Остальные разделы требуют стабильного подключения к серверу.",
              isLast: true,
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  static void show({
    required BuildContext context,
    required GlobalKey networkStatusKey,
    required GlobalKey themeMenuKey,
    required GlobalKey logoutKey,
    required GlobalKey bottomNavKey,
    required VoidCallback onFinish,
    required VoidCallback onSkipAll,
  }) {
    late TutorialCoachMark tutorial;

    final targets = _createTargets(
      context: context,
      networkStatusKey: networkStatusKey,
      themeMenuKey: themeMenuKey,
      logoutKey: logoutKey,
      bottomNavKey: bottomNavKey,
      onSkipCurrent: () => tutorial.next(),
      onSkipAll: () {
        onSkipAll();
        tutorial.finish();
      },
    );

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
