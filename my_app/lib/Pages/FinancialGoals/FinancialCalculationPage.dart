import 'package:flutter/material.dart';
import 'package:my_app/Pages/FinancialGoals/CalculatorTab.dart';
import 'package:my_app/Pages/FinancialGoals/GoalsListTab.dart';

class FinancialCalculationPage extends StatefulWidget {
  const FinancialCalculationPage({super.key});

  @override
  State<FinancialCalculationPage> createState() => _FinancialCalculationPageState();
}

class _FinancialCalculationPageState extends State<FinancialCalculationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<GoalsListTabState> _goalsTabKey = GlobalKey<GoalsListTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _onGoalCreated() {
    _tabController.animateTo(1);
    Future.delayed(const Duration(milliseconds: 300), () {
      _goalsTabKey.currentState?.loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Финансовые цели"),
        // Явно задаем цвета для AppBar
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        
        bottom: TabBar(
          controller: _tabController,
          // Явно задаем цвета для вкладок
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          // Добавляем стиль для иконок во вкладках
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: "Калькулятор", icon: Icon(Icons.calculate)),
            Tab(text: "Мои цели", icon: Icon(Icons.flag)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CalculatorTab(onGoalCreated: _onGoalCreated),
          GoalsListTab(key: _goalsTabKey),
        ],
      ),
    );
  }
}