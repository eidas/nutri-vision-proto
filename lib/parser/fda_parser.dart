/// Parser for US FDA "Nutrition Facts" panels.
///
/// Reference: 21 CFR 101.9 (2020 label format)
/// Required on label: Calories, Total Fat, Saturated Fat, Trans Fat,
/// Cholesterol, Sodium, Total Carbohydrate, Dietary Fiber, Total Sugars,
/// Protein.
library;

import '../models/nutrition_data.dart';
import '../models/ocr_block.dart';
import 'parser_utils.dart';

class FdaParser {
  NutritionData parse(List<OcrBlock> blocks, DateTime capturedAt) {
    final lines = _toLines(blocks);
    final fullText = lines.join('\n');

    final nutrients = <Nutrient, NutrientValue>{};

    // Helper: extract value + optional %DV from a labelled line.
    // e.g. "Total Fat 8g 10%" → value=8, unit='g', dv=10
    void addFromPattern(
      Nutrient nutrient,
      RegExp pattern, {
      String defaultUnit = 'g',
    }) {
      final m = pattern.firstMatch(fullText);
      if (m == null) return;
      final value = parseNumber(m.group(1));
      if (value == null) return;
      final unit = m.namedGroup('unit') ?? defaultUnit;
      final dvStr = m.groupCount >= 2 ? m.group(m.groupCount) : null;
      final dv = dvStr != null ? parseNumber(dvStr) : null;
      nutrients[nutrient] = NutrientValue(value: value, unit: unit, dailyValuePercent: dv);
    }

    // ── Calories ────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.energy,
      RegExp(r'Calories\s+(\d+(?:\.\d+)?)', caseSensitive: false),
      defaultUnit: 'kcal',
    );

    // ── Total Fat ────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.fat,
      RegExp(r'Total Fat\s+(\d+(?:\.\d+)?)(?<unit>g)\s+(\d+)%',
          caseSensitive: false),
    );

    // ── Saturated Fat ────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.saturatedFat,
      RegExp(r'Saturated Fat\s+(\d+(?:\.\d+)?)(?<unit>g)\s+(\d+)%',
          caseSensitive: false),
    );

    // ── Trans Fat ────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.transFat,
      RegExp(r'Trans Fat\s+(\d+(?:\.\d+)?)(?<unit>g)', caseSensitive: false),
    );

    // ── Cholesterol ───────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.cholesterol,
      RegExp(r'Cholesterol\s+(\d+(?:\.\d+)?)(?<unit>mg)\s+(\d+)%',
          caseSensitive: false),
      defaultUnit: 'mg',
    );

    // ── Sodium ────────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.sodium,
      RegExp(r'Sodium\s+(\d+(?:\.\d+)?)(?<unit>mg)\s+(\d+)%',
          caseSensitive: false),
      defaultUnit: 'mg',
    );

    // ── Total Carbohydrate ────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.carbohydrate,
      RegExp(r'Total Carbohydrate\s+(\d+(?:\.\d+)?)(?<unit>g)\s+(\d+)%',
          caseSensitive: false),
    );

    // ── Dietary Fiber ────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.dietaryFiber,
      RegExp(r'Dietary Fiber\s+(\d+(?:\.\d+)?)(?<unit>g)\s+(\d+)%',
          caseSensitive: false),
    );

    // ── Total Sugars ─────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.sugars,
      RegExp(r'Total Sugars\s+(\d+(?:\.\d+)?)(?<unit>g)', caseSensitive: false),
    );

    // ── Added Sugars ─────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.addedSugars,
      RegExp(r'Added Sugars\s+(\d+(?:\.\d+)?)(?<unit>g)\s+(\d+)%',
          caseSensitive: false),
    );

    // ── Protein ──────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.protein,
      RegExp(r'Protein\s+(\d+(?:\.\d+)?)(?<unit>g)', caseSensitive: false),
    );

    // ── Micronutrients ────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.vitaminD,
      RegExp(r'Vitamin D\s+(\d+(?:\.\d+)?)(?<unit>mcg)\s+(\d+)%',
          caseSensitive: false),
      defaultUnit: 'mcg',
    );
    addFromPattern(
      Nutrient.calcium,
      RegExp(r'Calcium\s+(\d+(?:\.\d+)?)(?<unit>mg)\s+(\d+)%',
          caseSensitive: false),
      defaultUnit: 'mg',
    );
    addFromPattern(
      Nutrient.iron,
      RegExp(r'Iron\s+(\d+(?:\.\d+)?)(?<unit>mg)\s+(\d+)%',
          caseSensitive: false),
      defaultUnit: 'mg',
    );
    addFromPattern(
      Nutrient.potassium,
      RegExp(r'Potassium\s+(\d+(?:\.\d+)?)(?<unit>mg)\s+(\d+)%',
          caseSensitive: false),
      defaultUnit: 'mg',
    );

    // ── Serving size ──────────────────────────────────────────────────────────
    final servingMatch = RegExp(
            r'Serving Size\s+(.+?)(?:\n|$)',
            caseSensitive: false,
            multiLine: true)
        .firstMatch(fullText);
    final servingSize = servingMatch?.group(1)?.trim();

    final servingsMatch = RegExp(
            r'(?:Servings? Per Container|About)\s+(.+?)(?:\n|$)',
            caseSensitive: false,
            multiLine: true)
        .firstMatch(fullText);
    final servingsPerContainer = servingsMatch?.group(1)?.trim();

    final confidence =
        NutritionData.computeConfidence(LabelFormat.fda, nutrients);

    return NutritionData(
      format: LabelFormat.fda,
      nutrients: nutrients,
      capturedAt: capturedAt,
      confidence: confidence,
      servingSize: servingSize,
      servingsPerContainer: servingsPerContainer,
    );
  }

  List<String> _toLines(List<OcrBlock> blocks) {
    final sorted = [...blocks]
      ..sort((a, b) {
        final dy = a.boundingBox.top - b.boundingBox.top;
        if (dy.abs() > 0.005) return dy.sign.toInt();
        return (a.boundingBox.left - b.boundingBox.left).sign.toInt();
      });
    return sorted.map((b) => b.text.trim()).where((t) => t.isNotEmpty).toList();
  }
}
