import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../models/dash_representation.dart';
import '../models/download_record.dart';
import 'cdn_service.dart';
import 'dash_parser.dart';
import 'download_library_service.dart';
import 'notification_service.dart';

class DownloadTask {
  final String id;
  final String title;
  final int progress;
  final String status;
  final int speedBps;
  final String? thumbnailPath;
  final bool isPaused;
  final bool isQueued;

  const DownloadTask({
    required this.id,
    required this.title,
    required this.progress,
    required this.status,
    this.speedBps = 0,
    this.thumbnailPath,
    this.isPaused = false,
    this.isQueued = false,
  });
}

class _DownloadParams {
  final String id;
  final String title;
  final bool isDash;
  final bool isNetwork;
  final String videoPath;
  final String? mpdContent;
  final DashRepresentation? selectedVideoRep;
  final bool fbCdnEnabled;
  final int? durationMs;
  final String? thumbnailPath;

  _DownloadParams({
    required this.id,
    required this.title,
    required this.isDash,
    required this.isNetwork,
    required this.videoPath,
    this.mpdContent,
    this.selectedVideoRep,
    this.fbCdnEnabled = false,
    this.durationMs,
    this.thumbnailPath,
  });
}

class _JobState {
  bool cancelRequested = false;
  bool pauseRequested = false;
  Completer<void>? pauseCompleter;
}

class DownloadService {
  static const _mediaChannel = MethodChannel('ply/media');
  static const _maxConcurrent = 5;

  static int _activeCount = 0;
  static final _queue = <_DownloadParams>[];
  static final _jobs = <String, _JobState>{};
  static final _taskMap = <String, DownloadTask>{};

  static final ValueNotifier<List<DownloadTask>> actives =
      ValueNotifier<List<DownloadTask>>([]);

  static Future<void> init() async {}

  static void _rebuildActives() {
    final list = <DownloadTask>[
      ..._taskMap.values,
      ..._queue.map((p) => DownloadTask(
            id: p.id,
            title: p.title,
            progress: 0,
            status: 'Queued',
            thumbnailPath: p.thumbnailPath,
            isQueued: true,
          )),
    ];
    actives.value = list;
  }

  static void cancelJob(String id) {
    _queue.removeWhere((p) => p.id == id);
    final job = _jobs[id];
    if (job != null) {
      job.cancelRequested = true;
      job.pauseCompleter?.complete();
    }
    _taskMap.remove(id);
    _rebuildActives();
  }

  static void pauseJob(String id) {
    final job = _jobs[id];
    if (job == null || job.pauseRequested) return;
    job.pauseRequested = true;
    final t = _taskMap[id];
    if (t != null) {
      _taskMap[id] = DownloadTask(
        id: t.id,
        title: t.title,
        progress: t.progress,
        status: t.status,
        speedBps: t.speedBps,
        thumbnailPath: t.thumbnailPath,
        isPaused: true,
      );
      _rebuildActives();
    }
  }

  static void resumeJob(String id) {
    final job = _jobs[id];
    if (job == null || !job.pauseRequested) return;
    job.pauseRequested = false;
    final c = job.pauseCompleter;
    job.pauseCompleter = null;
    c?.complete();
    final t = _taskMap[id];
    if (t != null) {
      _taskMap[id] = DownloadTask(
        id: t.id,
        title: t.title,
        progress: t.progress,
        status: t.status,
        speedBps: t.speedBps,
        thumbnailPath: t.thumbnailPath,
        isPaused: false,
      );
      _rebuildActives();
    }
  }

  static void cancel() {
    for (final id in _jobs.keys.toList()) {
      cancelJob(id);
    }
    _queue.clear();
    _rebuildActives();
  }

  static String? resolveVideoUrl(
      List<DashRepresentation> reps, DashRepresentation? selected) {
    if (selected != null) return selected.baseUrl;
    if (reps.isEmpty) return null;
    return reps.first.baseUrl;
  }

  static Future<void> startBackground({
    required String title,
    required bool isDash,
    required bool isNetwork,
    required String videoPath,
    String? mpdContent,
    DashRepresentation? selectedVideoRep,
    bool fbCdnEnabled = false,
    int? durationMs,
    String? thumbnailPath,
  }) async {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
    final params = _DownloadParams(
      id: id,
      title: title,
      isDash: isDash,
      isNetwork: isNetwork,
      videoPath: videoPath,
      mpdContent: mpdContent,
      selectedVideoRep: selectedVideoRep,
      fbCdnEnabled: fbCdnEnabled,
      durationMs: durationMs,
      thumbnailPath: thumbnailPath,
    );

    if (_activeCount >= _maxConcurrent) {
      _queue.add(params);
      _rebuildActives();
      return;
    }

    _activeCount++;
    _startJob(params);
  }

  static void _startJob(_DownloadParams p) {
    final job = _JobState();
    _jobs[p.id] = job;
    _taskMap[p.id] = DownloadTask(
      id: p.id,
      title: p.title,
      progress: 0,
      status: 'Preparing…',
      thumbnailPath: p.thumbnailPath,
    );
    _rebuildActives();
    unawaited(_runJob(p, job));
  }

  static void _onJobDone(String id) {
    _jobs.remove(id);
    _taskMap.remove(id);
    _activeCount = _activeCount > 0 ? _activeCount - 1 : 0;
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _activeCount++;
      _startJob(next);
    }
    _rebuildActives();
  }

  static Future<void> _runJob(_DownloadParams p, _JobState job) async {
    final stagedFiles = <File>[];
    final id = p.id;
    final title = p.title;
    final thumbnailPath = p.thumbnailPath;

    void updateTask(DownloadTask t) {
      _taskMap[id] = t;
      _rebuildActives();
    }

    try {
      await NotificationService.showProgress(
        title: title,
        body: 'Preparing…',
        progress: 0,
        indeterminate: true,
      );

      final tempDir = await getTemporaryDirectory();
      final downloadsDir = await _downloadsDirectory();
      final isDefaultTitle = title.trim().isEmpty;
      final safeTitle = isDefaultTitle
          ? 'video'
          : title.trim().replaceAll(RegExp(r'[^\w\s\-\u0600-\u06FF]'), '_');

      // For custom titles use the title as-is for the filename; only append
      // a timestamp for auto-generated (empty) titles to guarantee uniqueness.
      String fileId;
      if (isDefaultTitle) {
        fileId = 'video_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        fileId = safeTitle;
        var counter = 1;
        while (await File('${downloadsDir.path}/$fileId.mp4').exists()) {
          fileId = '${safeTitle}_$counter';
          counter++;
        }
      }
      final outputPath = '${downloadsDir.path}/$fileId.mp4';
      final outFile = File(outputPath);
      if (await outFile.exists()) await outFile.delete();

      if (!p.isDash && !p.isNetwork) {
        updateTask(DownloadTask(
            id: id,
            title: title,
            progress: 90,
            status: 'Saving…',
            thumbnailPath: thumbnailPath));
        await NotificationService.showProgress(
            title: title, body: 'Saving…', progress: 90);
        await File(p.videoPath).copy(outputPath);
        await _persistToLibrary(
          id: fileId,
          title: title,
          filePath: outputPath,
          isDash: p.isDash,
          durationMs: p.durationMs,
        );
        await NotificationService.showComplete(title, filePath: outputPath);
        return;
      }

      String resolvedVideoUrl;
      String? audioUrl;

      if (p.isDash && p.mpdContent != null) {
        final effectiveMpd = p.fbCdnEnabled
            ? CdnService.rewriteMpdContent(
                p.mpdContent!,
                fbCdnEnabled: true,
              )
            : p.mpdContent!;
        final videoReps = DashParser.parse(effectiveMpd);
        final maybeVideoUrl = resolveVideoUrl(videoReps, p.selectedVideoRep);
        if (maybeVideoUrl == null) {
          await NotificationService.showError(title, 'No video track found');
          return;
        }
        resolvedVideoUrl = maybeVideoUrl.replaceAll('&amp;', '&');
        final audioRep = DashParser.bestAudio(effectiveMpd);
        if (audioRep != null && audioRep.baseUrl != resolvedVideoUrl) {
          audioUrl = audioRep.baseUrl.replaceAll('&amp;', '&');
        }
      } else {
        resolvedVideoUrl = CdnService.rewrite(
          p.videoPath,
          fbCdnEnabled: p.fbCdnEnabled,
        ).replaceAll('&amp;', '&');
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final stagedVideoPath = '${tempDir.path}/${safeTitle}_v_$stamp.mp4';
      final stagedAudioPath =
          audioUrl != null ? '${tempDir.path}/${safeTitle}_a_$stamp.m4a' : null;

      await NotificationService.showProgress(
          title: title, body: 'Downloading… 0%', progress: 0);

      final videoWeight = audioUrl != null ? 0.7 : 1.0;
      final audioWeight = audioUrl != null ? 0.3 : 0.0;
      var lastPct = -1;

      await _downloadToFile(
        resolvedVideoUrl,
        stagedVideoPath,
        job: job,
        onProgress: (received, total, speedBps) {
          if (total == null || total <= 0) return;
          final pct =
              (received / total * videoWeight * 100).clamp(0, 89).toInt();
          if (pct > lastPct) {
            lastPct = pct;
            updateTask(DownloadTask(
              id: id,
              title: title,
              progress: pct,
              status: 'Downloading…',
              speedBps: speedBps,
              thumbnailPath: thumbnailPath,
              isPaused: job.pauseRequested,
            ));
            unawaited(NotificationService.showProgress(
                title: title, body: 'Downloading… $pct%', progress: pct));
          }
        },
      );
      stagedFiles.add(File(stagedVideoPath));

      if (audioUrl != null && stagedAudioPath != null) {
        await _downloadToFile(
          audioUrl,
          stagedAudioPath,
          job: job,
          onProgress: (received, total, speedBps) {
            if (total == null || total <= 0) return;
            final pct =
                ((videoWeight + received / total * audioWeight) * 100)
                    .clamp(0, 89)
                    .toInt();
            if (pct > lastPct) {
              lastPct = pct;
              updateTask(DownloadTask(
                id: id,
                title: title,
                progress: pct,
                status: 'Downloading…',
                speedBps: speedBps,
                thumbnailPath: thumbnailPath,
                isPaused: job.pauseRequested,
              ));
              unawaited(NotificationService.showProgress(
                  title: title, body: 'Downloading… $pct%', progress: pct));
            }
          },
        );
        stagedFiles.add(File(stagedAudioPath));
      }

      if (job.cancelRequested) throw const _CancelException();

      updateTask(DownloadTask(
          id: id,
          title: title,
          progress: 90,
          status: 'Merging…',
          thumbnailPath: thumbnailPath));
      await NotificationService.showProgress(
          title: title, body: 'Merging…', progress: 90);

      var muxed = false;
      String? muxError;

      if (audioUrl == null || stagedAudioPath == null) {
        // Direct stream or single stream already has audio and video combined
        try {
          await File(stagedVideoPath).copy(outputPath);
          muxed = true;
        } catch (e) {
          muxError = e.toString();
        }
      } else {
        try {
          muxed = await _mediaChannel.invokeMethod<bool>('mux', {
                'videoPath': stagedVideoPath,
                'audioPath': stagedAudioPath,
                'outputPath': outputPath,
              }) ??
              false;
        } on PlatformException catch (e) {
          muxError = e.message ?? e.code;
        }

        // If native muxing fails, fallback to saving the video file directly
        // so the user never loses the downloaded content!
        if (!muxed) {
          try {
            await File(stagedVideoPath).copy(outputPath);
            muxed = true;
          } catch (_) {}
        }
      }

      if (muxed) {
        updateTask(DownloadTask(
            id: id, title: title, progress: 98, status: 'Saving…'));
        await NotificationService.showProgress(
            title: title, body: 'Saving to gallery…', progress: 98);
        await _persistToLibrary(
          id: fileId,
          title: title,
          filePath: outputPath,
          isDash: p.isDash,
          durationMs: p.durationMs,
          initialThumbnailPath: thumbnailPath,
        );
        await NotificationService.showComplete(title, filePath: outputPath);
      } else {
        try {
          await outFile.delete();
        } catch (_) {}
        await NotificationService.showError(title, muxError ?? 'Merge failed');
      }
    } on _CancelException {
      try {
        await NotificationService.cancel();
      } catch (_) {}
    } catch (e) {
      await NotificationService.showError(title, e.toString());
    } finally {
      for (final f in stagedFiles) {
        try {
          await f.delete();
        } catch (_) {}
      }
      _onJobDone(id);
    }
  }

  static Future<String> _publicPlyRoot() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final root = ext.path.split('/Android/').first;
        return root;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  static Future<Directory> _downloadsDirectory() async {
    final root = await _publicPlyRoot();
    final dir = Directory('$root/Ply/Ply Videos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _thumbnailsDirectory() async {
    final appDocs = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocs.path}/Ply/thumbnails');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> syncWithPublicFolder() async {
    try {
      final dir = await _downloadsDirectory();
      if (!await dir.exists()) return;
      final existing = await DownloadLibraryService.instance.loadAll();
      final existingPaths = existing.map((e) => e.filePath).toSet();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) {
            final p = f.path.toLowerCase();
            return p.endsWith('.mp4') ||
                p.endsWith('.mkv') ||
                p.endsWith('.webm');
          })
          .toList();
      for (final file in files) {
        if (existingPaths.contains(file.path)) continue;
        final name = file.uri.pathSegments.last;
        final title =
            name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
        final id = 'scan_${file.path.hashCode.abs()}';

        int durationMs = 0;
        try {
          final ctrl = VideoPlayerController.file(file);
          await ctrl.initialize();
          durationMs = ctrl.value.duration.inMilliseconds;
          await ctrl.dispose();
        } catch (_) {}

        String? thumbnailPath;
        try {
          final thumbsDir = await _thumbnailsDirectory();
          final candidatePath = '${thumbsDir.path}/$id.jpg';
          final ok = await _mediaChannel.invokeMethod<bool>('thumbnail', {
                'videoPath': file.path,
                'outputPath': candidatePath,
                'timeUs': 1000000,
              }) ??
              false;
          if (ok && await File(candidatePath).exists()) {
            thumbnailPath = candidatePath;
          }
        } catch (_) {}

        await DownloadLibraryService.instance.add(DownloadRecord(
          id: id,
          title: title,
          filePath: file.path,
          durationMs: durationMs,
          thumbnailPath: thumbnailPath,
          isDash: false,
          downloadedAtMs: file.statSync().modified.millisecondsSinceEpoch,
        ));
      }
    } catch (_) {}
  }

  static Future<void> _persistToLibrary({
    required String id,
    required String title,
    required String filePath,
    required bool isDash,
    int? durationMs,
    String? initialThumbnailPath,
  }) async {
    var resolvedDuration = durationMs ?? 0;
    if (resolvedDuration <= 0) {
      try {
        final controller = VideoPlayerController.file(File(filePath));
        await controller.initialize();
        resolvedDuration = controller.value.duration.inMilliseconds;
        await controller.dispose();
      } catch (_) {}
    }

    String? thumbnailPath;
    try {
      final thumbsDir = await _thumbnailsDirectory();
      final candidatePath = '${thumbsDir.path}/$id.jpg';

      if (initialThumbnailPath != null &&
          initialThumbnailPath.isNotEmpty &&
          await File(initialThumbnailPath).exists()) {
        try {
          await File(initialThumbnailPath).copy(candidatePath);
          thumbnailPath = candidatePath;
        } catch (_) {
          thumbnailPath = initialThumbnailPath;
        }
      }

      if (thumbnailPath == null || !await File(thumbnailPath).exists()) {
        final ok = await _mediaChannel.invokeMethod<bool>('thumbnail', {
              'videoPath': filePath,
              'outputPath': candidatePath,
              'timeUs': 1000000,
            }) ??
            false;
        if (ok && await File(candidatePath).exists()) {
          thumbnailPath = candidatePath;
        }
      }
    } catch (_) {}

    await DownloadLibraryService.instance.add(DownloadRecord(
      id: id,
      title: title,
      filePath: filePath,
      durationMs: resolvedDuration,
      thumbnailPath: thumbnailPath,
      isDash: isDash,
      downloadedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  static Future<void> _downloadToFile(
    String url,
    String path, {
    required _JobState job,
    required void Function(int received, int? total, int speedBps) onProgress,
  }) async {
    final headers = CdnService.headersFor(url);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode} for $url');
      }
      final total = response.contentLength;
      final sink = File(path).openWrite();
      var received = 0;
      var speedBps = 0;
      var lastSpeedReceived = 0;
      var lastSpeedTime = DateTime.now();

      await for (final chunk in response.stream) {
        if (job.cancelRequested) throw const _CancelException();
        if (job.pauseRequested) {
          job.pauseCompleter = Completer<void>();
          await job.pauseCompleter!.future;
          if (job.cancelRequested) throw const _CancelException();
        }
        sink.add(chunk);
        received += chunk.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastSpeedTime).inMilliseconds;
        if (elapsed >= 500) {
          speedBps =
              ((received - lastSpeedReceived) * 1000 / elapsed).round();
          lastSpeedReceived = received;
          lastSpeedTime = now;
        }

        onProgress(received, total, speedBps);
      }
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }
}

class _CancelException implements Exception {
  const _CancelException();
}
