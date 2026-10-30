import 'dart:async';
import 'package:http/http.dart' as http;

class CdnService {
  static const List<String> candidateHosts = [
    'z-m-video-mxp.xx.fbcdn.net',
    'z-m-video-mia.xx.fbcdn.net',
    'z-m-video-mad.xx.fbcdn.net',
    'z-m-video-cph2-1.xx.fbcdn.net',
    'z-m-video-cdg4-2.xx.fbcdn.net',
    'z-m-video.xx.fbcdn.net',
    'z-m-video-ams.xx.fbcdn.net',
    'z-m-video-fra.xx.fbcdn.net',
    'z-m-video-lhr.xx.fbcdn.net',
  ];

  static const _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static String _activeFastestHost = candidateHosts.first;
  static DateTime? _lastRacedTime;
  static Future<String>? _ongoingRace;

  static String get currentHost => _activeFastestHost;

  static Future<String> getFastestHost({
    String? sampleUrl,
    bool force = true,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!force &&
        _lastRacedTime != null &&
        DateTime.now().difference(_lastRacedTime!) < const Duration(minutes: 5)) {
      return _activeFastestHost;
    }

    if (_ongoingRace != null) {
      return _ongoingRace!;
    }

    final completer = Completer<String>();
    _ongoingRace = completer.future;

    unawaited(_executeRace(sampleUrl, timeout).then((winner) {
      _activeFastestHost = winner;
      _lastRacedTime = DateTime.now();
      if (!completer.isCompleted) completer.complete(winner);
      _ongoingRace = null;
    }).catchError((_) {
      if (!completer.isCompleted) completer.complete(_activeFastestHost);
      _ongoingRace = null;
    }));

    return completer.future;
  }

  static Future<String> _executeRace(
    String? sampleUrl,
    Duration timeout,
  ) async {
    final completer = Completer<String>();
    final clients = <http.Client>[];
    var completedCount = 0;

    String cleanSample = '';
    if (sampleUrl != null && sampleUrl.isNotEmpty) {
      cleanSample = sampleUrl.replaceAll('&amp;', '&').trim();
    }

    String testPath = '';
    String? originalHost;
    if (cleanSample.isNotEmpty) {
      try {
        final uri = Uri.parse(cleanSample);
        testPath = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
        if (uri.host.isNotEmpty && uri.host.contains('fbcdn.net')) {
          originalHost = uri.host;
        }
      } catch (_) {}
    }

    final testHosts = <String>[];
    if (originalHost != null && !testHosts.contains(originalHost)) {
      testHosts.add(originalHost);
    }
    for (final h in candidateHosts) {
      if (!testHosts.contains(h)) {
        testHosts.add(h);
      }
    }

    String? fallbackHost;

    for (final host in testHosts) {
      final client = http.Client();
      clients.add(client);

      final uri = Uri.parse(
        testPath.isNotEmpty ? 'https://$host$testPath' : 'https://$host/',
      );

      final headers = {
        'User-Agent': _browserUserAgent,
        'Referer': 'https://m.facebook.com/',
        'Origin': 'https://m.facebook.com',
        if (testPath.isNotEmpty) 'Range': 'bytes=0-1024',
      };

      () async {
        try {
          final req = http.Request(testPath.isNotEmpty ? 'GET' : 'HEAD', uri)
            ..headers.addAll(headers)
            ..followRedirects = false;

          final streamedResponse = await client.send(req).timeout(timeout);
          final status = streamedResponse.statusCode;

          if (status >= 200 && status < 400) {
            if (!completer.isCompleted) {
              completer.complete(host);
            }
          } else if (status < 500 && fallbackHost == null) {
            fallbackHost = host;
          }
        } catch (_) {
        } finally {
          completedCount++;
          if (completedCount >= testHosts.length && !completer.isCompleted) {
            completer.complete(fallbackHost ?? originalHost ?? candidateHosts.first);
          }
        }
      }();
    }

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(fallbackHost ?? _activeFastestHost);
      }
    });

    final winner = await completer.future;
    timer.cancel();

    for (final c in clients) {
      try {
        c.close();
      } catch (_) {}
    }

    return winner;
  }

  static String rewriteMpdContent(
    String xmlContent, {
    bool fbCdnEnabled = true,
    String? preferredHost,
  }) {
    if (!xmlContent.contains('fbcdn.net')) return xmlContent;
    final host = preferredHost ?? _activeFastestHost;
    return xmlContent.replaceAllMapped(
      RegExp(r'https?://[a-zA-Z0-9\-\.]*fbcdn\.net'),
      (_) => 'https://$host',
    );
  }

  static Future<String> raceAndRewriteMpd(
    String xmlContent, {
    bool fbCdnEnabled = true,
    bool force = true,
  }) async {
    if (!xmlContent.contains('fbcdn.net')) return xmlContent;

    String? sampleUrl;
    final match =
        RegExp(r'''https?://[a-zA-Z0-9\-\.]*fbcdn\.net/[^\s"'<>]+''')
            .firstMatch(xmlContent);
    if (match != null) {
      sampleUrl = match.group(0);
    }

    final fastest = await getFastestHost(sampleUrl: sampleUrl, force: force);
    return rewriteMpdContent(
      xmlContent,
      fbCdnEnabled: true,
      preferredHost: fastest,
    );
  }

  static String rewrite(
    String url, {
    bool fbCdnEnabled = true,
    String? preferredHost,
  }) {
    if (!url.contains('fbcdn.net')) return url;
    try {
      final uri = Uri.parse(url);
      final host = preferredHost ?? _activeFastestHost;
      final rewritten = uri.replace(host: host);
      return rewritten.toString();
    } catch (_) {
      return url;
    }
  }

  static Future<String> raceAndRewrite(
    String url, {
    bool fbCdnEnabled = true,
    bool force = true,
  }) async {
    if (!url.contains('fbcdn.net')) return url;
    final fastest = await getFastestHost(sampleUrl: url, force: force);
    return rewrite(url, fbCdnEnabled: true, preferredHost: fastest);
  }

  static bool isFacebookCdn(String url) =>
      url.contains('fbcdn.net') || url.contains('facebook.com');

  static Map<String, String> headersFor(String url) {
    if (!isFacebookCdn(url)) return const {};
    return {
      'User-Agent': _browserUserAgent,
      'Referer': 'https://m.facebook.com/',
      'Origin': 'https://m.facebook.com',
    };
  }
}

