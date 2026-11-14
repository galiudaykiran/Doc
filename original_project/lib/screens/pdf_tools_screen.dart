import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gallery_app/widgets/folder_picker_dialog.dart';
import 'package:gallery_app/screens/text_to_pdf_screen.dart';
import 'dart:typed_data';

class PdfToolsScreen extends StatefulWidget {
  final String? initialFilePath;
  const PdfToolsScreen({super.key, this.initialFilePath});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.white : Colors.black;
    final appBarTextColor = isDark ? Colors.white : Colors.black87;
    final appBarIconColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08);
    final appBarIconBorder = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.12);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
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
            color: appBarIconColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: appBarIconBorder,
              width: 1,
            ),
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
          'PDF Tools',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: appBarTextColor,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.initialFilePath != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.description_rounded, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Editing File:',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38),
                                ),
                                Text(
                                  widget.initialFilePath!.split(Platform.pathSeparator).last,
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade().slideX(begin: -0.1),

                  _buildSectionHeader('Convert').animate().fade(duration: 400.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.image_rounded,
                          title: 'Images to PDF',
                          subtitle: 'Convert images to PDF',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: _imagesToPdf,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.photo_library_rounded,
                          title: 'PDF to Images',
                          subtitle: 'Extract images from PDF',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: widget.initialFilePath != null 
                              ? () => _pdfToImages(path: widget.initialFilePath)
                              : _pdfToImages,
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Edit').animate().fade(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.compress_rounded,
                          title: 'Compress PDF',
                          subtitle: 'Reduce file size',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: widget.initialFilePath != null 
                              ? () => _compressPdf(path: widget.initialFilePath)
                              : _compressPdf,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.water_drop_rounded,
                          title: 'Add Watermark',
                          subtitle: 'Add text watermark',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: widget.initialFilePath != null 
                              ? () => _addWatermark(path: widget.initialFilePath)
                              : _addWatermark,
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.rotate_right_rounded,
                          title: 'Rotate Pages',
                          subtitle: 'Rotate PDF pages',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: widget.initialFilePath != null 
                              ? () => _rotatePdf(path: widget.initialFilePath)
                              : _rotatePdf,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Container()), // Placeholder for alignment
                    ],
                  ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Create').animate().fade(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.text_fields_rounded,
                          title: 'Text to PDF',
                          subtitle: 'Create PDF from text',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TextToPdfScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          icon: Icons.draw_rounded,
                          title: 'Redact / Mark',
                          subtitle: 'Mark or erase text',
                          color: isDark ? Colors.white : Colors.black,
                          onTap: _redactPdf,
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: accentColor),
                            const SizedBox(height: 20),
                            Text(
                              'Processing...',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please wait while we prepare your PDF.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: isDark ? ImageFilter.blur(sigmaX: 10, sigmaY: 10) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ IMAGES TO PDF ============
  Future<void> _imagesToPdf() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 90);

    if (images.isEmpty) return;

    // Show options dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ImagesToPdfDialog(imageCount: images.length),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();
      final pageFormat = result['pageSize'] as PdfPageFormat;
      final fitToPage = result['fitToPage'] as bool;
      final quality = result['quality'] as int;

      for (final image in images) {
        final bytes = await File(image.path).readAsBytes();
        
        Uint8List finalBytes = bytes;

        // Only use the heavy image processing if quality is intentionally reduced
        if (quality < 100) {
          // Allow UI to breathe
          await Future.delayed(const Duration(milliseconds: 10));
          
          img.Image? decodedImage = img.decodeImage(bytes);
          if (decodedImage != null) {
            decodedImage = img.copyResize(
              decodedImage,
              width: (decodedImage.width * quality / 100).round(),
            );
            finalBytes = Uint8List.fromList(
              img.encodeJpg(decodedImage, quality: quality),
            );
          }
        }

        final pdfImage = pw.MemoryImage(finalBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: fitToPage
                ? pw.EdgeInsets.zero
                : const pw.EdgeInsets.all(20),
            build: (context) {
              if (fitToPage) {
                return pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                );
              } else {
                return pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.scaleDown),
                );
              }
            },
          ),
        );
      }

      final savedPath = await _savePdf(pdf, 'images_to_pdf');
      if (savedPath != null) {
        _showSuccessDialog(
          savedPath,
          'PDF Created',
          '${images.length} images converted',
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ============ PDF TO IMAGES ============
  Future<void> _pdfToImages({String? path}) async {
    String? pdfPath = path;

    if (pdfPath == null) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.first.path == null) return;
      pdfPath = result.files.first.path!;
    }

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = await File(pdfPath!).readAsBytes();
      
      // Select output folder
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => FolderPickerDialog(
          defaultFileName: 'Extracted Images',
          isFolderOnly: true,
        ),
      );

      if (result == null) return;
      
      final String selectedFolder = result['folder'] as String;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagesDir = Directory('$selectedFolder/extracted_images_$timestamp');
      await imagesDir.create(recursive: true);

      int pageNum = 0;
      await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
        pageNum++;
        final imageBytes = await page.toPng();
        final imagePath = '${imagesDir.path}/page_$pageNum.png';
        await File(imagePath).writeAsBytes(imageBytes);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Extraction Complete', style: GoogleFonts.poppins()),
              ],
            ),
            content: Text(
              '$pageNum images extracted to:\n${imagesDir.path}',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.poppins()),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles(
                    Directory(imagesDir.path)
                        .listSync()
                        .whereType<File>()
                        .map((f) => XFile(f.path))
                        .toList(),
                  );
                },
                child: Text('Share', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ============ COMPRESS PDF ============
  Future<void> _compressPdf({String? path}) async {
    String? pdfPath = path;

    if (pdfPath == null) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.first.path == null) return;
      pdfPath = result.files.first.path!;
    }

    // Show compression options
    final quality = await showDialog<int>(
      context: context,
      builder: (ctx) => _CompressionDialog(),
    );

    if (quality == null) return;

    setState(() => _isProcessing = true);

    try {
      final originalSize = await File(pdfPath).length();
      final pdfBytes = await File(pdfPath).readAsBytes();

      final pdf = pw.Document();
      final dpi = quality == 1 ? 72.0 : (quality == 2 ? 100.0 : 150.0);

      await for (final page in Printing.raster(pdfBytes, dpi: dpi)) {
        // Allow UI to breathe
        await Future.delayed(const Duration(milliseconds: 10));
        
        final imageBytes = await page.toPng();

        // Compress the image
        img.Image? image = img.decodePng(imageBytes);
        if (image == null) continue;

        final compressed = Uint8List.fromList(
          img.encodeJpg(
            image,
            quality: quality == 1 ? 50 : (quality == 2 ? 70 : 85),
          ),
        );

        final pdfImage = pw.MemoryImage(compressed);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        );
      }

      final savedPath = await _savePdf(pdf, 'compressed');
      if (savedPath != null) {
        final newSize = await File(savedPath).length();
        final reduction = ((originalSize - newSize) / originalSize * 100)
            .toStringAsFixed(1);

        _showSuccessDialog(
          savedPath,
          'PDF Compressed',
          'Reduced by $reduction% (${_formatBytes(originalSize)} → ${_formatBytes(newSize)})',
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ============ ADD WATERMARK ============
  Future<void> _addWatermark({String? path}) async {
    String? pdfPath = path;

    if (pdfPath == null) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.first.path == null) return;
      pdfPath = result.files.first.path!;
    }

    // Show watermark options
    final watermarkOptions = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _WatermarkDialog(),
    );

    if (watermarkOptions == null) return;

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = await File(pdfPath!).readAsBytes();

      final pdf = pw.Document();
      final watermarkText = watermarkOptions['text'] as String;
      final opacity = watermarkOptions['opacity'] as double;
      final fontSize = watermarkOptions['fontSize'] as double;
      final diagonal = watermarkOptions['diagonal'] as bool;

      await for (final page in Printing.raster(pdfBytes, dpi: 150)) {
        final imageBytes = await page.toPng();
        final pdfImage = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Stack(
              children: [
                pw.Image(pdfImage, fit: pw.BoxFit.contain),
                pw.Center(
                  child: pw.Transform.rotate(
                    angle: diagonal ? -0.5 : 0,
                    child: pw.Opacity(
                      opacity: opacity,
                      child: pw.Text(
                        watermarkText,
                        style: pw.TextStyle(
                          fontSize: fontSize,
                          color: PdfColors.grey,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final savedPath = await _savePdf(pdf, 'watermarked');
      if (savedPath != null) {
        _showSuccessDialog(
          savedPath,
          'Watermark Added',
          'Watermark: "$watermarkText"',
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ============ ROTATE PDF ============
  Future<void> _rotatePdf({String? path}) async {
    String? pdfPath = path;

    if (pdfPath == null) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.first.path == null) return;
      pdfPath = result.files.first.path!;
    }

    final rotation = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Rotate Pages', style: GoogleFonts.poppins()),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 90),
            child: Text('90° Clockwise', style: GoogleFonts.poppins()),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 180),
            child: Text('180°', style: GoogleFonts.poppins()),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 270),
            child: Text('90° Counter-clockwise', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (rotation == null) return;

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = await File(pdfPath!).readAsBytes();

      final pdf = pw.Document();

      await for (final page in Printing.raster(pdfBytes, dpi: 150)) {
        // Allow UI to breathe
        await Future.delayed(const Duration(milliseconds: 10));
        
        final imageBytes = await page.toPng();

        img.Image? image = img.decodePng(imageBytes);
        if (image == null) continue;

        image = img.copyRotate(image, angle: rotation);
        final rotatedBytes = Uint8List.fromList(img.encodePng(image));
        final pdfImage = pw.MemoryImage(rotatedBytes);

        final isLandscape = rotation == 90 || rotation == 270;
        pdf.addPage(
          pw.Page(
            pageFormat: isLandscape
                ? PdfPageFormat.a4.landscape
                : PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        );
      }

      final savedPath = await _savePdf(pdf, 'rotated');
      if (savedPath != null) {
        _showSuccessDialog(savedPath, 'PDF Rotated', 'Rotated by $rotation°');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _redactPdf() async {
    String? pdfPath = widget.initialFilePath;
    if (pdfPath == null) {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.first.path == null) return;
      pdfPath = result.files.first.path!;
    }

    setState(() => _isProcessing = true);

    try {
      final pdfBytes = await File(pdfPath!).readAsBytes();
      final List<Uint8List> originalPages = [];
      
      // Higher DPI for better redaction quality
      await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
        final pngBytes = await page.toPng();
        // Ensure white background so black text is visible in dark mode editor
        final image = img.decodeImage(pngBytes);
        if (image != null) {
          final whiteBg = img.Image(
            width: image.width,
            height: image.height,
            numChannels: 3, // No alpha
          );
          img.fillRect(
            whiteBg,
            x1: 0,
            y1: 0,
            x2: image.width,
            y2: image.height,
            color: img.ColorRgb8(255, 255, 255),
          );
          
          img.compositeImage(whiteBg, image);
          originalPages.add(Uint8List.fromList(img.encodePng(whiteBg)));
        } else {
          originalPages.add(pngBytes);
        }
      }
      
      setState(() => _isProcessing = false);

      if (!mounted) return;

      // Map to keep track of edited pages
      final Map<int, Uint8List> editedPagesMap = {};
      
      // Show page selector for professional redaction flow
      final resultPages = await Navigator.push<Map<int, Uint8List>>(
        context,
        MaterialPageRoute(
          builder: (context) => RedactionPageSelector(
            pages: originalPages,
            editedPages: editedPagesMap,
          ),
        ),
      );

      if (resultPages == null || resultPages.isEmpty && editedPagesMap.isEmpty) return;

      setState(() => _isProcessing = true);
      Fluttertoast.showToast(msg: "Generating high-quality redacted PDF...");

      final pdf = pw.Document();
      for (int i = 0; i < originalPages.length; i++) {
        final imageBytes = resultPages?[i] ?? originalPages[i];
        final image = pw.MemoryImage(imageBytes);
        
        // Match page size to image size for "Best Working" results
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(image.width!.toDouble(), image.height!.toDouble()),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(image),
              );
            },
          ),
        );
      }

      final savedPath = await _savePdf(pdf, 'redacted');
      if (savedPath != null) {
        _showSuccessDialog(savedPath, 'Redaction Complete', 'File saved with professional quality');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Redaction failed: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============ HELPERS ============
  Future<String?> _savePdf(pw.Document pdf, String prefix) async {
    // Show folder picker dialog with share option
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => FolderPickerDialog(
        defaultFileName:
            '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );

    if (result == null) return null;

    final action = result['action'] as String;
    final pdfBytes = await pdf.save();

    if (action == 'share') {
      // Save to temp and share
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${outputDir.path}/${prefix}_$timestamp.pdf';
      final file = File(tempPath);
      await file.writeAsBytes(pdfBytes);

      Share.shareXFiles([XFile(tempPath)]);
      return tempPath;
    } else {
      // Save to selected folder
      final selectedFolder = result['folder'] as String;
      final outputPath =
          '$selectedFolder/${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes);
      return outputPath;
    }
  }


  void _showSuccessDialog(String path, String title, String subtitle) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.grey, size: 28),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.poppins()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: GoogleFonts.poppins()),
            const SizedBox(height: 8),
            Text(
              path.split('/').last,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
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
              Share.shareXFiles([XFile(path)]);
            },
            icon: const Icon(Icons.share),
            label: Text('Share', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============ DIALOGS ============

class _ImagesToPdfDialog extends StatefulWidget {
  final int imageCount;

  const _ImagesToPdfDialog({required this.imageCount});

  @override
  State<_ImagesToPdfDialog> createState() => _ImagesToPdfDialogState();
}

class _ImagesToPdfDialogState extends State<_ImagesToPdfDialog> {
  PdfPageFormat _pageSize = PdfPageFormat.a4;
  bool _fitToPage = true;
  int _quality = 85;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      title: Text(
        'Convert ${widget.imageCount} Images',
        style: GoogleFonts.poppins(),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Page Size',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SegmentedButton<PdfPageFormat>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: isDark ? Colors.white : Colors.black,
              selectedForegroundColor: isDark ? Colors.black : Colors.white,
              backgroundColor: Colors.transparent,
              side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
            ),
            segments: const [
              ButtonSegment(value: PdfPageFormat.a4, label: Text('A4')),
              ButtonSegment(value: PdfPageFormat.letter, label: Text('Letter')),
              ButtonSegment(value: PdfPageFormat.a3, label: Text('A3')),
            ],
            selected: {_pageSize},
            onSelectionChanged: (s) => setState(() => _pageSize = s.first),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text('Fit to Page', style: GoogleFonts.poppins()),
            value: _fitToPage,
            onChanged: (v) => setState(() => _fitToPage = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            'Quality: $_quality%',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _quality.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            onChanged: (v) => setState(() => _quality = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'pageSize': _pageSize,
            'fitToPage': _fitToPage,
            'quality': _quality,
          }),
          child: Text('Convert', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

class _CompressionDialog extends StatefulWidget {
  @override
  State<_CompressionDialog> createState() => _CompressionDialogState();
}

class _CompressionDialogState extends State<_CompressionDialog> {
  int _level = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Compression Level', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(1, 'Maximum', 'Smallest file, lower quality'),
          _buildOption(2, 'Balanced', 'Good balance'),
          _buildOption(3, 'Minimum', 'Best quality, larger file'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _level),
          child: Text('Compress', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }

  Widget _buildOption(int value, String title, String subtitle) {
    return RadioListTile<int>(
      value: value,
      groupValue: _level,
      onChanged: (v) => setState(() => _level = v!),
      title: Text(title, style: GoogleFonts.poppins()),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _WatermarkDialog extends StatefulWidget {
  @override
  State<_WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<_WatermarkDialog> {
  final _textController = TextEditingController(text: 'CONFIDENTIAL');
  double _opacity = 0.3;
  double _fontSize = 48;
  bool _diagonal = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Watermark', style: GoogleFonts.poppins()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Watermark Text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Opacity: ${(_opacity * 100).round()}%',
              style: GoogleFonts.poppins(),
            ),
            Slider(
              value: _opacity,
              min: 0.1,
              max: 0.8,
              onChanged: (v) => setState(() => _opacity = v),
            ),
            Text('Font Size: ${_fontSize.round()}', style: GoogleFonts.poppins()),
            Slider(
              value: _fontSize,
              min: 24,
              max: 96,
              onChanged: (v) => setState(() => _fontSize = v),
            ),
            SwitchListTile(
              title: Text('Diagonal', style: GoogleFonts.poppins()),
              value: _diagonal,
              onChanged: (v) => setState(() => _diagonal = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'text': _textController.text,
            'opacity': _opacity,
            'fontSize': _fontSize,
            'diagonal': _diagonal,
          }),
          child: Text('Apply', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

// Replaced by shared FolderPickerDialog in lib/widgets/folder_picker_dialog.dart

class RedactionPageSelector extends StatefulWidget {
  final List<Uint8List> pages;
  final Map<int, Uint8List> editedPages;

  const RedactionPageSelector({
    super.key,
    required this.pages,
    required this.editedPages,
  });

  @override
  State<RedactionPageSelector> createState() => _RedactionPageSelectorState();
}

class _RedactionPageSelectorState extends State<RedactionPageSelector> {
  late Map<int, Uint8List> _currentEditedPages;

  @override
  void initState() {
    super.initState();
    _currentEditedPages = Map.from(widget.editedPages);
  }

  Future<void> _editPage(int index) async {
    final editedImage = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.memory(
          _currentEditedPages[index] ?? widget.pages[index],
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

    if (editedImage != null) {
      setState(() {
        _currentEditedPages[index] = editedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 1,
        title: Text('Redact / Mark Pages', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: accentColor)),
        leading: BackButton(color: accentColor),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _currentEditedPages),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text('Finish', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: accentColor.withOpacity(0.05),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: accentColor.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a page to redact or mark it. Tap Finish when done.',
                    style: GoogleFonts.poppins(fontSize: 12, color: accentColor.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: widget.pages.length,
              itemBuilder: (context, index) {
                final isEdited = _currentEditedPages.containsKey(index);
                return GestureDetector(
                  onTap: () => _editPage(index),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white, // White background for transparency
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isEdited ? accentColor : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _currentEditedPages[index] ?? widget.pages[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            if (isEdited)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Page ${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: isEdited ? FontWeight.bold : FontWeight.normal,
                          color: isEdited ? accentColor : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

