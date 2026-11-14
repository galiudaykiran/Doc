import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_app/services/trash_service.dart';
import 'package:gallery_app/models/file_info.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileViewPage extends StatefulWidget {
  final List<FileInfo> files;
  final int initialIndex;

  const FileViewPage({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  @override
  State<FileViewPage> createState() => _FileViewPageState();
}

class _FileViewPageState extends State<FileViewPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  late AnimationController _controlsAnimController;
  List<String> _favoriteFiles = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteFiles = prefs.getStringList('favorite_files') ?? [];
    });
  }

  Future<void> _toggleFavorite(String path) async {
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

  @override
  void dispose() {
    _pageController.dispose();
    _controlsAnimController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _controlsAnimController.forward();
      } else {
        _controlsAnimController.reverse();
      }
    });
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

  Future<void> _deleteFile(FileInfo file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Move to Trash?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will move the file to the trash bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await TrashService.instance.moveFileToTrash(file.path);
        if (success) {
          if (widget.files.length > 1) {
            setState(() {
              widget.files.removeAt(_currentIndex);
              if (_currentIndex >= widget.files.length) {
                _currentIndex = widget.files.length - 1;
              }
            });
          } else {
            Navigator.pop(context);
          }
          Fluttertoast.showToast(msg: "Moved to trash");
        } else {
          Fluttertoast.showToast(msg: "Failed to move file to trash");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Error moving file: $e");
      }
    }
  }

  Future<void> _editImage(FileInfo file) async {
    try {
      final imageBytes = await File(file.path).readAsBytes();

      final editedImageBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.memory(
            imageBytes,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                Navigator.pop(context, bytes);
              },
            ),
            configs: ProImageEditorConfigs(
              designMode: platformDesignMode,
              imageGeneration: const ImageGenerationConfigs(
                enableBackgroundGeneration: false,
              ),
            ),
          ),
        ),
      );

      if (editedImageBytes != null) {
        await File(file.path).writeAsBytes(editedImageBytes);
        // Force rebuild to show updated image
        setState(() {});
        Fluttertoast.showToast(msg: "Image edited successfully!");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error editing image: $e");
    }
  }

  void _showFileDetails(FileInfo file) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // Transparent to show the frosted look content
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
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
            _buildDetailRow('Name', file.name),
            const Divider(height: 32),
            _buildDetailRow('Path', file.path),
            const Divider(height: 32),
            FutureBuilder<FileStat>(
              future: File(file.path).stat(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Size',
                        '${(snapshot.data!.size / 1024).toStringAsFixed(2)} KB',
                      ),
                      const Divider(height: 32),
                      _buildDetailRow(
                        'Modified',
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
                  padding: EdgeInsets.symmetric(vertical: 8),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
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

  Widget _buildDetailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(fontSize: 15, height: 1.4)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: false, // Back icon removed
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            "No files to display",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final currentFile = widget.files[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Content Layer
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleControls,
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 20) {
                  Navigator.pop(context);
                }
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.files.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  return file.type == FileType.image
                      ? _buildImageViewer(file)
                      : _buildGenericFileViewer(file);
                },
              ),
            ),
          ),

          // 2. Top Bar Layer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _controlsAnimController,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.15),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.4),
                          Theme.of(context).primaryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                    ),
                    child: AppBar(
                      automaticallyImplyLeading: false, // Back icon removed
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentFile.name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_currentIndex + 1} of ${widget.files.length}',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  centerTitle: false,
                ),
              ),
            ),
          ),
        ),
      ),

      // 3. Bottom Bar Layer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _controlsAnimController,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      top: 16,
                      left: 16,
                      right: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: _favoriteFiles.contains(currentFile.path)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: 'Favorite',
                          color: _favoriteFiles.contains(currentFile.path)
                              ? Colors.redAccent
                              : Colors.white,
                          onTap: () => _toggleFavorite(currentFile.path),
                        ),
                        _buildActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          onTap: () => _shareFile(currentFile),
                        ),
                        if (currentFile.type == FileType.image)
                          _buildActionButton(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            onTap: () => _editImage(currentFile),
                          ),
                        _buildActionButton(
                          icon: Icons.info_outline_rounded,
                          label: 'Details',
                          onTap: () => _showFileDetails(currentFile),
                        ),
                        _buildActionButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Trash',
                          color: Colors.redAccent,
                          onTap: () => _deleteFile(currentFile),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer(FileInfo file) {
    return Container(
      color: Colors.black, // Ensure background is black
      child: PhotoView(
        imageProvider: FileImage(File(file.path)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        heroAttributes: PhotoViewHeroAttributes(tag: file.path),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                color: Colors.white54,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load image',
                style: GoogleFonts.poppins(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericFileViewer(FileInfo file) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(file.icon, size: 80, color: Colors.white70),
            const SizedBox(height: 24),
            Text(
              file.name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              file.type.toString().split('.').last.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => OpenFilex.open(file.path),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open External'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
