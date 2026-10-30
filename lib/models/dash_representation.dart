class DashRepresentation {
  final String id;
  final String baseUrl;
  final int bandwidth;
  final int width;
  final int height;
  final String contentType;
  final String qualityLabel;
  const DashRepresentation({
    required this.id,
    required this.baseUrl,
    required this.bandwidth,
    required this.width,
    required this.height,
    required this.contentType,
    required this.qualityLabel,
  });
  String get bitrateLabel {
    if (bandwidth < 1000000) {
      return '${(bandwidth / 1000).toStringAsFixed(0)} kbps';
    }
    return '${(bandwidth / 1000000).toStringAsFixed(1)} Mbps';
  }
  String get fullLabel => '$qualityLabel  ($bitrateLabel)';
  Map<String, dynamic> toJson() => {
        'id': id,
        'baseUrl': baseUrl,
        'bandwidth': bandwidth,
        'width': width,
        'height': height,
        'contentType': contentType,
        'qualityLabel': qualityLabel,
      };
  factory DashRepresentation.fromJson(Map<String, dynamic> json) =>
      DashRepresentation(
        id: json['id'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        bandwidth: json['bandwidth'] as int? ?? 0,
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
        contentType: json['contentType'] as String? ?? 'video',
        qualityLabel: json['qualityLabel'] as String? ?? '',
      );
}
