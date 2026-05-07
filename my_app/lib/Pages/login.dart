import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/Register/ForgotPasswordPage.dart';
import 'package:my_app/Pages/Register/register.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final dataSource = UserRemoteDataSource(dio: Dioclient.instance);
      bool success = await dataSource.loginUser(
        _passController.text,
        _loginController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка входа. Проверьте логин и пароль.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка сети: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Получаем текущую тему и цветовую схему
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Адаптивные цвета на основе ColorScheme из main.dart
    final Color bgColor = colorScheme.background;
    final Color textColor = colorScheme.onBackground;
    final Color textMuted = colorScheme.onSurfaceVariant;
    final Color cardBgColor = colorScheme.surface;
    final Color outlineVariant = colorScheme.outlineVariant;
    final Color primaryBtn = colorScheme.primary;
    final Color onPrimaryBtn = colorScheme.onPrimary;

    // Цвет для социальных кнопок (чуть светлее/темнее основного фона)
    final Color socialBtnBg = isDark ? const Color(0xFF37333D) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Декоративный неоновый фон
          _buildBlurCircle(
            top: -150,
            right: -100,
            color: colorScheme.primary.withOpacity(isDark ? 0.08 : 0.04),
          ),
          _buildBlurCircle(
            bottom: -150,
            left: -100,
            color: colorScheme.secondary.withOpacity(isDark ? 0.08 : 0.04),
          ),

          // 2. Основной контент
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Умный кошелёк",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Главная карточка
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: outlineVariant.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomerEdit(
                              label: "Имя пользователя или email",
                              icon: Icons.person_outlined,
                              controller: _loginController,
                              validator: AppValidators.login,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 20),
                            CustomerEdit(
                              label: "Введите ваш пароль",
                              icon: Icons.lock_outline,
                              controller: _passController,
                              isPassword: true,
                              validator: AppValidators.password,
                              textInputAction: TextInputAction.done,
                            ),

                            // Забыли пароль
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                                ),
                                child: Text(
                                  "Забыли пароль?",
                                  style: TextStyle(color: textMuted, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Кнопка входа
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBtn,
                                  foregroundColor: onPrimaryBtn,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: onPrimaryBtn),
                                      )
                                    : const Text("Войти", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Разделитель
                            _buildDivider(textMuted, outlineVariant),
                            const SizedBox(height: 24),

                            // Социальные кнопки
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSocialButton(
                                    logoUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuBWTnknpJ8kQYbDp-DXGhVueDNEiFuWKwxsLLNM4K16t6R3azHq8gkqCepFHC-ECy6VgY-yVxQaECw54h3P_Jk98xkR29pKeEatafN9RNv1TcAda12zJWDLRO0niNtAJHk6xFd48mz6-COrxwGNB5yryikFiqKgGFYYr5XxbqIetqDOu2kEjDBn48aRZ3fqoQKg4FTDOck9C68GKw74ZedZfKvcqZCQLt-wckBhYDYLmIEJEIzA5yf953CwjP00YMdJzZjzZlz_DW0",
                                    title: "Google",
                                    bgColor: socialBtnBg,
                                    textColor: textColor,
                                    borderColor: outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSocialButton(
                                    logoUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuBqqMVyLTNwgVfR_oiEwpJfINq40IWUdzYAobe7zWjNs_QMuNabJ_TEKOlYqqblXxGZeQgE68Tm9COAxduviVXH28-R48-iU4Sx5omelDTjDvi8STpz47wMAZvhBmw4T2No75bX-n_Is2t0tbt2OcrgN0M0YS-T2KsKShtXqftgSt6JAAOENhbaTdLNFlAVNK7g0xiJ4eMssPwqjf4Ea3-s8k__n_34sh8quGusXPRa05ULqJRf4vfJ09XieShIqg4PdrnppDy1HP8",
                                    title: "Apple",
                                    bgColor: socialBtnBg,
                                    textColor: textColor,
                                    borderColor: outlineVariant,
                                    invertLogo: isDark, // Инвертируем только в темной теме
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Кнопка регистрации
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        ),
                        child: Text(
                          'Нет аккаунта? Зарегистрироваться',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFD0BCFF) : colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Вспомогательные методы ---

  Widget _buildBlurCircle({double? top, double? right, double? bottom, double? left, required Color color}) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }

  Widget _buildDivider(Color textMuted, Color outlineVariant) {
    return Row(
      children: [
        Expanded(child: Divider(color: outlineVariant.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text("или", style: TextStyle(color: textMuted, fontSize: 12)),
        ),
        Expanded(child: Divider(color: outlineVariant.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildSocialButton({
    required String logoUrl,
    required String title,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    bool invertLogo = false,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: invertLogo
                  ? const ColorFilter.matrix([
                      -1, 0, 0, 0, 255,
                      0, -1, 0, 0, 255,
                      0, 0, -1, 0, 255,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.network(
                logoUrl,
                width: 20,
                errorBuilder: (_, __, ___) => Icon(Icons.star, size: 20, color: textColor),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}