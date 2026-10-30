import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/download_record.dart';
import '../services/download_library_service.dart';
import '../services/download_service.dart';
import '../widgets/app_dialog.dart';
import 'player_screen.dart';
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}
class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadRecord> _downloads = [];
  bool _loading = true;
  bool _showAll = false;
  static const _initialLimit = 5;
  @override
  void initState() {
    super.initState();
    _load();
    DownloadService.actives.addListener(_onActivesChanged);
  }
  @override
  void dispose() {
    DownloadService.actives.removeListener(_onActivesChanged);
    super.dispose();
  }
  void _onActivesChanged() {
    if (mounted) setState(() {});
    if (DownloadService.actives.value.isEmpty) _load();
  }
  Future<void> _load() async {
    await DownloadService.syncWithPublicFolder();
    final downloads = await DownloadLibraryService.instance.loadAll();
    if (mounted) {
      setState(() {
        _downloads = downloads;
        _loading = false;
      });
    }
  }
  Future<void> _openDownload(DownloadRecord record) async {
    final file = File(record.filePath);
    if (!await file.exists()) {
      if (mounted) await _confirmDelete(record, missing: true);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PlayerScreen(
          title: record.title,
          videoPath: record.filePath,
          isNetwork: false,
          isDash: false,
        ),
      ),
    );
  }
  Future<void> _confirmDelete(DownloadRecord record,
      {bool missing = false}) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = missing ||
        await AppDialog.showConfirmation(
          context,
          icon: LucideIcons.trash2,
          title: l10n.deleteDownload,
          message: l10n.deleteDownloadConfirm,
          cancelLabel: l10n.downloadCancel,
          confirmLabel: l10n.delete,
          isDestructive: true,
        ) ==
            true;
    if (confirmed != true) return;
    await DownloadLibraryService.instance.remove(record.id);
    try {
      final file = File(record.filePath);
      if (await file.exists()) await file.delete();
      if (record.thumbnailPath != null) {
        final thumb = File(record.thumbnailPath!);
        if (await thumb.exists()) await thumb.delete();
      }
    } catch (_) {}
    _load();
  }
  Future<void> _confirmCancelJob(String id, AppLocalizations l10n) async {
    final confirmed = await AppDialog.showConfirmation(
      context,
      icon: LucideIcons.alertTriangle,
      title: l10n.cancelDownload,
      message: l10n.cancelDownloadConfirm,
      cancelLabel: l10n.downloadCancel,
      confirmLabel: l10n.cancelDownload,
      isDestructive: true,
    );
    if (confirmed == true) DownloadService.cancelJob(id);
  }
  String _fmtDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
  String _fmtSpeed(int bps) {
    if (bps <= 0) return '';
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tasks = DownloadService.actives.value;
    final visible =
        _showAll ? _downloads : _downloads.take(_initialLimit).toList();
    final hasMore = !_showAll && _downloads.length > _initialLimit;
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
          title: Text(l10n.downloads),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    if (tasks.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          icon: LucideIcons.arrowDownToLine,
                          label: l10n.nowDownloading,
                          color: scheme.primary,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final task = tasks[i];
                            return _ActiveDownloadTile(
                              task: task,
                              speedLabel: task.isQueued
                                  ? ''
                                  : _fmtSpeed(task.speedBps),
                              scheme: scheme,
                              onCancel: () => _confirmCancelJob(task.id, l10n),
                              onPause: () => DownloadService.pauseJob(task.id),
                              onResume: () =>
                                  DownloadService.resumeJob(task.id),
                            );
                          },
                          childCount: tasks.length,
                        ),
                      ),
                    ],
                    if (_downloads.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          icon: LucideIcons.checkCircle,
                          label: l10n.downloadedVideos,
                          color: scheme.tertiary,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _DownloadTile(
                            record: visible[i],
                            durationLabel: _fmtDuration(visible[i].durationMs),
                            onTap: () => _openDownload(visible[i]),
                            onDelete: () => _confirmDelete(visible[i]),
                          ),
                          childCount: visible.length,
                        ),
                      ),
                      if (hasMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _showAll = true),
                              icon: const Icon(LucideIcons.chevronDown,
                                  size: 16),
                              label: Text(l10n.showMore(
                                  _downloads.length - _initialLimit)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.primary,
                                side: BorderSide(
                                    color: scheme.primary.withOpacity(0.4)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        ),
                      if (_showAll && _downloads.length > _initialLimit)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _showAll = false),
                              icon: const Icon(LucideIcons.chevronUp,
                                  size: 16),
                              label: Text(l10n.showLess),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.onSurfaceVariant,
                                side: BorderSide(
                                    color: scheme.outlineVariant
                                        .withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (tasks.isEmpty && _downloads.isEmpty)
                      SliverFillRemaining(
                        child: _buildEmpty(l10n, scheme),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
        ),
      ),
    );
  }
  Widget _buildEmpty(AppLocalizations l10n, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.download,
              size: 40, color: scheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(l10n.noDownloads,
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(l10n.noDownloadsSubtitle,
              style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 12)),
        ],
      ),
    );
  }
}
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}
class _ActiveThumb extends StatelessWidget {
  final DownloadTask task;
  const _ActiveThumb({required this.task});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = task.thumbnailPath;
    final file = path != null && path.isNotEmpty ? File(path) : null;
    final hasThumb = file != null && file.existsSync();
    return Stack(
      alignment: Alignment.center,
      children: [
        if (hasThumb)
          Image.file(file,
              fit: BoxFit.cover,
              width: 72,
              height: 72,
              errorBuilder: (_, __, ___) => const SizedBox.shrink())
        else
          Container(
            color: scheme.primary.withOpacity(0.15),
            child: const Icon(LucideIcons.film,
                color: Colors.white54, size: 28),
          ),
        Container(color: Colors.black45),
        if (!task.isQueued) ...[
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: task.progress > 0 && task.progress < 100
                  ? task.progress / 100
                  : null,
              strokeWidth: 3,
              color: task.isPaused ? Colors.orange : Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
          Text(
            '${task.progress}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ] else
          const Icon(LucideIcons.clock, color: Colors.white70, size: 22),
        if (task.isPaused)
          const Icon(LucideIcons.pause,
              color: Colors.orangeAccent, size: 18),
      ],
    );
  }
}
class _ActiveDownloadTile extends StatelessWidget {
  final DownloadTask task;
  final String speedLabel;
  final ColorScheme scheme;
  final VoidCallback onCancel;
  final VoidCallback onPause;
  final VoidCallback onResume;
  const _ActiveDownloadTile({
    required this.task,
    required this.speedLabel,
    required this.scheme,
    required this.onCancel,
    required this.onPause,
    required this.onResume,
  });
  @override
  Widget build(BuildContext context) {
    final statusColor = task.isPaused
        ? Colors.orange
        : task.isQueued
            ? scheme.onSurfaceVariant
            : scheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: scheme.primary.withOpacity(0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _ActiveThumb(task: task),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        task.isQueued
                            ? 'Waiting…'
                            : task.isPaused
                                ? 'Paused'
                                : task.status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      if (speedLabel.isNotEmpty && !task.isPaused) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.gaugeCircle,
                                  size: 10,
                                  color: scheme.onPrimaryContainer),
                              const SizedBox(width: 3),
                              Text(
                                speedLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!task.isQueued) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            task.progress > 0 ? task.progress / 100 : null,
                        minHeight: 4,
                        backgroundColor:
                            scheme.outlineVariant.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            task.isPaused ? Colors.orange : scheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!task.isQueued)
                  IconButton(
                    icon: Icon(
                      task.isPaused
                          ? LucideIcons.play
                          : LucideIcons.pause,
                      color: task.isPaused
                          ? Colors.orange
                          : scheme.onSurfaceVariant,
                      size: 18,
                    ),
                    tooltip: task.isPaused ? 'Resume' : 'Pause',
                    onPressed: task.isPaused ? onResume : onPause,
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: Icon(LucideIcons.x,
                      color: scheme.error, size: 18),
                  tooltip: 'Cancel',
                  onPressed: onCancel,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class _DownloadTile extends StatelessWidget {
  final DownloadRecord record;
  final String durationLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _DownloadTile({
    required this.record,
    required this.durationLabel,
    required this.onTap,
    required this.onDelete,
  });
  Widget _buildThumbnail(ColorScheme scheme) {
    final path = record.thumbnailPath;
    final file = path != null && path.isNotEmpty ? File(path) : null;
    final hasThumbnail = file != null && file.existsSync();
    return Container(
      width: 72,
      height: 72,
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
              errorBuilder: (_, __, ___) => Icon(
                LucideIcons.film,
                color: Colors.white,
                size: 28,
              ),
            )
          : const Icon(LucideIcons.film, color: Colors.white, size: 28),
    );
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildThumbnail(scheme),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(LucideIcons.clock,
                              size: 12,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            durationLabel,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12),
                          ),
                          if (record.isDash) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DASH',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.trash2,
                      color: scheme.error, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
