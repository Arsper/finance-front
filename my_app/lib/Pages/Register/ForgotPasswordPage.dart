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
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  final UserRemoteDataSource _dataSource = UserRemoteDataSource(
    dio: Dioclient.instance,
  );

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

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
    super.dispose();
  }

  // --- ЛОГИКА ---

  Future<void> _nextStep() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_currentStep == 0) {
        setState(() => _emailError = null);
        final success = await _dataSource.sendForgotPasswordCode(
          _emailController.text.trim(),
        );
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

        final isValid = await _dataSource.verifyRegistrationCode(
          _emailController.text.trim(),
          _otpController.text,
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
      _emailController.text.trim(),
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
    if (_currentStep == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      // При нажатии "назад" на любом этапе сбрасываем всё и идем в начало
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
  }

  // --- UI COMPONENTS ---

  Widget _buildPasswordRequirement(String label, bool isMet, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : colorScheme.onSurfaceVariant.withOpacity(0.5),
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
              color: _otpError != null ? Colors.redAccent : colorScheme.outlineVariant.withOpacity(0.5),
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
                        color: hasCharacter ? colorScheme.primary : colorScheme.outline,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasCharacter ? "●" : "",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
          Text(_otpError!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
        ],
        const SizedBox(height: 24),
        _buildTimerSection(colorScheme),
      ],
    );
  }

  // --- СТАНДАРТНЫЙ BUILD И ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---

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
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepWrapper(
                      "Почта",
                      "Введите email, привязанный к вашему аккаунту.",
                      CustomerEdit(
                        label: "Email",
                        icon: Icons.alternate_email,
                        controller: _emailController,
                        validator: AppValidators.email,
                        errorText: _emailError,
                        onChanged: (v) => setState(() => _emailError = null),
                      ),
                      colorScheme,
                    ),
                    _stepWrapper(
                      "Подтверждение",
                      "Введите код из письма.",
                      _buildOtpSection(colorScheme),
                      colorScheme,
                    ),
                    _stepWrapper(
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
                            validator: (v) => AppValidators.confirmPass(v, _passController.text),
                            onChanged: (v) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildPasswordRequirement("Минимум 6 символов", AppValidators.hasMinLength(_passController.text), colorScheme),
                                _buildPasswordRequirement("Одна заглавная буква", AppValidators.hasUppercase(_passController.text), colorScheme),
                                _buildPasswordRequirement("Одна строчная буква", AppValidators.hasLowercase(_passController.text), colorScheme),
                                _buildPasswordRequirement("Одна цифра", AppValidators.hasDigit(_passController.text), colorScheme),
                                _buildPasswordRequirement("Один спецсимвол (!@#\$...)", AppValidators.hasSpecialChar(_passController.text), colorScheme),
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
                color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepWrapper(String title, String subtitle, Widget child, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(subtitle, style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }

  Widget _buildTimerSection(ColorScheme colorScheme) {
    return Column(
      children: [
        Text(_canResend ? "Не получили код?" : "Повторная отправка через:", style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        _canResend
            ? TextButton(
                onPressed: () async {
                  _startTimer();
                  await _dataSource.sendForgotPasswordCode(_emailController.text);
                },
                child: Text("Отправить еще раз", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              )
            : Text(
                "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colorScheme.primary),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: _isLoading ? null : _nextStep,
        child: _isLoading
            ? CircularProgressIndicator(color: colorScheme.onPrimary)
            : Text(
                _currentStep == _totalSteps - 1 ? "Сбросить пароль" : "Продолжить",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}