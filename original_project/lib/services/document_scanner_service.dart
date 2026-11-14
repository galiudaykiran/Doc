import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DocumentScannerService {
  /// Scan multiple document pages using cunning_document_scanner which provides crop and filter
  Future<String?> scanDocument() async {
    try {
      // Launch native document scanner UI
      final List<String>? pictures = await CunningDocumentScanner.getPictures(isGalleryImportAllowed: true);
      
      if (pictures == null || pictures.isEmpty) return null;

      // Convert all pages to a single PDF
      final pdf = pw.Document();
      
      for (final picturePath in pictures) {
        final imageBytes = await File(picturePath).readAsBytes();
        final pdfImage = pw.MemoryImage(imageBytes);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
          ),
        );
        
        // Clean up temporary cropped picture from scanner
        try {
          await File(picturePath).delete();
        } catch (_) {}
      }

      // Save PDF to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'scanned_doc_$timestamp.pdf';
      final pdfPath = '${tempDir.path}/$fileName';

      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      return pdfPath;
    } catch (e) {
      print('Error scanning documents: $e');
      return null;
    }
  }

  /// Import scanned document to a specific folder
  Future<String?> importToFolder(
    String sourcePdfPath,
    String folderPath,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Scanned_Document_$timestamp.pdf';
      final targetPath = '$folderPath/$fileName';

      // Copy PDF to folder
      await File(sourcePdfPath).copy(targetPath);

      // Delete temp file
      await File(sourcePdfPath).delete();

      return targetPath;
    } catch (e) {
      print('Error importing scanned document: $e');
      return null;
    }
  }
}
