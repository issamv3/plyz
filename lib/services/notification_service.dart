import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages system notifications for download progress.
/// Call [init] once at app startup (before runApp completes).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'ply_downloads';
  static const _channelName = 'Downloads';
  static const _notifId = 1;

  /// Fired when the user taps a "download complete" notification. Carries
  /// the downloaded file's path as the payload so the app can jump straight
  /// into playing it, even if the notification was tapped after the app was
  /// fully killed (cold start).
  static void Function(String filePath)? onOpenDownload;

  static String? _pendingFilePath;

  /// Consumes and returns the file path a cold-start launch was triggered
  /// by tapping a notification for, if any. Call once, right after `init`.
  static String? takePendingFilePath() {
    final path = _pendingFilePath;
    _pendingFilePath = null;
    return path;
  }

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          if (onOpenDownload != null) {
            onOpenDownload!(payload);
          } else {
            _pendingFilePath = payload;
          }
        }
      },
    );

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      _pendingFilePath = details.notificationResponse!.payload;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  static Future<bool?> requestPermission() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      return null;
    }
  }

  static Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
    int maxProgress = 100,
    bool indeterminate = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      indeterminate: indeterminate,
      ongoing: true,
      autoCancel: false,
    );
    await _plugin.show(
      _notifId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showComplete(String title, {String? filePath}) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
    );
    await _plugin.show(
      _notifId,
      title,
      'Download complete',
      NotificationDetails(android: androidDetails),
      payload: filePath,
    );
  }

  static Future<void> showError(String title, String error) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
    );
    await _plugin.show(
      _notifId,
      title,
      'Download failed: $error',
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancel() async {
    await _plugin.cancel(_notifId);
  }
}
