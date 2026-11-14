import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
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
import '../widgets/floating_calculator.dart';
import 'package:gallery_app/widgets/optimized_image.dart';
import 'package:gallery_app/services/document_scanner_service.dart';
import 'package:gallery_app/services/trash_service.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
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
  FileType? _selectedFilterType;
  List<String> _favoriteFiles = [];
  bool _isLockedSession = false;
  bool _isGridView = true;

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
          return File(
            a.path,
          ).lastModifiedSync().compareTo(File(b.path).lastModifiedSync());
        case FileSortOption.dateDescending:
          return File(
            b.path,
          ).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
        case FileSortOption.sizeAscending:
          return File(a.path).lengthSync().compareTo(File(b.path).lengthSync());
        case FileSortOption.sizeDescending:
          return File(b.path).lengthSync().compareTo(File(a.path).lengthSync());
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

      setState(() {
        _isLoading = true;
      });

      for (var platformFile in result.files) {
        if (platformFile.path == null) continue;

        final String fileName = platformFile.name;
        final File newFile = File(
          '${widget.folder.path}${Platform.pathSeparator}$fileName',
        );
        await File(platformFile.path!).copy(newFile.path);

        _files.add(
          FileInfo(
            name: fileName,
            path: newFile.path,
            type: getFileType(newFile.path),
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: "${result.files.length} files added",
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
      final File newFile = File(
        '${widget.folder.path}${Platform.pathSeparator}$fileName',
      );
      await File(pickedFile.path).copy(newFile.path);

      setState(() {
        _files.add(
          FileInfo(
            name: fileName,
            path: newFile.path,
            type: getFileType(newFile.path),
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
    List<FileInfo> selectedImages = [];

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Select Images for PDF',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: _files
                      .where((file) => file.type == FileType.image)
                      .length,
                  itemBuilder: (BuildContext context, int index) {
                    final imageFile = _files
                        .where((file) => file.type == FileType.image)
                        .toList()[index];
                    final isSelected = selectedImages.contains(imageFile);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedImages.remove(imageFile);
                          } else {
                            selectedImages.add(imageFile);
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          Image.file(
                            File(imageFile.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                          if (isSelected)
                            Positioned.fill(
                              child: Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.5),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  size: 40,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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
                            _loadFiles(); // Refresh file list if PDF was created
                          }
                        },
                  child: const Text('Create PDF'),
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
            if (file.type == FileType.pdf)
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
                        '${(snapshot.data!.size / 1024).toStringAsFixed(2)} KB',
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
            const SizedBox(height: 24),
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
      
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      
      for (var file in files) {
        await encoder.addFile(File(file.path));
      }
      
      encoder.close();

      // Remove loading indicator
      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(zipPath)],
        text: 'Sharing ${files.length} files as a ZIP archive',
      );
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
        final String newPath =
            '${destination.path}${Platform.pathSeparator}${file.name}';
        
        // Check if file already exists in destination
        if (await File(newPath).exists()) {
          Fluttertoast.showToast(msg: "A file with this name already exists in destination.");
          return;
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
                final appBarTextColor = isDark ? Colors.white : Colors.black87;
                final appBarIconBg = isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08);
                final appBarIconBorder = isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.12);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120.0,
                      floating: false,
                      pinned: true,
                      stretch: false,
                      elevation: 0,
                      iconTheme: IconThemeData(color: appBarTextColor),
                      leading: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: appBarIconBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: appBarIconBorder, width: 1),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, size: 22),
                          color: appBarTextColor,
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          splashRadius: 24,
                        ),
                      ),
                      backgroundColor: Colors.transparent,
                      flexibleSpace: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                              titlePadding: const EdgeInsets.only(
                                left: 70,
                                bottom: 16,
                                right: 20,
                              ),
                              centerTitle: false,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _multiSelectMode
                                              ? '${_selectedFiles.length} selected'
                                              : widget.folder.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 26,
                                            color: appBarTextColor,
                                            letterSpacing: -0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (!_multiSelectMode)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              '${_files.length} items',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: appBarTextColor.withOpacity(0.6),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                                tooltip: 'Share',
                              ),
                              _buildAppBarAction(
                                icon: Icons.delete_rounded,
                                color: Colors.red.shade300,
                                onPressed: () async {
                                  if (_selectedFiles.isNotEmpty) {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      for (var file in _selectedFiles) {
                                        await _deleteFile(file);
                                      }
                                      setState(() {
                                        _selectedFiles.clear();
                                        _multiSelectMode = false;
                                      });
                                    }
                                  }
                                },
                                tooltip: 'Delete',
                              ),
                              const SizedBox(width: 12),
                            ]
                          : [
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _isGridView ? Theme.of(context).primaryColor : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _isGridView ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.grid_view_rounded, color: _isGridView ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).iconTheme.color),
                                      onPressed: () {
                                        setState(() => _isGridView = true);
                                        _saveViewPreference(true);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: !_isGridView ? Theme.of(context).primaryColor : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: !_isGridView ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.sort_rounded, color: !_isGridView ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).iconTheme.color),
                                      onPressed: () {
                                        setState(() => _isGridView = false);
                                        _saveViewPreference(false);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search files...',
                              hintStyle: GoogleFonts.poppins(
                                color: Theme.of(
                                  context,
                                ).hintColor.withOpacity(0.5),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Container(
                                padding: const EdgeInsets.all(14),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: Theme.of(context).primaryColor,
                                  size: 22,
                                ),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close_rounded, size: 18, color: Theme.of(context).primaryColor),
                                      ),
                                      onPressed: () => setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      }),
                                    )
                                  : null,
                              filled: true,
                              fillColor: Theme.of(context).cardColor.withOpacity(0.7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            ),
                            onChanged: (value) => setState(
                              () => _searchQuery = value.toLowerCase(),
                            ),
                          ),
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
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.08),
                                      Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _searchQuery.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.folder_open_rounded,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No Results Found'
                                    : 'Empty Folder',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                ),
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No files match "$_searchQuery". Try a different search term.'
                                      : 'Start adding files to organize your documents',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: Theme.of(context).hintColor,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 40),
                                ElevatedButton.icon(
                                  onPressed: _pickFiles,
                                  icon: const Icon(
                                    Icons.upload_file_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Add Files',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    elevation: 3,
                                    shadowColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.3),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 36,
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(child: _buildSummaryRow()),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      if (_selectedFilterType != null)
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
        backgroundColor: isDark ? Colors.white : Colors.black,
        foregroundColor: isDark ? Colors.black : Colors.white,
        spacing: 16,
        spaceBetweenChildren: 10,
        renderOverlay: true,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        elevation: 8,
        animationCurve: Curves.easeInOut,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: [


          SpeedDialChild(
            child: const Icon(Icons.camera_alt_rounded, size: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            label: 'Camera',
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            labelBackgroundColor: Theme.of(context).cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _takePicture,
          ),
          SpeedDialChild(
            child: const Icon(Icons.upload_file_rounded, size: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            label: 'Upload Files',
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            labelBackgroundColor: Theme.of(context).cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _pickFiles,
          ),
          SpeedDialChild(
            child: const Icon(Icons.document_scanner_rounded, size: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            label: 'Scan Document',
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            labelBackgroundColor: Theme.of(context).cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _scanDocument,
          ),
          SpeedDialChild(
            child: const Icon(Icons.note_add_rounded, size: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            label: 'Notes',
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            labelBackgroundColor: Theme.of(context).cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: _showNotes,
          ),
          SpeedDialChild(
            child: const Icon(Icons.check_box_outlined, size: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            label: 'Todos',
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            labelBackgroundColor: Theme.of(context).cardColor,
            elevation: 4,
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
            child: const Icon(Icons.picture_as_pdf_rounded, size: 24),
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            label: 'Create PDF',
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            labelBackgroundColor: Theme.of(context).cardColor,
            elevation: 4,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? Colors.white : Colors.black87);
    final bgColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    final borderColor = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: iconColor,
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildFilteredGrid() {
    final filteredFiles = _files
        .where((f) => f.type == _selectedFilterType)
        .toList();
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
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No items found",
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.65,
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
      
      final date = File(file.path).lastModifiedSync();
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.65,
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
     if (bytes <= 0) return "0 B";
     const suffixes = ["B", "KB", "MB", "GB", "TB"];
     var i = (log(bytes) / log(1024)).floor();
     return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
       return 'Today, ${DateFormat('h:mm a').format(date)}';
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildSummaryRow() {
    final imageCount = _files.where((file) => file.type == FileType.image).length;
    final pdfCount = _files.where((file) => file.type == FileType.pdf).length;
    final otherCount = _files.length - imageCount - pdfCount;

    Widget buildStatChip(
      IconData icon,
      String label,
      int count,
      Color color,
      FileType? type,
    ) {
      final isSelected = _selectedFilterType == type;

      return Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                if (type == null) {
                  _selectedFilterType = null;
                } else {
                  _selectedFilterType = isSelected ? null : type;
                }
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected 
                        ? (Theme.of(context).primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                        : Theme.of(context).iconTheme.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: isSelected 
                          ? (Theme.of(context).primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            buildStatChip(Icons.grid_view_rounded, 'All', _files.length, Theme.of(context).primaryColor, null),
            buildStatChip(Icons.image_outlined, 'Images', imageCount, Theme.of(context).primaryColor, FileType.image),
            buildStatChip(Icons.picture_as_pdf_outlined, 'PDFs', pdfCount, Theme.of(context).primaryColor, FileType.pdf),
            buildStatChip(Icons.description_outlined, 'Docs', otherCount, Theme.of(context).primaryColor, FileType.unknown),
          ],
        ),
      ),
    );
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
    final theme = Theme.of(context);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Hero(
                tag: file.path,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: theme.primaryColor, width: 3)
                        : Border.all(
                            color: theme.dividerColor.withOpacity(0.05),
                            width: 1,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 16 : 20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (file.type == FileType.image)
                          OptimizedImage(
                            path: file.path,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey.shade100,
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: Icon(
                                file.icon,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),

                        // Favorite Indicator
                        if (isFavorite && !_multiSelectMode)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: Colors.orange,
                                size: 14,
                              ),
                            ),
                          ),

                        // Selection Indicator
                        if (_multiSelectMode)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? theme.primaryColor : Colors.black26,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                isSelected ? Icons.check : null,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // Bottom Info Gradient Overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Options Button
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showFileOptions(file),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.black54
                                      : Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  size: 16,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                file.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
