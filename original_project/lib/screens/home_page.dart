import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_app/models/file_info.dart';
import 'package:gallery_app/models/folder_info.dart';
import 'package:gallery_app/screens/calculator_screen.dart';
import 'package:gallery_app/screens/folder_images_page.dart';
import 'package:gallery_app/screens/password_manager/password_manager_screen.dart';
import 'package:gallery_app/services/folder_lock_service.dart';
import 'package:gallery_app/services/app_lock_service.dart';
import 'package:gallery_app/screens/settings_screen.dart';
import 'package:gallery_app/screens/notes_page.dart';
import 'package:gallery_app/screens/pdf_preview_screen.dart';
import 'package:gallery_app/screens/todo_page.dart';
import 'package:gallery_app/screens/pdf_tools_screen.dart';
import 'package:gallery_app/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:gallery_app/screens/file_view_page.dart';
import 'package:gallery_app/services/trash_service.dart';
import 'package:gallery_app/widgets/optimized_image.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:gallery_app/services/document_scanner_service.dart';
import 'package:gallery_app/utils/performance_utils.dart';
import 'package:gallery_app/screens/trash_screen.dart';
import 'package:gallery_app/screens/pdf_merge_split_screen.dart';
import 'package:gallery_app/screens/enhanced_scanner_screen.dart';
import 'package:gallery_app/screens/pdf_tools_screen.dart';
import 'package:gallery_app/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  final Function(ThemeMode) setThemeMode;

  const HomePage({super.key, required this.setThemeMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final List<FolderInfo> _folders = [];
  late ScrollController _scrollController;
  bool _isBottomBarVisible = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  List<String> _favoritePaths = [];
  List<String> _recentPaths = [];
  List<String> _pinnedPaths = [];
  bool _isGridThreeColumns = false;
  final FolderLockService _folderLockService = FolderLockService.instance;
  bool _folderLockEnabled = false;
  Set<String> _lockedFolderPaths = <String>{};
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  // Storage variables
  double _storageUsedMb = 0.0;
  double _maxStorageMb = 1024.0; // Default 1 GB

  // Staggered entry animation
  late AnimationController _staggerController;
  // FAB breathing animation
  late AnimationController _fabPulseController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _initialSetup();
  }

  Future<void> _initialSetup() async {
    _loadFolderLockState();
    await _loadPreferences();
    _initFolders();
    _calculateStorage();
  }

  Future<void> _loadFolderLockState() async {
    final enabled = await _folderLockService.isEnabled();
    final paths = await _folderLockService.getLockedPaths();
    if (mounted) setState(() {
      _folderLockEnabled = enabled;
      _lockedFolderPaths = paths;
    });
  }

  Future<void> _calculateStorage() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory documentFoldersDir = Directory(
        '${appDocDir.path}${Platform.pathSeparator}document_folders',
      );

      if (!await documentFoldersDir.exists()) {
        if (mounted) setState(() { _storageUsedMb = 0.0; });
        return;
      }

      int totalBytes = 0;
      await for (var entity in documentFoldersDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }

      if (mounted) {
        setState(() {
          _storageUsedMb = totalBytes / (1024 * 1024);
        });
      }
    } catch (e) {
      // Ignore errors for storage calculation
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritePaths = prefs.getStringList('favorite_folders') ?? [];
      _recentPaths = prefs.getStringList('recent_folders') ?? [];
      _pinnedPaths = prefs.getStringList('pinned_folders') ?? [];
      _isGridThreeColumns = prefs.getBool('is_grid_three_columns') ?? false;
      _maxStorageMb = prefs.getDouble('max_storage_mb') ?? 1024.0;
    });
  }


  Future<void> _toggleFavorite(FolderInfo folder) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoritePaths.contains(folder.path)) {
        _favoritePaths.remove(folder.path);
      } else {
        _favoritePaths.add(folder.path);
      }
    });
    await prefs.setStringList('favorite_folders', _favoritePaths);
  }

  Future<void> _togglePinned(FolderInfo folder) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_pinnedPaths.contains(folder.path)) {
        _pinnedPaths.remove(folder.path);
      } else {
        _pinnedPaths.add(folder.path);
      }
    });
    await prefs.setStringList('pinned_folders', _pinnedPaths);
  }

  Future<void> _addToRecents(FolderInfo folder) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentPaths.remove(folder.path);
      _recentPaths.insert(0, folder.path);
      if (_recentPaths.length > 10) {
        _recentPaths = _recentPaths.sublist(0, 10);
      }
    });
    await prefs.setStringList('recent_folders', _recentPaths);
  }

  bool _isPathUnderFolder(String path, String folderPath) {
    if (path == folderPath) return true;
    final prefix = '$folderPath${Platform.pathSeparator}';
    return path.startsWith(prefix);
  }

  bool _isFolderLocked(FolderInfo folder) {
    return _lockedFolderPaths.contains(folder.path);
  }

  Future<bool> _ensureFolderAccess(FolderInfo folder, {String? reason}) async {
    if (!_folderLockEnabled) return true;
    if (!_isFolderLocked(folder)) return true;
    return _folderLockService.ensureUnlocked(
      context,
      reason: reason ?? 'Unlock to open "${folder.name}"',
    );
  }

  Future<void> _toggleFolderLock(FolderInfo folder, bool lock) async {
    final enabled = await _folderLockService.isEnabled();
    final hasPin = await _folderLockService.hasPin();
    if (!enabled || !hasPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set up Folder Lock in Settings first.')),
      );
      return;
    }

    if (lock == _isFolderLocked(folder)) return;

    final ok = await _folderLockService.ensureUnlocked(
      context,
      reason: lock
          ? 'Authenticate to lock "${folder.name}"'
          : 'Authenticate to unlock "${folder.name}"',
    );
    if (!ok) return;

    await _folderLockService.setFolderLocked(folder.path, lock);
    await _loadFolderLockState();
  }

  Future<void> _showFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteFilePaths = prefs.getStringList('favorite_files') ?? [];

    final favoriteFolders = _folders
        .where((f) => _favoritePaths.contains(f.path))
        .toList();

    // Aggregate all files to find favorite files
    final List<FileInfo> allFiles = [];
    for (var folder in _folders) {
      allFiles.addAll(folder.files);
    }
    final favoriteFiles = allFiles
        .where((f) => favoriteFilePaths.contains(f.path))
        .toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
            ]
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Text('Favorites', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 8),
                TabBar(
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                  tabs: const [
                    Tab(text: "Folders"),
                    Tab(text: "Files"),
                  ],
                ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                    child: TabBarView(
                      children: [
                        _buildFolderList(favoriteFolders, ScrollController()),
                        _buildFileList(favoriteFiles, ScrollController()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderList(
    List<FolderInfo> folders,
    ScrollController controller,
  ) {
    if (folders.isEmpty) {
      return Center(
        child: Text(
          "No favorite folders",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: folders.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          leading: Icon(
            Icons.folder_rounded,
            color: Colors.orange[300],
            size: 32,
          ),
          title: Text(
            folder.name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${folder.files.length} items',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          onTap: () {
            Navigator.pop(context);
            _navigateToFolder(folder);
          },
        );
      },
    );
  }

  Widget _buildFileList(List<FileInfo> files, ScrollController controller) {
    if (files.isEmpty) {
      return Center(
        child: Text(
          "No favorite files",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          leading: Icon(
            file.icon,
            color: Theme.of(context).primaryColor,
            size: 32,
          ),
          title: Text(
            file.name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            file.path,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            if (_folderLockEnabled) {
              final lockedFolder = _lockedFolderPaths.firstWhere(
                (path) => _isPathUnderFolder(file.path, path),
                orElse: () => '',
              );
              if (lockedFolder.isNotEmpty) {
                final ok = await _folderLockService.ensureUnlocked(
                  context,
                  reason: 'Unlock to open this file',
                );
                if (!ok) return;
              }
            }
            Navigator.pop(context);

            if (!mounted) return;



            if (file.type == FileType.image) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FileViewPage(files: files, initialIndex: index),
                ),
              );
            } else {
              OpenFilex.open(file.path);
            }
          },
        );
      },
    );
  }

  void _showRecents() {
    final recentFolders = _recentPaths
        .map(
          (path) => _folders.firstWhere(
            (f) => f.path == path,
            orElse: () => FolderInfo(name: '', path: '', files: []),
          ),
        ) // Dummy
        .where((f) => f.path.isNotEmpty)
        .toList();
    _showFolderListDialog('Recent Folders', recentFolders);
  }

  void _showFolderListDialog(String title, List<FolderInfo> folders) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
              const SizedBox(height: 16),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No items found', style: GoogleFonts.inter(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.folder_outlined, color: Theme.of(context).primaryColor, size: 20)
                        ),
                        title: Text(folder.name, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToFolder(folder);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToFolder(FolderInfo folder) async {
    if (!mounted) return;

    final allowed = await _ensureFolderAccess(folder);
    if (!allowed) return;

    _addToRecents(folder);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FolderImagesPage(folder: folder, isLocked: _isFolderLocked(folder)),
      ),
    ).then((_) => _initFolders());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    _staggerController.dispose();
    _fabPulseController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset <= 20) {
      if (!_isBottomBarVisible) setState(() => _isBottomBarVisible = true);
      return;
    }
    
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isBottomBarVisible) setState(() => _isBottomBarVisible = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isBottomBarVisible) setState(() => _isBottomBarVisible = true);
    }
  }

  Future<void> _initFolders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      final Directory folderDir = Directory(
        '$appDocPath${Platform.pathSeparator}document_folders',
      );

      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
      }

      final List<FileSystemEntity> entities = await folderDir.list().toList();
      final List<FolderInfo> folders = [];

      for (var entity in entities) {
        if (entity is Directory) {
          final String folderName = entity.path
              .split(Platform.pathSeparator)
              .last;
          final Directory folderContentDir = Directory(entity.path);
          final List<FileSystemEntity> filesInFolder = await folderContentDir
              .list()
              .toList();
          final List<FileInfo> files = [];

          for (var fileEntity in filesInFolder) {
            if (fileEntity is File) {
              files.add(
                FileInfo(
                  name: fileEntity.path.split(Platform.pathSeparator).last,
                  path: fileEntity.path,
                  type: getFileType(fileEntity.path),
                ),
              );
            }
          }
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          final String? customThumbnailPath = prefs.getString(
            'folder_thumbnail_${entity.path}',
          );

          folders.add(
            FolderInfo(
              name: folderName,
              path: entity.path,
              files: files,
              customThumbnailPath: customThumbnailPath,
            ),
          );
        }
      }

      setState(() {
        _folders.clear();
        _folders.addAll(folders);
        _isLoading = false;
      });
      // Trigger staggered entry animation
      _staggerController.reset();
      _staggerController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Error loading folders: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _createNewFolder() async {
    final TextEditingController folderNameController = TextEditingController();
    bool isCreating = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Create New Folder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: TextField(
              controller: folderNameController,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(hintText: 'Folder Name'),
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
                onPressed: isCreating
                    ? null
                    : () async {
                        final String folderName = folderNameController.text
                            .trim();
                        if (folderName.isEmpty) {
                          Fluttertoast.showToast(
                            msg: "Please enter a folder name",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                          );
                          return;
                        }

                        setDialogState(() {
                          isCreating = true;
                        });

                        try {
                          final Directory appDocDir =
                              await getApplicationDocumentsDirectory();
                          final String appDocPath = appDocDir.path;
                          final Directory newFolder = Directory(
                            '$appDocPath${Platform.pathSeparator}document_folders${Platform.pathSeparator}$folderName',
                          );

                          if (await newFolder.exists()) {
                            Fluttertoast.showToast(
                              msg: "Folder already exists",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                            );
                            setDialogState(() {
                              isCreating = false;
                            });
                            return;
                          }

                          await newFolder.create(recursive: true);

                          setState(() {
                            _folders.add(
                              FolderInfo(
                                name: folderName,
                                path: newFolder.path,
                                files: [],
                                customThumbnailPath: null,
                              ),
                            );
                          });

                          Navigator.pop(context);
                          Fluttertoast.showToast(
                            msg: "Folder created successfully",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                          );
                        } catch (e) {
                          Fluttertoast.showToast(
                            msg: "Error creating folder: $e",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                          );
                          setDialogState(() {
                            isCreating = false;
                          });
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFolderOptions(FolderInfo folder) {
    final isFavorite = _favoritePaths.contains(folder.path);
    final isPinned = _pinnedPaths.contains(folder.path);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned ? Theme.of(context).primaryColor : null,
              ),
              title: Text(isPinned ? 'Unpin Folder' : 'Pin to Top'),
              onTap: () {
                Navigator.pop(context);
                _togglePinned(folder);
              },
            ),
            ListTile(
              leading: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite ? Colors.orange : null,
              ),
              title: Text(
                isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Folder'),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Folder'),
              onTap: () {
                Navigator.pop(context);
                _renameFolder(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Folder'),
              onTap: () {
                Navigator.pop(context);
                _shareFolder(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Set Cover Image'),
              onTap: () {
                Navigator.pop(context);
                _setFolderCover(folder);
              },
            ),
            ListTile(
              leading: Icon(
                _isFolderLocked(folder)
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
              ),
              title: Text(
                _isFolderLocked(folder) ? 'Unlock Folder' : 'Lock Folder',
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleFolderLock(folder, !_isFolderLocked(folder));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setFolderCover(FolderInfo folder) async {
    try {
      final Directory folderDir = Directory(folder.path);
      final List<FileSystemEntity> entities = await folderDir.list().toList();
      final List<FileInfo> imageFiles = entities
          .where(
            (entity) =>
                entity is File &&
                (entity.path.toLowerCase().endsWith('.jpg') ||
                    entity.path.toLowerCase().endsWith('.jpeg') ||
                    entity.path.toLowerCase().endsWith('.png')),
          )
          .map(
            (entity) => FileInfo(
              name: entity.path.split(Platform.pathSeparator).last,
              path: entity.path,
              type: FileType.image,
            ),
          )
          .toList();

      if (imageFiles.isEmpty) {
        Fluttertoast.showToast(
          msg: "No images found in this folder.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      final String? selectedImagePath = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Cover Image'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: imageFiles.length,
              itemBuilder: (context, index) {
                final file = imageFiles[index];
                return GestureDetector(
                  onTap: () => Navigator.pop(context, file.path),
                  child: ThumbnailImage(path: file.path, thumbnailSize: 150),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedImagePath == null) return;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'folder_thumbnail_${folder.path}',
        selectedImagePath,
      );

      setState(() {
        final int index = _folders.indexOf(folder);
        if (index != -1) {
          _folders[index] = FolderInfo(
            name: folder.name,
            path: folder.path,
            files: folder.files,
            customThumbnailPath: selectedImagePath,
          );
        }
      });

      Fluttertoast.showToast(
        msg: "Folder cover updated",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error setting cover image: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _renameFolder(FolderInfo folder) async {
    final TextEditingController nameController = TextEditingController(
      text: folder.name,
    );
    bool isRenaming = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Rename Folder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: TextField(
              controller: nameController,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(hintText: 'New Folder Name'),
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
                onPressed: isRenaming
                    ? null
                    : () async {
                        final String newName = nameController.text.trim();
                        if (newName.isEmpty) {
                          Fluttertoast.showToast(
                            msg: "Please enter a folder name",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                          );
                          return;
                        }
                        if (newName == folder.name) {
                          Navigator.pop(context);
                          return;
                        }

                        setDialogState(() {
                          isRenaming = true;
                        });

                        try {
                          final Directory oldFolderDir = Directory(folder.path);
                          final String parentPath = oldFolderDir.parent.path;
                          final Directory newFolderDir = Directory(
                            '$parentPath${Platform.pathSeparator}$newName',
                          );

                          if (await newFolderDir.exists()) {
                            Fluttertoast.showToast(
                              msg: "Folder with this name already exists",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                            );
                            setDialogState(() {
                              isRenaming = false;
                            });
                            return;
                          }

                          await oldFolderDir.rename(newFolderDir.path);

                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          final String? oldThumbnailPath = prefs.getString(
                            'folder_thumbnail_${folder.path}',
                          );
                          if (oldThumbnailPath != null) {
                            await prefs.remove(
                              'folder_thumbnail_${folder.path}',
                            );
                            await prefs.setString(
                              'folder_thumbnail_${newFolderDir.path}',
                              oldThumbnailPath,
                            );
                          }

                          setState(() {
                            final int index = _folders.indexOf(folder);
                            if (index != -1) {
                              _folders[index] = FolderInfo(
                                name: newName,
                                path: newFolderDir.path,
                                files: folder.files,
                                customThumbnailPath: oldThumbnailPath,
                              );
                            }
                          });

                          Navigator.pop(context);
                          Fluttertoast.showToast(
                            msg: "Folder renamed successfully",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                          );
                        } catch (e) {
                          Fluttertoast.showToast(
                            msg: "Error renaming folder: $e",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                          );
                          setDialogState(() {
                            isRenaming = false;
                          });
                        }
                      },
                child: isRenaming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Rename'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareFolder(FolderInfo folder) async {
    try {
      final Directory folderDir = Directory(folder.path);
      if (await folderDir.exists()) {
        final List<String> imagePaths = [];
        await for (var entity in folderDir.list()) {
          if (entity is File &&
              (entity.path.toLowerCase().endsWith('.jpg') ||
                  entity.path.toLowerCase().endsWith('.jpeg') ||
                  entity.path.toLowerCase().endsWith('.png'))) {
            imagePaths.add(entity.path);
          }
        }

        final List<String> filePaths = folder.files.map((e) => e.path).toList();
        if (filePaths.isNotEmpty) {
          await Share.shareXFiles(
            filePaths.map((path) => XFile(path)).toList(),
            text: 'Check out this folder: ${folder.name}',
          );
        } else {
          Fluttertoast.showToast(
            msg: "Folder is empty, cannot share.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error sharing folder: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _deleteFolder(FolderInfo folder) async {
    try {
      final success = await TrashService.instance.moveFolderToTrash(
        folder.path,
      );
      if (!success) {
        Fluttertoast.showToast(
          msg: "Failed to move folder to trash",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('folder_thumbnail_${folder.path}');
      setState(() {
        _folders.remove(folder);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Folder moved to trash'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await TrashService.instance.restorePath(folder.path);
              _initFolders();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error deleting folder: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  List<FolderInfo> get _filteredFolders {
    List<FolderInfo> result;
    if (_searchQuery.isEmpty) {
      result = List.from(_folders);
    } else {
      // Search folder names AND file names
      result = _folders.where((folder) {
        final matchesFolder =
            folder.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesFiles = folder.files.any(
          (file) => file.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        );
        return matchesFolder || matchesFiles;
      }).toList();
    }
    
    // Sort so pinned folders are at the top
    result.sort((a, b) {
      bool aPinned = _pinnedPaths.contains(a.path);
      bool bPinned = _pinnedPaths.contains(b.path);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0; // Maintain relative order
    });
    
    return result;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
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
            onRefresh: _initFolders,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).cardColor,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(context),
                _buildSearchBar(context),
                if (_searchQuery.isEmpty) _buildQuickActions(context),
                if (_searchQuery.isEmpty)
                  _buildSectionTitle(context, 'Your Collections'),
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: _buildShimmerEffect()),
                  )
                else if (_filteredFolders.isEmpty)
                  _buildEmptyState(context)
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _isGridThreeColumns ? 3 : 2,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: _isGridThreeColumns ? 0.75 : 0.85,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final folder = _filteredFolders[index];
                        return _buildFolderCard(folder);
                      }, childCount: _filteredFolders.length),
                    ),
                  ),
                if (_searchQuery.isEmpty) _buildStorageCard(context),
                const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
              ],
            ),
          ),
          AnimatedPositioned(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeInOut,
             left: 20, right: 20, bottom: _isBottomBarVisible ? 20 : -100,
             child: _buildFloatingBottomNavAndFab(context)
          ),
        ],
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               _buildCreateOption(Icons.create_new_folder_outlined, 'Create Folder', _createNewFolder),
               const Divider(height: 1),
               _buildCreateOption(Icons.document_scanner_outlined, 'Scan Document', _scanDocumentToRoot),
            ]
          )
        );
      }
    );
  }

  Widget _buildCreateOption(IconData icon, String title, VoidCallback onTap) {
     return ListTile(
        leading: Container(
           padding: const EdgeInsets.all(10),
           decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
           child: Icon(icon, color: Theme.of(context).primaryColor)
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color)),
        onTap: () {
           Navigator.pop(context);
           onTap();
        }
     );
  }

  Widget _buildFloatingBottomNavAndFab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414).withOpacity(0.94) : Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.04), width: 1.5),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 30, offset: const Offset(0, 10))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: _buildNavItem(Icons.home_rounded, 'Home', true, () { HapticFeedback.lightImpact(); })),
                Expanded(child: _buildNavItem(Icons.history_rounded, 'Recent', false, () { HapticFeedback.lightImpact(); _showRecents(); })),
                
                // Circular Add Button
                Expanded(
                  child: _buildNavItem(Icons.add_rounded, 'Add', false, () {
                    HapticFeedback.mediumImpact();
                    _showCreateMenu();
                  }),
                ),

                Expanded(child: _buildNavItem(Icons.star_outline_rounded, 'Favorites', false, () { HapticFeedback.lightImpact(); _showFavorites(); })),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: activeColor.withOpacity(isSelected ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: activeColor.withOpacity(isSelected ? 0.2 : 0.06), 
                width: 1.5
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: activeColor.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ] : [],
            ),
            child: Icon(icon, color: isSelected ? activeColor : inactiveColor, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? activeColor : inactiveColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  bool isDarkTheme() {
     return Theme.of(context).brightness == Brightness.dark;
  }

  Widget _buildStorageCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                : [Colors.white, const Color(0xFFF3F4F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                 width: 56, height: 56,
                 decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                 ),
                 child: Icon(Icons.cloud_done_rounded, color: isDark ? Colors.white : Colors.black87, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Local Storage', style: GoogleFonts.inter(color: isDark ? Colors.white.withOpacity(0.8) : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                       const SizedBox(height: 4),
                       RichText(
                          text: TextSpan(
                             children: [
                                TextSpan(
                                  text: '${_storageUsedMb.toStringAsFixed(1)} MB ',
                                  style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: 'of ${_maxStorageMb >= 1024 ? "${(_maxStorageMb / 1024).toStringAsFixed(0)} GB" : "${_maxStorageMb.toStringAsFixed(0)} MB"}', style: GoogleFonts.inter(color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54, fontSize: 13)),
                             ]
                          )
                       ),
                       const SizedBox(height: 12),
                       ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (_storageUsedMb / _maxStorageMb).clamp(0.0, 1.0), 
                            minHeight: 6, 
                            backgroundColor: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.1), 
                            valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black87),
                          ),
                       )
                    ]
                 )
              ),
            ]
          )
        )
      )
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Stack(
         children: [
            // Decorative subtle background blob
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(isDark ? 0.3 : 0.1),
                      Colors.transparent
                    ]
                  )
                )
              )
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Document Hub',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    color: isDark ? Colors.white : Colors.black,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: _getGreeting().split(' ').first + ' ', 
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: _getGreeting().split(' ').length > 1 ? _getGreeting().split(' ').sublist(1).join(' ') + ' 👋' : '', 
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: isDark ? Colors.white54 : Colors.black54, 
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Let\'s organize your documents efficiently.',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () {
                         HapticFeedback.lightImpact();
                         Navigator.push(
                           context, 
                           MaterialPageRoute(builder: (context) => SettingsScreen(setThemeMode: widget.setThemeMode))
                         ).then((_) {
                           _loadPreferences();
                           _loadFolderLockState();
                         });
                      },
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
         ]
      )
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Focus(
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.0 : 0.04,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search documents, files...',
                    hintStyle: GoogleFonts.inter(
                      color: Theme.of(context).hintColor.withOpacity(0.5),
                      fontSize: 15,
                    ),
                    prefixIcon: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        color: hasFocus
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).hintColor.withOpacity(0.5),
                        size: 22,
                      ),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                  ),
                  onChanged: (value) {
                    _searchDebouncer.call(() {
                      setState(() {
                        _searchQuery = value;
                      });
                    });
                  },
                ),
               ),
              ),
             );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.inter(
                       fontWeight: FontWeight.w700,
                       fontSize: 16,
                       color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ]
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_folders.isNotEmpty) ...[
                    _QuickActionChip(
                      icon: Icons.create_new_folder_outlined,
                      label: 'New Folder',
                      color: isDark ? Colors.white : Colors.black,
                      onTap: _createNewFolder,
                    ),
                    const SizedBox(width: 10),
                  ],

                  _QuickActionChip(
                    icon: Icons.note_alt_outlined,
                    label: 'Notes',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotesPage(folderPath: 'quick_notes'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.vpn_key_outlined,
                    label: 'Passwords',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PasswordManagerScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.document_scanner_outlined,
                    label: 'Scanner',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: _scanDocumentToRoot,
                  ),

                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.check_box_outlined,
                    label: 'Todos',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TodoPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF Maker',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: _pickImagesAndCreatePdf,
                  ),
                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.merge_type_rounded,
                    label: 'Merge/Split',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfMergeSplitScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.build_circle_outlined,
                    label: 'PDF Suite',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfToolsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _QuickActionChip(
                    icon: Icons.delete_outline_rounded,
                    label: 'Trash',
                    color: isDark ? Colors.white : Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrashScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImagesAndCreatePdf() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    List<XFile> images = [];
    if (source == ImageSource.camera) {
      // Use cunning_document_scanner instead of basic camera
      try {
        final List<String>? scannedPaths =
            await CunningDocumentScanner.getPictures(
              isGalleryImportAllowed: true,
            );
        if (scannedPaths != null) {
          images.addAll(scannedPaths.map((path) => XFile(path)));
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Error launching scanner: $e");
      }
    } else {
      final List<XFile> picked = await _picker.pickMultiImage();
      images.addAll(picked);
    }

    if (images.isEmpty) return;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          initialImages: images
              .map(
                (x) =>
                    FileInfo(name: x.name, path: x.path, type: FileType.image),
              )
              .toList(),
        ),
      ),
    ).then((saved) {
      if (saved == true) {
        _initFolders(); // Refresh folders in case a new file was added
      }
    });
  }

  Future<void> _scanDocumentToRoot() async {
    try {
      final scannerService = DocumentScannerService();
      final tempPdfPath = await scannerService.scanDocument();

      if (tempPdfPath == null) {
        Fluttertoast.showToast(
          msg: "Scan cancelled",
          toastLength: Toast.LENGTH_SHORT,
        );
        return;
      }

      final Directory appDocDir = await getApplicationDocumentsDirectory();

      FolderInfo? targetFolder;

      if (_folders.isEmpty) {
        // Fallback if no folders exist yet
        final String fallbackFolderPath =
            '${appDocDir.path}${Platform.pathSeparator}document_folders${Platform.pathSeparator}Scanned Documents';
        final Directory fallbackDir = Directory(fallbackFolderPath);
        if (!await fallbackDir.exists())
          await fallbackDir.create(recursive: true);
        targetFolder = FolderInfo(
          name: 'Scanned Documents',
          path: fallbackFolderPath,
          files: [],
        );
      } else {
        // Prompt user to select an existing folder
        targetFolder = await showDialog<FolderInfo>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            title: Text(
              'Save to Folder',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _folders.length,
                itemBuilder: (context, index) {
                  final folder = _folders[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.folder_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    title: Text(folder.name, style: GoogleFonts.inter()),
                    subtitle: Text(
                      '${folder.fileCount} files',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, folder),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }

      if (targetFolder == null) {
        Fluttertoast.showToast(msg: "Scan discarded. No folder selected.");
        return;
      }

      final resultPath = await scannerService.importToFolder(
        tempPdfPath,
        targetFolder.path,
      );

      if (resultPath != null) {
        Fluttertoast.showToast(
          msg: "Document saved to '${targetFolder.name}'",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: const Color(0xFF00BCD4),
        );
        _initFolders(); // Reload the UI
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error scanning document: $e",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.red,
      );
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            if (title == 'Your Collections')
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _isGridThreeColumns
                      ? Icons.grid_view_rounded
                      : Icons.grid_on_rounded,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  setState(() {
                    _isGridThreeColumns = !_isGridThreeColumns;
                  });
                  await prefs.setBool(
                    'is_grid_three_columns',
                    _isGridThreeColumns,
                  );
                },
                tooltip: 'Toggle Grid Size',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/document_animation.json',
                width: 200,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.folder_open_rounded,
                    color: Theme.of(context).disabledColor,
                    size: 80,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isEmpty
                    ? 'Start Organizing'
                    : 'No matching folders found',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? 'Create your first folder to get started.'
                    : 'Try a different search term.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Theme.of(context).primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _createNewFolder,
                    icon: Icon(
                      Icons.add_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                    label: Text(
                      'Create Folder',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).disabledColor.withOpacity(0.05),
          highlightColor: Theme.of(context).disabledColor.withOpacity(0.1),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderCard(FolderInfo folder) {
    final isLocked = _isFolderLocked(folder);
    final index = _filteredFolders.indexOf(folder);

    // Staggered animation per card
    final double start = (index * 0.1).clamp(0.0, 0.8);
    final double end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: _FolderCardContent(
        folder: folder,
        isLocked: isLocked,
        isFavorite: _favoritePaths.contains(folder.path),
        isPinned: _pinnedPaths.contains(folder.path),
        onTap: () => _navigateToFolder(folder),
        onLongPress: () => _showFolderOptions(folder),
        onOptionsTap: () => _showFolderOptions(folder),
      ),
    );
  }
}

// ─── Enhanced Quick Action Chip ───
class _QuickActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => _bounceController.forward(),
      onTapUp: (_) {
        _bounceController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _bounceController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.color.withOpacity(isDark ? 0.3 : 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Folder Card Content with Press Animation ───
class _FolderCardContent extends StatefulWidget {
  final FolderInfo folder;
  final bool isLocked;
  final bool isFavorite;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptionsTap;

  const _FolderCardContent({
    required this.folder,
    required this.isLocked,
    required this.isFavorite,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
    required this.onOptionsTap,
  });

  @override
  State<_FolderCardContent> createState() => _FolderCardContentState();
}

class _FolderCardContentState extends State<_FolderCardContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      onLongPress: () {
        _pressController.reverse();
        widget.onLongPress();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : theme.primaryColor).withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.isLocked)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor.withOpacity(0.08),
                                theme.primaryColor.withOpacity(0.16),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.lock_rounded,
                              size: 48,
                              color: theme.primaryColor.withOpacity(0.6),
                            ),
                          ),
                        )
                      else if (widget.folder.thumbnailPath != null)
                        OptimizedImage(
                          path: widget.folder.thumbnailPath!,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 40,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                isDark ? Colors.transparent : Colors.transparent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withOpacity(0.5),
                                ],
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.folder_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      if (!widget.isLocked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),

                      if (widget.isFavorite)
                        Positioned(
                          top: 8,
                          left: widget.isPinned ? 34 : 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),

                      if (widget.isPinned)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.push_pin_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),

                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: widget.onOptionsTap,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.folder.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${widget.folder.fileCount} items',
                                style: GoogleFonts.inter(
                                  fontSize: 12, 
                                  color: theme.hintColor.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.isLocked) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.lock_rounded, size: 12, color: theme.hintColor.withOpacity(0.7)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.folder_rounded, color: theme.primaryColor, size: 20),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
