import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoRotate = false;
  String _defaultFit = 'contain';
  double _defaultSpeed = 1.0;
  int _seekInterval = 10;
  bool _autoResume = true;
  bool _saveThumbnails = true;
  bool _confirmBeforeDelete = true;
  ThemeMode get themeMode => _themeMode;
  bool get autoRotate => _autoRotate;
  String get defaultFit => _defaultFit;
  double get defaultSpeed => _defaultSpeed;
  int get seekInterval => _seekInterval;
  bool get autoResume => _autoResume;
  bool get saveThumbnails => _saveThumbnails;
  bool get confirmBeforeDelete => _confirmBeforeDelete;
  bool get fbCdnEnabled => true;
  Locale? get locale => const Locale('en');
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'system';
    _themeMode = theme == 'light'
        ? ThemeMode.light
        : theme == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
    _autoRotate = prefs.getBool('auto_rotate') ?? false;
    _defaultFit = prefs.getString('default_fit') ?? 'contain';
    _defaultSpeed = prefs.getDouble('default_speed') ?? 1.0;
    _seekInterval = prefs.getInt('seek_interval') ?? 10;
    _autoResume = prefs.getBool('auto_resume') ?? true;
    _saveThumbnails = prefs.getBool('save_thumbnails') ?? true;
    _confirmBeforeDelete = prefs.getBool('confirm_before_delete') ?? true;
  }
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme',
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
    notifyListeners();
  }
  Future<void> setAutoRotate(bool enabled) async {
    if (_autoRotate == enabled) return;
    _autoRotate = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_rotate', enabled);
    notifyListeners();
  }
  Future<void> setDefaultFit(String fit) async {
    if (_defaultFit == fit) return;
    _defaultFit = fit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_fit', fit);
    notifyListeners();
  }
  Future<void> setDefaultSpeed(double speed) async {
    if (_defaultSpeed == speed) return;
    _defaultSpeed = speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('default_speed', speed);
    notifyListeners();
  }
  Future<void> setSeekInterval(int seconds) async {
    if (_seekInterval == seconds) return;
    _seekInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seek_interval', seconds);
    notifyListeners();
  }
  Future<void> setAutoResume(bool enabled) async {
    if (_autoResume == enabled) return;
    _autoResume = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_resume', enabled);
    notifyListeners();
  }
  Future<void> setSaveThumbnails(bool enabled) async {
    if (_saveThumbnails == enabled) return;
    _saveThumbnails = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('save_thumbnails', enabled);
    notifyListeners();
  }
  Future<void> setConfirmBeforeDelete(bool enabled) async {
    if (_confirmBeforeDelete == enabled) return;
    _confirmBeforeDelete = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confirm_before_delete', enabled);
    notifyListeners();
  }
}
