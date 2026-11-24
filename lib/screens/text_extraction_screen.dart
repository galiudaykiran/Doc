import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:gallery_app/services/text_extraction_service.dart';
import 'package:gallery_app/screens/text_to_pdf_screen.dart';
import 'package:gallery_app/theme/app_theme.dart';
import 'package:gallery_app/widgets/folder_picker_dialog.dart';
import 'package:gallery_app/widgets/optimized_image.dart';

class TextExtractionScreen extends StatefulWidget {
  final String? initialImagePath;
  final List<String>? initialImagePaths;
  final String? autoExtractTitle;

  const TextExtractionScreen({
    super.key,
    this.initialImagePath,
    this.initialImagePaths,
    this.autoExtractTitle,
  });

  @override
  State<TextExtractionScreen> createState() => _TextExtractionScreenState();
}

class _TextExtractionScreenState extends State<TextExtractionScreen> {
  final TextExtractionService _service = TextExtractionService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _imagePaths = [];
  bool _isLoading = false;
  String _statusMessage = '';
  bool _showPreview = true;
  int _selectedPreviewIndex = 0;
  double _fontSize = 15.0;
  bool _isFullScreenEditor = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null && widget.initialImagePaths!.isNotEmpty) {
      _imagePaths = List.from(widget.initialImagePaths!);
      _processImages(_imagePaths);
    } else if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
      _imagePaths = [widget.initialImagePath!];
      _processImages(_imagePaths);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  int get _charCount => _textController.text.length;

  Future<void> _processImages(List<String> paths) async {
    if (paths.isEmpty) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Analyzing ${paths.length} ${paths.length == 1 ? "page" : "pages"} & extracting text...';
    });

    try {
      final result = await _service.extractTextFromMultiple(paths);
      if (mounted) {
        setState(() {
          _imagePaths = paths;
          _selectedPreviewIndex = 0;
          _textController.text = result.text;
          _isLoading = false;
        });

        if (result.text.isEmpty) {
          Fluttertoast.showToast(
            msg: "No text detected. Ensure the document is clear and well-lit.",
            backgroundColor: Colors.amber.shade800,
          );
        } else {
          Fluttertoast.showToast(
            msg: "Text extracted successfully!",
            backgroundColor: const Color(0xFF10B981),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Error extracting text: $e", backgroundColor: Colors.red);
      }
    }
  }

  Future<void> _scanDocument() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Launching document scanner...';
    });
    try {
      final result = await _service.scanAndExtract();
      if (!mounted) return;
      if (result != null && result.imagePaths.isNotEmpty) {
        setState(() {
          _imagePaths = result.imagePaths;
          _selectedPreviewIndex = 0;
          _textController.text = result.text;
          _isLoading = false;
        });
        if (result.text.isEmpty) {
          Fluttertoast.showToast(msg: "No text detected in scanned pages.", backgroundColor: Colors.amber.shade800);
        } else {
          Fluttertoast.showToast(msg: "Text extracted successfully!", backgroundColor: const Color(0xFF10B981));
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Scanner error: $e");
      }
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting image from gallery...';
    });
    try {
      final result = await _service.pickFromGalleryAndExtract();
      if (!mounted) return;
      if (result != null && result.imagePaths.isNotEmpty) {
        setState(() {
          _imagePaths = result.imagePaths;
          _selectedPreviewIndex = 0;
          _textController.text = result.text;
          _isLoading = false;
        });
        if (result.text.isEmpty) {
          Fluttertoast.showToast(msg: "No text detected in selected image.", backgroundColor: Colors.amber.shade800);
        } else {
          Fluttertoast.showToast(msg: "Text extracted successfully!", backgroundColor: const Color(0xFF10B981));
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Gallery error: $e");
      }
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening camera...';
    });
    try {
      final result = await _service.capturePhotoAndExtract();
      if (!mounted) return;
      if (result != null && result.imagePaths.isNotEmpty) {
        setState(() {
          _imagePaths = result.imagePaths;
          _selectedPreviewIndex = 0;
          _textController.text = result.text;
          _isLoading = false;
        });
        if (result.text.isEmpty) {
          Fluttertoast.showToast(msg: "No text detected in photo.", backgroundColor: Colors.amber.shade800);
        } else {
          Fluttertoast.showToast(msg: "Text extracted successfully!", backgroundColor: const Color(0xFF10B981));
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Camera error: $e");
      }
    }
  }

  void _copyToClipboard() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No text to copy");
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(
      msg: "Text copied to clipboard",
      backgroundColor: const Color(0xFF10B981),
    );
  }

  void _shareAsText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "No text to share");
      return;
    }
    HapticFeedback.lightImpact();
    Share.share(
      text,
      subject: widget.autoExtractTitle ?? 'Extracted Text from Document',
    );
  }

  void _showZoomedImageDialog(String imagePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfExportOptions() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: "Extract text before creating PDF");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.surfaceBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEA4335), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Extracted Text as PDF',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      'Generate, save, or custom format',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: AppTheme.tonal(context),
              leading: const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B)),
              title: Text(
                'Quick PDF & Share',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Generate standard A4 document and open share sheet',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _generateQuickPdfAndShare();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: AppTheme.tonal(context),
              leading: Icon(Icons.folder_open_rounded, color: AppTheme.primary(context)),
              title: Text(
                'Save PDF to App Folder',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Save directly into one of your Document Hub folders',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _savePdfToFolder();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: AppTheme.tonal(context),
              leading: const Icon(Icons.tune_rounded, color: Color(0xFF34A853)),
              title: Text(
                'Advanced PDF Editor & Formatter',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                'Customise fonts, alignments, margins, headers & footers',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TextToPdfScreen(
                      initialText: _textController.text,
                      initialTitle: widget.autoExtractTitle ?? 'Extracted Document',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _buildPdfFile() async {
    final pdf = pw.Document();
    final text = _textController.text.trim();
    final title = widget.autoExtractTitle ?? 'Extracted Text Document';
    final dateStr = DateTime.now().toLocal().toString().split('.').first;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Paragraph(
            text: text,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2.0),
          ),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/Extracted_Text_$ts.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  Future<void> _generateQuickPdfAndShare() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating PDF...';
    });
    try {
      final pdfPath = await _buildPdfFile();
      setState(() => _isLoading = false);
      if (pdfPath != null) {
        await Share.shareXFiles(
          [XFile(pdfPath)],
          text: 'Extracted Document PDF',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Error creating PDF: $e");
    }
  }

  Future<void> _savePdfToFolder() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const FolderPickerDialog(
        defaultFileName: 'Extracted_Text.pdf',
        isFolderOnly: true,
      ),
    );
    if (result == null || result['folder'] == null) return;
    final selectedFolder = result['folder'] as String;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving PDF to folder...';
    });

    try {
      final tempPdf = await _buildPdfFile();
      if (tempPdf == null) throw Exception("Failed to build PDF");

      final ts = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '$selectedFolder${Platform.pathSeparator}Extracted_Text_$ts.pdf';
      await File(tempPdf).copy(targetPath);

      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: "PDF saved to folder successfully!",
        backgroundColor: const Color(0xFF10B981),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Failed to save: $e", backgroundColor: Colors.red);
    }
  }

  void _showImageSourceChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.surfaceBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Select Image for Text Extraction',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Capture, scan, or pick from your device gallery',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            _buildSourceOption(
              icon: Icons.document_scanner_rounded,
              color: AppTheme.primary(context),
              title: 'Scan Document (Auto-Crop)',
              subtitle: 'Multi-page scanner with perspective correction',
              onTap: () {
                Navigator.pop(ctx);
                _scanDocument();
              },
            ),
            const SizedBox(height: 10),
            _buildSourceOption(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF34A853),
              title: 'Choose from Gallery',
              subtitle: 'Pick existing photos, screenshots, or receipts',
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 10),
            _buildSourceOption(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF4285F4),
              title: 'Take Quick Photo',
              subtitle: 'Snap a direct picture using device camera',
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: AppTheme.tonal(context),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary(context)),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardActive = bottomInset > 60;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Text Extractor (OCR)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          if (_imagePaths.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                _showPreview ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.textSecondary(context),
              ),
              tooltip: _showPreview ? 'Hide Image Strip' : 'Show Image Strip',
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),
            IconButton(
              icon: Icon(
                _isFullScreenEditor ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: AppTheme.textSecondary(context),
              ),
              tooltip: _isFullScreenEditor ? 'Exit Full Screen' : 'Full Screen Editor',
              onPressed: () => setState(() => _isFullScreenEditor = !_isFullScreenEditor),
            ),
          ],
          IconButton(
            icon: Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary(context)),
            tooltip: 'New Image',
            onPressed: _showImageSourceChooser,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Stats / Top Strip (Hidden in full screen mode for maximum canvas)
              if (!_isFullScreenEditor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    border: Border(
                      bottom: BorderSide(color: AppTheme.surfaceBorder(context).withOpacity(0.6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatPill(
                        Icons.description_outlined,
                        '${_imagePaths.length} ${_imagePaths.length == 1 ? "Page" : "Pages"}',
                      ),
                      const SizedBox(width: 8),
                      _buildStatPill(Icons.sort_by_alpha_rounded, '$_wordCount words'),
                      const SizedBox(width: 8),
                      _buildStatPill(Icons.text_fields_rounded, '$_charCount chars'),
                      const Spacer(),
                      // Font size decrease/increase buttons
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (_fontSize > 12) setState(() => _fontSize -= 1.5);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.tonal(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (_fontSize < 24) setState(() => _fontSize += 1.5);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.tonal(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      if (_textController.text.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            _textController.clear();
                            setState(() {});
                          },
                          child: Text(
                            'Clear',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Image Preview Strip (Auto-collapses when keyboard is active to give 100% space to text!)
              if (_imagePaths.isNotEmpty && _showPreview && !isKeyboardActive && !_isFullScreenEditor)
                _buildImagePreviewSection(),

              // Text Editor / Result Area
              Expanded(
                child: _imagePaths.isEmpty
                    ? _buildEmptyState()
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          _isFullScreenEditor ? 8 : 14,
                          _isFullScreenEditor ? 8 : 10,
                          _isFullScreenEditor ? 8 : 14,
                          isKeyboardActive ? 4 : 10,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.isDark(context)
                                ? const Color(0xFF1B1D24)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? AppTheme.primary(context).withOpacity(0.5)
                                  : AppTheme.surfaceBorder(context),
                              width: _focusNode.hasFocus ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(AppTheme.isDark(context) ? 0.35 : 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar inside Editor
                              Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.primary(context)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Extracted Text',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isKeyboardActive)
                                    GestureDetector(
                                      onTap: () => FocusScope.of(context).unfocus(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary(context).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.keyboard_hide_rounded, size: 14, color: AppTheme.primary(context)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Done',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 16),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  onChanged: (_) => setState(() {}),
                                  cursorColor: AppTheme.primary(context),
                                  cursorWidth: 2.2,
                                  cursorRadius: const Radius.circular(2),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: _fontSize,
                                    height: 1.65,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textPrimary(context),
                                    letterSpacing: 0.15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Extracted text will appear here. Tap to edit freely...',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: _fontSize,
                                      color: AppTheme.textMuted(context),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // Bottom Action Bar or Sleek Keyboard Accessory Toolbar
              if (_imagePaths.isNotEmpty)
                isKeyboardActive
                    ? _buildKeyboardAccessoryBar()
                    : _buildBottomActionBar(),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.surfaceBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary(context), strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Processing takes a few seconds...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.tonal(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewSection() {
    return Container(
      height: 105,
      width: double.infinity,
      color: AppTheme.tonal(context).withOpacity(0.6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imagePaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isSelected = _selectedPreviewIndex == index;
          final path = _imagePaths[index];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedPreviewIndex = index);
              _showZoomedImageDialog(path);
            },
            child: Container(
              width: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary(context) : AppTheme.surfaceBorder(context),
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  File(path).existsSync()
                      ? OptimizedImage(path: path, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                  Positioned(
                    bottom: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            'P${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: 44,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Extract Text from Image',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a scanned document, receipt, note, or photo to extract all readable text using high-accuracy on-device OCR.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.document_scanner_rounded, size: 20),
              label: const Text('Scan Document'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _scanDocument,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _pickFromGallery,
            ),
          ],
        ),
      ),
    );
  }

  // Slim compact toolbar shown right above keyboard when typing
  Widget _buildKeyboardAccessoryBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
      ),
      child: Row(
        children: [
          // Word count pill
          Text(
            '$_wordCount words',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(width: 12),
          // Copy button
          InkWell(
            onTap: _copyToClipboard,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary(context)),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Dismiss keyboard button
          FilledButton.tonalIcon(
            icon: const Icon(Icons.keyboard_hide_rounded, size: 16),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }

  // Full prominent bottom actions bar shown when keyboard is closed
  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBorder(context)),
        ),
      ),
      child: Row(
        children: [
          // Copy Button
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _copyToClipboard,
            ),
          ),
          const SizedBox(width: 8),

          // Share Text Button
          Expanded(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share Text'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _shareAsText,
            ),
          ),
          const SizedBox(width: 8),

          // Convert to PDF Button
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA4335),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _showPdfExportOptions,
            ),
          ),
        ],
      ),
    );
  }
}
