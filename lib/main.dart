import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'screens/player_screen.dart';
import 'screens/splash_screen.dart';
import 'services/dash_xml_sanitizer.dart';
import 'services/download_service.dart';
import 'services/facebook_auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
final navigatorKey = GlobalKey<NavigatorState>();
const _platform = MethodChannel('ply/media');
Completer<Map<String, dynamic>?>? _intentCompleter;
bool _intentHandled = false;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  await settings.init();
  await FacebookAuthService.instance.init();
  await NotificationService.init();
  await DownloadService.init();
  NotificationService.onOpenDownload = _openDownloadedVideo;
  _platform.setMethodCallHandler((call) async {
    if (call.method == 'onIntent') {
      final raw = call.arguments;
      if (raw is Map) {
        _intentHandled = false;
        await _processIntentData(Map<String, dynamic>.from(
            raw.map((k, v) => MapEntry(k.toString(), v))));
      }
    }
    return null;
  });
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: const PlyApp(),
    ),
  );
  final pendingPath = NotificationService.takePendingFilePath();
  if (pendingPath != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDownloadedVideo(pendingPath);
    });
  }
  _fetchInitialIntent();
}
void _fetchInitialIntent() {
  _intentCompleter = Completer<Map<String, dynamic>?>();
  _platform.invokeMethod<Map>('getInitialIntent').then((raw) {
    if (raw == null) {
      _intentCompleter!.complete(null);
    } else {
      final data = Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)));
      _intentCompleter!.complete(data);
    }
  }).catchError((_) {
    if (!(_intentCompleter!.isCompleted)) _intentCompleter!.complete(null);
  });
}
Future<void> handlePendingIntent() async {
  if (_intentHandled) return;
  _intentHandled = true;
  final data = await _intentCompleter?.future;
  if (data == null) return;
  await _processIntentData(data);
}
Future<void> _processIntentData(Map<String, dynamic> data) async {
  final uri = data['uri'] as String?;
  final mimeType = data['mimeType'] as String?;
  final displayName = data['displayName'] as String?;
  if (uri == null || uri.isEmpty) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final lowerUri = uri.toLowerCase();
  final isDash = mimeType == 'application/dash+xml' ||
      lowerUri.contains('.mpd');
  final title = _resolveTitle(uri, displayName);
  if (isDash) {
    String? mpdContent;
    if (uri.startsWith('content://') || uri.startsWith('file://')) {
      try {
        mpdContent = await _platform
            .invokeMethod<String>('readTextUri', {'uri': uri});
      } catch (_) {}
    } else if (uri.startsWith('http://') || uri.startsWith('https://')) {
      try {
        final resp = await http.get(Uri.parse(uri));
        if (resp.statusCode == 200) mpdContent = resp.body;
      } catch (_) {}
    }
    if (mpdContent == null) return;
    final sanitized = DashXmlSanitizer.sanitize(mpdContent);
    nav.push(CupertinoPageRoute(
      builder: (_) => PlayerScreen(
        title: title,
        videoPath: uri,
        isNetwork: true,
        isDash: true,
        mpdContent: sanitized,
      ),
    ));
  } else {
    String resolvedVideoPath = uri;
    if (uri.startsWith('content://')) {
      try {
        final realPath = await _platform
            .invokeMethod<String?>('resolveUriToFilePath', {'uri': uri});
        if (realPath != null && realPath.isNotEmpty) {
          resolvedVideoPath = realPath;
        }
      } catch (_) {}
    }
    final isNetwork = resolvedVideoPath.startsWith('http://') ||
        resolvedVideoPath.startsWith('https://');
    nav.push(CupertinoPageRoute(
      builder: (_) => PlayerScreen(
        title: title,
        videoPath: resolvedVideoPath,
        isNetwork: isNetwork,
        isDash: false,
      ),
    ));
  }
}
String _resolveTitle(String uri, String? displayName) {
  if (displayName != null && displayName.isNotEmpty) {
    final dot = displayName.lastIndexOf('.');
    return dot > 0 ? displayName.substring(0, dot) : displayName;
  }
  try {
    final decoded = Uri.decodeComponent(uri);
    final filename = decoded.split('/').last.split('?').first;
    final dot = filename.lastIndexOf('.');
    return dot > 0 ? filename.substring(0, dot) : filename;
  } catch (_) {
    return 'Video';
  }
}
void _openDownloadedVideo(String filePath) {
  if (!File(filePath).existsSync()) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(
    CupertinoPageRoute(
      builder: (_) => PlayerScreen(
        title: filePath.split('/').last,
        videoPath: filePath,
        isNetwork: false,
        isDash: false,
      ),
    ),
  );
}
class PlyApp extends StatelessWidget {
  const PlyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ply',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
