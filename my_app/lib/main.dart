import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_app/Pages/home.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/Pages/Register/register.dart';
import 'package:my_app/helpers/StorageService.dart';

// 1. СОЗДАЕМ ГЛОБАЛЬНЫЙ КЛЮЧ
// Он должен быть объявлен вне классов, чтобы был доступен из других файлов
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Тот самый сочный фиолетовый (Vibrant Purple)
const Color primaryAccent = Color(0xFF8B5CF6);
const Color onPrimaryColor = Colors.white;

// Темная тема
const Color darkBg = Color(0xFF0F0B15); // Сделал чуть глубже (темнее)
const Color darkCard = Color(0xFF1A1622);
const Color darkOutline = Color(0xFF37333D);

// Светлая тема
const Color lightBg = Color(0xFFF9FAFB);
const Color lightOutline = Color(0xFFE5E7EB);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  await StorageService.init();

  final String? token = StorageService.getToken();
  final String savedTheme = StorageService.getThemeMode();

  runApp(MyApp(isAuth: token != null, savedTheme: savedTheme));
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
    if (mode == ThemeMode.light)
      themeString = 'light';
    else if (mode == ThemeMode.dark)
      themeString = 'dark';
    else
      themeString = 'system';

    StorageService.setThemeMode(themeString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      // --- СВЕТЛАЯ ТЕМА (Насыщенная) ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryAccent, // Явный сочный цвет
          onPrimary: onPrimaryColor,
          secondary: const Color(0xFF7C3AED),
          surface: Colors.white,
          background: lightBg,
          outlineVariant: lightOutline,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2, // Добавил небольшую тень для сочности
          shadowColor: primaryAccent.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: lightOutline),
          ),
        ),
      ),

      // --- ТЕМНАЯ ТЕМА (Неоновая) ---
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primaryAccent, // В темноте он будет прямо гореть
          onPrimary: onPrimaryColor,
          secondary: const Color(0xFFA78BFA),
          surface: darkCard,
          background: darkBg,
          outlineVariant: darkOutline,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: darkOutline.withOpacity(0.5)),
          ),
        ),
        // Исправляем DialogThemeData
        dialogTheme: DialogThemeData(
          backgroundColor: darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
          contentTextStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
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
