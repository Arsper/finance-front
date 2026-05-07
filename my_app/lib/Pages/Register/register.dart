import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart';
import 'package:my_app/Pages/login.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/user.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;

  Timer? _timer;
  int _secondsRemaining = 40;
  bool _canResend = false;

  // Цветовая палитра из твоего дизайна
  final Color bgColor = const Color(0xFF15121B);
  final Color primaryColor = const Color(0xFFa078ff);
  final Color inactiveStepColor = const Color(0xFF37333d);

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in [
      _loginController,
      _emailController,
      _otpController,
      _passController,
      _confirmPassController,
    ]) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _resetToStart() {
    _timer?.cancel();
    setState(() {
      _currentStep = 0;
      _secondsRemaining = 40;
      _canResend = false;
      _loginController.clear();
      _emailController.clear();
      _otpController.clear();
      _passController.clear();
      _confirmPassController.clear();
    });
    _pageController.jumpToPage(0);
  }

  // Исправленная логика навигации назад
  void _handleBack() {
    if (_currentStep == 0) {
      // Если мы на первом шаге, принудительно возвращаемся на логин,
      // чтобы не было "белого экрана" из-за пустого стека
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else if (_currentStep == 3) {
      // Если на вводе пароля — сбрасываем всё до начала
      _resetToStart();
    } else {
      // Иначе просто идем на предыдущую страницу PageView
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
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
      if (_currentStep == 1) _startTimer();

      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _submit();
      }
    }
  }

  Future<void> _submit() async {
    if (_otpController.text != "123456") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Неверный код. Используйте 123456")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserModel newUser = UserModel(
        login: _loginController.text.trim(),
        email: _emailController.text.trim(),
        password: _passController.text,
      );
      final dataSource = UserRemoteDataSource(dio: Dioclient.instance);
      bool success = await dataSource.registerUser(newUser);

      if (success && mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          "Регистрация",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        automaticallyImplyLeading: false, // Отключаем дефолтную стрелку
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 22,
          ),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildProgressBar(),
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
                      ),
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
                      ),
                    ),
                    _stepWrapper(
                      "Подтверждение",
                      "Введите 6-значный код. Если письмо не пришло, проверьте папку «Спам».",
                      GestureDetector(
                        onTap: () => FocusScope.of(context).requestFocus(
                          FocusNode(),
                        ), // Позволяет вернуть фокус при клике
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1d1a23),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                // Используем Stack, чтобы наложить невидимое поле сверху
                                children: [
                                  // 1. Стилизованные ячейки (Визуал)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: List.generate(6, (index) {
                                      String char = "";
                                      if (_otpController.text.length > index) {
                                        char = _otpController.text[index];
                                      }
                                      return Container(
                                        width: 45,
                                        height: 55,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          border: Border.all(
                                            color: char.isNotEmpty
                                                ? primaryColor
                                                : Colors.white12,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          char,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),

                                  // 2. Реальное поле ввода (Скрытое, но активное)
                                  // Мы растягиваем его на всю высоту Row, чтобы клик попадал по нему
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: 0,
                                      child: TextFormField(
                                        controller: _otpController,
                                        autofocus: true,
                                        keyboardType: TextInputType.number,
                                        // Ограничение ввода только цифрами
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        onChanged: (v) {
                                          setState(
                                            () {},
                                          ); // Перерисовываем ячейки при каждом изменении
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTimerSection(),
                          ],
                        ),
                      ),
                    ),
                    _stepWrapper(
                      "Пароль",
                      "Установите пароль для защиты аккаунта.",
                      Column(
                        children: [
                          CustomerEdit(
                            label: "Пароль",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            controller: _passController,
                            validator: AppValidators.password,
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
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
          if (_currentStep == 0) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ),
              child: const Text.rich(
                TextSpan(
                  text: "Уже есть аккаунт? ",
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                  children: [
                    TextSpan(
                      text: "Войти",
                      style: TextStyle(
                        color: Colors.white,
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
