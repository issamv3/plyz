/// A single completed download, persisted locally so the Downloads screen
/// can list previously downloaded videos (title, duration, thumbnail)
/// without re-scanning the filesystem or the gallery.
class DownloadRecord {
  final String id;
  final String title;
  final String filePath;
  final int durationMs;
  final String? thumbnailPath;
  final bool isDash;
  final int downloadedAtMs;

  const DownloadRecord({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationMs,
    this.thumbnailPath,
    required this.isDash,
    required this.downloadedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'durationMs': durationMs,
        'thumbnailPath': thumbnailPath,
        'isDash': isDash,
        'downloadedAtMs': downloadedAtMs,
      };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        filePath: json['filePath'] as String? ?? '',
        durationMs: json['durationMs'] as int? ?? 0,
        thumbnailPath: json['thumbnailPath'] as String?,
        isDash: json['isDash'] as bool? ?? false,
        downloadedAtMs: json['downloadedAtMs'] as int? ?? 0,
      );
}
