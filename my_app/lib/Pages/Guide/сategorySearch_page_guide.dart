import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class CategorySearchPickerGuide {
  static List<TargetFocus> _createTargets({
    required BuildContext context,
    required GlobalKey searchKey,
    required GlobalKey filterChipsKey,
    required GlobalKey systemCategoryKey,
    required GlobalKey personalCategoryKey,
    required GlobalKey limitButtonKey,
    required GlobalKey addFabKey,
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

    // 1. Поиск по категориям
    targets.add(
      TargetFocus(
        identify: "cat_search_field",
        keyTarget: searchKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.55,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Быстрый поиск",
              body:
                  "Начните вводить название, чтобы мгновенно отфильтровать нужную категорию из списка.",
            ),
          ),
        ],
      ),
    );

    // 2. Фильтры (Чипсы)
    targets.add(
      TargetFocus(
        identify: "cat_filter_chips",
        keyTarget: filterChipsKey,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.55,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Тип категорий",
              body:
                  "Переключайтесь между всеми, личными или системными категориями для удобной навигации.",
            ),
          ),
        ],
      ),
    );

    // 3. Фантомная Общая категория
    targets.add(
      TargetFocus(
        identify: "cat_system_item",
        keyTarget: systemCategoryKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.65,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Общие категории",
              body:
                  "Это базовые системные категории. Они доступны всегда, но их нельзя отредактировать или удалить.",
            ),
          ),
        ],
      ),
    );

    // 4. Фантомная Личная категория
    targets.add(
      TargetFocus(
        identify: "cat_personal_item",
        keyTarget: personalCategoryKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.65,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Личные категории",
              body:
                  "Вы можете полностью управлять ими. Нажмите на иконку блокнота с карандашом, чтобы переименовать или безвозвратно удалить категорию.",
            ),
          ),
        ],
      ),
    );

    // 5. Кнопка лимитов (Будильник)
    targets.add(
      TargetFocus(
        identify: "cat_limit_button",
        keyTarget: limitButtonKey,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: screenSize.height * 0.65,
            ),
            builder: (context, controller) => buildGuideCard(
              title: "Бюджет и лимиты",
              body:
                  "Нажмите на иконку часов, чтобы установить ежемесячный лимит расходов для этой категории. Оранжевый цвет означает, что лимит уже активен.",
            ),
          ),
        ],
      ),
    );

    // 6. Создание новой категории
    targets.add(
      TargetFocus(
        identify: "cat_add_fab",
        keyTarget: addFabKey,
        paddingFocus: 4,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 24),
            builder: (context, controller) => buildGuideCard(
              title: "Новая категория",
              body:
                  "Нажмите плюс, чтобы создать свою личную категорию. Обратите внимание: управление категориями доступно только в онлайн-режиме.",
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  static void show({
    required BuildContext context,
    required GlobalKey searchKey,
    required GlobalKey filterChipsKey,
    required GlobalKey systemCategoryKey,
    required GlobalKey personalCategoryKey,
    required GlobalKey limitButtonKey,
    required GlobalKey addFabKey,
    required VoidCallback onFinish,
    required VoidCallback onSkipAll,
  }) {
    late TutorialCoachMark tutorial;

    final targets = _createTargets(
      context: context,
      searchKey: searchKey,
      filterChipsKey: filterChipsKey,
      systemCategoryKey: systemCategoryKey,
      personalCategoryKey: personalCategoryKey,
      limitButtonKey: limitButtonKey,
      addFabKey: addFabKey,
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
