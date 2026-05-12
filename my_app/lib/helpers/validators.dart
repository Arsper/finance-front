class AppValidators {
  // --- Базовые проверки ---

  static bool hasUppercase(String value) => value.contains(RegExp(r'[A-Z]'));
  static bool hasLowercase(String value) => value.contains(RegExp(r'[a-z]'));
  static bool hasDigit(String value) => value.contains(RegExp(r'[0-9]'));
  static bool hasSpecialChar(String value) =>
      value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  static bool hasMinLength(String value) => value.length >= 6;

  static String? password(String? value) {
    if (value == null || value.isEmpty) return "Введите пароль";
    if (!hasMinLength(value) ||
        !hasUppercase(value) ||
        !hasLowercase(value) ||
        !hasDigit(value) ||
        !hasSpecialChar(value)) {
      return "Пароль не соответствует требованиям";
    }
    return null;
  }

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

  static String? emailName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Введите имя почты";
    }
    // Разрешаем буквы, цифры и спецсимволы, которые допустимы в имени
    final nameRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+$');
    if (!nameRegExp.hasMatch(value.trim())) {
      return "Некорректные символы";
    }
    return null;
  }

  // Валидация только домена (часть ПОСЛЕ @, включая саму @)
  static String? emailDomain(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Введите домен";
    }
    // Должен начинаться с @, иметь имя и точку с расширением (напр. @mail.ru)
    final domainRegExp = RegExp(r'^@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!domainRegExp.hasMatch(value.trim())) {
      return "Пример: @domain.com";
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
