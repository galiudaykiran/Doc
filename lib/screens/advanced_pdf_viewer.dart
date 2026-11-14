import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_app/screens/pdf_preview_screen.dart'; // To access PdfImageInfo
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class _AdvancedPdfViewerState extends State<AdvancedPdfViewer> {
  // Reading Modes: 0: Normal, 1: Dark, 2: Sepia
  int _readingMode = 0;
  bool _isFullScreen = false;

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    // Preload fonts for text rendering
    // final font = await _loadFont();
    // final boldFont = await _loadBoldFont();

    for (var pdfImage in widget.pdfImages) {
      final imageBytes = File(pdfImage.fileInfo.path).readAsBytesSync();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            // Apply reading mode background
            if (_readingMode != 0) {
              return pw.Stack(
                children: [
                  pw.Container(
                    color: _readingMode == 1
                        ? PdfColors.black
                        : PdfColor.fromHex('#FFF8DC'), // Sepia color
                  ),
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: pdfImage.rotationAngle,
                      child: pw.Image(image, fit: pw.BoxFit.contain, dpi: 300),
                    ),
                  ),
                ],
              );
            }
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
    return pdf.save();
  }

  Future<void> _savePdf() async {
    try {
      // Generate PDF
      final pdfBytes = await _generatePdf(PdfPageFormat.a4);

      // Get the default file name
      String defaultFileName =
          'document_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid || Platform.isIOS) {
        // Save to specific folder if provided, otherwise app documents directory
        String targetDir = widget.folderPath ?? (await getApplicationDocumentsDirectory()).path;
        final dir = Directory(targetDir);
        if (!await dir.exists()) await dir.create(recursive: true);
        
        final filePath = '$targetDir/$defaultFileName';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        // Show success message
        Fluttertoast.showToast(
          msg: 'PDF saved successfully!',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.grey,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        // For desktop platforms, let user choose save location
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (outputPath != null) {
          // Ensure the file has .pdf extension
          if (!outputPath.toLowerCase().endsWith('.pdf')) {
            outputPath = '$outputPath.pdf';
          }

          // Write the PDF to the selected location
          final file = File(outputPath);
          await file.writeAsBytes(pdfBytes);

          // Show success message
          Fluttertoast.showToast(
            msg: 'PDF saved successfully!',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.grey,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      Fluttertoast.showToast(
        msg: 'Error saving PDF: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              automaticallyImplyLeading: false, // Back icon removed
              title: Text(
                'Advanced Viewer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
              backgroundColor: Theme.of(context).cardTheme.color,
              elevation: 1,
              foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _readingMode == 0
                        ? Icons.brightness_5_outlined
                        : _readingMode == 1
                        ? Icons.nightlight_round
                        : Icons.chrome_reader_mode_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _readingMode = (_readingMode + 1) % 3;
                    });
                  },
                  tooltip: 'Toggle Reading Mode\n(Day/Night/Sepia)',
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: () => setState(() => _isFullScreen = true),
                  tooltip: 'Full Screen',
                ),
              ],
            ),
      body: Stack(
        children: [
          PdfPreview(
            build: (format) => _generatePdf(format),
            canDebug: false,
                canChangeOrientation: false,
                canChangePageFormat: true,
                pdfFileName: 'document.pdf',
                allowSharing: true,
                allowPrinting: true,
                initialPageFormat: PdfPageFormat.a4,
                maxPageWidth: 700,
                loadingWidget: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating PDF...'),
                    ],
                  ),
                ),
                onError: (context, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text('Error: $error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  PdfPreviewAction(
                    icon: const Icon(Icons.save),
                    onPressed: (context, build, format) => _savePdf(),
                  ),
                ],
              ),
          if (_isFullScreen)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => setState(() => _isFullScreen = false),
                backgroundColor: Theme.of(context).primaryColor,
                tooltip: 'Exit Full Screen',
                child: const Icon(Icons.fullscreen_exit_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class AdvancedPdfViewer extends StatefulWidget {
  final List<PdfImageInfo> pdfImages;
  final String? folderPath;

  const AdvancedPdfViewer({
    super.key,
    required this.pdfImages,
    this.folderPath,
  });

  @override
  State<AdvancedPdfViewer> createState() => _AdvancedPdfViewerState();
}
