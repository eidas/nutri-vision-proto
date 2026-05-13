import 'package:flutter/material.dart';
import '../models/ocr_block.dart';

/// Draws a scan-guide rectangle, animated corner brackets, and
/// bounding boxes around detected OCR blocks.
class ScanOverlayPainter extends CustomPainter {
  const ScanOverlayPainter({
    required this.blocks,
    required this.confidence,
    required this.animValue, // 0..1 for corner animation
  });

  final List<OcrBlock> blocks;
  final double confidence;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    _drawDimBackground(canvas, size);
    _drawCornerBrackets(canvas, size);
    _drawOcrBlocks(canvas, size);
  }

  void _drawDimBackground(Canvas canvas, Size size) {
    const guideInset = 0.08; // fraction of shortest side
    final inset = size.shortestSide * guideInset;
    final guideRect = Rect.fromLTWH(
        inset, size.height * 0.25, size.width - inset * 2, size.height * 0.5);

    final dimPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(guideRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    const insetFraction = 0.08;
    final inset = size.shortestSide * insetFraction;
    final rect = Rect.fromLTWH(
        inset, size.height * 0.25, size.width - inset * 2, size.height * 0.5);

    final color = Color.lerp(Colors.white, Colors.greenAccent, confidence)!;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    _corner(canvas, paint, rect.topLeft, len, 1, 1);
    _corner(canvas, paint, rect.topRight, len, -1, 1);
    _corner(canvas, paint, rect.bottomLeft, len, 1, -1);
    _corner(canvas, paint, rect.bottomRight, len, -1, -1);
  }

  void _corner(Canvas canvas, Paint paint, Offset origin, double len,
      double dx, double dy) {
    canvas.drawLine(origin, origin.translate(len * dx, 0), paint);
    canvas.drawLine(origin, origin.translate(0, len * dy), paint);
  }

  void _drawOcrBlocks(Canvas canvas, Size size) {
    final blockPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final block in blocks) {
      final rect = Rect.fromLTWH(
        block.boundingBox.left * size.width,
        block.boundingBox.top * size.height,
        block.boundingBox.width * size.width,
        block.boundingBox.height * size.height,
      );
      canvas.drawRect(rect, blockPaint);
    }
  }

  @override
  bool shouldRepaint(ScanOverlayPainter old) =>
      old.blocks != blocks ||
      old.confidence != confidence ||
      old.animValue != animValue;
}
