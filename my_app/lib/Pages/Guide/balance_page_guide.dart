import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class BalancePageGuide {
  static List<TargetFocus> _createTargets({
    required GlobalKey firstWalletKey,
    required GlobalKey? syncIconKey,
    required GlobalKey fabKey,
    required VoidCallback onSkipCurrent,
    required VoidCallback onSkipAll,
  }) {
    List<TargetFocus> targets = [];

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
                  ),
                  child: Text("ДАЛЕЕ"),
                ),
              ],
            ),
          ],
        ),
      );
    }

    targets.add(
      TargetFocus(
        identify: "first_wallet_item",
        keyTarget: firstWalletKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => buildGuideCard(
              title: "Ваш счет (кошелёк)",
              body:
                  "Здесь вы видите название счета, баланс и индикатор статуса. Нажмите на карточку для просмотра истории.",
            ),
          ),
        ],
      ),
    );

    if (syncIconKey != null && syncIconKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "sync_status",
          keyTarget: syncIconKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
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

    targets.add(
      TargetFocus(
        identify: "add_wallet_fab",
        keyTarget: fabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
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

  static void show({
    required BuildContext context,
    required GlobalKey firstWalletKey,
    required GlobalKey? syncIconKey,
    required GlobalKey fabKey,
    required VoidCallback onFinish,
    required VoidCallback onSkipAll,
  }) {
    late TutorialCoachMark tutorial;
    final targets = _createTargets(
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
    tutorial.show(context: context);
  }
}
