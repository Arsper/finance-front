import 'dart:ui';
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

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    const String webClientId =
        "974712441086-nrs2249alchlrgh25298nkmsmb58ep6d.apps.googleusercontent.com";

    const String androidClientId =
        "974712441086-9j4esu8tthqcm5l3gl9pm7lu35th7sp7.apps.googleusercontent.com";

    await GoogleSignIn.instance.initialize(
      clientId: androidClientId,
      serverClientId: webClientId,
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

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        final dataSource = UserRemoteDataSource(dio: Dioclient.instance);
        final success = await dataSource.loginWithGoogle(idToken);

        if (success && mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        } else if (mounted) {
          setState(() => _serverError = "Ошибка авторизации на сервере");
        }
      } else {
        setState(() => _serverError = "Не удалось получить токен Google");
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = "Не удалось войти через Google";
        if (e.toString().contains("NETWORK_ERROR")) {
          errorMessage = "Ошибка сети. Проверьте интернет";
        } else if (e.toString().contains("CANCELED") ||
            e.toString().contains("canceled")) {
          errorMessage = "Вход отменен";
        } else if (e.toString().contains("DEVELOPER_ERROR")) {
          errorMessage = "Ошибка конфигурации. Проверьте SHA-1 в Firebase";
        }
        setState(() => _serverError = errorMessage);
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
      final success = await dataSource.loginUser(
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

    final Color textColor = colorScheme.onSurface;
    final Color textMuted = colorScheme.onSurfaceVariant;
    final Color cardBgColor = colorScheme.surface;
    final Color outlineVariant = colorScheme.outlineVariant;
    final Color primaryBtn = colorScheme.primary;
    final Color onPrimaryBtn = colorScheme.onPrimary;
    final Color socialBtnBg = isDark
        ? const Color(0xFF37333D)
        : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          _buildBlurCircle(
            top: -150,
            right: -100,
            color: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
          ),
          _buildBlurCircle(
            bottom: -150,
            left: -100,
            color: colorScheme.secondary.withValues(
              alpha: isDark ? 0.08 : 0.04,
            ),
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
                            color: outlineVariant.withValues(alpha: .3),
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
                                if (_serverError != null) {
                                  setState(() => _serverError = null);
                                }
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
                                if (_serverError != null) {
                                  setState(() => _serverError = null);
                                }
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
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.3,
                                    ),
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
                                    onPressed: _handleGoogleSignIn,
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
        Expanded(child: Divider(color: outlineVariant.withValues(alpha: 0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text("или", style: TextStyle(color: textMuted, fontSize: 12)),
        ),
        Expanded(child: Divider(color: outlineVariant.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildSocialButton({
    required String assetPath,
    required String title,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onPressed,
    Color? logoColor,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
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
