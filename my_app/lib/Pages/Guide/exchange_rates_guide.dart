import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class ExchangeRatesGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    required GlobalKey amountInputKey,
    required GlobalKey swapButtonKey,
    required GlobalKey transferButtonKey,
    required GlobalKey graphKey,
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
                    isLast ? "ПОНЯТНО" : "ДАЛЕЕ",
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

    // 1. Поле ввода суммы
    targets.add(
      TargetFocus(
        identify: "amount_input",
        keyTarget: amountInputKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.52,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Конвертер валют",
              body:
                  "Введите нужную сумму для конвертации. Результат по актуальному курсу рассчитается мгновенно.",
            ),
          ),
        ],
      ),
    );

    // 2. Кнопка смены валют
    targets.add(
      TargetFocus(
        identify: "swap_button",
        keyTarget: swapButtonKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.37,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Быстрая смена валют",
              body:
                  "Нажмите на эту кнопку, чтобы быстро поменять местами исходную и целевую валюты.",
            ),
          ),
        ],
      ),
    );

    // 3. Перевод между счетами
    targets.add(
      TargetFocus(
        identify: "transfer_button",
        keyTarget: transferButtonKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.75,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Перевод между счетами",
              body:
                  "Если у вас есть счета в выбранных валютах, вы можете в один клик перевести деньги с одного на другой.",
            ),
          ),
        ],
      ),
    );

    // 4. График динамики курса
    targets.add(
      TargetFocus(
        identify: "exchange_graph",
        keyTarget: graphKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 24),
            builder: (context, controller) => buildGuideCard(
              title: "Динамика курса",
              body:
                  "Следите за графиком изменения курса за неделю или месяц, чтобы выбрать самый выгодный момент для обмена.",
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
    required GlobalKey amountInputKey,
    required GlobalKey swapButtonKey,
    required GlobalKey transferButtonKey,
    required GlobalKey graphKey,
    required VoidCallback onFinish,
    required VoidCallback onSkipAll,
  }) {
    late TutorialCoachMark tutorial;

    final targets = _createTargets(
      context: context,
      amountInputKey: amountInputKey,
      swapButtonKey: swapButtonKey,
      transferButtonKey: transferButtonKey,
      graphKey: graphKey,
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
