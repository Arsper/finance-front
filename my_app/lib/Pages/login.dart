import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/CustomerEdit.dart'; // Путь к вашему файлу
import 'package:my_app/Pages/register.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/helpers/validators.dart'; // Путь к AppValidators

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
      // Убираем лишние пробелы в логине
      bool success = await dataSource.loginUser(
        _passController.text,
        _loginController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ошибка входа. Проверьте логин и пароль.")));
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка сети: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      // Center + SingleChildScrollView решает проблему с клавиатурой
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomerEdit(
                  label: "Логин",
                  maxLength: 64,
                  icon: Icons.person_outlined,
                  controller: _loginController,
                  isPassword: false,
                  validator: AppValidators.login,
                  // На клавиатуре будет кнопка "Далее"
                  textInputAction: TextInputAction.next, 
                ),
                const SizedBox(height: 15),
                CustomerEdit(
                  label: "Пароль", // Добавил лейбл
                  icon: Icons.lock_outline, // Явно указал иконку
                  controller: _passController,
                  isPassword: true, // Это пароль
                  validator: AppValidators.password,
                  // На клавиатуре будет кнопка "Готово"
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50), // Кнопка на всю ширину
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Войти"),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()));
                  },
                  child: const Text('Нет аккаунта? Зарегистрироваться'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}