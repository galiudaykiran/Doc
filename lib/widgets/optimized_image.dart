import 'dart:io';
import 'package:flutter/material.dart';

/// Optimized image widget with automatic caching, high quality, and STRICT aspect ratio preservation.
class OptimizedImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    if (!file.existsSync()) {
      return errorWidget ??
          const Icon(Icons.broken_image, size: 50, color: Colors.grey);
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate appropriate cacheWidth based on rendering dimensions.
        // CRITICAL: We ONLY specify cacheWidth and leave cacheHeight as null!
        // In Flutter, when both cacheWidth and cacheHeight are specified, the engine
        // forcibly squishes/stretches the image to that exact bounding box ratio,
        // distorting the natural aspect ratio of faces and objects.
        // Specifying only cacheWidth scales down the image while maintaining 100% of
        // its original proportional aspect ratio without any compression artifact!
        final double targetW = width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 400);
        final int cacheW = (targetW * dpr * 2.5).clamp(400, 2400).round();

        return Image.file(
          file,
          width: width ?? (constraints.maxWidth.isFinite ? double.infinity : null),
          height: height ?? (constraints.maxHeight.isFinite ? double.infinity : null),
          fit: fit,
          alignment: alignment,
          cacheWidth: cacheW,
          cacheHeight: null, // Always null to preserve native aspect ratio without distortion!
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ??
                const Icon(Icons.broken_image, size: 50, color: Colors.grey);
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            if (frame == null) {
              return placeholder ??
                  Container(
                    width: width,
                    height: height,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
            }
            return child;
          },
        );
      },
    );
  }
}

/// Thumbnail widget for grid/list items with optimized loading
class ThumbnailImage extends StatelessWidget {
  final String path;
  final double thumbnailSize;

  const ThumbnailImage({
    super.key,
    required this.path,
    this.thumbnailSize = 150,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      path: path,
      width: thumbnailSize,
      height: thumbnailSize,
      fit: BoxFit.cover,
      placeholder: Container(
        width: thumbnailSize,
        height: thumbnailSize,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      ),
    );
  }
}
