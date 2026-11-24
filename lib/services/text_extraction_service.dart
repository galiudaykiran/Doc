import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class TextExtractionResult {
  final String text;
  final List<String> imagePaths;
  final int pageCount;

  const TextExtractionResult({
    required this.text,
    required this.imagePaths,
    required this.pageCount,
  });
}

class TextExtractionService {
  static final TextExtractionService _instance = TextExtractionService._internal();
  factory TextExtractionService() => _instance;
  TextExtractionService._internal();

  /// Extract text from a single image file path using Google ML Kit on-device OCR
  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await textRecognizer.close();
    }
  }

  /// Extract text from multiple image file paths with page headers
  Future<TextExtractionResult> extractTextFromMultiple(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return const TextExtractionResult(text: '', imagePaths: [], pageCount: 0);
    }

    final buffer = StringBuffer();
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      for (int i = 0; i < imagePaths.length; i++) {
        final path = imagePaths[i];
        if (!File(path).existsSync()) continue;

        final inputImage = InputImage.fromFilePath(path);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        final pageText = recognizedText.text.trim();

        if (pageText.isNotEmpty) {
          if (imagePaths.length > 1) {
            buffer.writeln('--- Page ${i + 1} ---');
          }
          buffer.writeln(pageText);
          if (i < imagePaths.length - 1) {
            buffer.writeln();
          }
        }
      }
      return TextExtractionResult(
        text: buffer.toString().trim(),
        imagePaths: imagePaths,
        pageCount: imagePaths.length,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  /// Scan document pages using cunning document scanner and extract text
  Future<TextExtractionResult?> scanAndExtract() async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: true,
      );
      if (pictures == null || pictures.isEmpty) return null;
      return await extractTextFromMultiple(pictures);
    } catch (e) {
      return null;
    }
  }

  /// Pick one or more images from gallery and extract text
  Future<TextExtractionResult?> pickFromGalleryAndExtract() async {
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isEmpty) {
        final XFile? single = await picker.pickImage(source: ImageSource.gallery);
        if (single == null) return null;
        final text = await extractText(single.path);
        return TextExtractionResult(
          text: text,
          imagePaths: [single.path],
          pageCount: 1,
        );
      }
      final paths = images.map((x) => x.path).toList();
      return await extractTextFromMultiple(paths);
    } catch (e) {
      return null;
    }
  }

  /// Capture a single photo from camera and extract text
  Future<TextExtractionResult?> capturePhotoAndExtract() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return null;
      final text = await extractText(photo.path);
      return TextExtractionResult(
        text: text,
        imagePaths: [photo.path],
        pageCount: 1,
      );
    } catch (e) {
      return null;
    }
  }
}

