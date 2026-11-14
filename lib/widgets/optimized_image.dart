import 'dart:io';
import 'package:flutter/material.dart';

/// Optimized image widget with automatic caching and error handling
class OptimizedImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
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
        // Use actual layout size for cache resolution when no explicit size given
        final double effectiveWidth =
            width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 800);
        final double effectiveHeight =
            height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 800);

        // Ensure high quality for crisp rendering (3x resolution)
        final int finalCacheWidth = (effectiveWidth * dpr * 3).clamp(600, 4000).round();
        final int finalCacheHeight = (effectiveHeight * dpr * 3).clamp(600, 4000).round();

        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: finalCacheWidth,
          cacheHeight: finalCacheHeight,
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
