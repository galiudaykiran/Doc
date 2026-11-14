import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Performance utilities for heavy operations
class PerformanceUtils {
  /// Run file operations in isolate to prevent UI lag
  static Future<List<FileSystemEntity>> listDirectoryAsync(String path) async {
    return compute(_listDirectorySync, path);
  }

  static List<FileSystemEntity> _listDirectorySync(String path) {
    try {
      final directory = Directory(path);
      if (!directory.existsSync()) return [];
      return directory.listSync();
    } catch (e) {
      return [];
    }
  }

  /// Get file size asynchronously
  static Future<int> getFileSizeAsync(String path) async {
    return compute(_getFileSizeSync, path);
  }

  static int _getFileSizeSync(String path) {
    try {
      return File(path).lengthSync();
    } catch (e) {
      return 0;
    }
  }

  /// Check if file exists asynchronously
  static Future<bool> fileExistsAsync(String path) async {
    return compute(_fileExistsSync, path);
  }

  static bool _fileExistsSync(String path) {
    try {
      return File(path).existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Batch file statistics
  static Future<Map<String, FileStat>> getFileStatsAsync(
    List<String> paths,
  ) async {
    return compute(_getFileStatsSync, paths);
  }

  static Map<String, FileStat> _getFileStatsSync(List<String> paths) {
    final Map<String, FileStat> stats = {};
    for (final path in paths) {
      try {
        stats[path] = File(path).statSync();
      } catch (e) {
        // Skip failed files
      }
    }
    return stats;
  }
}

/// Debouncer for search and input operations
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Throttler for scroll operations
class Throttler {
  final Duration duration;
  DateTime? _lastExecuted;

  Throttler({this.duration = const Duration(milliseconds: 100)});

  void call(void Function() action) {
    final now = DateTime.now();
    if (_lastExecuted == null || now.difference(_lastExecuted!) > duration) {
      _lastExecuted = now;
      action();
    }
  }
}
