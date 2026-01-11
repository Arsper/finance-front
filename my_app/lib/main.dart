import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_app/Pages/home.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/Pages/register.dart';
import 'package:my_app/helpers/StorageService.dart';

// 1. СОЗДАЕМ ГЛОБАЛЬНЫЙ КЛЮЧ
// Он должен быть объявлен вне классов, чтобы был доступен из других файлов
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  await StorageService.init();

  final String? token = StorageService.getToken();
  final String savedTheme = StorageService.getThemeMode();

  runApp(MyApp(
    isAuth: token != null,
    savedTheme: savedTheme,
  ));
}

class MyApp extends StatefulWidget {
  final bool isAuth;
  final String savedTheme;

  const MyApp({super.key, required this.isAuth, required this.savedTheme});

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _getThemeModeFromString(widget.savedTheme);
  }

  ThemeMode _getThemeModeFromString(String themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    
    String themeString;
    if (mode == ThemeMode.light) themeString = 'light';
    else if (mode == ThemeMode.dark) themeString = 'dark';
    else themeString = 'system';
    
    StorageService.setThemeMode(themeString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 2. ПОДКЛЮЧАЕМ КЛЮЧ СЮДА
      navigatorKey: navigatorKey, 
      
      debugShowCheckedModeBanner: false,
      title: 'Finance App',
      themeMode: _themeMode, 

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[850],
          elevation: 2,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.grey[900],
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
          contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
      initialRoute: widget.isAuth ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}