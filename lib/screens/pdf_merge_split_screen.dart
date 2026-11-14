import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:gallery_app/utils/text_utils.dart';
import 'package:gallery_app/widgets/pdf_source_picker.dart';
import 'package:gallery_app/theme/app_theme.dart';

class PdfMergeSplitScreen extends StatefulWidget {
  const PdfMergeSplitScreen({super.key});

  @override
  State<PdfMergeSplitScreen> createState() => _PdfMergeSplitScreenState();
}

class _PdfMergeSplitScreenState extends State<PdfMergeSplitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Merge state
  final List<_PdfFileEntry> _mergeFiles = [];
  bool _isMerging = false;

  // Split state
  String? _splitFilePath;
  String? _splitFileName;
  int _splitTotalPages = 0;
  int _splitFromPage = 1;
  int _splitToPage = 1;
  bool _isSplitting = false;
  bool _splitAllPages = false;
  bool _splitAsImages = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============ MERGE ============

  Future<void> _addPdfForMerge() async {
    final paths = await PdfSourcePicker.pickMultiplePdfs(
      context,
      title: 'Add PDF Files to Merge',
    );

    if (paths != null && paths.isNotEmpty) {
      for (final filePath in paths) {
        final file = File(filePath);
        if (await file.exists()) {
          int pageCount = 0;
          Uint8List? thumb;
          final fileName = filePath.split(Platform.pathSeparator).last;
          final sizeBytes = await file.length();
          try {
            final bytes = await file.readAsBytes();
            await for (final page in Printing.raster(bytes, dpi: 40)) {
              if (pageCount == 0) {
                thumb = await page.toPng();
              }
              pageCount++;
            }
          } catch (_) {
            pageCount = 0;
          }

          setState(() {
            _mergeFiles.add(
              _PdfFileEntry(
                path: filePath,
                name: fileName,
                pageCount: pageCount,
                sizeBytes: sizeBytes,
                thumbnail: thumb,
              ),
            );
          });
        }
      }
    }
  }

  void _removeMergeFile(int index) {
    setState(() {
      _mergeFiles.removeAt(index);
    });
  }

  void _reorderMergeFiles(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _mergeFiles.removeAt(oldIndex);
      _mergeFiles.insert(newIndex, item);
    });
  }

  Future<void> _mergePdfs() async {
    if (_mergeFiles.length < 2) {
      Fluttertoast.showToast(msg: 'Add at least 2 PDF files to merge');
      return;
    }

    setState(() => _isMerging = true);

    try {
      final pdf = pw.Document();

      for (final entry in _mergeFiles) {
        final file = File(entry.path);
        final bytes = await file.readAsBytes();

        // Rasterize each page and add as image to the merged PDF
        await for (final page in Printing.raster(bytes, dpi: 200)) {
          final image = await page.toPng();
          final pdfImage = pw.MemoryImage(image);

          pdf.addPage(
            pw.Page(
              margin: pw.EdgeInsets.zero,
              build: (context) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
            ),
          );
        }
      }

      final outputBytes = await pdf.save();
      final folderPath = await _promptForFolder();
      if (folderPath == null) {
        setState(() => _isMerging = false);
        return;
      }
      final result = await _savePdf(outputBytes, 'merged', targetDirectory: folderPath);

      if (result != null) {
        if (mounted) {
          _showSuccessDialog(result, 'PDF Merged Successfully');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error merging PDFs: $e');
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  // ============ SPLIT ============

  Future<void> _pickPdfForSplit() async {
    final filePath = await PdfSourcePicker.pickSinglePdf(
      context,
      title: 'Select PDF to Split',
    );

    if (filePath != null) {
      final file = File(filePath);
      if (!await file.exists()) return;
      final fileName = filePath.split(Platform.pathSeparator).last;

      int pageCount = 0;
      try {
        final bytes = await file.readAsBytes();
        await for (final _ in Printing.raster(bytes, dpi: 36)) {
          pageCount++;
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error reading PDF: $e');
        return;
      }

      if (pageCount < 2) {
        Fluttertoast.showToast(msg: 'PDF has only 1 page, cannot split');
        return;
      }

      setState(() {
        _splitFilePath = filePath;
        _splitFileName = fileName;
        _splitTotalPages = pageCount;
        _splitFromPage = 1;
        _splitToPage = pageCount;
        _splitAllPages = false;
      });
    }
  }

  Future<void> _splitPdf() async {
    if (_splitFilePath == null) return;

    setState(() => _isSplitting = true);

    try {
      final bytes = await File(_splitFilePath!).readAsBytes();
      final pages = <Uint8List>[];

      await for (final page in Printing.raster(bytes, dpi: 200)) {
        pages.add(await page.toPng());
      }

      if (_splitAsImages) {
        final folderPath = await _promptForFolder();
        if (folderPath == null) {
          setState(() => _isSplitting = false);
          return;
        }

        final cleanBase = (_splitFileName ?? 'doc').replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final savedPaths = <String>[];
        final startIdx = _splitAllPages ? 0 : (_splitFromPage - 1);
        final endIdx = _splitAllPages ? pages.length : _splitToPage;

        for (int i = startIdx; i < endIdx; i++) {
          final pageNum = i + 1;
          var fileName = '${cleanBase}_page_$pageNum.png';
          var outPath = '$folderPath${Platform.pathSeparator}$fileName';
          if (await File(outPath).exists()) {
            final ts = DateTime.now().millisecondsSinceEpoch;
            fileName = '${cleanBase}_page_${pageNum}_$ts.png';
            outPath = '$folderPath${Platform.pathSeparator}$fileName';
          }
          await File(outPath).writeAsBytes(pages[i]);
          savedPaths.add(outPath);
        }

        if (mounted && savedPaths.isNotEmpty) {
          _showSuccessDialog(savedPaths.first, '${savedPaths.length} Split Images Saved');
        }
        return;
      }

      if (_splitAllPages) {
        final folderPath = await _promptForFolder();
        if (folderPath == null) {
          setState(() => _isSplitting = false);
          return;
        }
        // Split into individual pages
        final savedPaths = <String>[];
        for (int i = 0; i < pages.length; i++) {
          final pdf = pw.Document();
          final pdfImage = pw.MemoryImage(pages[i]);

          pdf.addPage(
            pw.Page(
              margin: pw.EdgeInsets.zero,
              build: (context) =>
                  pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
            ),
          );

          final outputBytes = await pdf.save();
          final path = await _savePdf(
            outputBytes,
            'split_page_${i + 1}',
            silent: true,
            targetDirectory: folderPath,
          );
          if (path != null) savedPaths.add(path);
        }

        if (mounted && savedPaths.isNotEmpty) {
          Fluttertoast.showToast(
            msg: '${savedPaths.length} pages saved successfully',
          );
        }
      } else {
        // Split range
        final from = _splitFromPage - 1; // 0-indexed
        final to = _splitToPage; // exclusive end

        if (from < 0 || to > pages.length || from >= to) {
          Fluttertoast.showToast(msg: 'Invalid page range');
          setState(() => _isSplitting = false);
          return;
        }

        final pdf = pw.Document();
        for (int i = from; i < to; i++) {
          final pdfImage = pw.MemoryImage(pages[i]);
          pdf.addPage(
            pw.Page(
              margin: pw.EdgeInsets.zero,
              build: (context) =>
                  pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
            ),
          );
        }

        final outputBytes = await pdf.save();
        final folderPath = await _promptForFolder();
        if (folderPath == null) {
          setState(() => _isSplitting = false);
          return;
        }
        final result = await _savePdf(
          outputBytes,
          'split_p$_splitFromPage-p$_splitToPage',
          targetDirectory: folderPath,
        );

        if (result != null && mounted) {
          _showSuccessDialog(result, 'PDF Split Successfully');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error splitting PDF: $e');
    } finally {
      if (mounted) setState(() => _isSplitting = false);
    }
  }

  // ============ HELPERS ============

  Future<String?> _promptForFolder() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory rootDir = Directory(
      '${appDocDir.path}${Platform.pathSeparator}document_folders',
    );
    if (!await rootDir.exists()) await rootDir.create(recursive: true);

    final List<FileSystemEntity> entities = rootDir.listSync();
    final List<Directory> folders = entities.whereType<Directory>().toList();

    if (folders.isEmpty) {
      return rootDir.path;
    }

    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Folder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: Icon(Icons.folder_shared_rounded, color: Theme.of(context).primaryColor),
                  title: Text('Root Directory', style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(context, rootDir.path),
                );
              }
              final folder = folders[index - 1];
              return ListTile(
                leading: Icon(Icons.folder_rounded, color: Theme.of(context).primaryColor.withOpacity(0.7)),
                title: Text(folder.path.split(Platform.pathSeparator).last, style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, folder.path),
              );
            },
          ),
        ),
      ),
    );
    return selectedPath;
  }

  Future<String?> _savePdf(
    Uint8List bytes,
    String prefix, {
    bool silent = false,
    String? targetDirectory,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final destinationFolder = targetDirectory ?? '${appDir.path}${Platform.pathSeparator}document_folders';
      final dir = Directory(destinationFolder);
      if (!await dir.exists()) await dir.create(recursive: true);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${prefix}_$timestamp.pdf';
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!silent) {
        Fluttertoast.showToast(msg: 'Saved: $fileName');
      }
      return filePath;
    } catch (e) {
      if (!silent) {
        Fluttertoast.showToast(msg: 'Error saving PDF: $e');
      }
      return null;
    }
  }

  void _showSuccessDialog(String filePath, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'File saved to:\n$filePath',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(filePath)]);
            },
            child: Text(
              'Share',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    return TextUtils.formatFileSize(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppTheme.isDark(context);
    final appBarTextColor = AppTheme.textPrimary(context);
    final appBarIconBg = AppTheme.tonal(context);
    final appBarIconBorder = AppTheme.surfaceBorder(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: AppTheme.background(context),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: appBarIconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: appBarIconBorder,
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, size: 22, color: appBarTextColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ),
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                        gradient: LinearGradient(
                          colors: [
                            isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            isDark ? Colors.transparent : Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                      ),
                      child: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 70, bottom: 16),
                        centerTitle: false,
                        title: Text(
                          'PDF Tools',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            color: appBarTextColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        background: Stack(
                          children: [
                            Positioned(
                              right: 30,
                              bottom: 30,
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 90,
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.primaryColor,
                unselectedLabelColor: theme.textTheme.bodySmall?.color,
                indicatorColor: theme.primaryColor,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                    icon: Icon(Icons.merge_rounded, color: isDark ? Colors.white : theme.primaryColor),
                    text: 'Merge',
                  ),
                  Tab(
                    icon: Icon(Icons.call_split_rounded, color: isDark ? Colors.white : theme.primaryColor),
                    text: 'Split',
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMergeTab(theme), _buildSplitTab(theme)],
            ),
          ),
        ],
      ), // End CustomScrollView
        ],
      ), // End Stack
    ); // End Scaffold
  }

  Widget _buildMergeTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add files button
          InkWell(
            onTap: _addPdfForMerge,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.2) : theme.primaryColor.withOpacity(0.3),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 40,
                    color: isDark ? Colors.white : theme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add PDF Files',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                    ),
                  ),
                  Text(
                    'Tap to select PDF files to merge',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_mergeFiles.isNotEmpty) ...[
            Text(
              '${_mergeFiles.length} files selected',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              'Long press and drag to reorder',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mergeFiles.length,
              onReorder: _reorderMergeFiles,
              itemBuilder: (context, index) {
                final entry = _mergeFiles[index];
                return Container(
                  key: ValueKey(entry.path),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: entry.thumbnail != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              entry.thumbnail!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Colors.red,
                            ),
                          ),
                    title: Text(
                      entry.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${entry.pageCount} pages • ${_formatSize(entry.sizeBytes)}',
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                            onPressed: () => _reorderMergeFiles(index, index - 1),
                            tooltip: 'Move Up',
                          ),
                        if (index < _mergeFiles.length - 1)
                          IconButton(
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            onPressed: () => _reorderMergeFiles(index, index + 2),
                            tooltip: 'Move Down',
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => _removeMergeFile(index),
                          tooltip: 'Remove',
                        ),
                        const Icon(Icons.drag_handle_rounded, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMerging ? null : _mergePdfs,
                icon: _isMerging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.merge_rounded),
                label: Text(
                  _isMerging ? 'Merging...' : 'Merge PDFs',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pick file button
          InkWell(
            onTap: _pickPdfForSplit,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.2) : theme.primaryColor.withOpacity(0.3),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    size: 40,
                    color: isDark ? Colors.white : theme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _splitFilePath == null
                        ? 'Select a PDF to Split'
                        : _splitFileName ?? 'PDF Selected',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : theme.primaryColor,
                    ),
                  ),
                  if (_splitFilePath != null)
                    Text(
                      '$_splitTotalPages pages • Tap to change',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_splitFilePath != null) ...[
            const SizedBox(height: 24),

            // Split options
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split Options',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Export as Split Images (PNG)',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _splitAsImages
                          ? 'Extract pages as high-resolution PNG images'
                          : 'Save pages as PDF documents',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    value: _splitAsImages,
                    onChanged: (val) => setState(() => _splitAsImages = val),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Split into individual pages',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _splitAsImages
                          ? 'Extracts all $_splitTotalPages pages as separate images'
                          : 'Creates $_splitTotalPages separate PDF files',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    value: _splitAllPages,
                    onChanged: (val) => setState(() => _splitAllPages = val),
                  ),
                  if (!_splitAllPages) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Extract page range',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From page',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              DropdownButton<int>(
                                value: _splitFromPage,
                                isExpanded: true,
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    _splitFromPage = val;
                                    if (_splitToPage < val) {
                                      _splitToPage = val;
                                    }
                                  });
                                },
                                items: List.generate(
                                  _splitTotalPages,
                                  (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text('Page ${i + 1}'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'To page',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              DropdownButton<int>(
                                value: _splitToPage,
                                isExpanded: true,
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() => _splitToPage = val);
                                },
                                items: List.generate(
                                  _splitTotalPages - _splitFromPage + 1,
                                  (i) => DropdownMenuItem(
                                    value: _splitFromPage + i,
                                    child: Text('Page ${_splitFromPage + i}'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSplitting ? null : _splitPdf,
                icon: _isSplitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.call_split_rounded),
                label: Text(
                  _isSplitting ? 'Splitting...' : 'Split PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfFileEntry {
  final String path;
  final String name;
  final int pageCount;
  final int sizeBytes;
  final Uint8List? thumbnail;

  _PdfFileEntry({
    required this.path,
    required this.name,
    required this.pageCount,
    required this.sizeBytes,
    this.thumbnail,
  });
}
