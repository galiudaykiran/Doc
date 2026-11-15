

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
import 'package:gallery_app/screens/settings_screen.dart';
import 'package:gallery_app/screens/notes_page.dart';
import 'package:gallery_app/screens/quick_notes_screen.dart';
import 'package:gallery_app/screens/recent_activity_screen.dart';
import 'package:gallery_app/services/recent_activity_service.dart';
import 'package:intl/intl.dart';
import 'package:gallery_app/screens/text_to_pdf_screen.dart';
import 'package:gallery_app/screens/pdf_preview_screen.dart';
import 'package:gallery_app/screens/todo_page.dart';
import 'package:gallery_app/screens/pdf_tools_screen.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:gallery_app/widgets/offline_animations.dart';
import 'package:gallery_app/utils/responsive_layout.dart';
import 'package:gallery_app/services/zip_service.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:gallery_app/theme/app_theme.dart';
import 'package:gallery_app/screens/favorites_screen.dart';
import 'package:gallery_app/models/user_profile.dart';
import 'package:gallery_app/services/profile_service.dart';
import 'package:gallery_app/screens/profile_screen.dart';
import 'package:gallery_app/widgets/voice_search_sheet.dart';

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
  bool _isListView = false;
  final FolderLockService _folderLockService = FolderLockService.instance;
  bool _folderLockEnabled = false;
  Set<String> _lockedFolderPaths = <String>{};
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  UserProfile? _profile;
  String _currentSort = 'name_asc';
  String _currentFilter = 'all';
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
    final profile = await ProfileService.getProfile();
    setState(() {
      _profile = profile;
      _favoritePaths = prefs.getStringList('favorite_folders') ?? [];
      _recentPaths = prefs.getStringList('recent_folders') ?? [];
      _pinnedPaths = prefs.getStringList('pinned_folders') ?? [];
      _isGridThreeColumns = prefs.getBool('is_grid_three_columns') ?? false;
      _isListView = prefs.getBool('is_list_view') ?? false;
      _maxStorageMb = prefs.getDouble('max_storage_mb') ?? 1024.0;
    });
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getProfile();
    if (mounted) setState(() => _profile = profile);
  }

  String get _avatarInitial {
    if (_profile != null && _profile!.username.trim().isNotEmpty) {
      return _profile!.username.trim()[0].toUpperCase();
    }
    return 'U';
  }

  String get _userFirstName {
    if (_profile != null && _profile!.username.trim().isNotEmpty) {
      return _profile!.username.trim().split(' ').first;
    }
    return '';
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
    await RecentActivityService.recordActivity(
      title: folder.name,
      subtitle: 'Collection opened • ${folder.fileCount} items',
      type: 'folder',
      targetPath: folder.path,
    );
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
        const SnackBar(
          content: Text('Set up Folder Lock in Settings first.'),
          duration: Duration(seconds: 3),
        ),
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
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesScreen(allFolders: _folders),
      ),
    );
    _loadPreferences();
    _initFolders();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecentActivityScreen(
          folders: _folders,
          onAddTap: () {
            Navigator.pop(context);
            _showFolderCreationChooser(context);
          },
        ),
      ),
    );
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
                          await RecentActivityService.recordActivity(
                            title: folderName,
                            subtitle: 'Collection created • 0 items',
                            type: 'folder',
                            targetPath: newFolder.path,
                          );
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
    final isLocked = _isFolderLocked(folder);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBorder(ctx),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer(ctx),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          color: AppTheme.onPrimaryContainer(ctx),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary(ctx),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${folder.fileCount} items',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppTheme.textSecondary(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: AppTheme.surfaceBorder(ctx), height: 16),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: isPinned ? AppTheme.primary(ctx) : AppTheme.textSecondary(ctx),
                    size: 22,
                  ),
                  title: Text(
                    isPinned ? 'Unpin Folder' : 'Pin to Top',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _togglePinned(folder);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFavorite ? Colors.amber : AppTheme.textSecondary(ctx),
                    size: 22,
                  ),
                  title: Text(
                    isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleFavorite(folder);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(
                    Icons.archive_outlined,
                    color: Color(0xFF4285F4),
                    size: 22,
                  ),
                  title: Text(
                    'Compress to ZIP & Share',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Bundle all files into a .zip archive',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondary(ctx)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _compressAndShareFolder(folder);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    Icons.share_outlined,
                    color: AppTheme.textSecondary(ctx),
                    size: 22,
                  ),
                  title: Text(
                    'Share Folder',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareFolder(folder);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    Icons.edit_outlined,
                    color: AppTheme.textSecondary(ctx),
                    size: 22,
                  ),
                  title: Text(
                    'Rename Folder',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _renameFolder(folder);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    Icons.image_outlined,
                    color: AppTheme.textSecondary(ctx),
                    size: 22,
                  ),
                  title: Text(
                    'Set Cover Image',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setFolderCover(folder);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    color: isLocked ? AppTheme.primary(ctx) : AppTheme.textSecondary(ctx),
                    size: 22,
                  ),
                  title: Text(
                    isLocked ? 'Unlock Folder' : 'Lock Folder',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleFolderLock(folder, !isLocked);
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  title: Text(
                    'Delete Folder',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteFolder(folder);
                  },
                ),
              ],
            ),
          ),
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
                          await RecentActivityService.recordActivity(
                            title: newName,
                            subtitle: 'Collection renamed',
                            type: 'folder',
                            targetPath: newFolderDir.path,
                          );
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
          duration: const Duration(seconds: 3),
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

    // Apply Filter
    if (_currentFilter == 'favorites') {
      result = result.where((f) => _favoritePaths.contains(f.path)).toList();
    } else if (_currentFilter == 'pinned') {
      result = result.where((f) => _pinnedPaths.contains(f.path)).toList();
    } else if (_currentFilter == 'non_empty') {
      result = result.where((f) => f.fileCount > 0).toList();
    }

    // Sort folders
    result.sort((a, b) {
      bool aPinned = _pinnedPaths.contains(a.path);
      bool bPinned = _pinnedPaths.contains(b.path);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      switch (_currentSort) {
        case 'name_asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name_desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'date_desc':
          return b.lastModified.compareTo(a.lastModified);
        case 'count_desc':
          return b.fileCount.compareTo(a.fileCount);
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return result;
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case 'name_asc':
        return 'Name (A-Z)';
      case 'name_desc':
        return 'Name (Z-A)';
      case 'date_desc':
        return 'Newest';
      case 'count_desc':
        return 'Item Count';
      default:
        return 'Name';
    }
  }

  void _showSortAndFilterSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppTheme.surface(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppTheme.surfaceBorder(ctx))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted(ctx).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sort & Filter Collections',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.textPrimary(ctx),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SORT BY',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    color: AppTheme.primary(ctx),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSortOption(ctx, setSheetState, 'Name (A to Z)', 'name_asc', Icons.sort_by_alpha_rounded),
                _buildSortOption(ctx, setSheetState, 'Name (Z to A)', 'name_desc', Icons.sort_by_alpha_rounded),
                _buildSortOption(ctx, setSheetState, 'Date Modified (Newest)', 'date_desc', Icons.schedule_rounded),
                _buildSortOption(ctx, setSheetState, 'Item Count (Highest)', 'count_desc', Icons.format_list_numbered_rounded),
                const Divider(height: 24),
                Text(
                  'FILTER BY',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    color: AppTheme.primary(ctx),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(ctx, setSheetState, 'All Collections', 'all'),
                    _buildFilterChip(ctx, setSheetState, 'Favorites Only', 'favorites'),
                    _buildFilterChip(ctx, setSheetState, 'Pinned Only', 'pinned'),
                    _buildFilterChip(ctx, setSheetState, 'Has Items', 'non_empty'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortOption(BuildContext ctx, StateSetter setSheetState, String label, String value, IconData icon) {
    final isSelected = _currentSort == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        setSheetState(() => _currentSort = value);
        setState(() => _currentSort = value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppTheme.primary(ctx) : AppTheme.textSecondary(ctx)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.primary(ctx) : AppTheme.textPrimary(ctx),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.primary(ctx), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext ctx, StateSetter setSheetState, String label, String value) {
    final isSelected = _currentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setSheetState(() => _currentFilter = value);
          setState(() => _currentFilter = value);
        }
      },
      selectedColor: AppTheme.primaryContainer(ctx),
      backgroundColor: AppTheme.tonal(ctx),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? AppTheme.onPrimaryContainer(ctx) : AppTheme.textSecondary(ctx),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: false,
      extendBody: false,
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
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                _buildSearchBar(context),
                if (_searchQuery.isEmpty) _buildQuickActions(context),
                if (_searchQuery.isEmpty)
                  _buildSectionTitle(context, 'Your Collections'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _initFolders,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).cardColor,
                    child: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildShimmerEffect(),
                          )
                        : _filteredFolders.isEmpty
                            ? _buildEmptyState(context)
                            : _isListView
                                ? ListView.builder(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                    itemCount: _filteredFolders.length,
                                    itemBuilder: (context, index) {
                                      final folder = _filteredFolders[index];
                                      return _buildFolderListCard(folder);
                                    },
                                  )
                                : GridView.builder(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: ResponsiveLayout.getAdaptiveGridColumns(
                                        context,
                                        minItemWidth: _isGridThreeColumns ? 120 : 160,
                                        minColumns: 2,
                                      ),
                                      crossAxisSpacing: 12.0,
                                      mainAxisSpacing: 16.0,
                                      childAspectRatio: ResponsiveLayout.getCardAspectRatio(
                                        context,
                                        isCompactGrid: _isGridThreeColumns,
                                      ),
                                    ),
                                    itemCount: _filteredFolders.length,
                                    itemBuilder: (context, index) {
                                      final folder = _filteredFolders[index];
                                      return _buildFolderCard(folder);
                                    },
                                  ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.surfaceBorder(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildM3NavDestination(
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: true,
              onTap: () {
                HapticFeedback.lightImpact();
              },
            ),
          ),
          Expanded(
            child: _buildM3NavDestination(
              icon: Icons.home_repair_service_rounded,
              label: 'Doc Tools',
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                _showDocToolsMenu(context);
              },
            ),
          ),
          Expanded(
            child: _buildM3NavDestination(
              icon: Icons.history_rounded,
              label: 'Recent',
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                _showRecents();
              },
            ),
          ),
          Expanded(
            child: _buildM3NavDestination(
              icon: Icons.star_outline_rounded,
              label: 'Favorites',
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                _showFavorites();
              },
            ),
          ),
          Expanded(
            child: _buildM3NavDestination(
              icon: Icons.delete_outline_rounded,
              label: 'Trash',
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrashScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildM3NavDestination({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryContainer(context)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppTheme.onPrimaryContainer(context)
                  : AppTheme.textSecondary(context),
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppTheme.textPrimary(context)
                  : AppTheme.textSecondary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted(context).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Create or Import',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildCreateGridTile(
                      icon: Icons.create_new_folder_outlined,
                      label: 'New Folder',
                      bgColor: AppTheme.primaryContainer(context),
                      fgColor: AppTheme.onPrimaryContainer(context),
                      onTap: () {
                        Navigator.pop(context);
                        _createNewFolder();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCreateGridTile(
                      icon: Icons.upload_file_rounded,
                      label: 'Upload File',
                      bgColor: AppTheme.tonal(context),
                      fgColor: AppTheme.textPrimary(context),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndImportFile();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCreateGridTile(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan Document',
                      bgColor: AppTheme.secondaryContainer(context),
                      fgColor: AppTheme.onSecondaryContainer(context),
                      onTap: () {
                        Navigator.pop(context);
                        _scanDocumentToRoot();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCreateGridTile(
                      icon: Icons.edit_note_rounded,
                      label: 'Quick Note',
                      bgColor: AppTheme.tertiaryContainer(context),
                      fgColor: AppTheme.onTertiaryContainer(context),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotesPage(folderPath: 'quick_notes'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateGridTile({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fgColor, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fgColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      if (_folders.isEmpty) {
        Fluttertoast.showToast(msg: "Please create a folder first");
        return;
      }
      final targetFolder = _folders.first;
      for (final file in result.files) {
        if (file.path != null) {
          final src = File(file.path!);
          final dest = File('${targetFolder.path}/${file.name}');
          if (!await dest.exists()) {
            await src.copy(dest.path);
          }
        }
      }
      await _initFolders();
      Fluttertoast.showToast(msg: "Imported ${result.files.length} file(s) into ${targetFolder.name}");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error importing files: $e");
    }
  }

  void _showStorageBreakdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.surfaceBorder(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted(context).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Storage Breakdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Used Space',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  Text(
                    '${_storageUsedMb.toStringAsFixed(1)} MB',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Free Space',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  Text(
                    '${(_maxStorageMb - _storageUsedMb).clamp(0.0, _maxStorageMb).toStringAsFixed(1)} MB',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Capacity',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  Text(
                    '${_maxStorageMb.toStringAsFixed(0)} MB',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  bool isDarkTheme() {
     return Theme.of(context).brightness == Brightness.dark;
  }

  Widget _buildStorageCard(BuildContext context) {
    final progress = (_storageUsedMb / _maxStorageMb).clamp(0.0, 1.0);
    final maxStr = _maxStorageMb >= 1024
        ? "${(_maxStorageMb / 1024).toStringAsFixed(0)} GB"
        : "${_maxStorageMb.toStringAsFixed(0)} MB";

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.surfaceBorder(context),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.cloud_done_outlined,
                      color: AppTheme.primary(context),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local Storage',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${_storageUsedMb.toStringAsFixed(1)} MB',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              ' of $maxStr',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _showStorageBreakdown(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.tonal(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.surfaceBorder(context)),
                      ),
                      child: Text(
                        'Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceBorder(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Brand & Profile Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_special_rounded,
                      color: AppTheme.primary(context),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Document Hub',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: AppTheme.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: AppTheme.textSecondary(context),
                      size: 22,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.tonal(context),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            setThemeMode: widget.setThemeMode,
                          ),
                        ),
                      ).then((_) {
                        _loadPreferences();
                        _loadFolderLockState();
                        _loadProfile();
                      });
                    },
                    tooltip: 'Settings',
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                      _loadProfile();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _avatarInitial,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.onPrimaryContainer(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Greeting Block
          Text(
            '${_getGreeting()}${_userFirstName.isNotEmpty ? ', $_userFirstName' : ''} 👋',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: AppTheme.textPrimary(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Let\'s organize your documents efficiently.',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: AppTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openVoiceSearch() {
    VoiceSearchSheet.show(
      context,
      initialQuery: _searchQuery,
      onSearchSubmitted: (query) {
        setState(() {
          _searchController.text = query;
          _searchQuery = query;
        });
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
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
            hintText: 'Search documents, files...',
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
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : IconButton(
                    icon: Icon(
                      Icons.mic_rounded,
                      color: AppTheme.primary(context),
                      size: 20,
                    ),
                    onPressed: _openVoiceSearch,
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
          onChanged: (value) {
            _searchDebouncer.call(() {
              setState(() {
                _searchQuery = value;
              });
            });
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Quick Actions',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    title: 'New Folder',
                    icon: Icons.create_new_folder_outlined,
                    bgColor: AppTheme.primaryContainer(context),
                    fgColor: AppTheme.onPrimaryContainer(context),
                    onTap: () => _showFolderCreationChooser(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    title: 'Notes',
                    icon: Icons.edit_note_rounded,
                    bgColor: AppTheme.secondaryContainer(context),
                    fgColor: AppTheme.onSecondaryContainer(context),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuickNotesScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    context,
                    title: 'Passwords',
                    icon: Icons.password_rounded,
                    bgColor: AppTheme.tertiaryContainer(context),
                    fgColor: AppTheme.onTertiaryContainer(context),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PasswordManagerScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFolderCreationChooser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add New Collection',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to add your documents',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.surfaceBorder(context)),
                  ),
                  tileColor: AppTheme.tonal(context).withOpacity(0.5),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.create_new_folder_rounded, color: AppTheme.onPrimaryContainer(context)),
                  ),
                  title: Text(
                    'Create New Folder',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Create an empty folder to organize files',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _createNewFolder();
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.surfaceBorder(context)),
                  ),
                  tileColor: AppTheme.tonal(context).withOpacity(0.5),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.folder_zip_rounded, color: AppTheme.onSecondaryContainer(context)),
                  ),
                  title: Text(
                    'Import ZIP Archive to Folder',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Extract and restore documents from a .zip backup',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _extractZipArchive();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddFolderSuggestionCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showFolderCreationChooser(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primary(context).withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.25 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  color: AppTheme.primaryContainer(context).withOpacity(0.35),
                ),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary(context).withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: AppTheme.onPrimaryContainer(context),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Folder',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create or import',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.textSecondary(context),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocToolsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBorder(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.home_repair_service_rounded,
                          color: AppTheme.onPrimaryContainer(context),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doc Tools',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          Text(
                            'PDF processing, scanner & productivity',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDocToolTile(
                    context,
                    icon: Icons.document_scanner_outlined,
                    title: 'Document Scanner',
                    subtitle: 'Scan receipts, pages & documents using camera',
                    color: AppTheme.primary(context),
                    onTap: () {
                      Navigator.pop(ctx);
                      _scanDocumentToRoot();
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'PDF Maker',
                    subtitle: 'Convert camera shots or gallery images to PDF',
                    color: const Color(0xFFEA4335),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImagesAndCreatePdf();
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.merge_type_rounded,
                    title: 'Merge & Split PDF',
                    subtitle: 'Combine multiple PDFs or extract selected pages',
                    color: const Color(0xFF4285F4),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfMergeSplitScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.build_circle_outlined,
                    title: 'PDF Suite',
                    subtitle: 'Reorder, compress, watermarks, rotate & encrypt',
                    color: const Color(0xFFFBBC04),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfToolsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.text_snippet_outlined,
                    title: 'Text to PDF',
                    subtitle: 'Format plain or markdown text directly into PDF',
                    color: const Color(0xFF34A853),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TextToPdfScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.calculate_outlined,
                    title: 'Calculator & Unit Converter',
                    subtitle: 'Currency, measurements & document arithmetic',
                    color: const Color(0xFF9C27B0),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalculatorScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.check_box_outlined,
                    title: 'Tasks & Checklist',
                    subtitle: 'Organize reminders and actionable to-do items',
                    color: const Color(0xFF009688),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TodoPage(),
                        ),
                      );
                    },
                  ),
                  _buildDocToolTile(
                    context,
                    icon: Icons.archive_outlined,
                    title: 'Offline ZIP Backup',
                    subtitle: 'Export complete archive or import external ZIP',
                    color: const Color(0xFF607D8B),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showZipDialog();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocToolTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.tonal(context).withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _compressAndShareFolder(FolderInfo folder) async {
    try {
      Fluttertoast.showToast(msg: "Compressing '${folder.name}' to ZIP...");
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = folder.name.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final outPath = '${tempDir.path}${Platform.pathSeparator}$sanitizedName.zip';
      
      final zip = await ZipService.compressDirectory(Directory(folder.path), outPath);
      if (zip != null && await zip.exists()) {
        Fluttertoast.showToast(
          msg: "ZIP ready! Opening share...",
          backgroundColor: const Color(0xFF10B981),
        );
        await Share.shareXFiles(
          [XFile(zip.path)],
          text: 'Shared ZIP Archive of ${folder.name}',
          subject: '${folder.name}.zip',
        );
      } else {
        Fluttertoast.showToast(
          msg: "Could not create ZIP archive for this folder",
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error compressing folder: $e", backgroundColor: Colors.red);
    }
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: fgColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.tonal(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.surfaceBorder(context), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showZipDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Text(
                'ZIP Tools (100% Offline)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.archive_rounded, color: Theme.of(context).primaryColor),
                ),
                title: Text(
                  'Backup Everything to ZIP',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text('Compress all collections into a single ZIP archive'),
                onTap: () async {
                  Navigator.pop(context);
                  _backupAllToZip();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.unarchive_rounded, color: Theme.of(context).primaryColor),
                ),
                title: Text(
                  'Extract ZIP Archive to Folder',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text('Unpack any offline ZIP into Document Hub'),
                onTap: () async {
                  Navigator.pop(context);
                  _extractZipArchive();
                },
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  Future<void> _backupAllToZip() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory documentFoldersDir = Directory(
        '${appDocDir.path}${Platform.pathSeparator}document_folders',
      );
      if (!await documentFoldersDir.exists()) {
        Fluttertoast.showToast(msg: "No documents to backup");
        return;
      }

      Fluttertoast.showToast(msg: "Compressing documents to ZIP...");
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${appDocDir.path}${Platform.pathSeparator}DocumentHub_Backup_$timestamp.zip';
      final zip = await ZipService.compressDirectory(documentFoldersDir, outPath);

      if (zip != null && await zip.exists()) {
        Fluttertoast.showToast(
          msg: "Backup complete: ${zip.path.split(Platform.pathSeparator).last}",
          backgroundColor: const Color(0xFF10B981),
        );
        await Share.shareXFiles([XFile(zip.path)], text: 'Document Hub Backup');
      } else {
        Fluttertoast.showToast(msg: "Failed to create ZIP backup", backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error creating ZIP: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _extractZipArchive() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.single.path == null) return;

      final zipFile = File(result.files.single.path!);
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final zipName = zipFile.path.split(Platform.pathSeparator).last.replaceAll('.zip', '');
      final targetDir = Directory(
        '${appDocDir.path}${Platform.pathSeparator}document_folders${Platform.pathSeparator}$zipName',
      );

      Fluttertoast.showToast(msg: "Extracting ZIP files...");
      final count = await ZipService.extractZipToDirectory(zipFile, targetDir);

      if (count > 0) {
        Fluttertoast.showToast(
          msg: "Extracted $count files into '$zipName'",
          backgroundColor: const Color(0xFF10B981),
        );
        _initFolders();
      } else {
        Fluttertoast.showToast(msg: "No files extracted from ZIP", backgroundColor: Colors.orange);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error extracting ZIP: $e", backgroundColor: Colors.red);
    }
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
    if (title != 'Your Collections') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.textPrimary(context),
          ),
        ),
      );
    }

    final isFiltered = _currentFilter != 'all' || _currentSort != 'name_asc';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Your Collections',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer(context).withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_filteredFolders.length}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onPrimaryContainer(context),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Sort & Filter chip
              GestureDetector(
                onTap: () => _showSortAndFilterSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFiltered
                        ? AppTheme.primaryContainer(context).withOpacity(0.4)
                        : AppTheme.tonal(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isFiltered
                          ? AppTheme.primary(context)
                          : AppTheme.surfaceBorder(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSortLabel(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isFiltered
                              ? AppTheme.primary(context)
                              : AppTheme.textSecondary(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: isFiltered
                            ? AppTheme.primary(context)
                            : AppTheme.textSecondary(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Material 3 View Toggle Pill Container (Grid / List)
              Container(
                  height: 32,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.tonal(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.surfaceBorder(context),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Grid Mode Toggle
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () async {
                          if (_isListView) {
                            HapticFeedback.lightImpact();
                            final prefs =
                                await SharedPreferences.getInstance();
                            setState(() => _isListView = false);
                            await prefs.setBool('is_list_view', false);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: !_isListView
                                ? AppTheme.primaryContainer(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: !_isListView
                                ? AppTheme.onPrimaryContainer(context)
                                : AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // List Mode Toggle
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () async {
                          if (!_isListView) {
                            HapticFeedback.lightImpact();
                            final prefs =
                                await SharedPreferences.getInstance();
                            setState(() => _isListView = true);
                            await prefs.setBool('is_list_view', true);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isListView
                                ? AppTheme.primaryContainer(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            Icons.view_agenda_rounded,
                            size: 16,
                            color: _isListView
                                ? AppTheme.onPrimaryContainer(context)
                                : AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  String _getFolderSubtitle(FolderInfo folder) {
    try {
      final dir = Directory(folder.path);
      if (dir.existsSync()) {
        final stat = dir.statSync();
        final dt = stat.modified;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final date = DateTime(dt.year, dt.month, dt.day);
        String dateStr;
        if (date == today) {
          dateStr = 'Today, ${DateFormat('h:mm a').format(dt)}';
        } else if (today.difference(date).inDays == 1) {
          dateStr = 'Yesterday';
        } else {
          dateStr = DateFormat('MMM d').format(dt);
        }
        return '${folder.fileCount} items • $dateStr';
      }
    } catch (_) {}
    return '${folder.fileCount} items';
  }

  Widget _buildFolderListCard(FolderInfo folder) {
    final isLocked = _isFolderLocked(folder);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.surfaceBorder(context),
            width: 1,
          ),
        ),
        elevation: AppTheme.isDark(context) ? 0 : 0.5,
        shadowColor: Colors.black.withOpacity(0.04),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToFolder(folder),
          onLongPress: () => _showFolderOptions(folder),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Leading Blue Folder Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer(context).withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      isLocked ? Icons.lock_rounded : Icons.folder_rounded,
                      color: AppTheme.primary(context),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Folder Title & Items Count Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _getFolderSubtitle(folder),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // More Options 3-dots
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary(context),
                    size: 20,
                  ),
                  onPressed: () => _showFolderOptions(folder),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddFolderListSuggestionCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.primary(context).withOpacity(0.35),
            width: 1.5,
          ),
        ),
        elevation: AppTheme.isDark(context) ? 0 : 0.5,
        shadowColor: Colors.black.withOpacity(0.04),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showFolderCreationChooser(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: AppTheme.onPrimaryContainer(context),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Folder',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.primary(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Create or import documents',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyFolderVectorAnimation(size: 72),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Start Organizing'
                          : 'No matching folders found',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Create your first folder to get started.'
                          : 'Try a different search term.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    if (_searchQuery.isEmpty) ...[
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _showFolderCreationChooser(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Create Folder',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.surfaceBorder(context),
              width: 1,
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
                      if (widget.isLocked)
                        Container(
                          color: AppTheme.primaryContainer(context).withOpacity(0.4),
                          child: Center(
                            child: Icon(
                              Icons.lock_rounded,
                              size: 42,
                              color: AppTheme.primary(context),
                            ),
                          ),
                        )
                      else if (widget.folder.thumbnailPath != null)
                        OptimizedImage(
                          path: widget.folder.thumbnailPath!,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppTheme.tonal(context),
                            child: Icon(
                              Icons.folder_rounded,
                              size: 42,
                              color: AppTheme.primary(context),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer(context),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.folder_rounded,
                              size: 32,
                              color: AppTheme.primary(context),
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
                              color: Colors.amber,
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
                              color: AppTheme.primary(context),
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
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: widget.onOptionsTap,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.folder.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isLocked) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: AppTheme.textMuted(context),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.folder.fileCount} items',
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
                          Icons.folder_outlined,
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
}
