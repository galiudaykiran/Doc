import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';

import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_app/models/file_info.dart';
import 'package:gallery_app/models/folder_info.dart';
import 'package:gallery_app/screens/file_view_page.dart';
import 'package:gallery_app/screens/notes_page.dart';
import 'package:gallery_app/screens/pdf_preview_screen.dart';
import 'package:gallery_app/screens/todo_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery_app/services/folder_lock_service.dart';
import 'package:gallery_app/widgets/optimized_image.dart';
import 'package:gallery_app/services/document_scanner_service.dart';
import 'package:gallery_app/services/trash_service.dart';
import 'package:gallery_app/services/recent_activity_service.dart';
import 'package:gallery_app/screens/document_metadata_screen.dart';
import 'package:gallery_app/services/zip_service.dart';
import 'package:gallery_app/utils/responsive_layout.dart';
import 'package:gallery_app/utils/text_utils.dart';
import 'package:printing/printing.dart';
import 'package:gallery_app/theme/app_theme.dart';
import 'package:gallery_app/widgets/voice_search_sheet.dart';
import 'package:gallery_app/widgets/duplicate_file_dialog.dart';
import 'package:gallery_app/screens/text_extraction_screen.dart';
import 'pdf_tools_screen.dart';

class FolderImagesPage extends StatefulWidget {
  final FolderInfo folder;
  final bool isLocked;

  const FolderImagesPage({
    super.key,
    required this.folder,
    this.isLocked = false,
  });

  @override
  State<FolderImagesPage> createState() => _FolderImagesPageState();
}

enum FileSortOption {
  dateAscending,
  dateDescending,
  sizeAscending,
  sizeDescending,
  nameAscending,
  nameDescending,
}

class _FolderImagesPageState extends State<FolderImagesPage>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  List<FileInfo> _files = [];
  bool _isLoading = true;
  bool _multiSelectMode = false;
  final List<FileInfo> _selectedFiles = [];
  FileSortOption _currentSortOption = FileSortOption.dateAscending;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterCategory = 'All';
  List<String> _favoriteFiles = [];
  bool _isLockedSession = false;
  bool _isGridView = true;

  List<FileInfo> get _filteredFiles {
    return _files.where((f) {
      if (_searchQuery.isNotEmpty && !f.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_filterCategory == 'Images' && f.type != FileType.image) return false;
      if (_filterCategory == 'PDFs' && f.type != FileType.pdf) return false;
      if (_filterCategory == 'Documents' && f.type != FileType.document) return false;
      if (_filterCategory == 'Favorites' && !_favoriteFiles.contains(f.path)) return false;
      return true;
    }).toList();
  }

  int _getCategoryCount(String category) {
    switch (category) {
      case 'All':
        return _files.length;
      case 'Images':
        return _files.where((f) => f.type == FileType.image).length;
      case 'PDFs':
        return _files.where((f) => f.type == FileType.pdf).length;
      case 'Documents':
        return _files.where((f) => f.type == FileType.document).length;
      case 'Favorites':
        return _files.where((f) => _favoriteFiles.contains(f.path)).length;
      default:
        return 0;
    }
  }

  Widget _buildFolderFilterChip(String label, IconData icon) {
    final isSelected = _filterCategory == label;
    final count = _getCategoryCount(label);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filterCategory = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryContainer(context)
              : AppTheme.tonal(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary(context)
                : AppTheme.surfaceBorder(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppTheme.onPrimaryContainer(context)
                  : AppTheme.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.onPrimaryContainer(context)
                    : AppTheme.textSecondary(context),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary(context).withOpacity(0.18)
                      : AppTheme.surfaceBorder(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppTheme.onPrimaryContainer(context)
                        : AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    WidgetsBinding.instance.addObserver(this);
    // Determine lock state immediately using cached service data
    _isLockedSession =
        widget.isLocked && !FolderLockService.instance.isSessionValidSync();
    _loadFiles();
    _loadFavorites();
    _checkLockStatus();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isGridView = prefs.getBool('folder_is_grid_view_${widget.folder.path}') ?? prefs.getBool('default_view_is_grid') ?? true;
      });
    }
  }

  Future<void> _saveViewPreference(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('folder_is_grid_view_${widget.folder.path}', isGrid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  Future<void> _checkLockStatus() async {
    final service = FolderLockService.instance;
    final enabled = await service.isEnabled();

    // Check if current folder is among locked folders
    final lockedFolders = await service.lockedFolders();
    final isPathLocked = lockedFolders.contains(widget.folder.path);

    if (!enabled || !isPathLocked) {
      if (mounted) setState(() => _isLockedSession = false);
      return;
    }

    final isValid = await service.isSessionValid();
    if (isValid) {
      if (mounted) setState(() => _isLockedSession = false);
      return;
    }

    // Still locked
    if (mounted) setState(() => _isLockedSession = true);

    if (!mounted) return;
    final ok = await service.ensureUnlocked(
      context,
      reason: 'Unlock to view "${widget.folder.name}"',
    );
    if (mounted) {
      setState(() => _isLockedSession = !ok);
      if (!ok) {
        Navigator.pop(context); // Go back if unlock failed
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteFiles = prefs.getStringList('favorite_files') ?? [];
    });
  }

  Future<void> _toggleFileFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteFiles.contains(path)) {
        _favoriteFiles.remove(path);
      } else {
        _favoriteFiles.add(path);
      }
    });
    await prefs.setStringList('favorite_files', _favoriteFiles);
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final Directory folderDir = Directory(widget.folder.path);
      final List<FileSystemEntity> entities = await folderDir.list().toList();
      final List<FileInfo> files = [];

      for (var entity in entities) {
        if (entity is File) {
          files.add(
            FileInfo(
              name: entity.path.split(Platform.pathSeparator).last,
              path: entity.path,
              type: getFileType(entity.path),
            ),
          );
        } else if (entity is Directory) {
          // Include any files from subdirectories (e.g. extracted image folders)
          try {
            final subFiles = entity.listSync().whereType<File>();
            for (var subFile in subFiles) {
              files.add(
                FileInfo(
                  name: subFile.path.split(Platform.pathSeparator).last,
                  path: subFile.path,
                  type: getFileType(subFile.path),
                ),
              );
            }
          } catch (_) {}
        }
      }

      setState(() {
        _files = files;
        _sortFiles(); // Sort files after loading
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Error loading files: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _sortFiles() {
    _files.sort((a, b) {
      switch (_currentSortOption) {
        case FileSortOption.dateAscending:
          return a.lastModified.compareTo(b.lastModified);
        case FileSortOption.dateDescending:
          return b.lastModified.compareTo(a.lastModified);
        case FileSortOption.sizeAscending:
          return a.size.compareTo(b.size);
        case FileSortOption.sizeDescending:
          return b.size.compareTo(a.size);
        case FileSortOption.nameAscending:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case FileSortOption.nameDescending:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });
  }

  Future<void> _pickFiles() async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      if (result.files.length > 5) {
        showProcessingSnackBar(context, message: 'Importing ${result.files.length} files... This may take a few seconds');
      }

      setState(() {
        _isLoading = true;
      });

      DuplicateFileResolution? rememberedResolution;
      int importedCount = 0;

      for (var platformFile in result.files) {
        if (platformFile.path == null) continue;

        String targetFileName = platformFile.name;
        String targetPath =
            '${widget.folder.path}${Platform.pathSeparator}$targetFileName';

        if (File(targetPath).existsSync()) {
          DuplicateFileResolution resolution;
          if (rememberedResolution != null && rememberedResolution.applyToAll) {
            resolution = rememberedResolution;
          } else {
            final res = await DuplicateFileDialog.show(
              context,
              fileName: targetFileName,
              destinationFolderName: widget.folder.name,
              showApplyToAll: result.files.length > 1,
            );
            if (res == null || res.action == DuplicateFileAction.skip) {
              continue;
            }
            resolution = res;
            if (res.applyToAll) {
              rememberedResolution = res;
            }
          }

          if (resolution.action == DuplicateFileAction.replace) {
            await File(platformFile.path!).copy(targetPath);
            _files.removeWhere((f) => f.path == targetPath);
            _files.add(
              FileInfo(
                name: targetFileName,
                path: targetPath,
                type: getFileType(targetPath),
              ),
            );
            importedCount++;
            continue;
          } else if (resolution.action == DuplicateFileAction.keepBoth) {
            targetFileName = DuplicateFileDialog.generateUniqueFileName(
              widget.folder.path,
              targetFileName,
            );
            targetPath =
                '${widget.folder.path}${Platform.pathSeparator}$targetFileName';
          }
        }

        await File(platformFile.path!).copy(targetPath);
        _files.add(
          FileInfo(
            name: targetFileName,
            path: targetPath,
            type: getFileType(targetPath),
          ),
        );
        importedCount++;
      }

      _sortFiles();

      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: "$importedCount file(s) imported",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Error adding files: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile == null) return;

      final String fileName = pickedFile.path
          .split(Platform.pathSeparator)
          .last;
      String targetFileName = fileName;
      String targetPath =
          '${widget.folder.path}${Platform.pathSeparator}$targetFileName';

      if (File(targetPath).existsSync()) {
        final res = await DuplicateFileDialog.show(
          context,
          fileName: targetFileName,
          destinationFolderName: widget.folder.name,
        );
        if (res == null || res.action == DuplicateFileAction.skip) return;
        if (res.action == DuplicateFileAction.replace) {
          _files.removeWhere((f) => f.path == targetPath);
        } else if (res.action == DuplicateFileAction.keepBoth) {
          targetFileName = DuplicateFileDialog.generateUniqueFileName(
            widget.folder.path,
            targetFileName,
          );
          targetPath =
              '${widget.folder.path}${Platform.pathSeparator}$targetFileName';
        }
      }

      await File(pickedFile.path).copy(targetPath);

      setState(() {
        _files.add(
          FileInfo(
            name: targetFileName,
            path: targetPath,
            type: getFileType(targetPath),
          ),
        );
      });

      Fluttertoast.showToast(
        msg: "Image added from camera",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error adding image from camera: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _scanDocument() async {
    try {
      final scannerService = DocumentScannerService();

      // Scan document first using native UI
      final tempPdfPath = await scannerService.scanDocument();

      if (tempPdfPath == null) {
        Fluttertoast.showToast(
          msg: "Scan cancelled",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // Show loading dialog for processing after scanning is done
      if (!mounted) return;
      showProcessingSnackBar(context, message: 'Processing document... This may take a few seconds');
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Processing document...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saving as PDF',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      // Import scanned document to folder
      final savedPath = await scannerService.importToFolder(
        tempPdfPath,
        widget.folder.path,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (savedPath != null) {
        // Reload files to show the new document
        await _loadFiles();

        Fluttertoast.showToast(
          msg: "Document scanned successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: const Color(0xFF00BCD4),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Failed to save scanned document",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      Fluttertoast.showToast(
        msg: "Error scanning document: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
      );
    }
  }

  void _showNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) =>
            NotesPage(folderPath: widget.folder.path),
      ),
    );
  }

  Future<void> _makePdf() async {
    final List<FileInfo> availableImages = _files
        .where((file) => file.type == FileType.image)
        .toList();
    final List<FileInfo> availablePdfs = _files
        .where((file) => file.type == FileType.pdf)
        .toList();

    List<FileInfo> selectedImages = List.from(availableImages);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            final theme = Theme.of(context);

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Create PDF',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Import existing PDF button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(
                          availablePdfs.isNotEmpty
                              ? 'Import Pages from PDF (${availablePdfs.length} available)'
                              : 'Import Pages from PDF',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          FileInfo? chosenPdf;
                          if (availablePdfs.length == 1) {
                            chosenPdf = availablePdfs.first;
                          } else if (availablePdfs.length > 1) {
                            chosenPdf = await showModalBottomSheet<FileInfo>(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (ctx) => Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select PDF to Extract Pages',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...availablePdfs.map(
                                      (pdf) => ListTile(
                                        leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                                        title: Text(pdf.name, style: GoogleFonts.poppins(fontSize: 14)),
                                        onTap: () => Navigator.pop(ctx, pdf),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            // Pick from file picker
                            final pickRes = await fp.FilePicker.platform.pickFiles(
                              type: fp.FileType.custom,
                              allowedExtensions: ['pdf'],
                            );
                            if (pickRes != null && pickRes.files.isNotEmpty && pickRes.files.first.path != null) {
                              chosenPdf = FileInfo(
                                name: pickRes.files.first.name,
                                path: pickRes.files.first.path!,
                                type: FileType.pdf,
                              );
                            }
                          }

                          if (chosenPdf != null) {
                            try {
                              Fluttertoast.showToast(msg: "Extracting pages from ${chosenPdf.name}...");
                              final pdfFile = File(chosenPdf.path);
                              final pdfBytes = await pdfFile.readAsBytes();
                              final tempDir = await getTemporaryDirectory();
                              final timestamp = DateTime.now().millisecondsSinceEpoch;
                              int pIdx = 0;

                              await for (final page in Printing.raster(pdfBytes, dpi: 250)) {
                                final png = await page.toPng();
                                final pPath = '${tempDir.path}/pdf_page_${timestamp}_$pIdx.png';
                                await File(pPath).writeAsBytes(png);
                                final pageInfo = FileInfo(
                                  name: '${chosenPdf.name} (P.${pIdx + 1})',
                                  path: pPath,
                                  type: FileType.image,
                                );
                                availableImages.add(pageInfo);
                                selectedImages.add(pageInfo);
                                pIdx++;
                              }

                              dialogSetState(() {});
                              Fluttertoast.showToast(msg: "Added $pIdx pages from ${chosenPdf.name}");
                            } catch (e) {
                              Fluttertoast.showToast(msg: "Error extracting pages: $e");
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Pages (${selectedImages.length}/${availableImages.length})',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          TextButton(
                            onPressed: () {
                              dialogSetState(() {
                                if (selectedImages.length == availableImages.length) {
                                  selectedImages.clear();
                                } else {
                                  selectedImages = List.from(availableImages);
                                }
                              });
                            },
                            child: Text(
                              selectedImages.length == availableImages.length ? 'Deselect All' : 'Select All',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      if (availableImages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No images or pages yet.\nTap button above to import from a PDF!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                          ),
                          itemCount: availableImages.length,
                          itemBuilder: (BuildContext context, int index) {
                            final imageFile = availableImages[index];
                            final isSelected = selectedImages.contains(imageFile);
                            return GestureDetector(
                              onTap: () {
                                dialogSetState(() {
                                  if (isSelected) {
                                    selectedImages.remove(imageFile);
                                  } else {
                                    selectedImages.add(imageFile);
                                  }
                                });
                              },
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(imageFile.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.45),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedImages.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfPreviewScreen(
                                initialImages: selectedImages,
                                folderPath: widget.folder.path,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadFiles();
                          }
                        },
                  child: Text('Create PDF (${selectedImages.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFileOptions(FileInfo file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(file.icon, color: Theme.of(context).primaryColor),
              ),
              title: Text(
                file.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                file.type.toString().split('.').last.toUpperCase(),
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ),
            const Divider(indent: 24, endIndent: 24),
            ListTile(
              leading: Icon(
                _favoriteFiles.contains(file.path)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _favoriteFiles.contains(file.path)
                    ? Colors.redAccent
                    : Colors.grey,
              ),
              title: Text(
                _favoriteFiles.contains(file.path)
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleFileFavorite(file.path);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.share_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                'Share',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _shareFile(file);
              },
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move_rounded, color: Theme.of(context).primaryColor),
              title: Text(
                'Move to Folder',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _moveFile(file);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, color: Theme.of(context).primaryColor),
              title: Text(
                'Copy to Folder',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _copyFile(file);
              },
            ),
            if (file.type == FileType.image) ...[
              ListTile(
                leading: Icon(Icons.document_scanner_rounded, color: Theme.of(context).primaryColor),
                title: Text(
                  'Extract Text (OCR)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Extract text to share or convert into PDF',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TextExtractionScreen(
                        initialImagePath: file.path,
                        autoExtractTitle: file.name,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (file.type == FileType.pdf) ...[
              ListTile(
                leading: Icon(Icons.call_split_rounded, color: Theme.of(context).primaryColor),
                title: Text(
                  'Split PDF to Images',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Extract each page as an image into this folder',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _splitPdfToImages(file);
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_fix_high_rounded, color: Theme.of(context).primaryColor),
                title: Text(
                  'Edit PDF Tools',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfToolsScreen(initialFilePath: file.path),
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.edit_rounded, color: Theme.of(context).primaryColor),
              title: Text(
                'Rename',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _renameFile(file);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                'Details',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _showFileDetails(file);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.redAccent,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileDetails(FileInfo file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'File Details',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailItem('Name', file.name),
            _buildDetailItem('Path', file.path),
            FutureBuilder<FileStat>(
              future: File(file.path).stat(),
              builder: (BuildContext context, AsyncSnapshot<FileStat> snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        'Size',
                        TextUtils.formatFileSize(snapshot.data!.size),
                      ),
                      _buildDetailItem(
                        'Last Modified',
                        snapshot.data!.modified.toString().substring(0, 16),
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Text(
                    'Error loading details',
                    style: GoogleFonts.poppins(color: Colors.red),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.security_rounded, size: 18),
                label: const Text('View SHA-256 & Cryptographic Proof'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentMetadataScreen(fileInfo: file),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _splitPdfToImages(FileInfo file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.call_split_rounded, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Split PDF to Images',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Extract all pages of "${file.name}" as separate PNG images directly into "${widget.folder.name}"?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Extract Images',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showProcessingSnackBar(context, message: 'Extracting images from PDF... This may take a few seconds');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                'Extracting split images...',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Rendering pages at high resolution',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final pdfBytes = await File(file.path).readAsBytes();
      final cleanName = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      int pageNum = 0;

      await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
        pageNum++;
        final imageBytes = await page.toPng();
        var targetName = '${cleanName}_page_$pageNum.png';
        var targetPath = '${widget.folder.path}${Platform.pathSeparator}$targetName';
        if (await File(targetPath).exists()) {
          final ts = DateTime.now().millisecondsSinceEpoch;
          targetName = '${cleanName}_page_${pageNum}_$ts.png';
          targetPath = '${widget.folder.path}${Platform.pathSeparator}$targetName';
        }
        await File(targetPath).writeAsBytes(imageBytes);
      }

      if (mounted) {
        Navigator.pop(context); // close progress dialog
        await _loadFiles();
        Fluttertoast.showToast(
          msg: '$pageNum images extracted into "${widget.folder.name}"',
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close progress dialog
        Fluttertoast.showToast(msg: 'Error splitting PDF: $e');
      }
    }
  }

  Future<void> _shareFile(FileInfo file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Check out this file!');
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error sharing file: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _shareFilesAsZip(List<FileInfo> files) async {
    if (files.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/shared_files_${DateTime.now().millisecondsSinceEpoch}.zip';
      
      final zipFile = await ZipService.createZipFromFiles(
        files.map((f) => File(f.path)).toList(),
        zipPath,
      );

      // Remove loading indicator
      if (mounted) Navigator.pop(context);

      if (zipFile != null && await zipFile.exists()) {
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'Sharing ${files.length} files as a ZIP archive',
        );
      }
    } catch (e) {
      // Remove loading indicator
      if (mounted) Navigator.pop(context);
      
      Fluttertoast.showToast(
        msg: "Error creating ZIP: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  /// Compress this entire folder into a ZIP archive saved directly inside the folder
  Future<void> _compressFolderToZip() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String cleanFolderName = widget.folder.name.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final String zipFileName = '${cleanFolderName}_archive_$timestamp.zip';
      final String destPath = '${widget.folder.path}${Platform.pathSeparator}$zipFileName';

      final zipFile = await ZipService.createZipFromFolder(
        Directory(widget.folder.path),
        destPath,
      );

      if (mounted) Navigator.pop(context);

      if (zipFile != null && await zipFile.exists()) {
        await _loadFiles();
        Fluttertoast.showToast(msg: "Folder archived as $zipFileName");
      } else {
        Fluttertoast.showToast(msg: "Could not create ZIP archive");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(msg: "Error archiving folder: $e");
    }
  }

  /// Archive selected files directly inside this folder
  Future<void> _archiveSelectedFilesToFolder(List<FileInfo> files) async {
    if (files.isEmpty) return;

    final nameController = TextEditingController(
      text: 'selection_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );

    final archiveName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive to ZIP', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'ZIP File Name',
            suffixText: '.zip',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (archiveName == null || archiveName.isEmpty) return;

    showProcessingSnackBar(context, message: 'Creating ZIP archive... This may take a few seconds');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final zipFileName = archiveName.endsWith('.zip') ? archiveName : '$archiveName.zip';
      final destPath = '${widget.folder.path}${Platform.pathSeparator}$zipFileName';

      final zipFile = await ZipService.createZipFromFiles(
        files.map((f) => File(f.path)).toList(),
        destPath,
      );

      if (mounted) Navigator.pop(context);

      if (zipFile != null && await zipFile.exists()) {
        await _loadFiles();
        Fluttertoast.showToast(msg: "Saved $zipFileName to folder");
      } else {
        Fluttertoast.showToast(msg: "Failed to create archive");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(msg: "Error archiving files: $e");
    }
  }

  /// Import and extract a ZIP file directly into this folder
  Future<void> _importZipIntoFolder() async {
    final result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty || result.files.first.path == null) return;

    showProcessingSnackBar(context, message: 'Extracting ZIP archive... This may take a few seconds');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final zipFile = File(result.files.first.path!);
      final extracted = await ZipService.extractZipToFolder(
        zipFile,
        widget.folder.path,
      );

      if (mounted) Navigator.pop(context);

      if (extracted.isNotEmpty) {
        await _loadFiles();
        Fluttertoast.showToast(msg: "Extracted ${extracted.length} files into folder");
      } else {
        Fluttertoast.showToast(msg: "No files extracted from archive");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(msg: "Error extracting ZIP: $e");
    }
  }

  /// Extract text from multiple selected image files via OCR
  void _extractTextFromSelected() {
    final imageFiles = _selectedFiles.where((f) => f.type == FileType.image).toList();
    if (imageFiles.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please select image files to extract text.",
        backgroundColor: Colors.amber.shade800,
      );
      return;
    }
    final paths = imageFiles.map((f) => f.path).toList();
    setState(() {
      _selectedFiles.clear();
      _multiSelectMode = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextExtractionScreen(
          initialImagePaths: paths,
          autoExtractTitle: '${widget.folder.name} (OCR)',
        ),
      ),
    );
  }

  /// Create PDF from currently selected files (handling both images and existing PDFs)
  Future<void> _createPdfFromSelected() async {
    if (_selectedFiles.isEmpty) return;

    showProcessingSnackBar(context, message: 'Preparing PDF pages... This may take a few seconds');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final List<FileInfo> processedPages = [];
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final file in _selectedFiles) {
        if (file.type == FileType.image) {
          processedPages.add(file);
        } else if (file.type == FileType.pdf) {
          final pdfFile = File(file.path);
          if (await pdfFile.exists()) {
            final pdfBytes = await pdfFile.readAsBytes();
            int pageIndex = 0;
            await for (final page in Printing.raster(pdfBytes, dpi: 250)) {
              final pngBytes = await page.toPng();
              final pagePath = '${tempDir.path}/imported_page_${timestamp}_${pageIndex}.png';
              final pageFile = File(pagePath);
              await pageFile.writeAsBytes(pngBytes);
              processedPages.add(
                FileInfo(
                  name: '${file.name} (P.${pageIndex + 1})',
                  path: pagePath,
                  type: FileType.image,
                ),
              );
              pageIndex++;
            }
          }
        }
      }

      if (mounted) Navigator.pop(context);

      if (processedPages.isEmpty) {
        Fluttertoast.showToast(msg: "No images or readable PDF pages selected");
        return;
      }

      setState(() {
        _selectedFiles.clear();
        _multiSelectMode = false;
      });

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            initialImages: processedPages,
            folderPath: widget.folder.path,
          ),
        ),
      );

      if (result == true) {
        _loadFiles();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(msg: "Error preparing PDF: $e");
    }
  }

  Future<void> _deleteFile(FileInfo file) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Move to Trash?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will move "${file.name}" to trash. You can restore it later from the Trash section.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Move to Trash',
              style: GoogleFonts.poppins(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Move to trash instead of permanently deleting
      debugPrint('TrashService: Attempting to move ${file.path} to trash');
      final success = await TrashService.instance.moveFileToTrash(file.path);
      debugPrint('TrashService: moveFileToTrash returned $success');
      if (success) {
        await RecentActivityService.removeActivity(
          targetPath: file.path,
          title: file.name,
        );
        await _loadFiles(); // Reload files to ensure UI reflects changes immediately
        Fluttertoast.showToast(
          msg: "Moved to trash",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        debugPrint('TrashService: Trash failed');
        Fluttertoast.showToast(
          msg: "Failed to move file to trash",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('TrashService: Exception during delete: $e');
      Fluttertoast.showToast(
        msg: "Error deleting file: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _renameFile(FileInfo file) async {
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController controller = TextEditingController(
          text: file.name,
        );
        return AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new file name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('Rename'),
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != file.name) {
      try {
        final String oldPath = file.path;
        final String newPath =
            '${widget.folder.path}${Platform.pathSeparator}$newName';
        final File oldFile = File(oldPath);
        await oldFile.rename(newPath);

        setState(() {
          final index = _files.indexOf(file);
          if (index != -1) {
            _files[index] = FileInfo(
              name: newName,
              path: newPath,
              type: getFileType(newPath),
            );
          }
        });
        Fluttertoast.showToast(msg: "File renamed successfully!");
      } catch (e) {
        Fluttertoast.showToast(msg: "Error renaming file: $e");
      }
    }
  }

  Future<void> _moveFile(FileInfo file) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory documentFoldersDir = Directory(
        '${appDocDir.path}${Platform.pathSeparator}document_folders',
      );

      if (!await documentFoldersDir.exists()) return;

      final List<FileSystemEntity> entities = await documentFoldersDir
          .list()
          .toList();
      final List<Directory> folders = entities.whereType<Directory>().toList();

      // Filter out current folder
      folders.removeWhere((d) => d.path == widget.folder.path);

      if (folders.isEmpty) {
        Fluttertoast.showToast(msg: "No other folders found to move to.");
        return;
      }

      if (!mounted) return;

      final Directory? destination = await showModalBottomSheet<Directory>(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Move to Folder',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final name = folder.path.split(Platform.pathSeparator).last;
                    return ListTile(
                      leading: const Icon(
                        Icons.folder_rounded,
                        color: Colors.orange,
                      ),
                      title: Text(name, style: GoogleFonts.poppins()),
                      onTap: () => Navigator.pop(context, folder),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (destination != null) {
        final String newPath =
            '${destination.path}${Platform.pathSeparator}${file.name}';
        
        // Check if file already exists in destination
        if (await File(newPath).exists()) {
          Fluttertoast.showToast(msg: "A file with this name already exists in destination.");
          return;
        }

        await File(file.path).rename(newPath);

        setState(() {
          _files.removeWhere((f) => f.path == file.path);
        });

        Fluttertoast.showToast(
          msg: "Moved to ${destination.path.split(Platform.pathSeparator).last}",
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error moving file: $e");
    }
  }

  Future<void> _copyFile(FileInfo file) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final documentFoldersDir = Directory('${appDocDir.path}${Platform.pathSeparator}document_folders');
      if (!await documentFoldersDir.exists()) await documentFoldersDir.create(recursive: true);
      
      if (!mounted) return;
      if (!mounted) return;

      final FolderInfo? destination = await showDialog<FolderInfo>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Copy to Folder',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
        child: FutureBuilder<List<Directory>>(
          future: Future.delayed(Duration.zero, () async {
            final appDocDir = await getApplicationDocumentsDirectory();
            final documentFoldersDir = Directory('${appDocDir.path}${Platform.pathSeparator}document_folders');
            if (!await documentFoldersDir.exists()) return [];
            return documentFoldersDir.listSync().whereType<Directory>().toList();
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            
            final folders = (snapshot.data ?? [])
                .map((d) => FolderInfo(
                      name: d.path.split(Platform.pathSeparator).last,
                      path: d.path,
                      files: [],
                    ))
                .where((f) => f.path != widget.folder.path)
                .toList();

                if (folders.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('No other folders found', 
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return ListTile(
                        leading: Icon(Icons.folder_rounded, color: Theme.of(context).primaryColor),
                        title: Text(folder.name, 
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                        onTap: () => Navigator.pop(context, folder),
                      );
                    },
                  );
              },
            ),
          ),
        ),
      );

      if (destination != null) {
        String targetName = file.name;
        String newPath =
            '${destination.path}${Platform.pathSeparator}$targetName';
        
        // Check if file already exists in destination
        if (await File(newPath).exists()) {
          final res = await DuplicateFileDialog.show(
            context,
            fileName: file.name,
            destinationFolderName: destination.name,
          );
          if (res == null || res.action == DuplicateFileAction.skip) return;
          if (res.action == DuplicateFileAction.keepBoth) {
            targetName = DuplicateFileDialog.generateUniqueFileName(
              destination.path,
              targetName,
            );
            newPath = '${destination.path}${Platform.pathSeparator}$targetName';
          }
        }

        await File(file.path).copy(newPath);

        Fluttertoast.showToast(
          msg: "Copied to ${destination.path.split(Platform.pathSeparator).last}",
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error copying file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLockedSession) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.folder.name,
            style: GoogleFonts.poppins(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF1F5F9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Folder Locked',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please unlock to view files',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _checkLockStatus,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock Folder'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Premium subtle background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                    isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF1F5F9),
                    isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadFiles,
            color: Theme.of(context).primaryColor,
            backgroundColor: Theme.of(context).cardColor,
            child: Builder(
              builder: (context) {
                final appBarTextColor = AppTheme.textPrimary(context);
                final appBarIconBg = AppTheme.tonal(context);
                final appBarIconBorder = AppTheme.surfaceBorder(context);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      floating: false,
                      pinned: true,
                      elevation: 0,
                      toolbarHeight: 64.0,
                      leadingWidth: 60.0,
                      iconTheme: IconThemeData(color: appBarTextColor),
                      backgroundColor: Colors.transparent,
                      flexibleSpace: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      leading: Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: appBarIconBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appBarIconBorder, width: 1),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            color: appBarTextColor,
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            splashRadius: 20,
                          ),
                        ),
                      ),
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _multiSelectMode
                                ? '${_selectedFiles.length} selected'
                                : widget.folder.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: appBarTextColor,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!_multiSelectMode)
                            Text(
                              '${_files.length} ${_files.length == 1 ? 'item' : 'items'}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: appBarTextColor.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      actions: _multiSelectMode
                          ? [
                              _buildAppBarAction(
                                icon: Icons.close_rounded,
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.clear();
                                    _multiSelectMode = false;
                                  });
                                },
                                tooltip: 'Cancel',
                              ),
                              _buildAppBarAction(
                                icon: Icons.document_scanner_rounded,
                                onPressed: _extractTextFromSelected,
                                tooltip: 'Extract Text (OCR)',
                              ),
                              _buildAppBarAction(
                                icon: Icons.picture_as_pdf_rounded,
                                onPressed: _createPdfFromSelected,
                                tooltip: 'Create PDF',
                              ),
                              _buildAppBarAction(
                                icon: Icons.archive_rounded,
                                onPressed: () => _archiveSelectedFilesToFolder(_selectedFiles),
                                tooltip: 'Archive to ZIP',
                              ),
                              _buildAppBarAction(
                                icon: Icons.share_rounded,
                                onPressed: () async {
                                  if (_selectedFiles.isNotEmpty) {
                                    await _shareFilesAsZip(_selectedFiles);
                                    setState(() {
                                      _selectedFiles.clear();
                                      _multiSelectMode = false;
                                    });
                                  }
                                },
                                tooltip: 'Share ZIP',
                              ),
                              _buildAppBarAction(
                                icon: Icons.delete_rounded,
                                color: Colors.red.shade400,
                                onPressed: () async {
                                  if (_selectedFiles.isNotEmpty) {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: Text(
                                          'Delete ${_selectedFiles.length} items?',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        content: Text(
                                          'This action cannot be undone.',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final filesToDelete = List<FileInfo>.from(_selectedFiles);
                                      int successCount = 0;
                                      for (var file in filesToDelete) {
                                        try {
                                          final success = await TrashService.instance.moveFileToTrash(file.path);
                                          if (success) successCount++;
                                        } catch (_) {}
                                      }
                                      await RecentActivityService.removeActivities(
                                        titles: filesToDelete.map((f) => f.name).toList(),
                                        paths: filesToDelete.map((f) => f.path).toList(),
                                      );
                                      setState(() {
                                        _selectedFiles.clear();
                                        _multiSelectMode = false;
                                      });
                                      await _loadFiles();
                                      Fluttertoast.showToast(
                                        msg: "Moved $successCount item(s) to trash",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                      );
                                    }
                                  }
                                },
                                tooltip: 'Delete',
                              ),
                              const SizedBox(width: 8),
                            ]
                          : [
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: appBarIconBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: appBarIconBorder, width: 1),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                      size: 20,
                                      color: appBarTextColor,
                                    ),
                                    onPressed: () {
                                      setState(() => _isGridView = !_isGridView);
                                      _saveViewPreference(_isGridView);
                                    },
                                    tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                                    padding: EdgeInsets.zero,
                                    splashRadius: 20,
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: appBarIconBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: appBarIconBorder, width: 1),
                                  ),
                                  child: PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, color: appBarTextColor, size: 20),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Folder Tools',
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    onSelected: (val) {
                                      switch (val) {
                                        case 'create_pdf':
                                          _makePdf();
                                          break;
                                        case 'zip_folder':
                                          _compressFolderToZip();
                                          break;
                                        case 'import_zip':
                                          _importZipIntoFolder();
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'create_pdf',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Colors.redAccent),
                                            const SizedBox(width: 12),
                                            Text('Create PDF', style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'zip_folder',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.archive_rounded, size: 20, color: Colors.blueAccent),
                                            const SizedBox(width: 12),
                                            Text('Archive Folder to ZIP', style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'import_zip',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.unarchive_rounded, size: 20, color: Colors.amber),
                                            const SizedBox(width: 12),
                                            Text('Extract ZIP into Folder', style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                    ),
                    // Home-screen style Search Bar & Filter Chips
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.tonal(context),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: AppTheme.surfaceBorder(context),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search files in ${widget.folder.name}...',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textMuted(context),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: AppTheme.textSecondary(context),
                                    size: 22,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 20),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : IconButton(
                                          icon: Icon(
                                            Icons.mic_rounded,
                                            color: AppTheme.primary(context),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            VoiceSearchSheet.show(
                                              context,
                                              initialQuery: _searchQuery,
                                              quickTopics: const [
                                                'PDF',
                                                'Images',
                                                'Documents',
                                                'Invoices',
                                                'Receipts',
                                                'Notes',
                                              ],
                                              onSearchSubmitted: (query) {
                                                setState(() {
                                                  _searchController.text = query;
                                                  _searchQuery = query.toLowerCase();
                                                });
                                              },
                                            );
                                          },
                                          tooltip: 'Voice Search',
                                        ),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                ),
                                onChanged: (value) => setState(
                                  () => _searchQuery = value.toLowerCase(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Quick Filter Chips
                            SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  _buildFolderFilterChip('All', Icons.grid_view_rounded),
                                  const SizedBox(width: 8),
                                  _buildFolderFilterChip('Images', Icons.image_rounded),
                                  const SizedBox(width: 8),
                                  _buildFolderFilterChip('PDFs', Icons.picture_as_pdf_rounded),
                                  const SizedBox(width: 8),
                                  _buildFolderFilterChip('Documents', Icons.description_rounded),
                                  const SizedBox(width: 8),
                                  _buildFolderFilterChip('Favorites', Icons.star_rounded),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildShimmerEffect(),
                        ),
                      )
                    else if (_files.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer(context).withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.folder_open_rounded,
                                  size: 56,
                                  color: AppTheme.primary(context),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Empty Folder',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: Text(
                                  'Start adding files to organize your documents.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _pickFiles,
                                icon: const Icon(Icons.upload_file_rounded, size: 20),
                                label: const Text('Add Files'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary(context),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filteredFiles.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 56,
                                color: AppTheme.textMuted(context),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matching files found',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try clearing your search query or filters',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.clear_all_rounded, size: 18),
                                label: const Text('Clear Filters'),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _filterCategory = 'All';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (_searchQuery.isNotEmpty || _filterCategory != 'All')
                        _buildFilteredGrid()
                      else
                        _buildGroupedList(),
                    ],
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add_rounded,
        activeIcon: Icons.close_rounded,
        backgroundColor: AppTheme.primary(context),
        foregroundColor: Colors.white,
        spacing: 16,
        spaceBetweenChildren: 10,
        renderOverlay: true,
        overlayColor: Colors.black,
        overlayOpacity: 0.45,
        elevation: 6,
        animationCurve: Curves.easeInOut,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.camera_alt_rounded, size: 22),
            backgroundColor: const Color(0xFFD3E3FD),
            foregroundColor: const Color(0xFF041E49),
            label: 'Camera',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary(context),
            ),
            labelBackgroundColor: AppTheme.surface(context),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _takePicture,
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_file_rounded, size: 22),
            backgroundColor: const Color(0xFFC2E7FF),
            foregroundColor: const Color(0xFF001D35),
            label: 'Upload Files',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary(context),
            ),
            labelBackgroundColor: AppTheme.surface(context),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _pickFiles,
          ),
          SpeedDialChild(
            child: const Icon(Icons.document_scanner_rounded, size: 22),
            backgroundColor: const Color(0xFFE8DEF8),
            foregroundColor: const Color(0xFF1D192B),
            label: 'Scan Document',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary(context),
            ),
            labelBackgroundColor: AppTheme.surface(context),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _scanDocument,
          ),
          SpeedDialChild(
            child: const Icon(Icons.note_add_rounded, size: 22),
            backgroundColor: const Color(0xFFCEEAD6),
            foregroundColor: const Color(0xFF0D652D),
            label: 'Notes',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary(context),
            ),
            labelBackgroundColor: AppTheme.surface(context),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _showNotes,
          ),
          SpeedDialChild(
            child: const Icon(Icons.check_box_outlined, size: 22),
            backgroundColor: const Color(0xFFFFF0D4),
            foregroundColor: const Color(0xFF6E3900),
            label: 'Todos',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary(context),
            ),
            labelBackgroundColor: AppTheme.surface(context),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TodoPage(
                    folderPath: widget.folder.path,
                    folderName: widget.folder.name,
                  ),
                ),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.picture_as_pdf_rounded, size: 22),
            backgroundColor: const Color(0xFFFFD8D8),
            foregroundColor: const Color(0xFFB3261E),
            label: 'Create PDF',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary(context),
            ),
            labelBackgroundColor: AppTheme.surface(context),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _makePdf,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    String? tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.tonal(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: color ?? AppTheme.textPrimary(context),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildFilteredGrid() {
    final filteredFiles = _filteredFiles;
    if (filteredFiles.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: AppTheme.textMuted(context),
                ),
                const SizedBox(height: 16),
                Text(
                  "No items found",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSecondary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: _isGridView
          ? SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.getAdaptiveGridColumns(
                  context,
                  minItemWidth: 150,
                  minColumns: 2,
                ),
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 14.0,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildFileCard(filteredFiles[index]),
                childCount: filteredFiles.length,
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildFileListCard(filteredFiles[index]),
                ),
                childCount: filteredFiles.length,
              ),
            ),
    );
  }

  Widget _buildGroupedList() {
    final now = DateTime.now();
    final today = <FileInfo>[];
    final thisWeek = <FileInfo>[];
    final older = <FileInfo>[];
    
    for (var file in _files) {
      if (_searchQuery.isNotEmpty && !file.name.toLowerCase().contains(_searchQuery)) continue;
      
      final date = file.lastModified;
      final difference = now.difference(date).inDays;
      if (difference == 0 && now.day == date.day) {
        today.add(file);
      } else if (difference < 7) {
        thisWeek.add(file);
      } else {
        older.add(file);
      }
    }

    final groups = [
      {'title': 'Today', 'files': today},
      {'title': 'This Week', 'files': thisWeek},
      {'title': 'Older', 'files': older},
    ];

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final group = groups[index];
        final List<FileInfo> filesOfType = group['files'] as List<FileInfo>;

        if (filesOfType.isEmpty) {
          return const SizedBox.shrink();
        }

        String typeLabel = group['title'] as String;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                     typeLabel,
                     style: GoogleFonts.poppins(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: Theme.of(context).textTheme.titleLarge?.color,
                     ),
                   ),
                   PopupMenuButton<FileSortOption>(
                     child: Row(
                        children: [
                           Text('Sort by: ${_getSortOptionName()}', style: GoogleFonts.poppins(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                           const SizedBox(width: 4),
                           Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Theme.of(context).primaryColor),
                        ]
                     ),
                     position: PopupMenuPosition.under,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     itemBuilder: (context) => [
                       PopupMenuItem(value: FileSortOption.dateDescending, child: Row(children: [Icon(Icons.access_time_rounded, size: 20, color: Theme.of(context).primaryColor), const SizedBox(width: 12), const Text('Date (Newest)')])),
                       PopupMenuItem(value: FileSortOption.dateAscending, child: Row(children: [Icon(Icons.access_time_filled_rounded, size: 20, color: Theme.of(context).primaryColor), const SizedBox(width: 12), const Text('Date (Oldest)')])),
                       const PopupMenuDivider(),
                       PopupMenuItem(value: FileSortOption.sizeDescending, child: Row(children: [Icon(Icons.arrow_upward_rounded, size: 20, color: Theme.of(context).primaryColor), const SizedBox(width: 12), const Text('Size (Largest)')])),
                       PopupMenuItem(value: FileSortOption.sizeAscending, child: Row(children: [Icon(Icons.arrow_downward_rounded, size: 20, color: Theme.of(context).primaryColor), const SizedBox(width: 12), const Text('Size (Smallest)')])),
                       const PopupMenuDivider(),
                       PopupMenuItem(value: FileSortOption.nameAscending, child: Row(children: [Icon(Icons.sort_by_alpha_rounded, size: 20, color: Theme.of(context).primaryColor), const SizedBox(width: 12), const Text('Name (A -> Z)')])),
                       PopupMenuItem(value: FileSortOption.nameDescending, child: Row(children: [Icon(Icons.sort_by_alpha_rounded, size: 20, color: Theme.of(context).primaryColor), const SizedBox(width: 12), const Text('Name (Z -> A)')])),
                     ],
                     onSelected: (option) {
                       setState(() {
                         _currentSortOption = option;
                         _sortFiles();
                       });
                     },
                   )
                ]
              )
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isGridView ? GridView.builder(
                key: const ValueKey('grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveLayout.getAdaptiveGridColumns(
                    context,
                    minItemWidth: 150,
                    minColumns: 2,
                  ),
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 14.0,
                  childAspectRatio: 0.82,
                ),
                itemCount: filesOfType.length,
                itemBuilder: (context, index) {
                  final file = filesOfType[index];
                  return _buildFileCard(file);
                },
              ) : ListView.separated(
                key: const ValueKey('list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filesOfType.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final file = filesOfType[index];
                  return _buildFileListCard(file);
                },
              ),
            ),
          ],
        );
      }, childCount: groups.length),
    );
  }

  String _getSortOptionName() {
     switch (_currentSortOption) {
       case FileSortOption.dateDescending: return 'Newest';
       case FileSortOption.dateAscending: return 'Oldest';
       case FileSortOption.sizeDescending: return 'Largest';
       case FileSortOption.sizeAscending: return 'Smallest';
       case FileSortOption.nameAscending: return 'A → Z';
       case FileSortOption.nameDescending: return 'Z → A';
     }
  }

  String _formatBytes(int bytes) {
    return TextUtils.formatFileSize(bytes);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
       return 'Today, ${DateFormat('h:mm a').format(date)}';
    }
    return DateFormat('MMM d, yyyy').format(date);
  }


  Widget _buildShimmerEffect() {
    return GridView.builder(
      padding: const EdgeInsets.all(12.0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest, // Use theme color
          highlightColor: Theme.of(
            context,
          ).colorScheme.surface, // Use theme color
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface, // Use theme color
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileCard(FileInfo file) {
    final isSelected = _selectedFiles.contains(file);
    final isFavorite = _favoriteFiles.contains(file.path);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () async {
          if (_multiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedFiles.remove(file);
              } else {
                _selectedFiles.add(file);
              }
            });
          } else {
            if (file.type == FileType.image) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => FileViewPage(
                    files: _files.where((f) => f.type == FileType.image).toList(),
                    initialIndex: _files
                        .where((f) => f.type == FileType.image)
                        .toList()
                        .indexOf(file),
                  ),
                ),
              );
            } else {
              OpenFilex.open(file.path);
            }
          }
        },
        onLongPress: () {
          if (_multiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedFiles.remove(file);
              } else {
                _selectedFiles.add(file);
              }
            });
          } else {
            setState(() {
              _multiSelectMode = true;
              _selectedFiles.add(file);
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primary(context) : AppTheme.surfaceBorder(context),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.25 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                    color: AppTheme.tonal(context),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: file.path,
                        child: file.type == FileType.image
                            ? OptimizedImage(
                                path: file.path,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  color: AppTheme.tonal(context),
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      color: AppTheme.textMuted(context),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: AppTheme.tonal(context),
                                child: Center(
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryContainer(context),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      file.icon,
                                      size: 28,
                                      color: AppTheme.primary(context),
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      // Favorite Indicator
                      if (isFavorite && !_multiSelectMode)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 14,
                            ),
                          ),
                        ),

                      // Selection Indicator
                      if (_multiSelectMode)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary(context) : Colors.black38,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),

                      // Frosted Options Button (Top-Right, matching Collections card)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showFileOptions(file),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.surface(context).withOpacity(0.85),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.surfaceBorder(context)),
                              ),
                              child: Icon(
                                Icons.more_vert_rounded,
                                color: AppTheme.textSecondary(context),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Details Row matching Collections Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatBytes(file.size),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          file.icon,
                          color: AppTheme.primary(context),
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileListCard(FileInfo file) {
     final isSelected = _selectedFiles.contains(file);
     final fileObj = File(file.path);
     final bytes = fileObj.existsSync() ? fileObj.lengthSync() : 0;
     final modified = fileObj.existsSync() ? fileObj.lastModifiedSync() : DateTime.now();

     return GestureDetector(
        onTap: () async {
           if (_multiSelectMode) {
               setState(() => isSelected ? _selectedFiles.remove(file) : _selectedFiles.add(file));
           } else {
               if (file.type == FileType.image) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, animation, secondaryAnimation) => FileViewPage(
                        files: _files.where((f) => f.type == FileType.image).toList(),
                        initialIndex: _files.where((f) => f.type == FileType.image).toList().indexOf(file),
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                } else {
                  OpenFilex.open(file.path);
                }
           }
        },
        onLongPress: () {
           if (!_multiSelectMode) {
              setState(() { _multiSelectMode = true; _selectedFiles.add(file); });
           }
        },
        child: AnimatedContainer(
           duration: const Duration(milliseconds: 200),
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : Border.all(color: Colors.grey.withOpacity(0.05)),
              boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
           ),
           child: Row(
              children: [
                 Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: file.type == FileType.image
                          ? null
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                       fit: StackFit.expand,
                       children: [
                          file.type == FileType.image 
                          ? OptimizedImage(path: file.path, fit: BoxFit.cover, errorWidget: const Icon(Icons.broken_image, color: Colors.grey))
                          : Icon(file.icon, color: Theme.of(context).primaryColor, size: 32),
                          if (_multiSelectMode)
                            Positioned(
                               top: 4, left: 4,
                               child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Theme.of(context).primaryColor : Colors.white, size: 20)
                            )
                       ]
                    )
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                                Expanded(child: Text(file.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                IconButton(icon: Icon(Icons.more_horiz_rounded, color: Theme.of(context).primaryColor), onPressed: () => _showFileOptions(file), padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 20),
                             ]
                          ),
                          const SizedBox(height: 8),
                          Row(
                             children: [
                                Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                   decoration: BoxDecoration(
                                     color: Theme.of(context).brightness == Brightness.dark
                                         ? Colors.white.withOpacity(0.1)
                                         : Colors.grey.shade200,
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                   child: Text(
                                     file.path.split('.').last.toUpperCase(),
                                     style: GoogleFonts.poppins(
                                       color: Theme.of(context).primaryColor,
                                       fontSize: 10,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                   decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                   child: Text(file.type.toString().split('.').last.toUpperCase(), style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                             ]
                          ),
                          const SizedBox(height: 8),
                          Text('${_formatBytes(bytes)} • ${_formatDate(modified)}', style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                       ]
                    )
                 )
              ]
           )
        )
     );
  }
}
