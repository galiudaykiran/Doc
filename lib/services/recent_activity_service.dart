import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_activity_item.dart';

class RecentActivityService {
  static const String _storageKey = 'hub_recent_activity_list_v2';
  static const int _maxItems = 10;

  static Future<List<RecentActivityItem>> getActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        return decoded.map((e) => RecentActivityItem.fromMap(e)).toList();
      } catch (_) {}
    }

    // Default seeded activities matching design reference
    final now = DateTime.now();
    final defaultList = [
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

    await _save(prefs, defaultList);
    return defaultList;
  }

  static Future<void> recordActivity({
    required String title,
    required String subtitle,
    required String type,
    String? targetPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getActivities();

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

    // Keep only last 10
    final trimmed = list.take(_maxItems).toList();
    await _save(prefs, trimmed);
  }

  static Future<void> removeActivity({String? targetPath, String? title}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getActivities();
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
    final list = await getActivities();
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

