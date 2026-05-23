import 'package:flutter/material.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class BalancePageGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    required GlobalKey firstWalletKey,
    required GlobalKey? syncIconKey,
    required GlobalKey fabKey,
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

    // 1. Первый кошелек
    targets.add(
      TargetFocus(
        identify: "first_wallet_item",
        keyTarget: firstWalletKey,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.5,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Ваш счет (кошелёк)",
              body:
                  "Здесь вы видите название счета, баланс и индикатор статуса. Нажмите на карточку для просмотра истории.",
            ),
          ),
        ],
      ),
    );

    // 2. Иконка синхронизации (если есть)
    if (syncIconKey != null) {
      targets.add(
        TargetFocus(
          identify: "sync_status",
          keyTarget: syncIconKey,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(
                top: screenSize.height * 0.2,
              ),
              builder: (context, controller) => buildGuideCard(
                title: "Офлайн изменения",
                body:
                    "Оранжевое облако означает, что изменения созданы офлайн. Они синхронизируются при появлении интернета.",
              ),
            ),
          ],
        ),
      );
    }

    // 3. Кнопка добавления счета
    targets.add(
      TargetFocus(
        identify: "add_wallet_fab",
        keyTarget: fabKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 24),
            builder: (context, controller) => buildGuideCard(
              title: "Создание счета",
              body:
                  "Нужен новый счет в другой валюте? Нажмите плюс, чтобы начать учет!",
              isLast: true,
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  static Future<void> show({
    required BuildContext context,
    required GlobalKey firstWalletKey,
    required GlobalKey? syncIconKey,
    required GlobalKey fabKey,
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
      firstWalletKey: firstWalletKey,
      syncIconKey: syncIconKey,
      fabKey: fabKey,
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
