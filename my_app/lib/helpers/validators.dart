class AppValidators {
  // --- Базовые проверки ---
  
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Поле обязательно для заполнения";
    }
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return "Введите сумму";
    }
    // Заменяем запятую на точку для корректного парсинга
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
      return "Введите число";
    }
    if (number <= 0) {
      return "Сумма должна быть больше 0";
    }
    return null;
  }

  // --- Специфичные проверки ---

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return "Введите email";
    }
    if (!value.contains('@')) {
      return "Введите корректный email";
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 6) {
      return "Пароль должен быть не меньше 6 символов";
    }
    return null;
  }
  
  static String? login(String? value) {
    if (value == null || value.length < 3) {
      return "Логин должен быть не меньше 3 символов";
    }
    return null;
  }

  static String? confirmPass(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return "Подтвердите пароль";
    }
    if (originalPassword != value) {
      return "Пароли должны совпадать";
    }
    return null;
  }
}