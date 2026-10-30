import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/download_record.dart';
import '../models/history_entry.dart';
import '../providers/settings_provider.dart';
import '../services/download_library_service.dart';
import '../services/history_service.dart';
import 'player_screen.dart';
class _SearchResult {
  final String title;
  final String? thumbnailPath;
  final int durationMs;
  final bool isDash;
  final bool isDownloaded;
  final HistoryEntry? historyEntry;
  final DownloadRecord? downloadRecord;
  const _SearchResult({
    required this.title,
    this.thumbnailPath,
    required this.durationMs,
    required this.isDash,
    required this.isDownloaded,
    this.historyEntry,
    this.downloadRecord,
  });
}
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<_SearchResult> _all = [];
  List<_SearchResult> _filtered = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
    _ctrl.addListener(_onQuery);
  }
  @override
  void dispose() {
    _ctrl.removeListener(_onQuery);
    _ctrl.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    final history = await HistoryService.instance.loadAll();
    final downloads = await DownloadLibraryService.instance.loadAll();
    final seen = <String>{};
    final results = <_SearchResult>[];
    final downloadByPath = {for (final d in downloads) d.filePath: d};
    for (final entry in history) {
      final key = entry.videoPath;
      if (seen.contains(key)) continue;
      seen.add(key);
      final matchedDownload = downloadByPath[entry.videoPath];
      results.add(_SearchResult(
        title: entry.title,
        thumbnailPath: entry.thumbnailPath ?? matchedDownload?.thumbnailPath,
        durationMs: entry.durationMs > 0
            ? entry.durationMs
            : (matchedDownload?.durationMs ?? 0),
        isDash: entry.isDash,
        isDownloaded: matchedDownload != null,
        historyEntry: entry,
        downloadRecord: matchedDownload,
      ));
    }
    for (final record in downloads) {
      if (seen.contains(record.filePath)) continue;
      seen.add(record.filePath);
      results.add(_SearchResult(
        title: record.title,
        thumbnailPath: record.thumbnailPath,
        durationMs: record.durationMs,
        isDash: record.isDash,
        isDownloaded: true,
        downloadRecord: record,
      ));
    }
    if (mounted) {
      setState(() {
        _all = results;
        _filtered = results;
        _loading = false;
      });
    }
  }
  void _onQuery() {
    final q = _ctrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((r) => r.title.toLowerCase().contains(q))
              .toList();
    });
  }
  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
  Future<void> _open(_SearchResult result) async {
    final fbCdn =
        context.read<SettingsProvider>().fbCdnEnabled;
    if (result.historyEntry != null) {
      final e = result.historyEntry!;
      await Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => PlayerScreen(
          title: e.title,
          videoPath: e.videoPath,
          isNetwork: e.isNetwork,
          isDash: e.isDash,
          mpdContent: e.mpdContent,
          fbCdnEnabled: e.fbCdnEnabled,
          resumeAt: Duration(milliseconds: e.positionMs),
          historyKey: e.key,
        ),
      ));
    } else if (result.downloadRecord != null) {
      final r = result.downloadRecord!;
      await Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => PlayerScreen(
          title: r.title,
          videoPath: r.filePath,
          isNetwork: false,
          isDash: r.isDash,
          fbCdnEnabled: fbCdn,
        ),
      ));
    }
  }
  Widget _buildThumbnail(String? path, ColorScheme scheme) {
    final file = path != null && path.isNotEmpty ? File(path) : null;
    final has = file != null && file.existsSync();
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: has
            ? null
            : LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? Image.file(file, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(LucideIcons.film, color: Colors.white, size: 22))
          : const Icon(LucideIcons.film, color: Colors.white, size: 22),
    );
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 300) Navigator.of(context).maybePop();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          cursorColor: scheme.primary,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withOpacity(0.6)),
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => _ctrl.clear(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.searchX,
                          size: 40,
                          color: scheme.onSurfaceVariant.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _ctrl.text.isEmpty
                            ? l10n.searchEmpty
                            : l10n.searchNoResults,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final r = _filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(r),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _buildThumbnail(r.thumbnailPath, scheme),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _MarqueeText(
                                        text: r.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: r.isDash
                                                  ? scheme.tertiaryContainer
                                                  : scheme.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              r.isDash ? 'DASH' : 'MP4',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: r.isDash
                                                      ? scheme
                                                          .onTertiaryContainer
                                                      : scheme
                                                          .onSecondaryContainer),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (r.durationMs > 0)
                                            Text(
                                              _fmt(r.durationMs),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      scheme.onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (r.isDownloaded)
                                  Icon(LucideIcons.checkCircle,
                                      size: 16, color: scheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
      child: Text(widget.text,
          style: widget.style, maxLines: 1, softWrap: false),
    );
  }
}
