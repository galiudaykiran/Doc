import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_activity_item.dart';

class RecentActivityService {
  static const String _storageKey = 'hub_recent_activity_list_v2';
  static const int _maxItems = 50;
  static const int _minKeepItems = 20; // Always keep the last 10 to 20 recents
  static const int _maxRetentionDays = 20; // Auto-prune entries older than 20 days

  static Future<List<RecentActivityItem>> getActivities({bool runAutoPrune = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    List<RecentActivityItem> items = [];

    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        items = decoded.map((e) => RecentActivityItem.fromMap(e)).toList();
      } catch (_) {
        items = [];
      }
    } else {
      // Default seeded activities matching design reference
      final now = DateTime.now();
      items = [
        RecentActivityItem(
          id: 'recent_1',
          title: 'Uday docs',
          subtitle: 'Collection created • 0 items',
          type: 'folder',
          timestamp: DateTime(now.year, now.month, now.day, 17, 34),
        ),
        RecentActivityItem(
          id: 'recent_2',
          title: 'Passport & ID Renewal Checklist',
          subtitle: 'Edited quick note',
          type: 'note',
          timestamp: DateTime(now.year, now.month, now.day, 16, 15),
          targetPath: 'note_sample_1',
        ),
        RecentActivityItem(
          id: 'recent_3',
          title: 'DigiLocker Portal',
          subtitle: 'Credential saved to Vault',
          type: 'credential',
          timestamp: now.subtract(const Duration(days: 3)),
        ),
      ];
      await _save(prefs, items);
      return items;
    }

    if (runAutoPrune) {
      return autoPruneAndClean(items: items);
    }
    return items;
  }

  /// Automatically prunes entries older than 20 days while strictly preserving
  /// the most recent 10 to 20 entries, ensuring long-term data consistency.
  static Future<List<RecentActivityItem>> autoPruneAndClean({
    List<RecentActivityItem>? items,
    bool checkExistence = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = items ?? await getActivities(runAutoPrune: false);
    final now = DateTime.now();

    // Sort newest first
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final List<RecentActivityItem> cleanList = [];

    for (int i = 0; i < list.length; i++) {
      final item = list[i];

      // Consistency check: if targetPath was deleted on disk, omit it
      if (checkExistence && item.targetPath != null) {
        if (item.type == 'folder') {
          if (!Directory(item.targetPath!).existsSync()) continue;
        } else if (item.type == 'document') {
          if (!File(item.targetPath!).existsSync()) continue;
        }
      }

      // Retention rule:
      // Always retain the first 10-20 most recent entries unconditionally
      if (cleanList.length < _minKeepItems) {
        cleanList.add(item);
      } else {
        // For entries beyond the top 20, prune if older than 20 days
        final ageDays = now.difference(item.timestamp).inDays;
        if (ageDays <= _maxRetentionDays) {
          cleanList.add(item);
        }
      }
    }

    final trimmed = cleanList.take(_maxItems).toList();
    if (trimmed.length != list.length) {
      await _save(prefs, trimmed);
    }
    return trimmed;
  }

  static Future<void> recordActivity({
    required String title,
    required String subtitle,
    required String type,
    String? targetPath,
  }) async {
    final list = await getActivities(runAutoPrune: false);

    // Remove duplicates of same title or path
    list.removeWhere((item) =>
        item.title.toLowerCase() == title.toLowerCase() ||
        (targetPath != null && item.targetPath == targetPath));

    // Insert at front
    list.insert(
      0,
      RecentActivityItem(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        subtitle: subtitle,
        type: type,
        timestamp: DateTime.now(),
        targetPath: targetPath,
      ),
    );

    // Auto-prune with retention guarantees
    await autoPruneAndClean(items: list);
  }

  static Future<void> removeActivity({String? targetPath, String? title}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getActivities(runAutoPrune: false);
    list.removeWhere((item) {
      if (targetPath != null &&
          ((item.targetPath != null && item.targetPath!.toLowerCase() == targetPath.toLowerCase()) ||
           targetPath.toLowerCase().endsWith(item.title.toLowerCase()))) {
        return true;
      }
      if (title != null &&
          (item.title.toLowerCase() == title.toLowerCase() ||
           (item.targetPath != null && item.targetPath!.toLowerCase().endsWith(title.toLowerCase())))) {
        return true;
      }
      return false;
    });
    await _save(prefs, list);
  }

  static Future<void> removeActivities({List<String>? titles, List<String>? paths}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getActivities(runAutoPrune: false);
    final titleSet = titles?.map((e) => e.toLowerCase()).toSet() ?? {};
    final pathSet = paths?.map((e) => e.toLowerCase()).toSet() ?? {};

    list.removeWhere((item) {
      if (item.targetPath != null && pathSet.contains(item.targetPath!.toLowerCase())) {
        return true;
      }
      if (titleSet.contains(item.title.toLowerCase())) {
        return true;
      }
      for (final p in pathSet) {
        if (p.endsWith(item.title.toLowerCase())) return true;
      }
      return false;
    });
    await _save(prefs, list);
  }

  static Future<void> _save(
    SharedPreferences prefs,
    List<RecentActivityItem> items,
  ) async {
    final encoded = jsonEncode(items.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
