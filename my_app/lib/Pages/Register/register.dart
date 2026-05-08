import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/api/url/urlParametrs.dart';
import 'package:my_app/helpers/validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  late final UserRemoteDataSource _dataSource;

  // Контроллеры полей
  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // Локальные ошибки под полями
  String? _loginError;
  String? _emailError;
  String? _otpError;

  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;

  Timer? _timer;
  int _secondsRemaining = 40;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _dataSource = UserRemoteDataSource(dio: Dioclient.instance);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loginController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- ЛОГИКА ---

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleBack() {
    if (_currentStep == 0) {
      // Если мы и так на первом шаге, уходим на страницу логина
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      // Если мы на шаге 1, 2 или 3 — возвращаемся в самое начало и всё очищаем
      setState(() {
        _currentStep = 0;
        _clearAllFields(); // Вызываем полную очистку
      });

      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // Добавь этот метод для полной очистки данных
  void _clearAllFields() {
    _loginController.clear();
    _emailController.clear();
    _otpController.clear();
    _passController.clear();
    _confirmPassController.clear();
    _clearErrors(); // Твой существующий метод очистки ошибок

    // Останавливаем таймер, если он работал
    _timer?.cancel();
    _secondsRemaining = 40;
    _canResend = false;
  }

  void _clearErrors() {
    setState(() {
      _loginError = null;
      _emailError = null;
      _otpError = null;
    });
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 40;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() => _canResend = true);
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _nextStep() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _clearErrors();

    try {
      bool canProceed = false;

      if (_currentStep == 0) {
        final String login = _loginController.text.trim();
        final bool isTaken = await _dataSource.isLoginTaken(login);

        if (isTaken) {
          setState(() => _loginError = "Этот логин уже занят");
          canProceed = false;
        } else {
          canProceed = true;
        }
      } else if (_currentStep == 1) {
        // Шаг 1: Отправка кода на Email
        canProceed = await _dataSource.sendRegistrationCode(
          _emailController.text.trim(),
        );
        if (!canProceed) {
          setState(() => _emailError = "Данная почта уже занята или неверна");
        }
      } else if (_currentStep == 2) {
        // Шаг 2: Проверка кода OTP
        if (_otpController.text.length < 6) {
          setState(() => _otpError = "Введите 6-значный код");
          canProceed = false;
        } else {
          canProceed = await _dataSource.verifyRegistrationCode(
            _emailController.text.trim(),
            _otpController.text.trim(),
          );
          if (!canProceed)
            setState(() => _otpError = "Неверный или истекший код");
        }
      } else if (_currentStep == 3) {
        // Шаг 3: Финальная регистрация
        await _submit();
        return;
      }

      if (canProceed && mounted) {
        if (_currentStep == 1) _startTimer();
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    } catch (e) {
      String errorMsg = "Ошибка соединения";
      if (e is DioException && e.response?.data != null) {
        errorMsg = e.response?.data.toString() ?? errorMsg;
      }
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    try {
      final response = await Dioclient.instance.post(
        UrlParameters.registrationUrl,
        data: {
          'login': _loginController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passController.text,
          'emailCode': _otpController.text
              .trim(), // Проверь, что в Java поле называется 'code'
        },
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } on DioException catch (e) {
      // Выводим текст ошибки от самого сервера
      final errorMessage = e.response?.data?.toString() ?? "Ошибка сервера";
      _showSnackBar("Ошибка: $errorMessage", isError: true);
      debugPrint("Full Error: ${e.response?.data}");
    } catch (e) {
      _showSnackBar("Неизвестная ошибка: $e", isError: true);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Регистрация",
          style: TextStyle(
            fontSize: 18,
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w500,
          ),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: colorScheme.onBackground,
            size: 22,
          ),
          onPressed: _isLoading ? null : _handleBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(colorScheme),
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepWrapper(
                      "Логин",
                      "Придумайте уникальное имя для входа в систему.",
                      CustomerEdit(
                        label: "Введите ваш логин",
                        icon: Icons.person_outline,
                        controller: _loginController,
                        validator: AppValidators.login,
                        errorText: _loginError,
                        onChanged: (v) => setState(() => _loginError = null),
                      ),
                      colorScheme,
                    ),
                    _stepWrapper(
                      "Почта",
                      "Введите вашу почту. Мы пришлем на неё код.",
                      CustomerEdit(
                        label: "Email",
                        icon: Icons.alternate_email,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: AppValidators.email,
                        errorText: _emailError,
                        onChanged: (v) => setState(() => _emailError = null),
                      ),
                      colorScheme,
                    ),
                    _stepWrapper(
                      "Подтверждение",
                      "Введите 6-значный код из письма.",
                      _buildOtpSection(colorScheme),
                      colorScheme,
                    ),
                    _stepWrapper(
                      "Пароль",
                      "Установите пароль для защиты аккаунта.",
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomerEdit(
                            label: "Пароль",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _passController,
                            validator: AppValidators.password,
                            onChanged: (v) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          CustomerEdit(
                            label: "Повтор пароля",
                            icon: Icons.shield_outlined,
                            isPassword: true,
                            controller: _confirmPassController,
                            validator: (v) => AppValidators.confirmPass(
                              v,
                              _passController.text,
                            ),
                            onChanged: (v) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          // Блок требований перенесен под повтор пароля
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(
                                0.3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildPasswordRequirement(
                                  "Минимум 6 символов",
                                  AppValidators.hasMinLength(
                                    _passController.text,
                                  ),
                                  colorScheme,
                                ),
                                _buildPasswordRequirement(
                                  "Одна заглавная буква",
                                  AppValidators.hasUppercase(
                                    _passController.text,
                                  ),
                                  colorScheme,
                                ),
                                _buildPasswordRequirement(
                                  "Одна строчная буква",
                                  AppValidators.hasLowercase(
                                    _passController.text,
                                  ),
                                  colorScheme,
                                ),
                                _buildPasswordRequirement(
                                  "Одна цифра",
                                  AppValidators.hasDigit(_passController.text),
                                  colorScheme,
                                ),
                                _buildPasswordRequirement(
                                  "Один спецсимвол (!@#\$...)",
                                  AppValidators.hasSpecialChar(
                                    _passController.text,
                                  ),
                                  colorScheme,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      colorScheme,
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNav(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          bool isActive = index <= _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepWrapper(
    String title,
    String subtitle,
    Widget child,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }

  Widget _buildOtpSection(ColorScheme colorScheme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _otpError != null
                  ? Colors.redAccent
                  : colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  // Логика маскировки:
                  bool hasCharacter = _otpController.text.length > index;

                  return Container(
                    width: 45,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hasCharacter
                            ? colorScheme.primary
                            : colorScheme.outline,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasCharacter
                          ? "●"
                          : "", // Показываем точку, если символ введен
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextFormField(
                    controller: _otpController,
                    autofocus: true,
                    // Важно оставить keyboardType number, чтобы вызывалась цифровая клавиатура
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (v) {
                      setState(() => _otpError = null);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 12),
          Text(
            _otpError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        _buildTimerSection(colorScheme),
      ],
    );
  }

  Widget _buildTimerSection(ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          _canResend ? "Не получили код?" : "Повторная отправка через:",
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        _canResend
            ? TextButton(
                onPressed: () async {
                  _startTimer();
                  await _dataSource.sendRegistrationCode(
                    _emailController.text.trim(),
                  );
                },
                child: Text(
                  "Отправить еще раз",
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            : Text(
                "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
      ],
    );
  }

  Widget _buildPasswordRequirement(
    String label,
    bool isMet,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet
                ? Colors.green
                : colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isMet ? Colors.green : colorScheme.onSurfaceVariant,
              decoration: isMet ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _nextStep,
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    _currentStep == _totalSteps - 1
                        ? "Зарегистрироваться"
                        : "Продолжить",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (_currentStep == 0) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ),
              child: Text.rich(
                TextSpan(
                  text: "Уже есть аккаунт? ",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                  children: [
                    TextSpan(
                      text: "Войти",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
