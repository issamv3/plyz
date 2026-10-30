import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dash_xml_sanitizer.dart';
import 'facebook_auth_service.dart';

class FacebookVideoResult {
  final String videoId;
  final String title;
  final String dashManifest;

  FacebookVideoResult({
    required this.videoId,
    required this.title,
    required this.dashManifest,
  });
}

class FacebookExtractorService {
  static final FacebookExtractorService instance =
      FacebookExtractorService._internal();
  FacebookExtractorService._internal();

  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const String unifiedVideoDocId = '27929861826665845';

  bool isFacebookUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    try {
      final uri = Uri.parse(lower);
      final host = uri.host;
      return host.contains('facebook.com') ||
          host.contains('fb.watch') ||
          host.contains('fb.me') ||
          host.contains('fb.gg');
    } catch (_) {
      return false;
    }
  }

  bool isMpdUrl(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.mpd') ||
        clean.contains('dash') ||
        clean.contains('manifest');
  }

  Future<String> fetchMpdContent(
    String url, {
    Map<String, String>? headers,
  }) async {
    final reqHeaders = <String, String>{
      'User-Agent': mobileUserAgent,
      if (headers != null) ...headers,
    };
    final response = await http
        .get(Uri.parse(url), headers: reqHeaders)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return DashXmlSanitizer.sanitize(response.body);
    }
    throw Exception('HTTP error ${response.statusCode} while fetching MPD');
  }

  Map<String, String>? extractGroupPermalink(String url) {
    final clean = url.trim().replaceAll('&amp;', '&');
    final match =
        RegExp(r'/groups/([^/]+)/(?:permalink|posts)/(\d+)').firstMatch(clean);
    if (match != null && match.groupCount >= 2) {
      return {
        'groupId': match.group(1)!,
        'postId': match.group(2)!,
      };
    }
    return null;
  }

  Future<String?> resolveGroupPermalinkVideoId(
    String url,
    String cookie,
  ) async {
    final permalink = extractGroupPermalink(url);
    if (permalink == null) return null;
    try {
      final targetUrl =
          'https://m.facebook.com/groups/${permalink['groupId']}/permalink/${permalink['postId']}/';
      final headers = {
        'authority': 'm.facebook.com',
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'accept-language':
            'en-US,en;q=0.9,ar-EG;q=0.8,ar;q=0.7,fr-FR;q=0.6,fr;q=0.5',
        if (cookie.isNotEmpty) 'Cookie': cookie,
        'sec-ch-prefers-color-scheme': 'light',
        'sec-ch-ua': '"Not-A.Brand";v="99", "Chromium";v="124"',
        'sec-ch-ua-full-version-list':
            '"Not-A.Brand";v="99.0.0.0", "Chromium";v="124.0.6327.4"',
        'sec-ch-ua-mobile': '?1',
        'sec-ch-ua-model': '"WIKO T10"',
        'sec-ch-ua-platform': '"Android"',
        'sec-ch-ua-platform-version': '"11.0.0"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
        'user-agent': mobileUserAgent,
        'viewport-width': '980'
      };

      final response = await http
          .get(Uri.parse(targetUrl), headers: headers)
          .timeout(const Duration(seconds: 20));
      await FacebookAuthService.instance
          .updateFromResponseHeaders(response.headers);
      final body = response.body;

      final dtsgMatch = RegExp(r'name="fb_dtsg" value="([^"]+)"').firstMatch(body) ??
          RegExp(r'"DTSGInitialData",\[\],\{"token":"([^"]+)"\}').firstMatch(body) ??
          RegExp(r'"token":"(NA[a-zA-Z0-9_\-:]+)"').firstMatch(body) ??
          RegExp(r'"dtsg_token":"([^"]+)"').firstMatch(body);
      if (dtsgMatch != null && dtsgMatch.group(1) != null) {
        final tok = dtsgMatch.group(1)!;
        if (!tok.endsWith(':0:0') && !tok.endsWith(':0')) {
          await FacebookAuthService.instance.saveSession(fbDtsg: tok);
        }
      }

      final dataVideoMatch = RegExp(r'data-video-id=["\x27](\d+)["\x27]').firstMatch(body);
      if (dataVideoMatch != null && dataVideoMatch.group(1) != null) {
        return dataVideoMatch.group(1);
      }

      final bodyMatch = RegExp(r'"(?:reel|video)_id"\s*:\s*"(\d+)"').firstMatch(body);
      if (bodyMatch != null && bodyMatch.group(1) != null) {
        return bodyMatch.group(1);
      }

      final targetMatch = RegExp(r'"target_id"\s*:\s*"(\d+)"').firstMatch(body);
      if (targetMatch != null && targetMatch.group(1) != null) {
        return targetMatch.group(1);
      }

      final videoUrlMatch = RegExp(r'/videos/(\d+)').firstMatch(body);
      if (videoUrlMatch != null && videoUrlMatch.group(1) != null) {
        return videoUrlMatch.group(1);
      }

      final reelUrlMatch = RegExp(r'/reel/(\d+)').firstMatch(body);
      if (reelUrlMatch != null && reelUrlMatch.group(1) != null) {
        return reelUrlMatch.group(1);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> resolveVideoIdFromHtmlOrPage(
    String pageUrl,
    String cookie,
  ) async {
    try {
      final cleanUrl = pageUrl.trim();
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null) return null;

      final mUrl = cleanUrl
          .replaceAll('www.facebook.com', 'm.facebook.com')
          .replaceAll('mbasic.facebook.com', 'm.facebook.com')
          .replaceAll('touch.facebook.com', 'm.facebook.com');

      final headers = {
        'authority': 'm.facebook.com',
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'accept-language':
            'en-US,en;q=0.9,ar-EG;q=0.8,ar;q=0.7,fr-FR;q=0.6,fr;q=0.5',
        if (cookie.isNotEmpty) 'Cookie': cookie,
        'user-agent': mobileUserAgent,
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'upgrade-insecure-requests': '1',
      };

      final response =
          await http.get(Uri.parse(mUrl), headers: headers).timeout(const Duration(seconds: 20));

      await FacebookAuthService.instance.updateFromResponseHeaders(response.headers);
      final body = response.body;

      final dtsgMatch = RegExp(r'name="fb_dtsg" value="([^"]+)"').firstMatch(body) ??
          RegExp(r'"DTSGInitialData",\[\],\{"token":"([^"]+)"\}').firstMatch(body) ??
          RegExp(r'"token":"(NA[a-zA-Z0-9_\-:]+)"').firstMatch(body) ??
          RegExp(r'"dtsg_token":"([^"]+)"').firstMatch(body);
      if (dtsgMatch != null && dtsgMatch.group(1) != null) {
        final tok = dtsgMatch.group(1)!;
        if (!tok.endsWith(':0:0') && !tok.endsWith(':0')) {
          await FacebookAuthService.instance.saveSession(fbDtsg: tok);
        }
      }

      final dataVideoMatch = RegExp(r'data-video-id=["\x27](\d+)["\x27]').firstMatch(body);
      if (dataVideoMatch != null && dataVideoMatch.group(1) != null) {
        return dataVideoMatch.group(1);
      }

      final bodyMatch = RegExp(r'"(?:reel|video)_id"\s*:\s*"(\d+)"').firstMatch(body);
      if (bodyMatch != null && bodyMatch.group(1) != null) {
        return bodyMatch.group(1);
      }

      final extracted = _extractUrlOrIdFromHtml(body);
      if (extracted != null && extracted.isNotEmpty) {
        final id = extractFacebookVideoId(extracted);
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }

      final videoIdMatch = RegExp(r'"target_id"\s*:\s*"(\d+)"').firstMatch(body) ??
          RegExp(r'"entity_id"\s*:\s*"(\d+)"').firstMatch(body) ??
          RegExp(r'"story_fbid"\s*:\s*"(\d+)"').firstMatch(body) ??
          RegExp(r'"post_id"\s*:\s*"(\d+)"').firstMatch(body) ??
          RegExp(r'/videos/(\d+)').firstMatch(body) ??
          RegExp(r'/reel/(\d+)').firstMatch(body);
      if (videoIdMatch != null && videoIdMatch.group(1) != null) {
        return videoIdMatch.group(1);
      }
    } catch (_) {}
    return null;
  }

  Future<String> resolveFacebookUrl(String url) async {
    final clean = url.trim();
    if (!clean.contains('/share/') &&
        !clean.contains('fb.watch') &&
        !clean.contains('fb.me') &&
        !clean.contains('fb.gg')) {
      return clean;
    }

    final quickResolved = await _resolveRedirectsFast(clean);
    if (quickResolved != null &&
        quickResolved.isNotEmpty &&
        !quickResolved.contains('/share/')) {
      return quickResolved;
    }

    final auth = FacebookAuthService.instance;
    final cookie = auth.cookie;

    final resolvedMobile =
        await _resolveUrlWithAgent(clean, mobileUserAgent, cookie);
    if (resolvedMobile != null && resolvedMobile.isNotEmpty) {
      return resolvedMobile;
    }

    final resolvedDesktop =
        await _resolveUrlWithAgent(clean, desktopUserAgent, cookie);
    if (resolvedDesktop != null && resolvedDesktop.isNotEmpty) {
      return resolvedDesktop;
    }

    return clean;
  }

  Future<String?> _resolveRedirectsFast(String startUrl) async {
    String currentUrl = startUrl;
    final userAgents = [
      'curl/8.5.0',
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
    ];

    for (final ua in userAgents) {
      currentUrl = startUrl;
      int redirects = 0;
      while (redirects < 8) {
        final uri = Uri.tryParse(currentUrl);
        if (uri == null) break;

        try {
          final client = http.Client();
          final request = http.Request('HEAD', uri)
            ..followRedirects = false
            ..headers.addAll({
              'User-Agent': ua,
              'Accept': '*/*',
            });

          http.StreamedResponse res;
          try {
            res = await client.send(request).timeout(const Duration(seconds: 8));
          } catch (_) {
            final getReq = http.Request('GET', uri)
              ..followRedirects = false
              ..headers.addAll({
                'User-Agent': ua,
                'Accept': '*/*',
              });
            res = await client.send(getReq).timeout(const Duration(seconds: 8));
          }

          final statusCode = res.statusCode;
          final location = res.headers['location'];
          client.close();

          if (statusCode >= 300 &&
              statusCode < 400 &&
              location != null &&
              location.isNotEmpty) {
            final nextUri = Uri.tryParse(location);
            if (nextUri != null) {
              currentUrl = nextUri.hasScheme
                  ? location
                  : uri.resolve(location).toString();
            }
            redirects++;
            if (!currentUrl.contains('/share/') &&
                !currentUrl.contains('fb.watch')) {
              return currentUrl;
            }
            continue;
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }

      if (!currentUrl.contains('/share/') &&
          !currentUrl.contains('fb.watch') &&
          currentUrl != startUrl) {
        return currentUrl;
      }
    }

    return (currentUrl != startUrl) ? currentUrl : null;
  }

  Future<String?> _resolveUrlWithAgent(
    String startUrl,
    String userAgent,
    String cookie,
  ) async {
    String currentUrl = startUrl;
    int redirectCount = 0;
    final client = http.Client();
    try {
      while (redirectCount < 10) {
        final uri = Uri.tryParse(currentUrl);
        if (uri == null) break;

        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers.addAll({
            'User-Agent': userAgent,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'Accept-Language':
                'en-US,en;q=0.9,ar-EG;q=0.8,ar;q=0.7,fr-FR;q=0.6,fr;q=0.5',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Upgrade-Insecure-Requests': '1',
            if (cookie.isNotEmpty) 'Cookie': cookie,
          });

        final streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 20));
        await FacebookAuthService.instance
            .updateFromResponseHeaders(streamedResponse.headers);

        final statusCode = streamedResponse.statusCode;
        final location = streamedResponse.headers['location'];

        if (statusCode >= 300 &&
            statusCode < 400 &&
            location != null &&
            location.isNotEmpty) {
          final nextUri = Uri.tryParse(location);
          if (nextUri != null) {
            currentUrl = nextUri.hasScheme
                ? location
                : uri.resolve(location).toString();
          }
          redirectCount++;
          if (!currentUrl.contains('/share/') &&
              !currentUrl.contains('fb.watch')) {
            final id = extractFacebookVideoId(currentUrl);
            if (id != null && id.isNotEmpty) {
              client.close();
              return currentUrl;
            }
          }
          continue;
        } else {
          final bodyBytes = await streamedResponse.stream.toBytes();
          final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);

          final extracted = _extractUrlOrIdFromHtml(bodyStr);
          if (extracted != null && extracted.isNotEmpty) {
            client.close();
            return extracted;
          }
          break;
        }
      }
      client.close();
      return currentUrl;
    } catch (_) {
      client.close();
      return null;
    }
  }

  String? _extractUrlOrIdFromHtml(String html) {
    if (html.isEmpty) return null;

    final ogMatch = RegExp(
            r'''<meta[^>]+property=["\x27]og:url["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]''',
            caseSensitive: false)
        .firstMatch(html) ??
        RegExp(
            r'''<meta[^>]+content=["\x27]([^"\x27]+)["\x27][^>]+property=["\x27]og:url["\x27]''',
            caseSensitive: false)
        .firstMatch(html);
    if (ogMatch != null && ogMatch.group(1) != null) {
      final ogUrl = ogMatch.group(1)!.replaceAll('&amp;', '&');
      if (!ogUrl.contains('/share/')) {
        final id = extractFacebookVideoId(ogUrl);
        if (id != null && id.isNotEmpty) return ogUrl;
      }
    }

    final canonicalMatch = RegExp(
            r'''<link[^>]+rel=["\x27]canonical["\x27][^>]+href=["\x27]([^"\x27]+)["\x27]''',
            caseSensitive: false)
        .firstMatch(html);
    if (canonicalMatch != null && canonicalMatch.group(1) != null) {
      final canonicalUrl =
          canonicalMatch.group(1)!.replaceAll('&amp;', '&');
      if (!canonicalUrl.contains('/share/')) {
        final id = extractFacebookVideoId(canonicalUrl);
        if (id != null && id.isNotEmpty) return canonicalUrl;
      }
    }

    final idMatch = RegExp(r'"(?:reel|video)_id"\s*:\s*"(\d+)"').firstMatch(html) ??
        RegExp(r'data-video-id=["\x27](\d+)["\x27]').firstMatch(html);
    if (idMatch != null && idMatch.group(1) != null) {
      return 'https://www.facebook.com/reel/${idMatch.group(1)!}';
    }

    final alMatch = RegExp(
            r'''<meta[^>]+property=["\x27]al:android:url["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]''',
            caseSensitive: false)
        .firstMatch(html) ??
        RegExp(
            r'''<meta[^>]+content=["\x27]([^"\x27]+)["\x27][^>]+property=["\x27]al:android:url["\x27]''',
            caseSensitive: false)
        .firstMatch(html);
    if (alMatch != null && alMatch.group(1) != null) {
      final alUrl = alMatch.group(1)!;
      final numMatch = RegExp(r'(\d{6,30})').firstMatch(alUrl);
      if (numMatch != null && numMatch.group(1) != null) {
        return 'https://www.facebook.com/reel/${numMatch.group(1)!}';
      }
    }

    return null;
  }

  String? extractFacebookVideoId(String url) {
    final clean = url.trim().replaceAll('&amp;', '&');
    if (RegExp(r'^\d{5,30}$').hasMatch(clean)) {
      return clean;
    }

    final patterns = [
      RegExp(r'/reel/(\d+)'),
      RegExp(r'/reels/(\d+)'),
      RegExp(r'/videos/(\d+)'),
      RegExp(r'facebook\.com/(?:[^/]+/)?videos/(\d+)'),
      RegExp(r'facebook\.com/watch/\?v=(\d+)'),
      RegExp(r'fb\.watch/([a-zA-Z0-9_-]+)'),
      RegExp(r'[?&]v=(\d+)'),
      RegExp(r'[?&]video_id=(\d+)'),
      RegExp(r'fb://(?:reel|video)/(\d+)'),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(clean);
      if (m != null && m.group(1) != null) {
        return m.group(1)!;
      }
    }
    return null;
  }

  Future<String> resolveVideoId(String inputUrl) async {
    final trimmed = inputUrl.trim();
    if (RegExp(r'^\d{5,30}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final resolvedUrl = await resolveFacebookUrl(trimmed);

    if (extractGroupPermalink(resolvedUrl) != null ||
        extractGroupPermalink(trimmed) != null) {
      final groupVideoId = await resolveGroupPermalinkVideoId(
            resolvedUrl,
            FacebookAuthService.instance.cookie,
          ) ??
          await resolveGroupPermalinkVideoId(
            trimmed,
            FacebookAuthService.instance.cookie,
          );
      if (groupVideoId != null && groupVideoId.isNotEmpty) {
        return groupVideoId;
      }
    }

    final videoId = extractFacebookVideoId(resolvedUrl) ??
        extractFacebookVideoId(trimmed);

    if (videoId != null && videoId.isNotEmpty) {
      return videoId;
    }

    final pageExtractedId = await resolveVideoIdFromHtmlOrPage(
          resolvedUrl,
          FacebookAuthService.instance.cookie,
        ) ??
        await resolveVideoIdFromHtmlOrPage(
          trimmed,
          FacebookAuthService.instance.cookie,
        );

    if (pageExtractedId != null && pageExtractedId.isNotEmpty) {
      return pageExtractedId;
    }

    throw Exception('Could not extract video ID from URL: $inputUrl');
  }

  Future<FacebookVideoResult> extractByVideoId(String videoId) async {
    return extract(videoId);
  }

  Future<FacebookVideoResult> extract(String inputUrl) async {
    final auth = FacebookAuthService.instance;
    await auth.fetchAndSyncNativeCookies();
    final cookie = auth.cookie;
    final videoId = await resolveVideoId(inputUrl);

    final result = await _extractWithFallback(videoId, cookie);
    if (result != null && result['manifest'] != null) {
      final sanitized = DashXmlSanitizer.sanitize(result['manifest']!);
      return FacebookVideoResult(
        videoId: videoId,
        title: result['title'] ?? 'Facebook Video $videoId',
        dashManifest: sanitized,
      );
    }

    throw Exception(
        'Could not extract DASH manifest for Facebook Video ID: $videoId');
  }

  Future<Map<String, String>?> _extractWithFallback(
    String videoId,
    String cookie,
  ) async {
    String? currentDtsg = authDtsgOrFresh(cookie) ?? await ensureDtsg(cookie);

    if (currentDtsg != null && currentDtsg.isNotEmpty) {
      final rGraphql = await fetchManifestFromGraphql(videoId, cookie, currentDtsg);
      if (rGraphql != null && rGraphql['manifest'] != null) {
        return rGraphql;
      }
    }

    final rMobile = await _fetchManifestFromMobilePage(videoId, cookie);
    if (rMobile != null && rMobile['manifest'] != null) {
      return rMobile;
    }

    final freshDtsg = authDtsgOrFresh(cookie);
    if (freshDtsg != null &&
        freshDtsg.isNotEmpty &&
        freshDtsg != currentDtsg &&
        !freshDtsg.endsWith(':0:0') &&
        !freshDtsg.endsWith(':0')) {
      final rGraphql2 = await fetchManifestFromGraphql(videoId, cookie, freshDtsg);
      if (rGraphql2 != null && rGraphql2['manifest'] != null) {
        return rGraphql2;
      }
    }

    return null;
  }

  Future<String?> ensureDtsg(String cookie) async {
    final cached = authDtsgOrFresh(cookie);
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final response = await http.get(
        Uri.parse('https://m.facebook.com'),
        headers: {
          'User-Agent': mobileUserAgent,
          if (cookie.isNotEmpty) 'Cookie': cookie,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 15));
      await FacebookAuthService.instance.updateFromResponseHeaders(response.headers);
      final body = response.body;

      final dtsgMatch = RegExp(r'name="fb_dtsg" value="([^"]+)"').firstMatch(body) ??
          RegExp(r'"DTSGInitialData",\[\],\{"token":"([^"]+)"\}').firstMatch(body) ??
          RegExp(r'"token":"(NA[a-zA-Z0-9_\-:]+)"').firstMatch(body) ??
          RegExp(r'"dtsg_token":"([^"]+)"').firstMatch(body);
      if (dtsgMatch != null && dtsgMatch.group(1) != null) {
        final tok = dtsgMatch.group(1)!;
        if (!tok.endsWith(':0:0') && !tok.endsWith(':0')) {
          await FacebookAuthService.instance.saveSession(fbDtsg: tok);
          return tok;
        }
      }
    } catch (_) {}
    return null;
  }

  String? authDtsgOrFresh(String cookie) {
    final cached = FacebookAuthService.instance.fbDtsg;
    if (cached.isNotEmpty && !cached.endsWith(':0:0') && !cached.endsWith(':0')) {
      return cached;
    }
    return null;
  }

  Future<Map<String, String>?> fetchManifestFromGraphql(
    String videoId,
    String cookie,
    String dtsg,
  ) async {
    try {
      final uid = FacebookAuthService.instance.userId.isNotEmpty
          ? FacebookAuthService.instance.userId
          : (FacebookAuthService.extractCookieValue(cookie, 'c_user') ?? '');

      final jazoest = FacebookAuthService.generateJazoest(dtsg);

      final variables = {
        'count': 1,
        'initial_node_id': videoId,
        'isAggregationProfileViewerOrShouldShowReelsForPage': false,
        'page_id': '',
        'root_video_id': videoId,
        'scale': 1,
        'should_use_stream': true,
        'shouldIncludeInitialNodeFetch': true,
        'shouldShowReelsForPage': false,
        'shouldShowReelsForUser': false,
        'stream_initial_count': 0,
        'useDefaultActor': false,
        'user_id': '',
        'video_feed_context_data': {
          'arltw_feed_section_type': 'FB_SHORTS_CHAINING',
          'in_session_watched_video': null,
          'is_async_ads_enabled': true,
          'is_async_ads_headload_coupling_enabled': true,
          'player_behavior': 'UNIFIED_PLAYER_VDD',
          'real_time_ranking_context_data': {'recent_vpvs_v2': []},
          'request_type': 'NORMAL',
          'seed_video_id': videoId,
          'shorts_search_params': {},
          'surface_type': 'FEED_VIDEO_DEEP_DIVE',
          'tracking_code': '',
          'video_channel_entry_point': 'NEWSFEED',
        },
        '__relay_internal__pv__FBUnifiedVideoMediaContentContainer_comet_reels_video_footer_defer_loading_gkrelayprovider':
            true,
        '__relay_internal__pv__FBUnifiedVideoMediaContentContainer_comet_video_document_picture_in_picture_gkrelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoMediaContentContainer_enable_chapters_pill_gkrelayprovider':
            false,
        '__relay_internal__pv__ShouldEnableBakedInTextUnifiedVideorelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoMediaHeaderControls_enable_chapters_pill_gkrelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoMediaFooter_comet_enable_reels_ads_gkrelayprovider':
            true,
        '__relay_internal__pv__FBUnifiedVideoMediaFooter_organic_ad_cta_on_comet_gkrelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoMediaFooter_enable_meta_ai_pill_gkrelayprovider':
            true,
        '__relay_internal__pv__FBUnifiedVideoMediaFooter_enable_ai_embodiment_chat_pill_gkrelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoMediaFooter_enable_video_augment_pills_gkrelayprovider':
            true,
        '__relay_internal__pv__FBUnifiedVideoPlayerScrubber_fb_comet_vpv_heatmap_gkrelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoDescriptionWithEntities_comet_translations_revamp_sync_caption_with_audio_gkrelayprovider':
            false,
        '__relay_internal__pv__FBUnifiedVideoFeedbackBar_comet_reels_save_button_gkrelayprovider':
            false,
        '__relay_internal__pv__usePushPipEngagementCounts_comet_video_document_picture_in_picture_gkrelayprovider':
            false,
        '__relay_internal__pv__FBReels_enable_view_dubbed_audio_type_gkrelayprovider':
            true,
        '__relay_internal__pv__FBUnifiedVideoMenu_fb_reels_ranking_debug_tool_gkrelayprovider':
            false,
        '__relay_internal__pv__CometAudioLanguageUtils_comet_translations_revamp_preferred_languages_gkrelayprovider':
            false,
      };

      final response = await http.post(
        Uri.parse('https://www.facebook.com/api/graphql/'),
        headers: {
          'User-Agent': mobileUserAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
          'sec-ch-ua': '"Not-A.Brand";v="99", "Chromium";v="124"',
          'sec-ch-ua-mobile': '?0',
          'x-fb-friendly-name': 'FBUnifiedVideoContainerQuery',
          'sec-ch-ua-platform-version': '""',
          'x-asbd-id': '359341',
          'sec-ch-ua-full-version-list':
              '"Not-A.Brand";v="99.0.0.0", "Chromium";v="124.0.6327.4"',
          'sec-ch-ua-model': '""',
          'sec-ch-prefers-color-scheme': 'dark',
          'sec-ch-ua-platform': '"Linux"',
          'origin': 'https://www.facebook.com',
          'sec-fetch-site': 'same-origin',
          'sec-fetch-mode': 'cors',
          'sec-fetch-dest': 'empty',
          'referer': 'https://www.facebook.com/reel/$videoId',
          'accept-language':
              'en-US,en;q=0.9,ar-EG;q=0.8,ar;q=0.7,fr-FR;q=0.6,fr;q=0.5',
          if (cookie.isNotEmpty) 'Cookie': cookie,
        },
        body: {
          'av': uid,
          '__aaid': '0',
          '__user': uid,
          '__a': '1',
          '__req': '1',
          'dpr': '1',
          '__ccg': 'GOOD',
          'fb_dtsg': dtsg,
          'jazoest': jazoest,
          '__spin_r': '1045115170',
          '__spin_b': 'trunk',
          '__spin_t': '1786626467',
          'fb_api_caller_class': 'RelayModern',
          'fb_api_req_friendly_name': 'FBUnifiedVideoRootWithEntrypointQuery',
          'server_timestamps': 'true',
          'variables': jsonEncode(variables),
          'doc_id': unifiedVideoDocId,
        },
      ).timeout(const Duration(seconds: 25));

      final body = response.body;

      String? dashManifest;
      String? title;

      final lines = body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
      for (final line in lines) {
        try {
          final dynamic obj = jsonDecode(line);
          if (obj is Map<String, dynamic>) {
            final extensions = obj['extensions'];
            if (extensions is Map<String, dynamic>) {
              final freshToken = extensions['dtsg_token']?.toString() ??
                  (extensions['dtsg'] is Map
                      ? extensions['dtsg']['token']?.toString()
                      : null);
              if (freshToken != null &&
                  freshToken.isNotEmpty &&
                  freshToken != 'null' &&
                  !freshToken.endsWith(':0:0') &&
                  !freshToken.endsWith(':0')) {
                await FacebookAuthService.instance
                    .saveSession(fbDtsg: freshToken);
              }
            }

            final data = obj['data'];
            if (data is Map<String, dynamic>) {
              final video = data['video'];
              if (video is Map<String, dynamic>) {
                final attachments =
                    video['creation_story']?['attachments'];
                if (attachments is List && attachments.isNotEmpty) {
                  final media = attachments[0]?['media'];
                  final manifest = media?['videoDeliveryLegacyFields']
                          ?['dash_manifest_xml_string']
                      ?.toString();
                  if (manifest != null &&
                      manifest.isNotEmpty &&
                      dashManifest == null) {
                    dashManifest = manifest;
                  }
                }
              }

              final node = data['node'];
              if (node is Map<String, dynamic>) {
                final manifest = node['videoDeliveryLegacyFields']
                        ?['dash_manifest_xml_string']
                    ?.toString() ??
                    node['creation_story']?['attachments']?[0]?['media']
                        ?['videoDeliveryLegacyFields']
                        ?['dash_manifest_xml_string']
                    ?.toString();
                if (manifest != null &&
                    manifest.isNotEmpty &&
                    dashManifest == null) {
                  dashManifest = manifest;
                }
              }

              final attachments = data['attachments'];
              if (attachments is List && attachments.isNotEmpty) {
                final media = attachments[0]?['media'];
                if (media is Map<String, dynamic>) {
                  final manifest = media['videoDeliveryLegacyFields']
                          ?['dash_manifest_xml_string']
                      ?.toString();
                  if (manifest != null &&
                      manifest.isNotEmpty &&
                      dashManifest == null) {
                    dashManifest = manifest;
                  }
                  if (media['id']?.toString() == videoId) {
                    if (data['message']?['text'] != null && title == null) {
                      title = data['message']['text'].toString();
                    }
                    if (media['owner']?['name'] != null && title == null) {
                      title = media['owner']['name'].toString();
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      if (dashManifest != null && dashManifest.isNotEmpty) {
        return {
          'manifest': dashManifest,
          'title': title ?? 'Facebook Video $videoId',
        };
      }

      final jsonDash =
          RegExp(r'"dash_manifest(?:_xml_string)?":"([^"]+)"')
              .firstMatch(body);
      if (jsonDash != null) {
        try {
          final decoded =
              jsonDecode('"${jsonDash.group(1)!}"') as String;
          if (decoded.contains('<MPD') ||
              decoded.contains('urn:mpeg:dash')) {
            return {
              'manifest': decoded,
              'title': title ?? 'Facebook Video $videoId',
            };
          }
        } catch (_) {}
      }

      final dashRegex = RegExp(
          r'dash_manifest(?:_xml_string)?["\s:]+["\x27](<MPD[\s\S]+?<\/MPD>)["\x27]');
      final match = dashRegex.firstMatch(body);
      if (match != null) {
        final rawXml = match
            .group(1)!
            .replaceAll(r'\"', '"')
            .replaceAll(r'\/', '/');
        return {
          'manifest': rawXml,
          'title': title ?? 'Facebook Video $videoId',
        };
      }

      final mpdMatch = RegExp(r'(<MPD[\s\S]+?<\/MPD>)').firstMatch(body);
      if (mpdMatch != null) {
        return {
          'manifest': mpdMatch.group(1)!,
          'title': title ?? 'Facebook Video $videoId',
        };
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>?> _fetchManifestFromMobilePage(
    String videoId,
    String cookie,
  ) async {
    final urls = [
      'https://m.facebook.com/watch/?v=$videoId',
      'https://m.facebook.com/reel/$videoId',
      'https://m.facebook.com/videos/$videoId',
    ];

    for (final u in urls) {
      try {
        final response = await http.get(
          Uri.parse(u),
          headers: {
            'User-Agent': mobileUserAgent,
            if (cookie.isNotEmpty) 'Cookie': cookie,
            'accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ).timeout(const Duration(seconds: 22));

        await FacebookAuthService.instance
            .updateFromResponseHeaders(response.headers);
        final body = response.body;

        final dtsgMatch = RegExp(r'name="fb_dtsg" value="([^"]+)"').firstMatch(body) ??
            RegExp(r'"DTSGInitialData",\[\],\{"token":"([^"]+)"\}').firstMatch(body) ??
            RegExp(r'"token":"(NA[a-zA-Z0-9_\-:]+)"').firstMatch(body) ??
            RegExp(r'"dtsg_token":"([^"]+)"').firstMatch(body);
        if (dtsgMatch != null && dtsgMatch.group(1) != null) {
          final tok = dtsgMatch.group(1)!;
          if (!tok.endsWith(':0:0') && !tok.endsWith(':0')) {
            await FacebookAuthService.instance.saveSession(fbDtsg: tok);
          }
        }

        final dashRegex = RegExp(
            r'dash_manifest(?:_xml_string)?["\s:]+["\x27](<MPD[\s\S]+?<\/MPD>)["\x27]');
        final match = dashRegex.firstMatch(body);
        if (match != null) {
          final rawXml = match
              .group(1)!
              .replaceAll(r'\"', '"')
              .replaceAll(r'\/', '/');
          return {
            'manifest': rawXml,
            'title': 'Facebook Video $videoId',
          };
        }

        final jsonDash =
            RegExp(r'"dash_manifest(?:_xml_string)?":"([^"]+)"')
                .firstMatch(body);
        if (jsonDash != null) {
          try {
            final decoded =
                jsonDecode('"${jsonDash.group(1)!}"') as String;
            if (decoded.contains('<MPD') ||
                decoded.contains('urn:mpeg:dash')) {
              return {
                'manifest': decoded,
                'title': 'Facebook Video $videoId',
              };
            }
          } catch (_) {}
        }

        final mpdMatch = RegExp(r'(<MPD[\s\S]+?<\/MPD>)').firstMatch(body);
        if (mpdMatch != null) {
          return {
            'manifest': mpdMatch.group(1)!,
            'title': 'Facebook Video $videoId',
          };
        }
      } catch (_) {}
    }
    return null;
  }
}
