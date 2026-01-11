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
    // В AppBar текст должен быть контрастным к фону AppBar.
    // Если фон AppBar фиолетовый (primary), то текст должен быть белым.
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Финансовые цели"),
        // Принудительно задаем белый цвет для иконки "назад"
        iconTheme: const IconThemeData(color: Colors.white),
        // Принудительно задаем белый цвет для заголовка
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        
        bottom: TabBar(
          controller: _tabController,
          // ИСПРАВЛЕНИЕ:
          // Используем белый цвет, чтобы было видно на фиолетовом фоне
          indicatorColor: Colors.white, 
          labelColor: Colors.white,
          // Для неактивных иконок берем белый с прозрачностью (0.7)
          unselectedLabelColor: Colors.white70,
          
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