import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/file_info.dart';
import '../models/folder_info.dart';
import '../models/quick_note_item.dart';
import '../theme/app_theme.dart';
import 'file_view_page.dart';
import 'folder_images_page.dart';
import 'notes_page.dart';

class FavoritesScreen extends StatefulWidget {
  final List<FolderInfo> allFolders;

  const FavoritesScreen({
    super.key,
    required this.allFolders,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FolderInfo> _favoriteFolders = [];
  List<FileInfo> _favoriteFiles = [];
  List<QuickNoteItem> _favoriteNotes = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Folders', 'Documents', 'Images', 'Notes'];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favFolderPaths = (prefs.getStringList('favorite_folders') ?? []).toSet();
    final favFilePaths = (prefs.getStringList('favorite_files') ?? []).toSet();

    // 1. Matched Folders
    final folders = widget.allFolders.where((f) => favFolderPaths.contains(f.path)).toList();

    // 2. Aggregate all files
    final List<FileInfo> files = [];
    for (final folder in widget.allFolders) {
      for (final file in folder.files) {
        if (favFilePaths.contains(file.path)) {
          files.add(file);
        }
      }
    }

    // 3. Pinned / Favorite Notes
    final List<QuickNoteItem> notes = [];
    final rawNotes = prefs.getString('hub_quick_notes_list_v1');
    if (rawNotes != null) {
      try {
        final List list = prefs.getString('hub_quick_notes_list_v1') != null
            ? (prefs.getString('hub_quick_notes_list_v1')!.isNotEmpty
                ? (prefs.getStringList('favorite_notes') ?? [])
                : [])
            : [];
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _favoriteFolders = folders;
        _favoriteFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFolderFavorite(FolderInfo folder) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_folders') ?? [];
    list.remove(folder.path);
    await prefs.setStringList('favorite_folders', list);

    setState(() {
      _favoriteFolders.removeWhere((f) => f.path == folder.path);
    });
    Fluttertoast.showToast(msg: 'Removed "${folder.name}" from favorites');
  }

  Future<void> _removeFileFavorite(FileInfo file) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_files') ?? [];
    list.remove(file.path);
    await prefs.setStringList('favorite_files', list);

    setState(() {
      _favoriteFiles.removeWhere((f) => f.path == file.path);
    });
    Fluttertoast.showToast(msg: 'Removed "${file.name}" from favorites');
  }

  List<dynamic> get _filteredItems {
    final List<dynamic> all = [];
    if (_selectedFilter == 'All') {
      all.addAll(_favoriteFolders);
      all.addAll(_favoriteFiles);
    } else if (_selectedFilter == 'Folders') {
      all.addAll(_favoriteFolders);
    } else if (_selectedFilter == 'Documents') {
      all.addAll(_favoriteFiles.where((f) {
        final ext = f.name.toLowerCase();
        return ext.endsWith('.pdf') || ext.endsWith('.doc') || ext.endsWith('.docx') || ext.endsWith('.txt');
      }));
    } else if (_selectedFilter == 'Images') {
      all.addAll(_favoriteFiles.where((f) {
        final ext = f.name.toLowerCase();
        return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.webp');
      }));
    } else if (_selectedFilter == 'Notes') {
      // Notes filter
    }
    return all;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: AppTheme.surface(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favorites',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Starred folders and documents for quick access',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryContainer(context)
                            : AppTheme.tonal(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary(context).withOpacity(0.3)
                              : AppTheme.surfaceBorder(context),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.onPrimaryContainer(context)
                              : AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item is FolderInfo) {
                              return _buildFolderFavoriteCard(item);
                            } else if (item is FileInfo) {
                              return _buildFileFavoriteCard(item);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderFavoriteCard(FolderInfo folder) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.surfaceBorder(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.folder_rounded,
            color: AppTheme.primary(context),
            size: 24,
          ),
        ),
        title: Text(
          folder.name,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppTheme.textPrimary(context),
          ),
        ),
        subtitle: Text(
          'Collection • ${folder.fileCount} items',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              tooltip: 'Remove favorite',
              onPressed: () => _removeFolderFavorite(folder),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted(context),
              size: 20,
            ),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderImagesPage(folder: folder),
            ),
          );
          _loadFavorites();
        },
      ),
    );
  }

  Widget _buildFileFavoriteCard(FileInfo file) {
    final isPdf = file.name.toLowerCase().endsWith('.pdf');
    final isImage = file.name.toLowerCase().endsWith('.jpg') ||
        file.name.toLowerCase().endsWith('.jpeg') ||
        file.name.toLowerCase().endsWith('.png');

    Color badgeBg = const Color(0xFFE9EEF6);
    Color badgeFg = const Color(0xFF0B57D0);
    IconData icon = Icons.insert_drive_file_rounded;

    if (isPdf) {
      badgeBg = const Color(0xFFFCE8E6);
      badgeFg = const Color(0xFFC5221F);
      icon = Icons.picture_as_pdf_rounded;
    } else if (isImage) {
      badgeBg = const Color(0xFFE6F4EA);
      badgeFg = const Color(0xFF137333);
      icon = Icons.image_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.surfaceBorder(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: badgeFg, size: 22),
        ),
        title: Text(
          file.name,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.textPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatSize(file.size),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              tooltip: 'Remove favorite',
              onPressed: () => _removeFileFavorite(file),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted(context),
              size: 20,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FileViewPage(
                files: [file],
                initialIndex: 0,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 44,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Favorites Yet',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the star icon on any folder or file to easily find it here anytime.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

