import 'package:flutter/material.dart';

/// 100% Offline Vector Animated Empty Folder Widget
class EmptyFolderVectorAnimation extends StatefulWidget {
  final double size;
  final Color? color;

  const EmptyFolderVectorAnimation({
    super.key,
    this.size = 140,
    this.color,
  });

  @override
  State<EmptyFolderVectorAnimation> createState() =>
      _EmptyFolderVectorAnimationState();
}

class _EmptyFolderVectorAnimationState extends State<EmptyFolderVectorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = widget.color ?? theme.primaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft glowing background circle
                Container(
                  width: widget.size * 0.85,
                  height: widget.size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(_glowAnimation.value),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                // Vector folder icon with layered paper
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _FolderVectorPainter(
                    primaryColor: primary,
                    isDark: isDark,
                    progress: _controller.value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FolderVectorPainter extends CustomPainter {
  final Color primaryColor;
  final bool isDark;
  final double progress;

  _FolderVectorPainter({
    required this.primaryColor,
    required this.isDark,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back folder tab
    final backPaint = Paint()
      ..color = primaryColor.withOpacity(isDark ? 0.45 : 0.25)
      ..style = PaintingStyle.fill;

    final backPath = Path()
      ..moveTo(w * 0.15, h * 0.35)
      ..lineTo(w * 0.45, h * 0.35)
      ..lineTo(w * 0.52, h * 0.42)
      ..lineTo(w * 0.85, h * 0.42)
      ..arcToPoint(Offset(w * 0.88, h * 0.46), radius: const Radius.circular(8))
      ..lineTo(w * 0.88, h * 0.78)
      ..arcToPoint(Offset(w * 0.85, h * 0.82), radius: const Radius.circular(8))
      ..lineTo(w * 0.15, h * 0.82)
      ..arcToPoint(Offset(w * 0.12, h * 0.78), radius: const Radius.circular(8))
      ..lineTo(w * 0.12, h * 0.39)
      ..arcToPoint(Offset(w * 0.15, h * 0.35), radius: const Radius.circular(8))
      ..close();
    canvas.drawPath(backPath, backPaint);

    // Floating sheet inside folder
    final sheetYOffset = (1.0 - progress) * 8.0;
    final sheetPaint = Paint()
      ..color = isDark ? const Color(0xFF2E3842) : Colors.white
      ..style = PaintingStyle.fill;
    final sheetShadow = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final sheetRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.52 - sheetYOffset),
        width: w * 0.52,
        height: h * 0.44,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(sheetRect, sheetShadow);
    canvas.drawRRect(sheetRect, sheetPaint);

    // Document lines on floating sheet
    final linePaint = Paint()
      ..color = (isDark ? Colors.white38 : Colors.black26)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final sheetCenterY = h * 0.52 - sheetYOffset;
    canvas.drawLine(
      Offset(w * 0.32, sheetCenterY - 12),
      Offset(w * 0.58, sheetCenterY - 12),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.32, sheetCenterY),
      Offset(w * 0.68, sheetCenterY),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.32, sheetCenterY + 12),
      Offset(w * 0.48, sheetCenterY + 12),
      linePaint,
    );

    // Front folder flap
    final frontPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withOpacity(isDark ? 0.85 : 0.85),
          primaryColor.withOpacity(isDark ? 0.65 : 0.70),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final frontPath = Path()
      ..moveTo(w * 0.12, h * 0.46)
      ..lineTo(w * 0.88, h * 0.46)
      ..arcToPoint(Offset(w * 0.90, h * 0.50), radius: const Radius.circular(8))
      ..lineTo(w * 0.88, h * 0.84)
      ..arcToPoint(Offset(w * 0.84, h * 0.88), radius: const Radius.circular(10))
      ..lineTo(w * 0.16, h * 0.88)
      ..arcToPoint(Offset(w * 0.10, h * 0.84), radius: const Radius.circular(10))
      ..lineTo(w * 0.10, h * 0.50)
      ..arcToPoint(Offset(w * 0.12, h * 0.46), radius: const Radius.circular(8))
      ..close();

    final frontShadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(frontPath, frontShadow);
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _FolderVectorPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.isDark != isDark;
}

/// 100% Offline Vector Animated Scanner Beam
class DocumentScanningVectorBeam extends StatefulWidget {
  final double width;
  final double height;
  final Color? color;

  const DocumentScanningVectorBeam({
    super.key,
    this.width = 240,
    this.height = 280,
    this.color,
  });

  @override
  State<DocumentScanningVectorBeam> createState() =>
      _DocumentScanningVectorBeamState();
}

class _DocumentScanningVectorBeamState extends State<DocumentScanningVectorBeam>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.color ?? theme.primaryColor;

    return AnimatedBuilder(
      animation: _sweepController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _ScanningSweepPainter(
            progress: _sweepController.value,
            color: accent,
          ),
        );
      },
    );
  }
}

class _ScanningSweepPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanningSweepPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Corner targeting brackets
    final bracketPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLen = 24.0;
    // Top-Left
    canvas.drawLine(const Offset(4, 4), const Offset(4 + cornerLen, 4), bracketPaint);
    canvas.drawLine(const Offset(4, 4), const Offset(4, 4 + cornerLen), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(w - 4, 4), Offset(w - 4 - cornerLen, 4), bracketPaint);
    canvas.drawLine(Offset(w - 4, 4), Offset(w - 4, 4 + cornerLen), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(4, h - 4), Offset(4 + cornerLen, h - 4), bracketPaint);
    canvas.drawLine(Offset(4, h - 4), Offset(4, h - 4 - cornerLen), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(w - 4, h - 4), Offset(w - 4 - cornerLen, h - 4), bracketPaint);
    canvas.drawLine(Offset(w - 4, h - 4), Offset(w - 4, h - 4 - cornerLen), bracketPaint);

    // Laser Sweep Line & Gradient Trail
    final y = 12 + progress * (h - 24);

    final sweepGradient = LinearGradient(
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.35),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(12, y - 40, w - 24, 40));

    final trailPaint = Paint()..shader = sweepGradient;
    canvas.drawRect(Rect.fromLTWH(12, y - 40, w - 24, 40), trailPaint);

    final laserPaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final glowLaser = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawLine(Offset(12, y), Offset(w - 12, y), glowLaser);
    canvas.drawLine(Offset(12, y), Offset(w - 12, y), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanningSweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
