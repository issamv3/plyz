import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show handlePendingIntent;
import '../models/history_entry.dart';
import '../providers/settings_provider.dart';
import '../services/cdn_service.dart';
import '../services/dash_parser.dart';
import '../services/dash_xml_sanitizer.dart';
import '../services/download_service.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../utils/smart_error.dart';
import '../widgets/app_dialog.dart';
import 'downloads_screen.dart';
import 'facebook_browser_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../services/facebook_auth_service.dart';
import '../services/facebook_extractor_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final FileService _fs = FileService();
  bool _loading = false;
  bool _inputExpanded = false;
  List<HistoryEntry> _history = [];
  bool _historyLoading = true;
  String _historyFilter = 'all';
  late final AnimationController _iconAnim;
  late final Animation<double> _iconScale;
  List<HistoryEntry> get _filteredHistory {
    if (_history.length <= 10) return _history;
    switch (_historyFilter) {
      case 'facebook':
        return _history.where((e) => e.isFacebook).toList();
      case 'downloaded':
        return _history.where((e) => e.isDownloaded).toList();
      case 'dash':
        return _history.where((e) => e.isDash).toList();
      case 'all':
      default:
        return _history;
    }
  }
  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(_onFocusChanged);
    _iconAnim = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _iconScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _iconAnim, curve: Curves.easeInOut),
    );
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => handlePendingIntent());
  }
  void _onFocusChanged() {
    if (mounted) setState(() {});
  }
  Future<void> _loadHistory() async {
    final history = await HistoryService.instance.loadAll();
    if (mounted) {
      setState(() {
        _history = history;
        _historyLoading = false;
        _inputExpanded = history.isEmpty;
      });
    }
  }
  @override
  void dispose() {
    _inputFocus.removeListener(_onFocusChanged);
    _inputFocus.dispose();
    _ctrl.dispose();
    _iconAnim.dispose();
    super.dispose();
  }
  String _titleFromInput(String input, {String? mpdContent}) {
    if (_fs.isMpdXml(input) || mpdContent != null) {
      final extracted = DashParser.extractTitle(mpdContent ?? input);
      if (extracted != null) return extracted;
      return 'DASH Manifest';
    }
    final uri = Uri.tryParse(input);
    return uri?.host.isNotEmpty == true ? uri!.host : 'Video';
  }
  Future<void> _handlePlay() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() => _loading = true);
    final fbCdnEnabled = context.read<SettingsProvider>().fbCdnEnabled;
    try {
      String videoPath;
      bool isNetwork;
      bool isDash;
      String? mpdContent;
      if (_fs.isMpdXml(input)) {
        mpdContent = DashXmlSanitizer.sanitize(input);
        videoPath = await _fs.saveMpdToFile(input);
        isNetwork = true;
        isDash = true;
      } else if (FacebookExtractorService.instance.isFacebookUrl(input)) {
        if (!FacebookAuthService.instance.hasSession) {
          setState(() => _loading = false);
          final shouldLogin = await AppDialog.showConfirmation(
            context,
            icon: LucideIcons.logIn,
            title: 'Facebook Login Required',
            message:
                'To extract and stream this Facebook video, please log in to your Facebook account in the in-app browser.',
            cancelLabel: 'Cancel',
            confirmLabel: 'Log In',
          );
          if (shouldLogin != true || !mounted) return;
          final loggedIn = await Navigator.of(context).push<bool>(
            CupertinoPageRoute(
              builder: (_) =>
                  const FacebookBrowserScreen(autoCloseOnLogin: true),
            ),
          );
          if (loggedIn != true &&
              !FacebookAuthService.instance.hasSession) {
            return;
          }
          if (!mounted) return;
          setState(() => _loading = true);
        }
        try {
          final fbResult =
              await FacebookExtractorService.instance.extract(input);
          mpdContent = fbResult.dashManifest;
          videoPath = await _fs.saveMpdToFile(fbResult.dashManifest);
          isNetwork = true;
          isDash = true;
          if (!mounted) return;
          setState(() => _loading = false);
          _ctrl.clear();
          await _openPlayer(
            title: fbResult.title,
            videoPath: videoPath,
            isNetwork: isNetwork,
            isDash: isDash,
            mpdContent: mpdContent,
            fbCdnEnabled: true,
            originalFbUrl: input,
            fbVideoId: fbResult.videoId,
          );
          return;
        } catch (e, stackTrace) {
          print('[HomeScreen] Extraction error: $e');
          print(stackTrace);
          if (!mounted) return;
          setState(() => _loading = false);
          final smartErr = SmartError.analyze(e, url: input);
          if (smartErr.isNetworkError) {
            final retry = await AppDialog.showConfirmation(
              context,
              icon: smartErr.icon,
              title: smartErr.title,
              message: smartErr.message,
              cancelLabel: 'Cancel',
              confirmLabel: 'Retry',
            );
            if (retry == true && mounted) {
              _handlePlay();
            }
            return;
          }
          final openBrowser = await AppDialog.showConfirmation(
            context,
            icon: smartErr.icon,
            title: smartErr.title,
            message: smartErr.message,
            cancelLabel: 'Cancel',
            confirmLabel: 'Open Browser',
          );
          if (openBrowser == true && mounted) {
            final loggedIn = await Navigator.of(context).push<bool>(
              CupertinoPageRoute(
                builder: (_) => FacebookBrowserScreen(initialUrl: input),
              ),
            );
            if (loggedIn == true && mounted) {
              _handlePlay();
            }
          }
          return;
        }
      } else if (_fs.isNetworkUrl(input)) {
        final rewritten =
            CdnService.rewrite(input, fbCdnEnabled: fbCdnEnabled);
        videoPath = rewritten;
        isNetwork = true;
        isDash = _fs.isMpdUrl(rewritten);
        if (isDash) {
          try {
            mpdContent = await _fs.fetchMpdContent(
              rewritten,
              headers: CdnService.headersFor(rewritten),
            );
          } catch (e) {
            if (mounted) {
              setState(() => _loading = false);
              final smartErr = SmartError.analyze(e, url: input);
              final retry = await AppDialog.showConfirmation(
                context,
                icon: smartErr.icon,
                title: smartErr.title,
                message: smartErr.message,
                cancelLabel: 'Cancel',
                confirmLabel: 'Retry',
              );
              if (retry == true && mounted) {
                _handlePlay();
              }
            }
            return;
          }
        }
      } else {
        setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      _ctrl.clear();
      final title = _titleFromInput(input, mpdContent: mpdContent);
      if (mpdContent != null) {
        mpdContent = DashParser.stripTitle(mpdContent);
      }
      await _openPlayer(
        title: title,
        videoPath: videoPath,
        isNetwork: isNetwork,
        isDash: isDash,
        mpdContent: mpdContent,
        fbCdnEnabled: fbCdnEnabled,
      );
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _resumeEntry(HistoryEntry entry) async {
    await _openPlayer(
      title: entry.title,
      videoPath: entry.videoPath,
      isNetwork: entry.isNetwork,
      isDash: entry.isDash,
      mpdContent: entry.mpdContent,
      fbCdnEnabled: entry.fbCdnEnabled,
      resumeAt: Duration(milliseconds: entry.positionMs),
      historyKey: entry.key,
      originalFbUrl: entry.originalFbUrl,
      fbVideoId: entry.fbVideoId,
    );
  }
  Future<void> _openPlayer({
    required String title,
    required String videoPath,
    required bool isNetwork,
    required bool isDash,
    String? mpdContent,
    bool fbCdnEnabled = false,
    Duration? resumeAt,
    String? historyKey,
    String? originalFbUrl,
    String? fbVideoId,
  }) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PlayerScreen(
          title: title,
          videoPath: videoPath,
          isNetwork: isNetwork,
          mpdContent: mpdContent,
          fbCdnEnabled: fbCdnEnabled,
          isDash: isDash,
          resumeAt: resumeAt,
          historyKey: historyKey,
          originalFbUrl: originalFbUrl,
          fbVideoId: fbVideoId,
        ),
      ),
    );
    _loadHistory();
  }
  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.showConfirmation(
      context,
      icon: LucideIcons.trash2,
      title: l10n.clearHistory,
      message: l10n.clearHistoryConfirm,
      cancelLabel: l10n.downloadCancel,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (confirmed == true) {
      await HistoryService.instance.clear();
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.historyCleared),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  Future<void> _showHistoryMenu(HistoryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                        ),
                        child: Icon(LucideIcons.film,
                            size: 18, color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const SizedBox(height: 4),
                ListTile(
                  leading: Icon(LucideIcons.pencilLine,
                      color: scheme.onSurface, size: 20),
                  title: Text(l10n.rename),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showRenameDialog(entry);
                  },
                ),
                ListTile(
                  leading:
                      Icon(LucideIcons.trash2, color: scheme.error, size: 20),
                  title: Text(l10n.deleteFromHistory,
                      style: TextStyle(color: scheme.error)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _deleteEntry(entry);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _deleteEntry(HistoryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.showConfirmation(
      context,
      icon: LucideIcons.trash2,
      title: l10n.deleteFromHistory,
      message: '${l10n.deleteFromHistory}: "${entry.title}"?',
      cancelLabel: l10n.downloadCancel,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (confirmed == true) {
      await HistoryService.instance.remove(entry.key);
      _loadHistory();
    }
  }
  Future<void> _showRenameDialog(HistoryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final newTitle = await AppDialog.showInput(
      context,
      icon: LucideIcons.pencilLine,
      title: l10n.renameVideo,
      initialValue: entry.title,
      hintText: l10n.renameHint,
      cancelLabel: l10n.downloadCancel,
      confirmLabel: l10n.rename,
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != entry.title) {
      await HistoryService.instance.rename(entry.key, newTitle);
      _loadHistory();
    }
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.search),
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const SearchScreen()),
          ),
        ),
        title: Text(
          l10n.appName,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: DownloadService.actives,
            builder: (context, activeList, _) {
              final hasActive = activeList.isNotEmpty;
              return IconButton(
                tooltip: l10n.downloads,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(LucideIcons.download),
                    if (hasActive)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 8.5,
                          height: 8.5,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const DownloadsScreen()),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildInputCard(l10n, scheme),
              const SizedBox(height: 28),
              _buildHistorySection(l10n, scheme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildInputCard(AppLocalizations l10n, ColorScheme scheme) {
    final isFocused = _inputFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _inputExpanded = !_inputExpanded),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.addNewVideo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                AnimatedRotation(
                  turns: _inputExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(LucideIcons.chevronDown,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: _inputExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _ctrl,
                        focusNode: _inputFocus,
                        maxLines: 5,
                        minLines: 2,
                        cursorColor: scheme.primary,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: '${l10n.urlHint}\n\n${l10n.xmlHint}',
                          fillColor: Colors.transparent,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(right: 12, top: 10),
                            child: Icon(
                              LucideIcons.link,
                              size: 20,
                              color: isFocused ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: isFocused ? 2.0 : 1.2,
                        margin: const EdgeInsets.only(top: 6, bottom: 16),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? scheme.primary
                              : scheme.outlineVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _handlePlay,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.play),
                    label: Text(
                      _loading ? l10n.loading : l10n.play,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
  Widget _buildFilterChips(ColorScheme scheme) {
    final countAll = _history.length;
    final countFb = _history.where((e) => e.isFacebook).length;
    final countDl = _history.where((e) => e.isDownloaded).length;
    final countDash = _history.where((e) => e.isDash).length;
    final options = [
      {
        'id': 'all',
        'label': 'All',
        'labelAr': 'الكل',
        'count': countAll,
        'icon': LucideIcons.layers,
      },
      {
        'id': 'facebook',
        'label': 'Facebook',
        'labelAr': 'فيسبوك',
        'count': countFb,
        'icon': Icons.facebook,
      },
      {
        'id': 'downloaded',
        'label': 'Downloaded',
        'labelAr': 'المحمّلة',
        'count': countDl,
        'icon': LucideIcons.download,
      },
      {
        'id': 'dash',
        'label': 'DASH',
        'labelAr': 'DASH',
        'count': countDash,
        'icon': LucideIcons.zap,
      },
    ];
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((opt) {
            final isSelected = _historyFilter == opt['id'];
            final id = opt['id'] as String;
            final label =
                isArabic ? (opt['labelAr'] as String) : (opt['label'] as String);
            final count = opt['count'] as int;
            final icon = opt['icon'] as IconData;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _historyFilter = id);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary.withOpacity(0.5)
                            : scheme.outlineVariant.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : (id == 'facebook'
                                  ? const Color(0xFF1877F2)
                                  : scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primary.withOpacity(0.2)
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  Widget _buildHistorySection(AppLocalizations l10n, ColorScheme scheme) {
    if (_historyLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(LucideIcons.history,
                size: 40, color: scheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(l10n.noHistory,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l10n.noHistorySubtitle,
                style: TextStyle(
                    color: scheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 12)),
          ],
        ),
      );
    }
    final filtered = _filteredHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.continueWatching,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: Text(l10n.clearHistory,
                  style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_history.length > 10) _buildFilterChips(scheme),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'لا توجد فيديوهات مطابقة لهذا الفلتر'
                    : 'No matching videos found',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...filtered.map((e) => _HistoryTile(
                entry: e,
                onTap: () => _resumeEntry(e),
                onLongPress: () => _showHistoryMenu(e),
                l10n: l10n,
              )),
      ],
    );
  }
}
class _FormatBadge extends StatelessWidget {
  final bool isDash;
  final ColorScheme scheme;
  const _FormatBadge({required this.isDash, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDash
            ? scheme.tertiaryContainer
            : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isDash ? 'DASH' : 'MP4',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: isDash
              ? scheme.onTertiaryContainer
              : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _MarqueeText({required this.text, this.style});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}
class _MarqueeTextState extends State<_MarqueeText> {
  final _sc = ScrollController();
  bool _scrolling = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }
  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _scrolling = false;
      if (_sc.hasClients) _sc.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    }
  }
  void _maybeStart() {
    if (!mounted || !_sc.hasClients) return;
    if (_sc.position.maxScrollExtent > 0 && !_scrolling) {
      _scrolling = true;
      Future.delayed(const Duration(milliseconds: 1800), _scroll);
    }
  }
  Future<void> _scroll() async {
    if (!mounted || !_sc.hasClients) return;
    final max = _sc.position.maxScrollExtent;
    if (max <= 0) {
      _scrolling = false;
      return;
    }
    await _sc.animateTo(max,
        duration: Duration(milliseconds: (max * 28).round()),
        curve: Curves.linear);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || !_sc.hasClients) return;
    _sc.jumpTo(0);
    await Future.delayed(const Duration(milliseconds: 1200));
    _scroll();
  }
  @override
  void dispose() {
    _scrolling = false;
    _sc.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _sc,
      physics: const NeverScrollableScrollPhysics(),
      child:
          Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
    );
  }
}
class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AppLocalizations l10n;
  const _HistoryTile({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
    required this.l10n,
  });
  String _relativeTime(int ms) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}${l10n.minutesAgo}';
    if (diff.inDays < 1) return '${diff.inHours}${l10n.hoursAgo}';
    return '${diff.inDays}${l10n.daysAgo}';
  }
  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
  Widget _buildThumbnail(ColorScheme scheme) {
    final path = entry.thumbnailPath;
    final file = path != null && path.isNotEmpty ? File(path) : null;
    final hasThumbnail = file != null && file.existsSync();
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: hasThumbnail
                ? null
                : LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasThumbnail
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    LucideIcons.film,
                    color: Colors.white,
                    size: 24,
                  ),
                )
              : const Icon(LucideIcons.film, color: Colors.white, size: 24),
        ),
        if (entry.isFacebook)
          Positioned(
            bottom: 3,
            right: 3,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                color: Color(0xFF1877F2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.facebook,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : scheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildThumbnail(scheme),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MarqueeText(
                              text: entry.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (entry.isFacebook) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF1877F2).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                    const Color(0xFF1877F2).withOpacity(0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.facebook,
                                    size: 10,
                                    color: Color(0xFF1877F2),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'FB',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1877F2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          _FormatBadge(isDash: entry.isDash, scheme: scheme),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.progress,
                          minHeight: 4,
                          backgroundColor: scheme.outlineVariant.withOpacity(0.3),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(scheme.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.durationMs > 0
                            ? '${_fmt(entry.positionMs)} / ${_fmt(entry.durationMs)} · ${_relativeTime(entry.lastWatchedAtMs)}'
                            : _relativeTime(entry.lastWatchedAtMs),
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.play, color: scheme.primary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
