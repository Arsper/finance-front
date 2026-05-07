import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart'; // Твой кастомный инпут
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
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ошибка входа. Проверьте логин и пароль."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка сети: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Цветовая палитра из твоего Tailwind-конфига
    const Color bgColor = Color(0xFF15121B);
    const Color textColor = Color(0xFFE7E0ED);
    const Color textMuted = Color(0xFF958EA0);
    const Color cardBgColor = Color(0xFF1D1A23);
    const Color outlineVariant = Color(0xFF494454);
    const Color primaryContainer = Color(0xFFA078FF);
    const Color onPrimaryContainer = Color(0xFF340080);
    const Color socialBtnBg = Color(0xFF37333D);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Декоративный неоновый фон (размытые круги)
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryContainer.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF3A4A5F,
                    ).withOpacity(0.08), // secondary-container из конфига
                    Colors.transparent,
                  ],
                ),
              ),
            ),
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
                      // Заголовок приложения
                      const Text(
                        "Умный кошелёк",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Главная карточка с формой входа
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: outlineVariant.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            CustomerEdit(
                              label: "Имя пользователя или email",
                              maxLength: 64,
                              icon: Icons.person_outlined,
                              controller: _loginController,
                              isPassword: false,
                              validator: AppValidators.login,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 20),

                            const SizedBox(height: 8),
                            CustomerEdit(
                              label: "Введите ваш пароль",
                              icon: Icons.lock_outline,
                              controller: _passController,
                              isPassword: true,
                              validator: AppValidators.password,
                              textInputAction: TextInputAction.done,
                            ),

                            // Забыли пароль
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 20,
                                right: 4,
                              ), // Настраивай значения под себя
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                child: const Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    "Забыли пароль?",
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Кнопка входа
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryContainer,
                                  foregroundColor: onPrimaryContainer,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Войти",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Разделитель
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: outlineVariant.withOpacity(0.3),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Text(
                                    "или войти через",
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: outlineVariant.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Социальные кнопки
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSocialButton(
                                    logoUrl:
                                        "https://lh3.googleusercontent.com/aida-public/AB6AXuBWTnknpJ8kQYbDp-DXGhVueDNEiFuWKwxsLLNM4K16t6R3azHq8gkqCepFHC-ECy6VgY-yVxQaECw54h3P_Jk98xkR29pKeEatafN9RNv1TcAda12zJWDLRO0niNtAJHk6xFd48mz6-COrxwGNB5yryikFiqKgGFYYr5XxbqIetqDOu2kEjDBn48aRZ3fqoQKg4FTDOck9C68GKw74ZedZfKvcqZCQLt-wckBhYDYLmIEJEIzA5yf953CwjP00YMdJzZjzZlz_DW0",
                                    title: "Google",
                                    bgColor: socialBtnBg,
                                    textColor: textColor,
                                    borderColor: outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSocialButton(
                                    logoUrl:
                                        "https://lh3.googleusercontent.com/aida-public/AB6AXuBqqMVyLTNwgVfR_oiEwpJfINq40IWUdzYAobe7zWjNs_QMuNabJ_TEKOlYqqblXxGZeQgE68Tm9COAxduviVXH28-R48-iU4Sx5omelDTjDvi8STpz47wMAZvhBmw4T2No75bX-n_Is2t0tbt2OcrgN0M0YS-T2KsKShtXqftgSt6JAAOENhbaTdLNFlAVNK7g0xiJ4eMssPwqjf4Ea3-s8k__n_34sh8quGusXPRa05ULqJRf4vfJ09XieShIqg4PdrnppDy1HP8",
                                    title: "Apple",
                                    bgColor: socialBtnBg,
                                    textColor: textColor,
                                    borderColor: outlineVariant,
                                    invertLogo:
                                        true, // Инвертируем черный логотип Apple для темной темы
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Кнопка перехода на регистрацию
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Нет аккаунта? Зарегистрироваться',
                          style: TextStyle(
                            color: Color(0xFFD0BCFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  // Вспомогательный виджет для социальных кнопок
  Widget _buildSocialButton({
    required String logoUrl,
    required String title,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    bool invertLogo = false,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          // Логика авторизации через соцсети
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: invertLogo
                  ? const ColorFilter.matrix([
                      -1, 0, 0, 0, 255, // Инвертирование в белый цвет для Apple
                      0, -1, 0, 0, 255,
                      0, 0, -1, 0, 255,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.network(
                logoUrl,
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  // Фолбек на иконку в случае отсутствия сети
                  return Icon(
                    title == "Google" ? Icons.g_mobiledata : Icons.apple,
                    color: Colors.white,
                    size: 20,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
