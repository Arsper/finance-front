import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_app/Pages/home.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/Pages/Register/register.dart';
import 'package:my_app/helpers/StorageService.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const Color primaryAccent = Color(0xFF8B5CF6);
const Color onPrimaryColor = Colors.white;

// Темная тема
const Color darkBg = Color(0xFF0F0B15);
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
    if (mode == ThemeMode.light) {
      themeString = 'light';
    } else if (mode == ThemeMode.dark) {
      themeString = 'dark';
    } else {
      themeString = 'system';
    }
    StorageService.setThemeMode(themeString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      // --- СВЕТЛАЯ ТЕМА ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryAccent,
          onPrimary: onPrimaryColor,
          secondary: const Color(0xFF7C3AED),
          surface: lightBg,
          surfaceContainer: Colors.white,
          onSurface: Colors.black87,
          outlineVariant: lightOutline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryAccent),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: lightOutline),
          ),
        ),
      ),

      // --- ТЕМНАЯ ТЕМА ---
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primaryAccent,
          onPrimary: onPrimaryColor,
          secondary: const Color(0xFFA78BFA),
          surface: darkBg,
          surfaceContainer: darkCard,
          onSurface: Colors.white,
          outlineVariant: darkOutline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        datePickerTheme: const DatePickerThemeData(
          headerBackgroundColor: primaryAccent,
          headerForegroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
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
