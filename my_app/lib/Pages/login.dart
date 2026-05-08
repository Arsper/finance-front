import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  String? _serverError;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    // Твой Client ID от WEB-приложения из Google Cloud Console
    const String webClientId =
        "974712441086-g5786e4k76hgq7iq5ur1pcabdk4tnf4a.apps.googleusercontent.com";

    await _googleSignIn.initialize(
      clientId: kIsWeb ? webClientId : null, // Для веба нужен clientId
      serverClientId:
          webClientId, // ДЛЯ ANDROID ОБЯЗАТЕЛЬНО передаем веб-клиент сюда
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
        _serverError = null;
      });

      // Заменяем .signIn() на .authenticate()
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // В этой версии authenticate возвращает GoogleSignInAccount (не nullable),
      // но лучше оставить проверку или обработать исключение через try-catch,
      // так как при отмене пользователем кидается GoogleSignInException.

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        final dataSource = UserRemoteDataSource(dio: Dioclient.instance);
        bool success = await dataSource.loginWithGoogle(idToken);

        if (success && mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        } else if (mounted) {
          setState(() => _serverError = "Ошибка авторизации на сервере");
        }
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) {
        // Если пользователь отменил вход, authenticate() выбросит исключение
        // с кодом GoogleSignInExceptionCode.canceled
        setState(() => _serverError = "Не удалось войти через Google");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _serverError = null;
    });

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
        setState(
          () => _serverError = "Ошибка входа. Проверьте логин и пароль.",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _serverError = "Ошибка сети. Попробуйте позже.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color textColor = colorScheme.onBackground;
    final Color textMuted = colorScheme.onSurfaceVariant;
    final Color cardBgColor = colorScheme.surface;
    final Color outlineVariant = colorScheme.outlineVariant;
    final Color primaryBtn = colorScheme.primary;
    final Color onPrimaryBtn = colorScheme.onPrimary;
    final Color socialBtnBg = isDark
        ? const Color(0xFF37333D)
        : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        children: [
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
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: outlineVariant.withOpacity(0.3),
                          ),
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
                              onChanged: (_) {
                                if (_serverError != null)
                                  setState(() => _serverError = null);
                              },
                            ),
                            const SizedBox(height: 20),
                            CustomerEdit(
                              label: "Введите ваш пароль",
                              icon: Icons.lock_outline,
                              controller: _passController,
                              isPassword: true,
                              validator: AppValidators.password,
                              onChanged: (_) {
                                if (_serverError != null)
                                  setState(() => _serverError = null);
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordPage(),
                                  ),
                                ),
                                child: Text(
                                  "Забыли пароль?",
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBtn,
                                  foregroundColor: onPrimaryBtn,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: onPrimaryBtn,
                                        ),
                                      )
                                    : const Text(
                                        "Войти",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            if (_serverError != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _serverError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            _buildDivider(textMuted, outlineVariant),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSocialButton(
                                    assetPath: 'assets/icons/google.svg',
                                    title: "Google",
                                    bgColor: socialBtnBg,
                                    textColor: textColor,
                                    borderColor: outlineVariant,
                                    onPressed:
                                        _handleGoogleSignIn, // ПЕРЕДАЕМ МЕТОД
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        ),
                        child: Text(
                          'Нет аккаунта? Зарегистрироваться',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFD0BCFF)
                                : colorScheme.primary,
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

  Widget _buildBlurCircle({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required Color color,
  }) {
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
    required String assetPath,
    required String title,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onPressed, // Добавили обязательный колбэк
    Color? logoColor,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor.withOpacity(0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed, // Привязываем к кнопке
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              assetPath,
              width: 22,
              height: 22,
              colorFilter: logoColor != null
                  ? ColorFilter.mode(logoColor, BlendMode.srcIn)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
