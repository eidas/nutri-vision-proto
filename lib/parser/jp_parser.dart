/// Parser for Japanese 食品表示基準 nutrition labels.
///
/// Mandatory fields: 熱量・たんぱく質・脂質・炭水化物・食塩相当量
/// Optional extras : 飽和脂肪酸, 食物繊維, ナトリウム, 糖質/糖類, etc.
library;

import '../models/nutrition_data.dart';
import '../models/ocr_block.dart';
import 'parser_utils.dart';

class JpParser {
  NutritionData parse(List<OcrBlock> blocks, DateTime capturedAt) {
    // Merge all text into one string for regex scanning,
    // but keep line-level context so label→value proximity works.
    final lines = _toLines(blocks);
    final fullText = lines.join('\n');

    final nutrients = <Nutrient, NutrientValue>{};

    void tryAdd(Nutrient n, String? text, String unit,
        {double scale = 1.0}) {
      if (text == null) return;
      final v = parseNumber(text);
      if (v != null) nutrients[n] = NutrientValue(value: v * scale, unit: unit);
    }

    // ── 熱量 / エネルギー ──────────────────────────────────────────────────
    // Appears as: "熱量 250kcal" or "熱量\n250\nkcal"
    final energyMatch = RegExp(
            r'(?:熱量|エネルギー)[^\d]*(\d+(?:\.\d+)?)\s*(?:kcal|Kcal|KCAL|kJ)',
            multiLine: true)
        .firstMatch(fullText);
    tryAdd(Nutrient.energy, energyMatch?.group(1), 'kcal');

    // Fallback: label on one line, value on next
    if (!nutrients.containsKey(Nutrient.energy)) {
      final v = _nextValue(lines, RegExp(r'熱量|エネルギー'));
      if (v != null) nutrients[Nutrient.energy] = NutrientValue(value: v, unit: 'kcal');
    }

    // ── たんぱく質 ─────────────────────────────────────────────────────────
    final proteinMatch =
        RegExp(r'たんぱく質[^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.protein, proteinMatch?.group(1), 'g');
    if (!nutrients.containsKey(Nutrient.protein)) {
      final v = _nextValue(lines, RegExp(r'たんぱく質|タンパク質'));
      if (v != null) nutrients[Nutrient.protein] = NutrientValue(value: v, unit: 'g');
    }

    // ── 脂質 ───────────────────────────────────────────────────────────────
    final fatMatch = RegExp(r'(?<![一多価不]飽和|コレステロール)脂質[^\d]*(\d+(?:\.\d+)?)\s*g',
            multiLine: true)
        .firstMatch(fullText);
    tryAdd(Nutrient.fat, fatMatch?.group(1), 'g');
    if (!nutrients.containsKey(Nutrient.fat)) {
      final v = _nextValue(lines, RegExp(r'^脂質$'));
      if (v != null) nutrients[Nutrient.fat] = NutrientValue(value: v, unit: 'g');
    }

    // ── 飽和脂肪酸 ────────────────────────────────────────────────────────
    final satFatMatch =
        RegExp(r'飽和脂肪酸[^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.saturatedFat, satFatMatch?.group(1), 'g');

    // ── トランス脂肪酸 ────────────────────────────────────────────────────
    final transFatMatch =
        RegExp(r'トランス脂肪酸[^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.transFat, transFatMatch?.group(1), 'g');

    // ── コレステロール ────────────────────────────────────────────────────
    final cholMatch =
        RegExp(r'コレステロール[^\d]*(\d+(?:\.\d+)?)\s*mg', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.cholesterol, cholMatch?.group(1), 'mg');

    // ── 炭水化物 ───────────────────────────────────────────────────────────
    final carbMatch =
        RegExp(r'炭水化物[^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.carbohydrate, carbMatch?.group(1), 'g');
    if (!nutrients.containsKey(Nutrient.carbohydrate)) {
      final v = _nextValue(lines, RegExp(r'炭水化物'));
      if (v != null) nutrients[Nutrient.carbohydrate] = NutrientValue(value: v, unit: 'g');
    }

    // ── 糖質 / 糖類 ───────────────────────────────────────────────────────
    final sugarMatch =
        RegExp(r'糖[質類][^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.sugars, sugarMatch?.group(1), 'g');

    // ── 食物繊維 ───────────────────────────────────────────────────────────
    final fiberMatch =
        RegExp(r'食物繊維[^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.dietaryFiber, fiberMatch?.group(1), 'g');

    // ── 食塩相当量 ─────────────────────────────────────────────────────────
    final saltMatch =
        RegExp(r'食塩相当量[^\d]*(\d+(?:\.\d+)?)\s*g', multiLine: true)
            .firstMatch(fullText);
    tryAdd(Nutrient.salt, saltMatch?.group(1), 'g');
    if (!nutrients.containsKey(Nutrient.salt)) {
      final v = _nextValue(lines, RegExp(r'食塩相当量'));
      if (v != null) nutrients[Nutrient.salt] = NutrientValue(value: v, unit: 'g');
    }

    // ── ナトリウム (fallback / additional) ───────────────────────────────
    final naMatch =
        RegExp(r'ナトリウム[^\d]*(\d+(?:\.\d+)?)\s*(mg|g)', multiLine: true)
            .firstMatch(fullText);
    if (naMatch != null && !nutrients.containsKey(Nutrient.salt)) {
      final v = parseNumber(naMatch.group(1));
      if (v != null) {
        // Convert mg Na → g salt: Na(mg) × 2.54 / 1000
        final unit = naMatch.group(2)!;
        final saltG = unit == 'mg' ? v * 2.54 / 1000 : v * 2.54;
        nutrients[Nutrient.salt] = NutrientValue(
            value: double.parse(saltG.toStringAsFixed(2)), unit: 'g');
        nutrients[Nutrient.sodium] = NutrientValue(value: v, unit: unit);
      }
    }

    // ── Serving size ───────────────────────────────────────────────────────
    String? servingSize;
    final servingMatch = RegExp(
            r'(?:1食|1回|100g|100ml|内容量)[^\d]*(\d+(?:\.\d+)?)\s*(?:g|ml|mL)',
            caseSensitive: false,
            multiLine: true)
        .firstMatch(fullText);
    if (servingMatch != null) {
      servingSize = servingMatch.group(0)?.trim();
    }

    final confidence =
        NutritionData.computeConfidence(LabelFormat.jp, nutrients);

    return NutritionData(
      format: LabelFormat.jp,
      nutrients: nutrients,
      capturedAt: capturedAt,
      confidence: confidence,
      servingSize: servingSize,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  List<String> _toLines(List<OcrBlock> blocks) {
    // Sort by Y position (top to bottom), then X (left to right)
    final sorted = [...blocks]
      ..sort((a, b) {
        final dy = (a.boundingBox.top - b.boundingBox.top);
        if (dy.abs() > 0.01) return dy.sign.toInt();
        return (a.boundingBox.left - b.boundingBox.left).sign.toInt();
      });
    return sorted.map((b) => b.text.trim()).where((t) => t.isNotEmpty).toList();
  }

  /// Returns the first number on the line immediately after a label match.
  double? _nextValue(List<String> lines, Pattern labelPattern) {
    for (int i = 0; i < lines.length - 1; i++) {
      if (lines[i].contains(labelPattern)) {
        return parseNumber(lines[i + 1]);
      }
    }
    return null;
  }
}
