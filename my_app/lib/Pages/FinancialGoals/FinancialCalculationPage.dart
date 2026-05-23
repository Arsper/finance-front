import 'package:flutter/material.dart';
import 'package:my_app/Pages/FinancialGoals/CalculatorTab.dart';
import 'package:my_app/Pages/FinancialGoals/GoalsListTab.dart';
import 'package:my_app/Pages/Guide/financial_goals_guide.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';

class FinancialCalculationPage extends StatefulWidget {
  const FinancialCalculationPage({super.key});

  @override
  State<FinancialCalculationPage> createState() =>
      _FinancialCalculationPageState();
}

class _FinancialCalculationPageState extends State<FinancialCalculationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<GoalsListTabState> _goalsTabKey =
      GlobalKey<GoalsListTabState>();

  final GlobalKey _tabBarKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  final GlobalKey _calcButtonKey = GlobalKey();
  final GlobalKey _createGoalButtonKey = GlobalKey();
  bool _isGuideActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkGuide();
  }

  Future<void> _checkGuide() async {
    final manager = GuideManager();
    if (await manager.hasSeenGuide('financial_goals_v1')) return;

    setState(() => _isGuideActive = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FinancialGoalsGuide.show(
        context: context,
        tabBarKey: _tabBarKey,
        calcButtonKey: _calcButtonKey,
        createGoalButtonKey: _createGoalButtonKey,
        onFinish: () async {
          await manager.markGuideAsSeen('financial_goals_v1');
          if (mounted) setState(() => _isGuideActive = false);
        },
        onSkipAll: () async {
          await manager.markGuideAsSeen('financial_goals_v1');
          await manager.disableAllGuidesForever();
          if (mounted) setState(() => _isGuideActive = false);
        },
      );
    });
  }

  void _onGoalCreated() {
    _tabController.animateTo(1);
    Future.delayed(const Duration(milliseconds: 300), () {
      _goalsTabKey.currentState?.loadGoals();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AbsorbPointer(
      absorbing: _isGuideActive,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 8,
                ),
                child: Container(
                  key: _tabBarKey,
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: isDark
                        ? Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.15,
                            ),
                          )
                        : null,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: isDark
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isDark
                          ? Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.05,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: isDark
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    unselectedLabelColor: isDark
                        ? colorScheme.onSurface.withValues(alpha: 0.5)
                        : colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: "Калькулятор"),
                      Tab(text: "Мои цели"),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    CalculatorTab(
                      onGoalCreated: _onGoalCreated,
                      fabKey: _fabKey,
                      calcButtonKey: _calcButtonKey,
                      createGoalButtonKey: _createGoalButtonKey,
                    ),
                    GoalsListTab(key: _goalsTabKey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
