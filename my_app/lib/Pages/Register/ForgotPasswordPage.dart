import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final List<GlobalKey<FormState>> _formKeys = List.generate(
    3,
    (_) => GlobalKey<FormState>(),
  );
  final PageController _pageController = PageController();

  final UserRemoteDataSource _dataSource = UserRemoteDataSource(
    dio: Dioclient.instance,
  );

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _customDomainController = TextEditingController();

  final List<String> _domains = [
    "@gmail.com",
    "@mail.ru",
    "@yandex.ru",
    "Свой...",
  ];
  String _selectedDomain = "@gmail.com";
  bool _isCustomDomain = false;

  String? _emailError;
  String? _otpError;

  int _currentStep = 0;
  final int _totalSteps = 3;
  bool _isLoading = false;

  Timer? _timer;
  int _secondsRemaining = 40;
  bool _canResend = false;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (!_formKeys[_currentStep].currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      if (_currentStep == 0) {
        setState(() => _emailError = null);
        final fullEmail = _getFullEmail();
        final success = await _dataSource.sendForgotPasswordCode(fullEmail);
        if (success) {
          _animateToStep(1);
          _startTimer();
        } else {
          setState(() => _emailError = "Пользователь с такой почтой не найден");
        }
      } else if (_currentStep == 1) {
        setState(() => _otpError = null);

        if (_otpController.text.length < 6) {
          setState(() => _otpError = "Введите 6-значный код");
          setState(() => _isLoading = false);
          return;
        }

        final fullEmail = _getFullEmail();
        final isValid = await _dataSource.verifyRegistrationCode(
          fullEmail,
          _otpController.text.trim(),
        );

        if (isValid) {
          _animateToStep(2);
        } else {
          setState(() => _otpError = "Неверный или истекший код");
        }
      } else if (_currentStep == 2) {
        await _submitNewPassword();
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

  Future<void> _submitNewPassword() async {
    final success = await _dataSource.resetPassword(
      _getFullEmail(),
      _otpController.text,
      _passController.text,
    );

    if (success) {
      _showSnackBar("Пароль успешно изменен!", isError: false);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } else {
      _showSnackBar("Ошибка сброса пароля", isError: true);
    }
  }

  void _handleBack() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      setState(() {
        _currentStep = 0;
        _clearAllFields();
      });

      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _clearAllFields() {
    _emailController.clear();
    _otpController.clear();
    _passController.clear();
    _confirmPassController.clear();
    _emailError = null;
    _otpError = null;
    _timer?.cancel();
    _secondsRemaining = 40;
    _canResend = false;
    _customDomainController.clear();
    _isCustomDomain = false;
    _selectedDomain = "@gmail.com";
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
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
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
                      hasCharacter ? "●" : "",
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
                    autofocus: _currentStep == 1,
                    enabled: _currentStep == 1,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (v) => setState(() => _otpError = null),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Восстановление", style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _isLoading ? null : _handleBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(colorScheme),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Form(
                    key: _formKeys[0],
                    child: _stepWrapper(
                      "Почта",
                      "Введите email, привязанный к вашему аккаунту.",
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: CustomerEdit(
                                    label: "Имя почты",
                                    controller: _emailController,
                                    maxLength: 32,
                                    validator: AppValidators.emailName,
                                    onChanged: (v) =>
                                        setState(() => _emailError = null),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _isCustomDomain
                                      ? CustomerEdit(
                                          label: "@домен",
                                          maxLength: 32,
                                          controller: _customDomainController,
                                          validator: AppValidators.emailDomain,
                                          onChanged: (v) => setState(() {}),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.outlineVariant,
                                            ),
                                          ),
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _selectedDomain,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 15,
                                                  ),
                                              isDense: true,
                                            ),
                                            isExpanded: true,
                                            icon: const Icon(
                                              Icons.arrow_drop_down,
                                            ),
                                            onChanged: _currentStep != 0
                                                ? null
                                                : (newValue) {
                                                    setState(() {
                                                      if (newValue ==
                                                          "Свой...") {
                                                        _isCustomDomain = true;
                                                        _customDomainController
                                                                .text =
                                                            "@";
                                                        _customDomainController
                                                                .selection =
                                                            TextSelection.fromPosition(
                                                              TextPosition(
                                                                offset:
                                                                    _customDomainController
                                                                        .text
                                                                        .length,
                                                              ),
                                                            );
                                                      } else {
                                                        _selectedDomain =
                                                            newValue!;
                                                      }
                                                    });
                                                  },
                                            items: _domains.map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          if (_isCustomDomain && _currentStep == 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _isCustomDomain = false),
                                child: const Text(
                                  "Выбрать из списка",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          if (_emailError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12),
                              child: Text(
                                _emailError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      colorScheme,
                    ),
                  ),

                  Form(
                    key: _formKeys[1],
                    child: _stepWrapper(
                      "Подтверждение",
                      "Введите код из письма.",
                      _buildOtpSection(colorScheme),
                      colorScheme,
                    ),
                  ),

                  Form(
                    key: _formKeys[2],
                    child: _stepWrapper(
                      "Новый пароль",
                      "Придумайте сложный пароль.",
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomerEdit(
                            label: "Новый пароль",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _passController,
                            validator: AppValidators.password,
                            onChanged: (v) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          CustomerEdit(
                            label: "Повторите пароль",
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
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
                  ),
                ],
              ),
            ),
            _buildBottomNav(colorScheme),
          ],
        ),
      ),
    );
  }

  void _animateToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                onPressed: _currentStep != 1
                    ? null
                    : () async {
                        _startTimer();
                        await _dataSource.sendForgotPasswordCode(
                          _getFullEmail(),
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

  Widget _buildBottomNav(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: _isLoading ? null : _nextStep,
        child: _isLoading
            ? CircularProgressIndicator(color: colorScheme.onPrimary)
            : Text(
                _currentStep == _totalSteps - 1
                    ? "Сбросить пароль"
                    : "Продолжить",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  String _getFullEmail() {
    final name = _emailController.text.trim();
    final domain = _isCustomDomain
        ? _customDomainController.text.trim()
        : _selectedDomain;
    return "$name$domain";
  }
}
