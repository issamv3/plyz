import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_record.dart';

/// Persists the list of completed downloads (title, file path, duration,
/// thumbnail) in SharedPreferences, most-recent first. Powers the Downloads
/// screen's library list, independent of the system gallery.
class DownloadLibraryService {
  static const _prefsKey = 'download_library_v1';

  static final DownloadLibraryService instance = DownloadLibraryService._();
  DownloadLibraryService._();

  Future<List<DownloadRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => DownloadRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<DownloadRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    records.sort((a, b) => b.downloadedAtMs.compareTo(a.downloadedAtMs));
    await prefs.setString(
      _prefsKey,
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(DownloadRecord record) async {
    final list = await loadAll();
    list.removeWhere((e) => e.id == record.id || e.filePath == record.filePath);
    list.insert(0, record);
    await _saveAll(list);
  }

  Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((e) => e.id == id);
    await _saveAll(list);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
