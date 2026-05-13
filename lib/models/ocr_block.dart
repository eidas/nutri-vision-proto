import 'dart:ui';

/// A single text block returned by the native OCR engine.
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.boundingBox,
    this.confidence = 1.0,
  });

  final String text;

  /// Normalised bounding box (0..1) in image coordinates.
  final Rect boundingBox;

  final double confidence;

  factory OcrBlock.fromMap(Map<Object?, Object?> map) {
    return OcrBlock(
      text: map['text'] as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      boundingBox: Rect.fromLTWH(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      ),
    );
  }

  @override
  String toString() => text;
}
