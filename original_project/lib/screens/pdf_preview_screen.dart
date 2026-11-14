import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_app/models/file_info.dart';
import 'package:gallery_app/widgets/optimized_image.dart';
import 'package:gallery_app/screens/advanced_pdf_viewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../widgets/floating_calculator.dart';
import 'package:gallery_app/services/document_scanner_service.dart';

class PdfPreviewScreen extends StatefulWidget {
  final List<FileInfo> initialImages;
  final String? folderPath;

  const PdfPreviewScreen({
    super.key,
    required this.initialImages,
    this.folderPath,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late List<PdfImageInfo> _pdfImages;
  int _currentPageIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void initState() {
    super.initState();
    _pdfImages = widget.initialImages
        .map((fileInfo) => PdfImageInfo(fileInfo: fileInfo))
        .toList();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        final bool wasEmpty = _pdfImages.isEmpty;
        for (var xFile in pickedFiles) {
          _pdfImages.add(
            PdfImageInfo(
              fileInfo: FileInfo(
                name: xFile.name,
                path: xFile.path,
                type: FileType.image,
              ),
            ),
          );
        }
        if (wasEmpty) {
          _currentPageIndex = 0;
        }
      });
      Fluttertoast.showToast(msg: "${pickedFiles.length} images added.");
    }
  }

  Future<void> _importPdfAndExtractPages() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final pdfFile = File(result.files.first.path!);
      Fluttertoast.showToast(msg: "Extracting PDF pages...");

      // Read and render PDF pages as images using printing package
      final pdfBytes = await pdfFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      List<PdfImageInfo> extractedPages = [];

      // Render each page using the printing package with high DPI for better quality
      await for (var page in Printing.raster(pdfBytes, dpi: 300)) {
        final index = extractedPages.length;
        final imageBytes = await page.toPng();

        // Save the rendered page as image
        final imagePath = '${tempDir.path}/pdf_page_${timestamp}_$index.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageBytes);

        extractedPages.add(
          PdfImageInfo(
            fileInfo: FileInfo(
              name: 'Page ${index + 1}',
              path: imagePath,
              type: FileType.image,
            ),
          ),
        );
      }

      setState(() {
        final bool wasEmpty = _pdfImages.isEmpty;
        _pdfImages.addAll(extractedPages);
        if (wasEmpty) {
          _currentPageIndex = 0;
        }
      });

      Fluttertoast.showToast(
        msg: "${extractedPages.length} pages imported from PDF",
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Error importing PDF: $e");
      debugPrint("PDF import error: $e");
    }
  }

  Future<void> _scanDocument() async {
    try {
      final scannerService = DocumentScannerService();
      final tempPdfPath = await scannerService.scanDocument();
      if (tempPdfPath != null) {
        Fluttertoast.showToast(msg: "Processing scanned pages...");
        final pdfBytes = await File(tempPdfPath).readAsBytes();
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        List<PdfImageInfo> extractedPages = [];
        await for (var page in Printing.raster(pdfBytes, dpi: 300)) {
          final index = extractedPages.length;
          final imageBytes = await page.toPng();
          final imagePath = '${tempDir.path}/scanned_page_${timestamp}_$index.png';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(imageBytes);
          extractedPages.add(
            PdfImageInfo(
              fileInfo: FileInfo(
                name: 'Scanned Page ${index + 1}',
                path: imagePath,
                type: FileType.image,
              ),
            ),
          );
        }
        setState(() {
          final bool wasEmpty = _pdfImages.isEmpty;
          _pdfImages.addAll(extractedPages);
          if (wasEmpty) _currentPageIndex = 0;
        });
        Fluttertoast.showToast(msg: "${extractedPages.length} scanned pages added");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error scanning document: $e");
    }
  }

  Future<void> _insertPageAtPosition() async {
    if (_pdfImages.isEmpty) {
      Fluttertoast.showToast(msg: "Add some pages first");
      return;
    }

    final int? position = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Insert Page Position',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select where to insert the new page:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded),
              title: const Text('Before current page'),
              subtitle: Text('Position ${_currentPageIndex + 1}'),
              onTap: () => Navigator.pop(context, _currentPageIndex),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded),
              title: const Text('After current page'),
              subtitle: Text('Position ${_currentPageIndex + 2}'),
              onTap: () => Navigator.pop(context, _currentPageIndex + 1),
            ),
            ListTile(
              leading: const Icon(Icons.last_page_rounded),
              title: const Text('At the end'),
              subtitle: Text('Position ${_pdfImages.length + 1}'),
              onTap: () => Navigator.pop(context, _pdfImages.length),
            ),
          ],
        ),
      ),
    );

    if (position == null) return;

    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var i = 0; i < pickedFiles.length; i++) {
          _pdfImages.insert(
            position + i,
            PdfImageInfo(
              fileInfo: FileInfo(
                name: pickedFiles[i].name,
                path: pickedFiles[i].path,
                type: FileType.image,
              ),
            ),
          );
        }
      });
      Fluttertoast.showToast(
        msg:
            "${pickedFiles.length} page(s) inserted at position ${position + 1}",
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pdfImages.removeAt(index);
      if (_currentPageIndex >= _pdfImages.length && _pdfImages.isNotEmpty) {
        _currentPageIndex = _pdfImages.length - 1;
      } else if (_pdfImages.isEmpty) {
        _currentPageIndex = 0;
      }
    });
    Fluttertoast.showToast(msg: "Image removed.");
  }

  void _rotateImage(int index, double angle) {
    setState(() {
      _pdfImages[index].rotationAngle += angle;
    });
  }

  Future<void> _editImage(int index) async {
    final currentImage = _pdfImages[index];
    final imageBytes = await File(currentImage.fileInfo.path).readAsBytes();

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
      await File(currentImage.fileInfo.path).writeAsBytes(editedImageBytes);
      setState(() {
        _pdfImages[index] = currentImage.copyWith(
          rotationAngle: currentImage.rotationAngle,
        );
      });
      Fluttertoast.showToast(msg: "Image updated with professional edits.");
    }
  }

  void _openAdvancedPdfPreview() {
    if (_pdfImages.isEmpty) {
      Fluttertoast.showToast(msg: "No images to create PDF.");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedPdfViewer(
          pdfImages: _pdfImages,
          folderPath: widget.folderPath,
        ),
      ),
    );
  }

  Future<void> _generateAndSavePdf() async {
    if (_pdfImages.isEmpty) {
      Fluttertoast.showToast(msg: "No images to create PDF.");
      return;
    }

    String? fileName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController controller = TextEditingController(
          text: "document_${DateTime.now().millisecondsSinceEpoch}",
        );
        return AlertDialog(
          title: const Text('Name your PDF'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter PDF file name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
            ),
          ],
        );
      },
    );

    if (fileName == null || fileName.isEmpty) {
      Fluttertoast.showToast(msg: "PDF save cancelled.");
      return;
    }

    Fluttertoast.showToast(msg: "Generating PDF...");

    try {
      final pdf = pw.Document();

      // Load fonts to ensure proper PDF generation and text rendering
      // final font = await PdfGoogleFonts.nunitoRegular();

      for (var pdfImage in _pdfImages) {
        final imageBytes = File(pdfImage.fileInfo.path).readAsBytesSync();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Transform.rotate(
                  angle: pdfImage.rotationAngle,
                  child: pw.Image(image, fit: pw.BoxFit.contain, dpi: 300),
                ),
              );
            },
          ),
        );
      }

      final Uint8List pdfBytes = await pdf.save();
      String? savePath;

      if (widget.folderPath != null) {
        savePath = '${widget.folderPath}${Platform.pathSeparator}$fileName.pdf';
      } else {
        // Quick Action Mode: Ask to Share or Save
        final String? action = await showModalBottomSheet<String>(
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
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share PDF'),
                  onTap: () => Navigator.pop(context, 'share'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Save to Folder'),
                  onTap: () => Navigator.pop(context, 'save'),
                ),
              ],
            ),
          ),
        );

        if (action == 'share') {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}${Platform.pathSeparator}$fileName.pdf',
          );
          await tempFile.writeAsBytes(pdfBytes);
          await Share.shareXFiles([XFile(tempFile.path)], text: 'Shared PDF');
          return;
        } else if (action == 'save') {
          // Simple folder picker
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final Directory folderDir = Directory(
            '${appDocDir.path}${Platform.pathSeparator}document_folders',
          );

          if (!await folderDir.exists()) {
            Fluttertoast.showToast(msg: "No folders found. Create one first.");
            return;
          }

          final List<FileSystemEntity> entities = folderDir.listSync();
          final List<Directory> folders = entities
              .whereType<Directory>()
              .toList();

          if (folders.isEmpty) {
            Fluttertoast.showToast(msg: "No folders available.");
            return;
          }

          final String? selectedFolderPath = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Folder'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final folderName = folder.path
                        .split(Platform.pathSeparator)
                        .last;
                    return ListTile(
                      leading: const Icon(
                        Icons.folder_rounded,
                        color: Colors.orange,
                      ),
                      title: Text(folderName),
                      onTap: () => Navigator.pop(context, folder.path),
                    );
                  },
                ),
              ),
            ),
          );

          if (selectedFolderPath != null) {
            savePath =
                '$selectedFolderPath${Platform.pathSeparator}$fileName.pdf';
          } else {
            return; // Cancelled folder selection
          }
        } else {
          return; // Cancelled bottom sheet
        }
      }

      final File file = File(savePath);
      await file.writeAsBytes(pdfBytes);

      Fluttertoast.showToast(msg: "PDF saved successfully!");
      Navigator.pop(context, true);
      OpenFilex.open(savePath);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error processing PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Colors.transparent, // Background gradient handled by Stack wrapper
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
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
        title: Column(
          children: [
            Text(
              'PDF Preview',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: appBarTextColor,
              ),
            ),
            if (_pdfImages.isNotEmpty)
              Text(
                '${_pdfImages.length} Pages • Ready to Export',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: appBarTextColor.withOpacity(0.75),
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add_rounded, color: appBarTextColor),
            tooltip: 'Add Content',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              switch (value) {
                case 'images':
                  _pickImages();
                  break;
                case 'scan':
                  _scanDocument();
                  break;
                case 'pdf':
                  _importPdfAndExtractPages();
                  break;
                case 'insert':
                  _insertPageAtPosition();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text('Scan Document', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'images',
                child: Row(
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text('Add Images', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text('Import PDF', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              if (_pdfImages.isNotEmpty)
                PopupMenuItem(
                  value: 'insert',
                  child: Row(
                    children: [
                      const Icon(Icons.insert_page_break_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text('Insert Page', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _generateAndSavePdf,
              style: TextButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(
                'Save',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
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
            child: _pdfImages.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildMetadataHeader(),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          child: CarouselSlider.builder(
                            carouselController: _carouselController,
                            itemCount: _pdfImages.length,
                            itemBuilder: (context, index, realIndex) {
                              return _buildImagePreview(
                                _pdfImages[index],
                                index == _currentPageIndex,
                              );
                            },
                            options: CarouselOptions(
                              height: MediaQuery.of(context).size.height * 0.55,
                              viewportFraction: 0.75, // Improved focus
                              enlargeCenterPage: true,
                              enableInfiniteScroll: false,
                              onPageChanged: (index, reason) {
                                setState(() {
                                  _currentPageIndex = index;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      _buildControlBar(),
                      const Divider(height: 1),
                      _buildThumbnailList(),
                      const SizedBox(height: 80), // Added spacing for FAB
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildMetadataHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.black26
          : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Current Page: ${_currentPageIndex + 1} of ${_pdfImages.length}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.post_add_rounded,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Create or Edit PDF',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add images or import existing PDF to edit',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _scanDocument,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.document_scanner_rounded),
                label: Text(
                  'Scan Document',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickImages,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text(
                  'Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _importPdfAndExtractPages,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text(
              'Import PDF',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(PdfImageInfo imageInfo, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Transform.rotate(
            angle: imageInfo.rotationAngle,
            child: OptimizedImage(
              path: imageInfo.fileInfo.path,
              fit: BoxFit.contain,
              errorWidget: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image Error',
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
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            Icons.rotate_left_rounded,
            'Rotate Left',
            () => _rotateImage(_currentPageIndex, -1.5708),
          ),
          _buildControlButton(
            Icons.rotate_right_rounded,
            'Rotate Right',
            () => _rotateImage(_currentPageIndex, 1.5708),
          ),
          Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
          _buildControlButton(
            Icons.edit_rounded,
            'Edit Image',
            () => _editImage(_currentPageIndex),
          ),
          _buildControlButton(
            Icons.delete_outline_rounded,
            'Remove Page',
            () => _removeImage(_currentPageIndex),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pdfImages.isNotEmpty ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailList() {
    return Container(
      height: 100,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        header: const SizedBox(width: 16),
        footer: const SizedBox(width: 80), // Space for FAB
        itemCount: _pdfImages.length,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            elevation: 4,
            child: child,
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final PdfImageInfo item = _pdfImages.removeAt(oldIndex);
            _pdfImages.insert(newIndex, item);
            if (_currentPageIndex == oldIndex) {
              _currentPageIndex = newIndex;
            }
            // Update current page if it moved
          });
        },
        itemBuilder: (context, index) {
          final imageInfo = _pdfImages[index];
          final isSelected = index == _currentPageIndex;

          return GestureDetector(
            key: ValueKey(imageInfo.id),
            onTap: () {
              setState(() => _currentPageIndex = index);
              _carouselController.animateToPage(index);
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      )
                    : null,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ThumbnailImage(
                      path: imageInfo.fileInfo.path,
                      thumbnailSize: 100,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
    );
  }
}

class PdfImageInfo {
  final FileInfo fileInfo;
  final String id;
  double rotationAngle;

  PdfImageInfo({required this.fileInfo, this.rotationAngle = 0.0, String? id})
    : id = id ?? UniqueKey().toString();

  PdfImageInfo copyWith({FileInfo? fileInfo, double? rotationAngle}) {
    return PdfImageInfo(
      fileInfo: fileInfo ?? this.fileInfo,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      id: id,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfImageInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
