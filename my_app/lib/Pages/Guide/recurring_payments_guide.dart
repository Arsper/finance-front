import 'package:flutter/material.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class RecurringPaymentsGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    required GlobalKey firstItemKey,
    required GlobalKey fabKey,
    required Function() onSkipCurrent,
    required Function() onSkipAll,
  }) {
    List<TargetFocus> targets = [];
    final screenSize = MediaQuery.of(context).size;

    Widget buildGuideCard({required String title, required String body}) {
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "ДАЛЕЕ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // 1. Первая карточка платежа
    targets.add(
      TargetFocus(
        identify: "recurring_item",
        keyTarget: firstItemKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.5,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Ваши платежи",
              body:
                  "Здесь отображаются регулярные списания. Вы можете редактировать их, нажав на карточку.",
            ),
          ),
        ],
      ),
    );

    // 2. Кнопка добавления
    targets.add(
      TargetFocus(
        identify: "add_recurring_fab",
        keyTarget: fabKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 24),
            builder: (context, controller) => buildGuideCard(
              title: "Новый платеж",
              body: "Нажмите сюда, чтобы запланировать следующее списание.",
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  static Future<void> show({
    required BuildContext context,
    required GlobalKey firstItemKey,
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
      firstItemKey: firstItemKey,
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
      hideSkip: true,
      onFinish: onFinish,
      onSkip: () {
        onFinish();
        return true;
      },
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!context.mounted) {
        return;
      }
      tutorial.show(context: context);
    });
  }
}
