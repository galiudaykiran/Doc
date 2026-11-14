import 'dart:io';
import 'package:archive/archive_io.dart';

/// 100% Offline ZIP Compression and Extraction Service
class ZipService {
  ZipService._();

  /// Create a ZIP archive from a list of files
  static Future<File?> createZipFromFiles(
    List<File> files,
    String destinationZipPath,
  ) async {
    try {
      final archive = Archive();

      for (final file in files) {
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final fileName = file.uri.pathSegments.last;
        final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
        archive.addFile(archiveFile);
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;
      final zipFile = File(destinationZipPath);
      await zipFile.writeAsBytes(zipData);
      return zipFile;
    } catch (e) {
      return null;
    }
  }

  /// Create a ZIP archive from an entire directory
  static Future<File?> compressDirectory(
    Directory directory,
    String destinationZipPath,
  ) async {
    try {
      final archive = Archive();
      final entities = directory.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
        if (entity is File) {
          final relativePath = entity.path.substring(directory.path.length + 1);
          final bytes = await entity.readAsBytes();
          final archiveFile = ArchiveFile(relativePath, bytes.length, bytes);
          archive.addFile(archiveFile);
        }
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;
      final zipFile = File(destinationZipPath);
      await zipFile.writeAsBytes(zipData);
      return zipFile;
    } catch (e) {
      return null;
    }
  }

  /// Extract a ZIP archive into a target directory
  static Future<int> extractZipToDirectory(
    File zipFile,
    Directory targetDirectory,
  ) async {
    try {
      if (!await zipFile.exists()) return 0;
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      int extractedCount = 0;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${targetDirectory.path}${Platform.pathSeparator}$filename');
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
          extractedCount++;
        }
      }
      return extractedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Alias for compressDirectory
  static Future<File?> createZipFromFolder(
    Directory directory,
    String destinationZipPath,
  ) => compressDirectory(directory, destinationZipPath);

  /// Alias for extracting to a folder path, returning extracted files
  static Future<List<File>> extractZipToFolder(
    File zipFile,
    String targetPath,
  ) async {
    final count = await extractZipToDirectory(zipFile, Directory(targetPath));
    if (count > 0) {
      return Directory(targetPath).listSync().whereType<File>().toList();
    }
    return [];
  }
}
