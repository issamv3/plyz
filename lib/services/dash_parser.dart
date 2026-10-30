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
      final adaptationSets = document.findAllElements('AdaptationSet').toList();

      for (final adaptationSet in adaptationSets) {
        final setContentType = _resolveContentType(adaptationSet);
        final setBaseUrl = _extractBaseUrl(adaptationSet);

        for (final rep in adaptationSet.findElements('Representation')) {
          final repContentType = _resolveContentType(rep);
          final effectiveType = repContentType.isNotEmpty
              ? repContentType
              : setContentType;

          if (effectiveType != wantedType) continue;

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
    final direct = el.getAttribute('contentType')?.toLowerCase();
    if (direct == 'video' || direct == 'audio') return direct!;

    final mime = (el.getAttribute('mimeType') ?? '').toLowerCase();
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('audio/')) return 'audio';

    final codecs = (el.getAttribute('codecs') ?? '').toLowerCase();
    if (codecs.startsWith('avc') ||
        codecs.startsWith('mp4v') ||
        codecs.startsWith('hvc') ||
        codecs.startsWith('hev') ||
        codecs.startsWith('vp8') ||
        codecs.startsWith('vp9') ||
        codecs.startsWith('av01')) {
      return 'video';
    }
    if (codecs.startsWith('mp4a') ||
        codecs.startsWith('opus') ||
        codecs.startsWith('aac') ||
        codecs.contains('audio')) {
      return 'audio';
    }

    if (el.getAttribute('audioSamplingRate') != null ||
        el.findAllElements('AudioChannelConfiguration').isNotEmpty) {
      return 'audio';
    }

    final width = int.tryParse(el.getAttribute('width') ?? '0') ?? 0;
    final height = int.tryParse(el.getAttribute('height') ?? '0') ?? 0;
    if (width > 0 || height > 0 || el.getAttribute('frameRate') != null) {
      return 'video';
    }

    for (final child in el.children.whereType<XmlElement>()) {
      final childType = _resolveContentType(child);
      if (childType.isNotEmpty) return childType;
    }
    return '';
  }

  static String _extractBaseUrl(XmlElement el) {
    final nodes = el.findElements('BaseURL');
    if (nodes.isNotEmpty && nodes.first.innerText.trim().isNotEmpty) {
      return nodes.first.innerText.trim().replaceAll('&amp;', '&');
    }
    final allBaseUrls = el.findAllElements('BaseURL');
    if (allBaseUrls.isNotEmpty && allBaseUrls.first.innerText.trim().isNotEmpty) {
      return allBaseUrls.first.innerText.trim().replaceAll('&amp;', '&');
    }
    return '';
  }
}
