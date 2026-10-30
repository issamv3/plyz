import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FacebookAuthService extends ChangeNotifier {
  static final FacebookAuthService instance =
      FacebookAuthService._internal();
  FacebookAuthService._internal();

  static const MethodChannel _nativeChannel = MethodChannel('ply/media');

  static const String _keyCookie = 'fb_session_cookie';
  static const String _keyDtsg = 'fb_session_dtsg';
  static const String _keyUserId = 'fb_session_user_id';
  static const String _keyLastUpdated = 'fb_session_last_updated';

  String _cookie = '';
  String _fbDtsg = '';
  String _userId = '';
  DateTime? _lastUpdated;
  bool _initialized = false;

  String get cookie => _cookie;
  String get fbDtsg => _fbDtsg;
  String get userId => _userId;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasSession =>
      _cookie.isNotEmpty && (_userId.isNotEmpty || _cookie.contains('c_user='));
  bool get hasValidDtsg =>
      _fbDtsg.isNotEmpty &&
      !_fbDtsg.endsWith(':0:0') &&
      !_fbDtsg.endsWith(':0');

  String get dtsgSummary {
    if (_fbDtsg.isEmpty) return 'None';
    if (_fbDtsg.endsWith(':0:0') || _fbDtsg.endsWith(':0')) {
      return 'Guest Token (:0:0)';
    }
    final lastColon = _fbDtsg.lastIndexOf(':');
    if (lastColon > 0) {
      final prevColon = _fbDtsg.lastIndexOf(':', lastColon - 1);
      if (prevColon >= 0) {
        return 'Active (${_fbDtsg.substring(prevColon)})';
      }
      return 'Active (${_fbDtsg.substring(lastColon)})';
    }
    return 'Token (${_fbDtsg.length} chars)';
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString(_keyCookie) ?? '';
    _fbDtsg = prefs.getString(_keyDtsg) ?? '';
    _userId = prefs.getString(_keyUserId) ?? '';
    final lastUpdatedMs = prefs.getInt(_keyLastUpdated);
    if (lastUpdatedMs != null) {
      _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs);
    }
    if (_userId.isEmpty && _cookie.isNotEmpty) {
      _userId = extractCookieValue(_cookie, 'c_user') ?? '';
    }
    _initialized = true;
    await fetchAndSyncNativeCookies();
    notifyListeners();
  }

  Future<String> fetchAndSyncNativeCookies() async {
    try {
      final String? nativeCookies =
          await _nativeChannel.invokeMethod<String>('getCookies', {
        'url': 'https://m.facebook.com',
      });
      if (nativeCookies != null && nativeCookies.isNotEmpty) {
        final cUser = extractCookieValue(nativeCookies, 'c_user');
        if (cUser != null && cUser.isNotEmpty) {
          await saveSession(cookie: nativeCookies, userId: cUser);
        } else if (_cookie.isEmpty) {
          await saveSession(cookie: nativeCookies);
        }
        return _cookie;
      }
    } catch (_) {}
    return _cookie;
  }

  static String generateJazoest(String dtsg) {
    if (dtsg.isEmpty) return '25318';
    int sum = 0;
    for (int i = 0; i < dtsg.length; i++) {
      sum += dtsg.codeUnitAt(i);
    }
    return '2$sum';
  }

  static String? extractCookieValue(String cookieString, String name) {
    final parts = cookieString.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$name=')) {
        return trimmed.substring(name.length + 1);
      }
    }
    return null;
  }

  Future<void> overwriteSession({
    required String cookie,
    String? fbDtsg,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = cookie.trim();
    await prefs.setString(_keyCookie, _cookie);

    if (fbDtsg != null && fbDtsg.trim().isNotEmpty) {
      _fbDtsg = fbDtsg.trim();
      await prefs.setString(_keyDtsg, _fbDtsg);
    }

    final extractedUid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : (extractCookieValue(_cookie, 'c_user') ?? '');
    _userId = extractedUid;
    await prefs.setString(_keyUserId, _userId);

    _lastUpdated = DateTime.now();
    await prefs.setInt(_keyLastUpdated, _lastUpdated!.millisecondsSinceEpoch);

    await syncCookiesToNativeAndWebView(_cookie, clearExisting: false);
    notifyListeners();
  }

  Future<void> syncCookiesToNativeAndWebView(
    String cookieString, {
    bool clearExisting = false,
  }) async {
    if (cookieString.isEmpty) return;
    try {
      await _nativeChannel.invokeMethod('setCookies', {
        'url': 'https://m.facebook.com',
        'cookies': cookieString,
        'clearExisting': clearExisting,
      });
    } catch (_) {}

    try {
      final cookieManager = WebViewCookieManager();
      if (clearExisting) {
        await cookieManager.clearCookies();
      }
      final parts = cookieString.split(';');
      for (final part in parts) {
        final pair = part.trim();
        final eqIdx = pair.indexOf('=');
        if (eqIdx > 0) {
          final key = pair.substring(0, eqIdx).trim();
          final value = pair.substring(eqIdx + 1).trim();
          final lowerK = key.toLowerCase();
          if (lowerK != 'expires' &&
              lowerK != 'path' &&
              lowerK != 'domain' &&
              lowerK != 'max-age' &&
              lowerK != 'samesite' &&
              lowerK != 'secure' &&
              lowerK != 'httponly' &&
              key.isNotEmpty) {
            for (final domain in [
              '.facebook.com',
              'm.facebook.com',
              'facebook.com',
              'www.facebook.com'
            ]) {
              await cookieManager.setCookie(
                WebViewCookie(
                  name: key,
                  value: value,
                  domain: domain,
                  path: '/',
                ),
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> saveSession({
    String? cookie,
    String? fbDtsg,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (cookie != null && cookie.isNotEmpty) {
      _cookie = _mergeCookies(_cookie, cookie);
      await prefs.setString(_keyCookie, _cookie);
    }
    if (fbDtsg != null &&
        fbDtsg.isNotEmpty &&
        fbDtsg != 'null' &&
        fbDtsg != 'undefined') {
      final isNewGuest = fbDtsg.endsWith(':0:0') || fbDtsg.endsWith(':0');
      final isCurrentGuest = _fbDtsg.endsWith(':0:0') || _fbDtsg.endsWith(':0');
      if (!isNewGuest || isCurrentGuest || _fbDtsg.isEmpty) {
        _fbDtsg = fbDtsg;
        await prefs.setString(_keyDtsg, _fbDtsg);
      }
    }
    final extractedUid =
        (userId != null && userId.isNotEmpty && userId != 'null')
            ? userId
            : extractCookieValue(_cookie, 'c_user');
    if (extractedUid != null &&
        extractedUid.isNotEmpty &&
        extractedUid != 'null') {
      _userId = extractedUid;
      await prefs.setString(_keyUserId, _userId);
    }
    _lastUpdated = DateTime.now();
    await prefs.setInt(_keyLastUpdated, _lastUpdated!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> updateFromResponseHeaders(Map<String, String> headers) async {
    final setCookie = headers['set-cookie'] ?? headers['Set-Cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      await saveSession(cookie: setCookie);
    }
  }

  Future<void> clearSession() async {
    _cookie = '';
    _fbDtsg = '';
    _userId = '';
    _lastUpdated = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCookie);
    await prefs.remove(_keyDtsg);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyLastUpdated);
    try {
      await _nativeChannel.invokeMethod('clearCookies');
    } catch (_) {}
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {}
    notifyListeners();
  }

  static String _mergeCookies(String oldCookie, String newCookie) {
    if (oldCookie.isEmpty) return newCookie;
    if (newCookie.isEmpty) return oldCookie;
    final Map<String, String> map = {};
    void parseInto(String str) {
      final items = str.split(';');
      for (final item in items) {
        final pair = item.trim();
        final eqIdx = pair.indexOf('=');
        if (eqIdx > 0) {
          final k = pair.substring(0, eqIdx).trim();
          final v = pair.substring(eqIdx + 1).trim();
          final lowerK = k.toLowerCase();
          if (lowerK != 'expires' &&
              lowerK != 'path' &&
              lowerK != 'domain' &&
              lowerK != 'max-age' &&
              lowerK != 'samesite' &&
              lowerK != 'secure' &&
              lowerK != 'httponly') {
            map[k] = v;
          }
        }
      }
    }
    parseInto(oldCookie);
    parseInto(newCookie);
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}
