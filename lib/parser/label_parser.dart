/// Detects the label format and dispatches to the appropriate parser.
library;

import '../models/nutrition_data.dart';
import '../models/ocr_block.dart';
import 'jp_parser.dart';
import 'fda_parser.dart';
import 'eu_parser.dart';

enum DetectedFormat { jp, fda, eu, unknown }

class LabelParser {
  LabelParser._();
  static final instance = LabelParser._();

  final _jpParser = JpParser();
  final _fdaParser = FdaParser();
  final _euParser = EuParser();

  /// Detect format and parse in one step.
  NutritionData parse(List<OcrBlock> blocks) {
    final now = DateTime.now();
    final format = _detectFormat(blocks);
    return switch (format) {
      DetectedFormat.jp      => _jpParser.parse(blocks, now),
      DetectedFormat.fda     => _fdaParser.parse(blocks, now),
      DetectedFormat.eu      => _euParser.parse(blocks, now),
      DetectedFormat.unknown => _tryAll(blocks, now),
    };
  }

  DetectedFormat _detectFormat(List<OcrBlock> blocks) {
    final text = blocks.map((b) => b.text).join(' ');

    // Strong JP signals
    if (text.contains('熱量') ||
        text.contains('たんぱく質') ||
        text.contains('食塩相当量') ||
        text.contains('栄養成分')) {
      return DetectedFormat.jp;
    }

    // Strong FDA signals
    if (RegExp(r'Nutrition Facts', caseSensitive: false).hasMatch(text) ||
        RegExp(r'% Daily Value', caseSensitive: false).hasMatch(text) ||
        (RegExp(r'Calories', caseSensitive: false).hasMatch(text) &&
            RegExp(r'Total Fat', caseSensitive: false).hasMatch(text))) {
      return DetectedFormat.fda;
    }

    // Strong EU signals
    if (RegExp(r'of which saturates', caseSensitive: false).hasMatch(text) ||
        (RegExp(r'per 100\s*(?:g|ml)', caseSensitive: false).hasMatch(text) &&
            RegExp(r'\bFibre\b', caseSensitive: false).hasMatch(text))) {
      return DetectedFormat.eu;
    }

    return DetectedFormat.unknown;
  }

  /// When format is ambiguous, try all parsers and return the highest-confidence result.
  NutritionData _tryAll(List<OcrBlock> blocks, DateTime now) {
    final results = [
      _jpParser.parse(blocks, now),
      _fdaParser.parse(blocks, now),
      _euParser.parse(blocks, now),
    ];
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.first;
  }
}
