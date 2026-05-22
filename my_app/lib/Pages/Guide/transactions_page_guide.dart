import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TransactionsPageGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    required GlobalKey appBarTitleKey,
    required GlobalKey firstTxKey,
    required GlobalKey syncIconKey,
    required GlobalKey filterKey,
    required GlobalKey statsIconKey,
    required GlobalKey fabKey,
    required VoidCallback onSkipCurrent,
    required VoidCallback onSkipAll,
  }) {
    List<TargetFocus> targets = [];

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
                  child: const Text(
                    "ДАЛЕЕ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 1. Шапка
    targets.add(
      TargetFocus(
        identify: "tx_appbar_title",
        keyTarget: appBarTitleKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 24),
            builder: (context, controller) => buildGuideCard(
              title: "Текущий счет и остаток",
              body:
                  "Здесь отображается название выбранного счета и актуальный баланс с учетом всех проведенных операций.",
            ),
          ),
        ],
      ),
    );

    // 2. Статистика
    targets.add(
      TargetFocus(
        identify: "tx_stats_icon",
        keyTarget: statsIconKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => buildGuideCard(
              title: "Аналитика расходов",
              body:
                  "Нажмите здесь, чтобы открыть детальную статистику и графики ваших трат по категориям и периодам.",
            ),
          ),
        ],
      ),
    );

    // 3. Фильтры
    targets.add(
      TargetFocus(
        identify: "tx_filter_button",
        keyTarget: filterKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 32),
            builder: (context, controller) => buildGuideCard(
              title: "Поиск и фильтрация",
              body:
                  "Нужно найти конкретный платеж? Нажмите сюда, чтобы отфильтровать операции по категориям, датам или суммам.",
            ),
          ),
        ],
      ),
    );

    // 4. Первая транзакция
    targets.add(
      TargetFocus(
        identify: "tx_first_item",
        keyTarget: firstTxKey,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 32),
            builder: (context, controller) => buildGuideCard(
              title: "Карточка операции",
              body:
                  "Каждая строка содержит описание, категорию и сумму. Нажмите на неё для редактирования.",
            ),
          ),
        ],
      ),
    );

    // 5. Иконка синхронизации
    targets.add(
      TargetFocus(
        identify: "tx_sync_icon",
        keyTarget: syncIconKey,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 32),
            builder: (context, controller) => buildGuideCard(
              title: "Локальные транзакции",
              body:
                  "Оранжевые часики означают, что транзакция создана офлайн. Она синхронизируется автоматически при появлении сети.",
            ),
          ),
        ],
      ),
    );

    // 6. Кнопка добавления
    targets.add(
      TargetFocus(
        identify: "tx_add_fab",
        keyTarget: fabKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 32),
            builder: (context, controller) => buildGuideCard(
              title: "Новая операция",
              body:
                  "Нажмите эту кнопку, чтобы внести новый расход или доход. Система автоматически проверит лимиты перед сохранением.",
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  static void show({
    required BuildContext context,
    required GlobalKey appBarTitleKey,
    required GlobalKey statsIconKey,
    required GlobalKey firstTxKey,
    required GlobalKey syncIconKey,
    required GlobalKey filterKey,
    required GlobalKey fabKey,
    required VoidCallback onFinish,
    required VoidCallback onSkipAll,
  }) {
    late TutorialCoachMark tutorial;

    final targets = _createTargets(
      context: context,
      appBarTitleKey: appBarTitleKey,
      statsIconKey: statsIconKey,
      firstTxKey: firstTxKey,
      syncIconKey: syncIconKey,
      filterKey: filterKey,
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
      opacityShadow: 0.9,
      hideSkip: true,
      onFinish: onFinish,
      onSkip: () {
        onFinish();
        return true;
      },
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      tutorial.show(context: context);
    });
  }
}
