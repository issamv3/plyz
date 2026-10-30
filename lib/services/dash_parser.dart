import 'package:xml/xml.dart';
import '../models/dash_representation.dart';

class DashParser {
  static final RegExp _rootTitlePattern =
      RegExp(r'<Title\b[^>]*>([\s\S]*?)<\/Title>', caseSensitive: false);

  static List<DashRepresentation> parse(String xmlContent) {
    return _parseByType(xmlContent, 'video');
  }

  /// Extracts audio representations (used by the downloader to find a track
  /// to mux with the chosen video representation — DASH manifests usually
  /// split audio and video into separate AdaptationSets/BaseURLs).
  static List<DashRepresentation> parseAudio(String xmlContent) {
    return _parseByType(xmlContent, 'audio');
  }

  /// Convenience accessor for the download flow: highest-bitrate audio
  /// track, or null if the manifest has no separate audio representation.
  static DashRepresentation? bestAudio(String xmlContent) {
    final reps = parseAudio(xmlContent);
    return reps.isEmpty ? null : reps.first;
  }

  static List<DashRepresentation> _parseByType(
      String xmlContent, String wantedType) {
    final representations = <DashRepresentation>[];
    try {
      final document = XmlDocument.parse(xmlContent);
      for (final period in document.findAllElements('Period')) {
        for (final adaptationSet in period.findElements('AdaptationSet')) {
          final contentType = _resolveContentType(adaptationSet);
          if (contentType != wantedType) continue;

          final setBaseUrl = _extractBaseUrl(adaptationSet);

          for (final rep in adaptationSet.findElements('Representation')) {
            final id = rep.getAttribute('id') ?? '';
            final bandwidth =
                int.tryParse(rep.getAttribute('bandwidth') ?? '0') ?? 0;
            final width =
                int.tryParse(rep.getAttribute('width') ?? '0') ?? 0;
            final height =
                int.tryParse(rep.getAttribute('height') ?? '0') ?? 0;

            final rawLabel = wantedType == 'video'
                ? (rep.getAttribute('FBQualityLabel') ??
                    rep.getAttribute('qualityLabel') ??
                    (height > 0 ? '${height}p' : '${bandwidth ~/ 1000}kbps'))
                : (rep.getAttribute('audioSamplingRate') != null
                    ? '${rep.getAttribute('audioSamplingRate')} Hz'
                    : 'Audio');

            final repBaseUrl = _extractBaseUrl(rep);
            final baseUrl =
                repBaseUrl.isNotEmpty ? repBaseUrl : setBaseUrl;

            if (baseUrl.isNotEmpty) {
              representations.add(DashRepresentation(
                id: id,
                baseUrl: baseUrl,
                bandwidth: bandwidth,
                width: width,
                height: height,
                contentType: wantedType,
                qualityLabel: rawLabel,
              ));
            }
          }
        }
      }
      representations.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    } catch (_) {}
    return representations;
  }

  /// Extracts `ProgramInformation/Title` (or any top-level `Title`) from the
  /// MPD, if present, so the app can use the manifest's own title instead of
  /// asking the user to type one.
  static String? extractTitle(String xmlContent) {
    final regexMatch = _rootTitlePattern.firstMatch(xmlContent);
    if (regexMatch != null) {
      final title = regexMatch.group(1)?.trim();
      if (title != null && title.isNotEmpty) return title;
    }
    try {
      final doc = XmlDocument.parse(xmlContent);
      final titleEl = doc.findAllElements('Title').firstOrNull;
      if (titleEl != null && titleEl.innerText.trim().isNotEmpty) {
        return titleEl.innerText.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Removes any `<Title>` element from the manifest (after its text has
  /// already been read via [extractTitle]). Some manifests place `Title`
  /// outside the strict DASH schema position ExoPlayer's parser expects,
  /// which breaks parsing — so the tag must not reach the player.
  static String stripTitle(String xmlContent) {
    final preStripped = xmlContent.replaceAll(_rootTitlePattern, '');
    try {
      final doc = XmlDocument.parse(preStripped);
      for (final titleEl in doc.findAllElements('Title').toList()) {
        titleEl.parent?.children.remove(titleEl);
      }
      return doc.toXmlString();
    } catch (_) {
      return preStripped;
    }
  }

  static String generateSubMpd(String originalXml, String videoRepId) {
    try {
      final doc = XmlDocument.parse(originalXml);
      for (final adaptationSet in doc.findAllElements('AdaptationSet')) {
        final contentType = _resolveContentType(adaptationSet);
        if (contentType != 'video') continue;

        final toRemove = adaptationSet
            .findElements('Representation')
            .where((rep) => rep.getAttribute('id') != videoRepId)
            .toList();

        for (final rep in toRemove) {
          rep.parent?.children.remove(rep);
        }
      }
      return doc.toXmlString();
    } catch (_) {
      return originalXml;
    }
  }

  static String _resolveContentType(XmlElement el) {
    final direct = el.getAttribute('contentType');
    if (direct != null && direct.isNotEmpty) return direct;

    final mime = el.getAttribute('mimeType') ?? '';
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('audio/')) return 'audio';

    for (final child in el.children.whereType<XmlElement>()) {
      final childMime = child.getAttribute('mimeType') ?? '';
      if (childMime.startsWith('video/')) return 'video';
      if (childMime.startsWith('audio/')) return 'audio';
    }
    return '';
  }

  static String _extractBaseUrl(XmlElement el) {
    final nodes = el.findElements('BaseURL');
    if (nodes.isEmpty) return '';
    return nodes.first.innerText.trim();
  }
}
