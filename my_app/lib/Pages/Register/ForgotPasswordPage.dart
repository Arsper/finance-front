import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/helpers/validators.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  // Начинаем с 0, но это будет шаг с Email
  final PageController _pageController = PageController();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  int _currentStep = 0;
  final int _totalSteps = 3; // Почта, OTP, Пароль
  bool _isLoading = false;

  Timer? _timer;
  int _secondsRemaining = 40;
  bool _canResend = false;

  final Color bgColor = const Color(0xFF15121B);
  final Color primaryColor = const Color(0xFFa078ff);
  final Color inactiveStepColor = const Color(0xFF37333d);

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
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

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep == 0) _startTimer(); // Запуск таймера после ввода Email

      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _submitNewPassword();
      }
    }
  }

  Future<void> _submitNewPassword() async {
    // Здесь ваша логика API для сброса пароля
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Имитация
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Восстановление",
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Шаги (Email, OTP, Password) остаются такими же
                    _stepWrapper(
                      "Почта",
                      "Введите email, привязанный к вашему аккаунту.",
                      CustomerEdit(
                        label: "Email",
                        icon: Icons.alternate_email,
                        controller: _emailController,
                        validator: AppValidators.email,
                      ),
                    ),
                    _stepWrapper(
                      "Подтверждение",
                      "Введите код из письма.",
                      Column(
                        children: [const SizedBox(height: 20), _buildOtpCard()],
                      ),
                    ),
                    _stepWrapper(
                      "Новый пароль",
                      "Придумайте сложный пароль.",
                      Column(
                        children: [
                          CustomerEdit(
                            label: "Новый пароль",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _passController,
                            validator: AppValidators.password,
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNav(), // Теперь вызывается правильный метод
          ],
        ),
      ),
    );
  }

  // Виджет карточки OTP из предыдущего шага
  Widget _buildOtpCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1d1a23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  String char = _otpController.text.length > index
                      ? _otpController.text[index]
                      : "";
                  return Container(
                    width: 42,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: char.isNotEmpty ? primaryColor : Colors.white12,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (v) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimerSection(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
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
                color: isActive ? primaryColor : inactiveStepColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepWrapper(String title, String subtitle, Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    return Column(
      children: [
        Text(
          _canResend ? "Не получили код?" : "Повторная отправка через:",
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 12),
        _canResend
            ? TextButton(
                onPressed: () {
                  _startTimer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Код отправлен повторно")),
                  );
                },
                child: Text(
                  "Отправить еще раз",
                  style: TextStyle(
                    color: primaryColor,
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
                  color: primaryColor,
                  letterSpacing: 1.1,
                ),
              ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _nextStep,
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
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
          if (_currentStep == 0) ...[const SizedBox(height: 20)],
        ],
      ),
    );
  }
}
