import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/ocr_block.dart';

/// Thin bridge to iOS Vision / Android ML Kit via a MethodChannel.
///
/// The native side receives a JPEG-encoded image and returns a list of
/// recognised text blocks with normalised bounding boxes.
class OcrService {
  OcrService._();
  static final instance = OcrService._();

  static const _channel = MethodChannel('com.nutrivision/ocr');

  /// [jpegBytes]  — JPEG-encoded camera frame.
  /// [rotation]   — clockwise degrees (0 / 90 / 180 / 270) so the native
  ///                engine knows which way is up on Android.
  Future<List<OcrBlock>> recognizeText({
    required Uint8List jpegBytes,
    int rotation = 0,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('recognizeText', {
      'imageBytes': jpegBytes,
      'rotation': rotation,
    });

    if (raw == null) return [];

    return raw
        .cast<Map<Object?, Object?>>()
        .map(OcrBlock.fromMap)
        .toList(growable: false);
  }
}
