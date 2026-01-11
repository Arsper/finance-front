import 'package:shared_preferences/shared_preferences.dart';

class  StorageService{
  static late SharedPreferences _prefs;
  static const String _themeKey = 'app_theme';


  static String getThemeMode() {
    return _prefs?.getString(_themeKey) ?? 'system'; 
  }

  static Future<void> setThemeMode(String theme) async {
    await _prefs?.setString(_themeKey, theme);
  }


  static Future<void> init() async{
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getToken(){
    return _prefs.getString("jwt_token");
  }

  static Future<void> saveToken(String token) async {
    await _prefs.setString('jwt_token', token);
  }

  static Future<void> clear() async {
    await _prefs.clear();
  }
}