import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';

enum ScanMode { color, grayscale, blackWhite, enhanced }

class EnhancedScannerScreen extends StatefulWidget {
  final String? savePath;

  const EnhancedScannerScreen({super.key, this.savePath});

  @override
  State<EnhancedScannerScreen> createState() => _EnhancedScannerScreenState();
}

class _EnhancedScannerScreenState extends State<EnhancedScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<ScannedPage> _scannedPages = [];
  bool _isProcessing = false;
  ScanMode _scanMode = ScanMode.enhanced;
  double _brightness = 0.0;
  double _contrast = 1.0;
  int? _selectedPageIndex;
  String _documentName = 'Scanned Document';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarTextColor = isDark ? Colors.white : Colors.black87;
    final appBarIconBg = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.08);
    final appBarIconBorder = isDark
        ? Colors.white.withOpacity(0.2)
        : Colors.black.withOpacity(0.12);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          Colors.transparent, // Background gradient handled by wrapping body
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: appBarIconBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: appBarIconBorder, width: 1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: appBarTextColor,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Document Scanner',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: appBarTextColor,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_scannedPages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: appBarTextColor),
              onPressed: _editDocumentName,
              tooltip: 'Rename',
            ),
          if (_scannedPages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.save_rounded, color: appBarTextColor),
              onPressed: _savePdf,
              tooltip: 'Save PDF',
            ),
        ],
      ),
      body: Stack(
        children: [
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
            child: _scannedPages.isEmpty
                ? _buildEmptyState()
                : _buildScannerContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _showScanOptions,
        backgroundColor: const Color(0xFF4F46E5),
        icon: Icon(
          _scannedPages.isEmpty ? Icons.camera_alt_rounded : Icons.add_rounded,
          color: Colors.white,
        ),
        label: Text(
          _scannedPages.isEmpty ? 'Scan Document' : 'Add Page',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.document_scanner_rounded,
              size: 80,
              color: const Color(0xFF4F46E5).withOpacity(0.8),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            'Scan Documents',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ).animate().fade(delay: 100.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Capture documents with your camera and convert them to high-quality PDFs',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
            ),
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 32),
          // Scan mode selector
          _buildScanModeSelector().animate().fade(delay: 300.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildScanModeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Mode',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModeChip(ScanMode.color, 'Color', Icons.palette_outlined),
              const SizedBox(width: 8),
              _buildModeChip(
                ScanMode.grayscale,
                'Gray',
                Icons.gradient_rounded,
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                ScanMode.blackWhite,
                'B&W',
                Icons.contrast_rounded,
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                ScanMode.enhanced,
                'Auto',
                Icons.auto_fix_high_rounded,
              ),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildModeChip(ScanMode mode, String label, IconData icon) {
    final isSelected = _scanMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
           HapticFeedback.lightImpact();
           setState(() => _scanMode = mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4F46E5).withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF3730A3) : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xFF3730A3) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerContent() {
    return Column(
      children: [
        // Page thumbnails
        Container(
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _scannedPages.length,
            onReorder: _reorderPages,
            itemBuilder: (context, index) {
              final page = _scannedPages[index];
              final isSelected = _selectedPageIndex == index;

              return GestureDetector(
                key: ValueKey(page.id),
                onTap: () => setState(() => _selectedPageIndex = index),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          page.thumbnail,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 110,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _deletePage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Selected page preview
        Expanded(
          child: _selectedPageIndex != null
              ? _buildPagePreview(_scannedPages[_selectedPageIndex!])
              : _buildPagePreview(_scannedPages.first),
        ),

        // Controls
        _buildControls(),

        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildPagePreview(ScannedPage page) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.memory(
          page.processedImage ?? page.originalImage,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (_selectedPageIndex == null && _scannedPages.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
      child: Column(
        children: [
          // Brightness
          Row(
            children: [
              const Icon(Icons.brightness_6_rounded, size: 20),
              const SizedBox(width: 12),
              Text('Brightness', style: GoogleFonts.poppins(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: -1.0,
                  max: 1.0,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (v) {
                    setState(() => _brightness = v);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          // Contrast
          Row(
            children: [
              const Icon(Icons.contrast_rounded, size: 20),
              const SizedBox(width: 12),
              Text('Contrast', style: GoogleFonts.poppins(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _contrast,
                  min: 0.5,
                  max: 2.0,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (v) {
                    setState(() => _contrast = v);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                Icons.rotate_left_rounded,
                'Rotate',
                _rotateLeft,
              ),
              _buildQuickAction(
                Icons.rotate_right_rounded,
                'Rotate',
                _rotateRight,
              ),
              _buildQuickAction(Icons.crop_rounded, 'Crop', _cropImage),
              _buildQuickAction(Icons.refresh_rounded, 'Reset', _resetFilters),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF3730A3)),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF3730A3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Page',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildScanOption(
                    Icons.camera_alt_rounded,
                    'Camera',
                    'Scan with camera',
                    () {
                      Navigator.pop(context);
                      _scanFromCamera();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildScanOption(
                    Icons.photo_library_rounded,
                    'Gallery',
                    'Import from gallery',
                    () {
                      Navigator.pop(context);
                      _importFromGallery();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildScanOption(
                    Icons.burst_mode_rounded,
                    'Batch',
                    'Scan multiple pages',
                    () {
                      Navigator.pop(context);
                      _batchScan();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildScanOption(
                    Icons.insert_drive_file_rounded,
                    'Import PDF',
                    'Add pages from PDF',
                    () {
                      Navigator.pop(context);
                      _importFromPdf();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
         HapticFeedback.lightImpact();
         onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 32, color: const Color(0xFF4F46E5)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scanFromCamera() async {
    setState(() => _isProcessing = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await _processAndAddImage(File(photo.path));
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error scanning: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _importFromGallery() async {
    setState(() => _isProcessing = true);

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 100,
      );

      for (final image in images) {
        await _processAndAddImage(File(image.path));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error importing: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _batchScan() async {
    int pageCount = 0;
    bool continueScan = true;

    while (continueScan) {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) break;

      setState(() => _isProcessing = true);
      await _processAndAddImage(File(photo.path));
      pageCount++;
      setState(() => _isProcessing = false);

      if (!mounted) break;

      // Ask if user wants to continue
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Page $pageCount Scanned', style: GoogleFonts.poppins()),
          content: Text('Scan another page?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Done', style: GoogleFonts.poppins()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Scan More', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );

      continueScan = result ?? false;
    }
  }

  Future<void> _importFromPdf() async {
    Fluttertoast.showToast(msg: 'PDF import coming soon');
  }

  Future<void> _processAndAddImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) return;

    // Apply scan mode processing
    final processedImage = _applyMode(image);
    final processedBytes = Uint8List.fromList(img.encodePng(processedImage));

    // Create thumbnail
    final thumbnail = img.copyResize(processedImage, width: 150);
    final thumbnailBytes = Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: 80),
    );

    setState(() {
      _scannedPages.add(
        ScannedPage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          originalImage: bytes,
          processedImage: processedBytes,
          thumbnail: thumbnailBytes,
        ),
      );
      _selectedPageIndex = _scannedPages.length - 1;
    });

    // Clean up temp file
    try {
      await imageFile.delete();
    } catch (_) {}
  }

  img.Image _applyMode(img.Image image) {
    switch (_scanMode) {
      case ScanMode.color:
        return image;
      case ScanMode.grayscale:
        return img.grayscale(image);
      case ScanMode.blackWhite:
        var bw = img.grayscale(image);
        bw = img.contrast(bw, contrast: 150);
        return bw;
      case ScanMode.enhanced:
        var enhanced = img.contrast(image, contrast: 120);
        enhanced = img.adjustColor(enhanced, brightness: 1.05);
        enhanced = img.normalize(enhanced, min: 0, max: 255);
        return enhanced;
    }
  }

  void _applyFilters() {
    if (_selectedPageIndex == null) return;

    final page = _scannedPages[_selectedPageIndex!];
    img.Image? image = img.decodeImage(page.originalImage);
    if (image == null) return;

    // Apply mode first
    image = _applyMode(image);

    // Apply brightness and contrast
    if (_brightness != 0.0) {
      image = img.adjustColor(image, brightness: 1.0 + _brightness);
    }
    if (_contrast != 1.0) {
      image = img.contrast(image, contrast: (_contrast * 100).toInt());
    }

    final processedBytes = Uint8List.fromList(img.encodePng(image));

    setState(() {
      _scannedPages[_selectedPageIndex!] = ScannedPage(
        id: page.id,
        originalImage: page.originalImage,
        processedImage: processedBytes,
        thumbnail: page.thumbnail,
      );
    });
  }

  void _rotateLeft() {
    if (_selectedPageIndex == null) return;
    _rotateImage(-90);
  }

  void _rotateRight() {
    if (_selectedPageIndex == null) return;
    _rotateImage(90);
  }

  void _rotateImage(int degrees) {
    final page = _scannedPages[_selectedPageIndex!];
    img.Image? image = img.decodeImage(
      page.processedImage ?? page.originalImage,
    );
    if (image == null) return;

    image = img.copyRotate(image, angle: degrees);

    final processedBytes = Uint8List.fromList(img.encodePng(image));
    final thumbnail = img.copyResize(image, width: 150);
    final thumbnailBytes = Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: 80),
    );

    setState(() {
      _scannedPages[_selectedPageIndex!] = ScannedPage(
        id: page.id,
        originalImage: page.originalImage,
        processedImage: processedBytes,
        thumbnail: thumbnailBytes,
      );
    });
  }

  void _cropImage() {
    Fluttertoast.showToast(msg: 'Crop feature coming soon');
  }

  void _resetFilters() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
    });
    _applyFilters();
  }

  void _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _scannedPages.removeAt(oldIndex);
      _scannedPages.insert(newIndex, item);
      _selectedPageIndex = newIndex;
    });
  }

  void _deletePage(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Page?', style: GoogleFonts.poppins()),
        content: Text(
          'This will remove page ${index + 1}.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _scannedPages.removeAt(index);
                if (_selectedPageIndex == index) {
                  _selectedPageIndex = _scannedPages.isNotEmpty ? 0 : null;
                } else if (_selectedPageIndex != null &&
                    _selectedPageIndex! > index) {
                  _selectedPageIndex = _selectedPageIndex! - 1;
                }
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _editDocumentName() {
    final controller = TextEditingController(text: _documentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Document Name', style: GoogleFonts.poppins()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter document name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _documentName = controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _savePdf() async {
    if (_scannedPages.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      for (final page in _scannedPages) {
        final imageBytes = page.processedImage ?? page.originalImage;
        final pdfImage = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) =>
                pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
          ),
        );
      }

      // Save to documents folder
      final directory = widget.savePath != null
          ? Directory(widget.savePath!)
          : await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${_documentName.replaceAll(' ', '_')}_$timestamp.pdf';
      final filePath = '${directory.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.grey, size: 28),
                const SizedBox(width: 12),
                Text('PDF Saved', style: GoogleFonts.poppins()),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_scannedPages.length} page(s)',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done', style: GoogleFonts.poppins()),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(filePath)]);
                },
                icon: const Icon(Icons.share),
                label: Text('Share', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error saving PDF: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

class ScannedPage {
  final String id;
  final Uint8List originalImage;
  final Uint8List? processedImage;
  final Uint8List thumbnail;

  ScannedPage({
    required this.id,
    required this.originalImage,
    this.processedImage,
    required this.thumbnail,
  });
}
