import 'package:flutter/material.dart';
import 'package:my_app/Pages/BalanceTab.dart';
import 'package:my_app/Pages/ExchangeRatesPage.dart';
import 'package:my_app/Pages/RecurringPaymentsPage.dart';
import 'package:my_app/Pages/FinancialGoals/FinancialCalculationPage.dart'; 
import 'package:my_app/helpers/StorageService.dart';
import 'package:my_app/main.dart'; // ! Важно импортировать main.dart, чтобы видеть MyApp

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  List<Widget> get _widgetOptions => <Widget>[
    const BalanceTab(),             
    const RecurringPaymentsPage(),    
    const FinancialCalculationPage(), 
    const ExchangeRatesPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Финансы'),
        centerTitle: true,
        actions: [
          // --- ВОТ ВАШ "ГЛАЗИК" (Кнопка смены темы) ---
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6), // Иконка "Солнце/Луна"
            tooltip: 'Сменить тему',
            onSelected: (ThemeMode mode) {
              // Обращаемся к main.dart и меняем тему
              MyApp.of(context).changeTheme(mode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
              const PopupMenuItem(
                value: ThemeMode.system,
                child: ListTile(
                  leading: Icon(Icons.settings_brightness),
                  title: Text('Системная'),
                ),
              ),
              const PopupMenuItem(
                value: ThemeMode.light,
                child: ListTile(
                  leading: Icon(Icons.wb_sunny),
                  title: Text('Светлая'),
                ),
              ),
              const PopupMenuItem(
                value: ThemeMode.dark,
                child: ListTile(
                  leading: Icon(Icons.nights_stay),
                  title: Text('Темная'),
                ),
              ),
            ],
          ),
          
          // Кнопка выхода
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await StorageService.clear();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Баланс',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Платежи',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_outlined),
            activeIcon: Icon(Icons.calculate),
            label: 'Цели',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_exchange),
            label: 'Курсы',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}