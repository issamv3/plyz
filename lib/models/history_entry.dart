class HistoryEntry {
  final String key;
  final String title;
  final String videoPath;
  final bool isNetwork;
  final bool isDash;
  final bool fbCdnEnabled;
  final String? mpdContent;
  final int positionMs;
  final int durationMs;
  final int lastWatchedAtMs;
  final String? thumbnailPath;
  final String? originalFbUrl;
  final String? fbVideoId;
  const HistoryEntry({
    required this.key,
    required this.title,
    required this.videoPath,
    required this.isNetwork,
    required this.isDash,
    required this.fbCdnEnabled,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatchedAtMs,
    this.mpdContent,
    this.thumbnailPath,
    this.originalFbUrl,
    this.fbVideoId,
  });
  double get progress =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
  bool get isFinished => progress > 0.96;
  bool get isFacebook {
    if (originalFbUrl != null && originalFbUrl!.isNotEmpty) {
      final u = originalFbUrl!.toLowerCase();
      if (u.contains('facebook.com') ||
          u.contains('fb.watch') ||
          u.contains('fb.me') ||
          u.contains('fb.gg')) {
        return true;
      }
    }
    final path = videoPath.toLowerCase();
    if (path.contains('facebook.com') ||
        path.contains('fb.watch') ||
        path.contains('fb.me') ||
        path.contains('fb.gg')) {
      return true;
    }
    return false;
  }
  bool get isDownloaded =>
      !isNetwork ||
      videoPath.startsWith('/') ||
      videoPath.startsWith('file://') ||
      videoPath.startsWith('content://');
  HistoryEntry copyWith({
    String? title,
    int? positionMs,
    int? durationMs,
    int? lastWatchedAtMs,
    String? thumbnailPath,
    String? originalFbUrl,
    String? fbVideoId,
    String? mpdContent,
  }) {
    return HistoryEntry(
      key: key,
      title: title ?? this.title,
      videoPath: videoPath,
      isNetwork: isNetwork,
      isDash: isDash,
      fbCdnEnabled: fbCdnEnabled,
      mpdContent: mpdContent ?? this.mpdContent,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastWatchedAtMs: lastWatchedAtMs ?? this.lastWatchedAtMs,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      originalFbUrl: originalFbUrl ?? this.originalFbUrl,
      fbVideoId: fbVideoId ?? this.fbVideoId,
    );
  }
  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'videoPath': videoPath,
        'isNetwork': isNetwork,
        'isDash': isDash,
        'fbCdnEnabled': fbCdnEnabled,
        'mpdContent': mpdContent,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'lastWatchedAtMs': lastWatchedAtMs,
        'thumbnailPath': thumbnailPath,
        'originalFbUrl': originalFbUrl,
        'fbVideoId': fbVideoId,
      };
  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        key: json['key'] as String,
        title: json['title'] as String? ?? 'Video',
        videoPath: json['videoPath'] as String? ?? '',
        isNetwork: json['isNetwork'] as bool? ?? true,
        isDash: json['isDash'] as bool? ?? false,
        fbCdnEnabled: json['fbCdnEnabled'] as bool? ?? false,
        mpdContent: json['mpdContent'] as String?,
        positionMs: json['positionMs'] as int? ?? 0,
        durationMs: json['durationMs'] as int? ?? 0,
        lastWatchedAtMs: json['lastWatchedAtMs'] as int? ?? 0,
        thumbnailPath: json['thumbnailPath'] as String?,
        originalFbUrl: json['originalFbUrl'] as String?,
        fbVideoId: json['fbVideoId'] as String?,
      );
}
