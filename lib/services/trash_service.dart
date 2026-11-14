import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a trashed item
class TrashedItem {
  final String id;
  final String originalPath;
  final String trashPath;
  final String name;
  final bool isFolder;
  final DateTime deletedAt;
  final int sizeBytes;

  TrashedItem({
    required this.id,
    required this.originalPath,
    required this.trashPath,
    required this.name,
    required this.isFolder,
    required this.deletedAt,
    this.sizeBytes = 0,
  });

  /// Days remaining before auto-purge (30 days)
  int get daysRemaining {
    final expiry = deletedAt.add(const Duration(days: 30));
    final remaining = expiry.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isExpired => daysRemaining <= 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalPath': originalPath,
    'trashPath': trashPath,
    'name': name,
    'isFolder': isFolder,
    'deletedAt': deletedAt.toIso8601String(),
    'sizeBytes': sizeBytes,
  };

  factory TrashedItem.fromJson(Map<String, dynamic> json) => TrashedItem(
    id: json['id'] as String,
    originalPath: json['originalPath'] as String,
    trashPath: json['trashPath'] as String,
    name: json['name'] as String,
    isFolder: json['isFolder'] as bool? ?? false,
    deletedAt: DateTime.parse(json['deletedAt'] as String),
    sizeBytes: json['sizeBytes'] as int? ?? 0,
  );
}

/// Service to manage a local trash/recycle bin
class TrashService {
  TrashService._();
  static final TrashService instance = TrashService._();

  static const String _trashMetaKey = 'trash_items_meta';

  /// Get the trash directory path
  Future<Directory> get _trashDir async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}${Platform.pathSeparator}DocumentHub_Trash');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}${Platform.pathSeparator}trash_Fallback');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  Future<void> _safeFileMove(File source, String destPath) async {
    if (!await source.exists()) return;

    final destDir = File(destPath).parent;
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    
    try {
      await source.copy(destPath);
      // Wait a tiny bit for IO buffer
      await Future.delayed(const Duration(milliseconds: 50));
      
      if (await File(destPath).exists()) {
        try {
          await source.delete();
        } catch (_) {
          // If delete fails, ignore. Copy succeeded!
        }
      } else {
        throw Exception('File copy failed silently');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Safely move/rename a directory, falling back to recursive copy+delete
  Future<void> _safeDirMove(Directory source, String destPath) async {
    try {
      await source.rename(destPath);
    } catch (_) {
      // Recursive copy + delete fallback for cross-device moves
      final destDir = Directory(destPath);
      await destDir.create(recursive: true);
      await for (final entity in source.list(recursive: false)) {
        final entityName = entity.path.split(RegExp(r'[/\\]')).last;
        final newPath = '$destPath${Platform.pathSeparator}$entityName';
        if (entity is File) {
          await entity.copy(newPath);
        } else if (entity is Directory) {
          await _safeDirMove(entity, newPath);
        }
      }
      await source.delete(recursive: true);
    }
  }

  /// Load all trashed items metadata
  Future<List<TrashedItem>> getAllTrashedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_trashMetaKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => TrashedItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    } catch (e) {
      debugPrint('TrashService: Error loading trash metadata: $e');
      return [];
    }
  }

  /// Save trashed items metadata
  Future<void> _saveTrashedItems(List<TrashedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_trashMetaKey, jsonStr);
  }

  /// Calculate size of a file or directory
  Future<int> _calculateSize(FileSystemEntity entity) async {
    try {
      if (entity is File) {
        return await entity.length();
      } else if (entity is Directory) {
        int total = 0;
        await for (final child in entity.list(recursive: true)) {
          if (child is File) {
            total += await child.length();
          }
        }
        return total;
      }
    } catch (e) {
      debugPrint('TrashService: Error calculating size: $e');
    }
    return 0;
  }

  /// Move a file to trash instead of permanently deleting it
  Future<bool> moveFileToTrash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('TrashService: File does not exist: $filePath');
        return false;
      }

      // Evict any cached images to release file handles on Windows
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await Future.delayed(const Duration(milliseconds: 50));

      final trashDir = await _trashDir;
      debugPrint('TrashService: Trash dir: ${trashDir.path}');
      
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final name = filePath.split(RegExp(r'[/\\]')).last;
      final trashPath = '${trashDir.path}${Platform.pathSeparator}${id}_$name';

      final sizeBytes = await _calculateSize(file);
      debugPrint('TrashService: Moving file $name ($sizeBytes bytes) to trash');
      
      await _safeFileMove(file, trashPath);

      // Verify the file was actually moved
      if (!await File(trashPath).exists()) {
        debugPrint('TrashService: File was not found at trash path after move!');
        return false;
      }

      final item = TrashedItem(
        id: id,
        originalPath: filePath,
        trashPath: trashPath,
        name: name,
        isFolder: false,
        deletedAt: DateTime.now(),
        sizeBytes: sizeBytes,
      );

      final items = await getAllTrashedItems();
      items.add(item);
      await _saveTrashedItems(items);
      
      debugPrint('TrashService: Successfully moved $name to trash');
      return true;
    } catch (e) {
      debugPrint('TrashService: Error moving file to trash: $e');
      return false;
    }
  }

  /// Move a folder to trash
  Future<bool> moveFolderToTrash(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        debugPrint('TrashService: Folder does not exist: $folderPath');
        return false;
      }

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await Future.delayed(const Duration(milliseconds: 50));

      final trashDir = await _trashDir;
      debugPrint('TrashService: Trash dir: ${trashDir.path}');
      
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final name = folderPath.split(RegExp(r'[/\\]')).last;
      final trashPath = '${trashDir.path}${Platform.pathSeparator}${id}_$name';

      final sizeBytes = await _calculateSize(dir);
      debugPrint('TrashService: Moving folder $name ($sizeBytes bytes) to trash');
      
      await _safeDirMove(dir, trashPath);

      // Verify the folder was actually moved
      if (!await Directory(trashPath).exists()) {
        debugPrint('TrashService: Folder was not found at trash path after move!');
        return false;
      }

      final item = TrashedItem(
        id: id,
        originalPath: folderPath,
        trashPath: trashPath,
        name: name,
        isFolder: true,
        deletedAt: DateTime.now(),
        sizeBytes: sizeBytes,
      );

      final items = await getAllTrashedItems();
      items.add(item);
      await _saveTrashedItems(items);
      
      debugPrint('TrashService: Successfully moved folder $name to trash');
      return true;
    } catch (e) {
      debugPrint('TrashService: Error moving folder to trash: $e');
      return false;
    }
  }

  /// Restore a trashed item to its original location
  Future<bool> restoreItem(TrashedItem item) async {
    try {
      if (item.isFolder) {
        final dir = Directory(item.trashPath);
        if (!await dir.exists()) {
          debugPrint('TrashService: Trash folder not found at: ${item.trashPath}');
          // Clean up orphaned metadata
          final items = await getAllTrashedItems();
          items.removeWhere((i) => i.id == item.id);
          await _saveTrashedItems(items);
          return false;
        }

        // Ensure the parent directory exists
        final parentDir = Directory(item.originalPath).parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        // Check if original path already exists
        if (await Directory(item.originalPath).exists()) {
          final newPath = '${item.originalPath}_restored';
          await _safeDirMove(dir, newPath);
        } else {
          await _safeDirMove(dir, item.originalPath);
        }
      } else {
        final file = File(item.trashPath);
        if (!await file.exists()) {
          debugPrint('TrashService: Trash file not found at: ${item.trashPath}');
          // Clean up orphaned metadata
          final items = await getAllTrashedItems();
          items.removeWhere((i) => i.id == item.id);
          await _saveTrashedItems(items);
          return false;
        }

        // Ensure the parent directory exists
        final parentDir = File(item.originalPath).parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        if (await File(item.originalPath).exists()) {
          final ext = item.name.contains('.')
              ? '.${item.name.split('.').last}'
              : '';
          final baseName = item.name.contains('.')
              ? item.name.substring(0, item.name.lastIndexOf('.'))
              : item.name;
          final newPath =
              '${parentDir.path}${Platform.pathSeparator}${baseName}_restored$ext';
          await _safeFileMove(file, newPath);
        } else {
          await _safeFileMove(file, item.originalPath);
        }
      }

      // Remove from metadata
      final items = await getAllTrashedItems();
      items.removeWhere((i) => i.id == item.id);
      await _saveTrashedItems(items);
      
      debugPrint('TrashService: Successfully restored ${item.name}');
      return true;
    } catch (e) {
      debugPrint('TrashService: Error restoring item: $e');
      return false;
    }
  }

  /// Restore a trashed item by its original path
  Future<bool> restorePath(String originalPath) async {
    try {
      final items = await getAllTrashedItems();
      final item = items.cast<TrashedItem?>().firstWhere(
        (i) => i?.originalPath == originalPath,
        orElse: () => null,
      );
      if (item == null) {
        debugPrint(
          'TrashService: No trashed item found for path: $originalPath',
        );
        return false;
      }
      return restoreItem(item);
    } catch (e) {
      debugPrint('TrashService: Error restoring by path: $e');
      return false;
    }
  }

  /// Permanently delete a trashed item
  Future<bool> permanentlyDelete(TrashedItem item) async {
    try {
      if (item.isFolder) {
        final dir = Directory(item.trashPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } else {
        final file = File(item.trashPath);
        if (await file.exists()) {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          await Future.delayed(const Duration(milliseconds: 50));
          await file.delete();
        }
      }

      final items = await getAllTrashedItems();
      items.removeWhere((i) => i.id == item.id);
      await _saveTrashedItems(items);

      return true;
    } catch (e) {
      debugPrint('TrashService: Error permanently deleting: $e');
      return false;
    }
  }

  /// Empty entire trash
  Future<void> emptyTrash() async {
    try {
      final trashDir = await _trashDir;
      if (await trashDir.exists()) {
        await for (final entity in trashDir.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }
      await _saveTrashedItems([]);
    } catch (e) {
      debugPrint('TrashService: Error emptying trash: $e');
    }
  }

  /// Auto-purge expired items (older than 30 days)
  Future<int> autoPurgeExpired() async {
    final items = await getAllTrashedItems();
    final expired = items.where((i) => i.isExpired).toList();

    for (final item in expired) {
      await permanentlyDelete(item);
    }

    return expired.length;
  }

  /// Get total trash size in bytes
  Future<int> getTrashSize() async {
    final items = await getAllTrashedItems();
    return items.fold<int>(0, (sum, item) => sum + item.sizeBytes);
  }

  /// Get trash item count
  Future<int> getTrashCount() async {
    final items = await getAllTrashedItems();
    return items.length;
  }
}
