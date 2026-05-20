import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_app/Pages/BalanceTab.dart';
import 'package:my_app/Pages/ExchangeRatesPage.dart';
import 'package:my_app/Pages/FinancialGoals/FinancialCalculationPage.dart';
import 'package:my_app/Pages/RecurringPaymen/RecurringPaymentsPage.dart';
import 'package:my_app/helpers/OverlayToastService.dart';
import 'package:my_app/main.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/DioClient.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  bool _isOnline = true;
  bool _isServerAlive = true;

  late final UserRemoteDataSource _dataSource;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _healthCheckTimer;

  List<Widget> get _widgetOptions => <Widget>[
    const BalanceTab(),
    const RecurringPaymentsPage(),
    const FinancialCalculationPage(),
    const ExchangeRatesPage(),
  ];

  bool get _isApiAvailable => _isOnline && _isServerAlive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _dataSource = UserRemoteDataSource(dio: Dioclient.instance);
    _initConnectivity();
    _startHealthCheckTimer();
  }

  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkFullStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _checkFullStatus();
          _startHealthCheckTimer();
        }
      });
    } else if (state == AppLifecycleState.paused) {
      _healthCheckTimer?.cancel();
    }
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();

    final result = await connectivity.checkConnectivity();
    await _updateConnectionStatus(result);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      result,
    ) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    final hasInternet = result != ConnectivityResult.none;

    if (mounted) {
      setState(() {
        _isOnline = hasInternet;
      });
    }

    await _checkFullStatus();
  }

  Future<void> _checkFullStatus() async {
    if (!_isOnline) {
      _handleOfflineMode(reason: 'Отсутствует интернет-соединение');
      return;
    }

    try {
      final serverAlive = await _dataSource.checkServerHealth();

      if (mounted) {
        setState(() {
          _isServerAlive = serverAlive;
        });

        if (!serverAlive) {
          _handleOfflineMode(
            reason: 'Сервер временно недоступен (Ошибка 502/503/Таймаут)',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServerAlive = false;
        });
        _handleOfflineMode(reason: 'Не удалось связаться с сервером');
      }
    }
  }

  void _handleOfflineMode({required String reason}) {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });

      OverlayToastService.show(
        context,
        message: 'Офлайн-режим: $reason. Доступен только Баланс.',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _healthCheckTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) async {
    if (index != 0) {
      await _checkFullStatus();
    }

    if (!_isApiAvailable && index != 0) {
      final String alertMessage = !_isOnline
          ? 'Нет интернет-соединения.'
          : 'Сервер недоступен. Попробуйте позже.';

      if (mounted) {
        OverlayToastService.show(
          context,
          message: alertMessage,
          isError: false,
        );
      }
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    try {
      await _dataSource.logout();
    } catch (e) {
      debugPrint("Error during logout: $e");
    } finally {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Умный кошелёк'),
        centerTitle: true,
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Сменить тему',
            onSelected: (ThemeMode mode) {
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
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Баланс',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_month_outlined,
              color: _isApiAvailable ? null : Colors.grey.shade400,
            ),
            activeIcon: const Icon(Icons.calendar_month),
            label: 'Автоплатеж',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.calculate_outlined,
              color: _isApiAvailable ? null : Colors.grey.shade400,
            ),
            activeIcon: const Icon(Icons.calculate),
            label: 'Цели',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.currency_exchange,
              color: _isApiAvailable ? null : Colors.grey.shade400,
            ),
            label: 'Курсы',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: _isApiAvailable
            ? Colors.grey
            : Colors.grey.shade400,
        onTap: _onItemTapped,
      ),
    );
  }
}
