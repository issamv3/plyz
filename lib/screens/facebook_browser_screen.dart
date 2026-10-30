import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/facebook_auth_service.dart';
import '../services/facebook_extractor_service.dart';

class FacebookBrowserScreen extends StatefulWidget {
  final String initialUrl;
  final bool autoCloseOnLogin;

  const FacebookBrowserScreen({
    super.key,
    this.initialUrl = 'https://m.facebook.com',
    this.autoCloseOnLogin = false,
  });

  @override
  State<FacebookBrowserScreen> createState() => _FacebookBrowserScreenState();
}

class _FacebookBrowserScreenState extends State<FacebookBrowserScreen> {
  late final WebViewController _controller;
  final TextEditingController _urlCtrl = TextEditingController();
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isLoggedIn = false;
  String _currentUserId = '';
  String _currentDtsg = '';
  Timer? _sessionCheckTimer;

  static String enforceMobileFacebookUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (host == 'www.facebook.com' ||
          host == 'web.facebook.com' ||
          host == 'facebook.com' ||
          host == 'touch.facebook.com') {
        return uri.replace(host: 'm.facebook.com').toString();
      }
    } catch (_) {}
    return url;
  }

  static bool isAllowedFacebookUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'about' ||
          uri.scheme == 'data' ||
          uri.scheme == 'javascript') {
        return true;
      }
      final host = uri.host.toLowerCase();
      return host == 'm.facebook.com' ||
          host == 'facebook.com' ||
          host.endsWith('.facebook.com') ||
          host == 'fb.watch' ||
          host == 'fb.me' ||
          host == 'fb.gg' ||
          host.endsWith('.fb.gg') ||
          host == 'messenger.com' ||
          host.endsWith('.messenger.com') ||
          host.endsWith('.fbcdn.net');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    final startUrl = enforceMobileFacebookUrl(widget.initialUrl);
    _urlCtrl.text = startUrl;
    _isLoggedIn = FacebookAuthService.instance.hasSession;
    _currentUserId = FacebookAuthService.instance.userId;
    _currentDtsg = FacebookAuthService.instance.fbDtsg;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(FacebookExtractorService.mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (!isAllowedFacebookUrl(request.url)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Security Alert: Only Facebook URLs are allowed.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return NavigationDecision.prevent;
            }

            final mobileUrl = enforceMobileFacebookUrl(request.url);
            if (mobileUrl != request.url) {
              _controller.loadRequest(Uri.parse(mobileUrl));
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _urlCtrl.text = url;
              });
              _updateNavState();
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _urlCtrl.text = url;
              });
              _updateNavState();
            }
            await _checkAndCaptureSession();
          },
          onWebResourceError: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(startUrl));

    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkAndCaptureSession();
    });
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateNavState() async {
    final canBack = await _controller.canGoBack();
    final canFwd = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canFwd;
      });
    }
  }

  Future<void> _checkAndCaptureSession() async {
    try {
      final String nativeCookie =
          await FacebookAuthService.instance.fetchAndSyncNativeCookies();
      final dynamic rawCookieResult =
          await _controller.runJavaScriptReturningResult('document.cookie');
      String jsCookie = '';
      if (rawCookieResult != null) {
        jsCookie = rawCookieResult.toString();
        if (jsCookie.startsWith('"') &&
            jsCookie.endsWith('"') &&
            jsCookie.length > 1) {
          jsCookie = jsCookie.substring(1, jsCookie.length - 1);
        }
      }
      final combinedCookie =
          nativeCookie.isNotEmpty ? nativeCookie : jsCookie;

      const extractScript = r'''
        (() => {
          try {
            let candidates = [];
            let uid = "";

            if (window.wlct && window.wlct.dtsg) {
              candidates.push(window.wlct.dtsg);
            }
            if (window.__WLCT_DTSG) {
              candidates.push(window.__WLCT_DTSG);
            }
            if (window.Env && window.Env.DTSGInitData && window.Env.DTSGInitData.token) {
              candidates.push(window.Env.DTSGInitData.token);
            }
            if (window.__DTSGInitialData && window.__DTSGInitialData.token) {
              candidates.push(window.__DTSGInitialData.token);
            }
            if (window.DTSGInitialData && window.DTSGInitialData.token) {
              candidates.push(window.DTSGInitialData.token);
            }
            if (window.DTSG && window.DTSG.token) {
              candidates.push(window.DTSG.token);
            }

            if (typeof require === "function") {
              try {
                const reqData = require("DTSGInitialData");
                if (reqData && reqData.token) candidates.push(reqData.token);
              } catch (e) {}
              try {
                const reqData2 = require("DTSGInitData");
                if (reqData2 && reqData2.token) candidates.push(reqData2.token);
              } catch (e) {}
            }

            const inputs = document.querySelectorAll('input[name="fb_dtsg"]');
            inputs.forEach(inp => { if (inp && inp.value) candidates.push(inp.value); });

            const html = document.documentElement.innerHTML;
            const regexList = [
              /name="fb_dtsg" value="([^"]+)"/g,
              /"DTSGInitialData",\[\],\{"token":"([^"]+)"\}/g,
              /"DTSGInitData",\[\],\{"token":"([^"]+)"\}/g,
              /"token":"(NA[a-zA-Z0-9_\-:]+)"/g,
              /"dtsg":\{"token":"([^"]+)"\}/g,
              /"dtsg_token":"([^"]+)"/g,
              /"async_get_token":"([^"]+)"/g,
              /["']wlct["']\s*:\s*\{[^}]*["']dtsg["']\s*:\s*["']([^"']+)["']/g
            ];
            for (const r of regexList) {
              let m;
              while ((m = r.exec(html)) !== null) {
                if (m[1]) candidates.push(m[1]);
              }
            }

            if (window.Env && window.Env.USER_ID && window.Env.USER_ID !== "0") {
              uid = window.Env.USER_ID;
            } else if (window.__user && window.__user !== "0") {
              uid = String(window.__user);
            }

            candidates = candidates.filter(t => typeof t === "string" && t.length > 5);
            candidates.sort((a, b) => {
              const aGuest = a.endsWith(":0:0") || a.endsWith(":0");
              const bGuest = b.endsWith(":0:0") || b.endsWith(":0");
              const aActive = !aGuest && /:\d+:\d+/.test(a);
              const bActive = !bGuest && /:\d+:\d+/.test(b);
              if (aActive && !bActive) return -1;
              if (!aActive && bActive) return 1;
              if (!aGuest && bGuest) return -1;
              if (aGuest && !bGuest) return 1;
              return b.length - a.length;
            });

            const bestDtsg = candidates.length > 0 ? candidates[0] : "";
            return JSON.stringify({ dtsg: bestDtsg, uid: uid || "", count: candidates.length });
          } catch (e) {
            return JSON.stringify({ dtsg: "", uid: "", count: 0 });
          }
        })()
      ''';

      final dynamic metaResult =
          await _controller.runJavaScriptReturningResult(extractScript);
      String dtsg = '';
      String uid = '';
      if (metaResult != null) {
        String str = metaResult.toString().trim();
        if (str.startsWith('"') && str.endsWith('"') && str.length >= 2) {
          str = str
              .substring(1, str.length - 1)
              .replaceAll(r'\"', '"')
              .replaceAll(r'\\', r'\');
        }
        try {
          final Map<String, dynamic> parsed = jsonDecode(str);
          dtsg = parsed['dtsg']?.toString() ?? '';
          uid = parsed['uid']?.toString() ?? '';
        } catch (_) {
          final dtsgMatch =
              RegExp(r'"dtsg"\s*:\s*"([^"]*)"').firstMatch(str);
          final uidMatch =
              RegExp(r'"uid"\s*:\s*"([^"]*)"').firstMatch(str);
          if (dtsgMatch != null) dtsg = dtsgMatch.group(1) ?? '';
          if (uidMatch != null) uid = uidMatch.group(1) ?? '';
        }
      }

      final cUser =
          FacebookAuthService.extractCookieValue(combinedCookie, 'c_user');
      final finalUid = (cUser != null && cUser.isNotEmpty) ? cUser : uid;

      if (combinedCookie.isNotEmpty &&
          (finalUid.isNotEmpty || combinedCookie.contains('c_user='))) {
        await FacebookAuthService.instance.saveSession(
          cookie: combinedCookie,
          fbDtsg: (dtsg.isNotEmpty && dtsg != 'null') ? dtsg : null,
          userId:
              (finalUid.isNotEmpty && finalUid != 'null') ? finalUid : null,
        );

        final newDtsg = FacebookAuthService.instance.fbDtsg;

        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _currentUserId = FacebookAuthService.instance.userId;
            _currentDtsg = newDtsg;
          });
        }
      }
    } catch (_) {}
  }

  void _navigateToUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    url = enforceMobileFacebookUrl(url);
    if (!isAllowedFacebookUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security Alert: Only Facebook URLs are allowed.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = scheme.surfaceContainer;
    final urlBarBg = isDark
        ? scheme.surfaceContainerHigh
        : const Color(0xFFF0F2F7);
    final urlBarBorder = isDark
        ? scheme.outlineVariant.withValues(alpha: 0.3)
        : const Color(0xFFDCE1EC);
    final textColor = scheme.onSurface;
    final hintColor = scheme.onSurfaceVariant;
    final iconColor = scheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.x, color: scheme.onSurface, size: 22),
                    tooltip: 'Close Browser',
                    onPressed: () =>
                        Navigator.of(context).pop(_isLoggedIn),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: urlBarBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: urlBarBorder,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.lock,
                            size: 14,
                            color: iconColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _urlCtrl,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: scheme.primary,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'https://m.facebook.com...',
                                hintStyle: TextStyle(
                                  color: hintColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              onSubmitted: _navigateToUrl,
                            ),
                          ),
                          if (_progress > 0 && _progress < 100)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            )
                          else
                            IconButton(
                              icon: Icon(
                                LucideIcons.rotateCw,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              tooltip: 'Reload',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _controller.reload(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(LucideIcons.cookie, color: scheme.primary, size: 22),
                    tooltip: 'Edit & Paste Cookies',
                    onPressed: () => _showBrowserCookieEditor(context),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    icon: Icon(
                      _isLoggedIn
                          ? LucideIcons.checkCheck
                          : LucideIcons.logIn,
                      size: 16,
                    ),
                    label: Text(
                      _isLoggedIn ? 'Done' : 'Save',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () async {
                      await _checkAndCaptureSession();
                      if (mounted) {
                        Navigator.of(context).pop(_isLoggedIn);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              minHeight: 2.5,
            ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 20),
                  tooltip: 'Back',
                  onPressed: _canGoBack ? () => _controller.goBack() : null,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 20),
                  tooltip: 'Forward',
                  onPressed:
                      _canGoForward ? () => _controller.goForward() : null,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.home, size: 20),
                  tooltip: 'Home (m.facebook.com)',
                  onPressed: () => _controller.loadRequest(
                      Uri.parse('https://m.facebook.com')),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.cookie, size: 20),
                  tooltip: 'Edit & Paste Cookies',
                  onPressed: () => _showBrowserCookieEditor(context),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  tooltip: 'Reload',
                  onPressed: () => _controller.reload(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBrowserCookieEditor(BuildContext context) {
    final auth = FacebookAuthService.instance;
    final cookieCtrl = TextEditingController(text: auth.cookie);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(LucideIcons.cookie, color: scheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paste & Apply Cookies',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Paste your account cookies here to immediately log in and open your account.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cookie String',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(LucideIcons.clipboardPaste, size: 14),
                          label: const Text('Paste', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data != null && data.text != null && data.text!.isNotEmpty) {
                              cookieCtrl.text = data.text!.trim();
                            }
                          },
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            foregroundColor: scheme.error,
                          ),
                          icon: const Icon(LucideIcons.trash2, size: 14),
                          label: const Text('Clear', style: TextStyle(fontSize: 12)),
                          onPressed: () => cookieCtrl.clear(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: cookieCtrl,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'c_user=...; xs=...; fr=...; datr=...;',
                    hintStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? scheme.surfaceContainerHigh : const Color(0xFFF7F8FA),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text(
                    'Save & Apply in Browser',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final newCookie = cookieCtrl.text.trim();
                    if (newCookie.isEmpty) {
                      Navigator.of(ctx).pop();
                      return;
                    }

                    await auth.overwriteSession(cookie: newCookie);

                    final parts = newCookie.split(';');
                    for (final part in parts) {
                      final p = part.trim();
                      if (p.isNotEmpty && p.contains('=')) {
                        try {
                          await _controller.runJavaScript(
                              'document.cookie = ${jsonEncode('$p; path=/; domain=.facebook.com; secure')};');
                          await _controller.runJavaScript(
                              'document.cookie = ${jsonEncode('$p; path=/')};');
                        } catch (_) {}
                      }
                    }

                    if (mounted) {
                      setState(() {
                        _isLoggedIn = auth.hasSession;
                        _currentUserId = auth.userId;
                        _currentDtsg = auth.fbDtsg;
                      });
                    }

                    Navigator.of(ctx).pop();

                    await _controller.loadRequest(
                      Uri.parse('https://m.facebook.com/home.php'),
                      headers: {'Cookie': newCookie},
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cookies applied successfully. Loading account...'),
                          duration: Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
