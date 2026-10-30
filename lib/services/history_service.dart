import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';
class HistoryService {
  static const _prefsKey = 'watch_history_v1';
  static const _maxEntries = 60;
  static final HistoryService instance = HistoryService._();
  HistoryService._();
  static String keyFor({required String videoPath, String? mpdContent}) {
    final basis = mpdContent != null && mpdContent.isNotEmpty
        ? mpdContent
        : Uri.tryParse(videoPath)?.replace(query: '').toString() ?? videoPath;
    return _stableHash(basis).toRadixString(36);
  }
  static int _stableHash(String input) {
    const fnvPrime = 0x100000001b3;
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash;
  }
  Future<List<HistoryEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.lastWatchedAtMs.compareTo(a.lastWatchedAtMs));
      return list;
    } catch (_) {
      return [];
    }
  }
  Future<void> _saveAll(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    entries.sort((a, b) => b.lastWatchedAtMs.compareTo(a.lastWatchedAtMs));
    final trimmed = entries.take(_maxEntries).toList();
    await prefs.setString(
      _prefsKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }
  Future<String> upsert({
    required String title,
    required String videoPath,
    required bool isNetwork,
    required bool isDash,
    required bool fbCdnEnabled,
    String? mpdContent,
    int positionMs = 0,
    int durationMs = 0,
    String? originalFbUrl,
    String? fbVideoId,
  }) async {
    final key = keyFor(videoPath: videoPath, mpdContent: mpdContent);
    final entries = await loadAll();
    final idx = entries.indexWhere((e) => e.key == key);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (idx >= 0) {
      entries[idx] = entries[idx].copyWith(
        title: title.isNotEmpty ? title : entries[idx].title,
        positionMs: positionMs > 0 ? positionMs : entries[idx].positionMs,
        durationMs: durationMs > 0 ? durationMs : entries[idx].durationMs,
        lastWatchedAtMs: now,
        originalFbUrl: originalFbUrl ?? entries[idx].originalFbUrl,
        fbVideoId: fbVideoId ?? entries[idx].fbVideoId,
        mpdContent: mpdContent ?? entries[idx].mpdContent,
      );
    } else {
      entries.add(HistoryEntry(
        key: key,
        title: title,
        videoPath: videoPath,
        isNetwork: isNetwork,
        isDash: isDash,
        fbCdnEnabled: fbCdnEnabled,
        mpdContent: mpdContent,
        positionMs: positionMs,
        durationMs: durationMs,
        lastWatchedAtMs: now,
        originalFbUrl: originalFbUrl,
        fbVideoId: fbVideoId,
      ));
    }
    await _saveAll(entries);
    return key;
  }
  Future<void> updateMpd(String key, String newMpdContent) async {
    final entries = await loadAll();
    final idx = entries.indexWhere((e) => e.key == key);
    if (idx < 0) return;
    entries[idx] = entries[idx].copyWith(
      mpdContent: newMpdContent,
      lastWatchedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveAll(entries);
  }
  Future<void> updateProgress(
      String key, int positionMs, int durationMs) async {
    final entries = await loadAll();
    final idx = entries.indexWhere((e) => e.key == key);
    if (idx < 0) return;
    entries[idx] = entries[idx].copyWith(
      positionMs: positionMs,
      durationMs: durationMs,
      lastWatchedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveAll(entries);
  }
  Future<void> setThumbnailIfAbsent(String key, String thumbnailPath) async {
    final entries = await loadAll();
    final idx = entries.indexWhere((e) => e.key == key);
    if (idx < 0) return;
    final existing = entries[idx].thumbnailPath;
    if (existing != null && existing.isNotEmpty) return;
    entries[idx] = entries[idx].copyWith(thumbnailPath: thumbnailPath);
    await _saveAll(entries);
  }
  Future<void> remove(String key) async {
    final entries = await loadAll();
    entries.removeWhere((e) => e.key == key);
    await _saveAll(entries);
  }
  Future<void> rename(String key, String newTitle) async {
    if (newTitle.trim().isEmpty) return;
    final entries = await loadAll();
    final idx = entries.indexWhere((e) => e.key == key);
    if (idx < 0) return;
    entries[idx] = entries[idx].copyWith(title: newTitle.trim());
    await _saveAll(entries);
  }
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
