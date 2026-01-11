import 'package:flutter/material.dart';
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

  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController(); // Исправил опечатку в имени

  bool _isLoading = false;

  // ВАЖНО: Обязательно освобождаем память
  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
        // После регистрации логично сразу пустить в приложение или на экран логина
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ошибка регистрации. Возможно, логин занят.")));
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
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
                  isPassword: false,
                  icon: Icons.person_outlined,
                  controller: _loginController,
                  validator: AppValidators.login,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 15),
                CustomerEdit(
                  label: "Email",
                  maxLength: 254,
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  isPassword: false,
                  // Важно: клавиатура с "@"
                  keyboardType: TextInputType.emailAddress, 
                  validator: AppValidators.email,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 15),
                CustomerEdit(
                  label: "Пароль",
                  icon: Icons.lock_outline,
                  controller: _passController,
                  isPassword: true, // Скрываем текст
                  validator: AppValidators.password,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 15),
                CustomerEdit(
                  label: "Повторный пароль",
                  icon: Icons.lock,
                  isPassword: true, // Тоже скрываем
                  controller: _confirmPassController,
                  // Проверка совпадения
                  validator: (value) => AppValidators.confirmPass(value, _passController.text),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Создать"),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => const LoginPage()));
                  },
                  child: const Text('Уже с нами? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}