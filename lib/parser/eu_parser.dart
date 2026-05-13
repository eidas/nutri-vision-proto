/// Parser for EU Regulation 1169/2011 nutrition declaration.
///
/// Mandatory per 100 g/ml: Energy (kJ + kcal), Fat, Saturated Fat,
/// Carbohydrate, Sugars, Protein, Salt.
/// Optional: Fibre, MUFA, PUFA, polyols, starch, vitamins/minerals.
library;

import '../models/nutrition_data.dart';
import '../models/ocr_block.dart';
import 'parser_utils.dart';

class EuParser {
  NutritionData parse(List<OcrBlock> blocks, DateTime capturedAt) {
    final lines = _toLines(blocks);
    final fullText = lines.join('\n');

    final nutrients = <Nutrient, NutrientValue>{};

    void addFromPattern(
      Nutrient nutrient,
      RegExp pattern, {
      String defaultUnit = 'g',
    }) {
      final m = pattern.firstMatch(fullText);
      if (m == null) return;
      final value = parseNumber(m.group(1));
      if (value == null) return;
      final unit = m.groupCount >= 2 ? (m.group(2) ?? defaultUnit) : defaultUnit;
      nutrients[nutrient] = NutrientValue(value: value, unit: unit);
    }

    // ── Energy ───────────────────────────────────────────────────────────────
    // EU shows "1539 kJ / 367 kcal" — capture kcal value
    final energyMatch = RegExp(
            r'Energy\s+\d+\s*kJ\s*/\s*(\d+(?:\.\d+)?)\s*kcal',
            caseSensitive: false,
            multiLine: true)
        .firstMatch(fullText);
    if (energyMatch != null) {
      final v = parseNumber(energyMatch.group(1));
      if (v != null) nutrients[Nutrient.energy] = NutrientValue(value: v, unit: 'kcal');
    }

    // Fallback: just kJ
    if (!nutrients.containsKey(Nutrient.energy)) {
      final kJMatch = RegExp(r'Energy\s+(\d+(?:\.\d+)?)\s*kJ',
              caseSensitive: false)
          .firstMatch(fullText);
      final v = parseNumber(kJMatch?.group(1));
      if (v != null) nutrients[Nutrient.energy] = NutrientValue(value: v, unit: 'kJ');
    }

    // ── Fat ───────────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.fat,
      RegExp(r'\bFat\b\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── Saturated Fat ─────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.saturatedFat,
      RegExp(r'of which saturates\s+(\d+(?:\.\d+)?)\s*(g)',
          caseSensitive: false),
    );

    // ── MUFA / PUFA (optional) ────────────────────────────────────────────────
    addFromPattern(
      Nutrient.monounsaturatedFat,
      RegExp(r'monounsaturates\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );
    addFromPattern(
      Nutrient.polyunsaturatedFat,
      RegExp(r'polyunsaturates\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── Carbohydrate ──────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.carbohydrate,
      RegExp(r'\bCarbohydrate\b\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── Sugars ────────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.sugars,
      RegExp(r'of which sugars\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── Fibre ─────────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.dietaryFiber,
      RegExp(r'\bFibre\b\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── Protein ───────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.protein,
      RegExp(r'\bProtein\b\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── Salt ──────────────────────────────────────────────────────────────────
    addFromPattern(
      Nutrient.salt,
      RegExp(r'\bSalt\b\s+(\d+(?:\.\d+)?)\s*(g)', caseSensitive: false),
    );

    // ── per 100g label ────────────────────────────────────────────────────────
    final per100Match = RegExp(r'per\s+100\s*(g|ml)', caseSensitive: false)
        .firstMatch(fullText);
    final per100g = per100Match?.group(0);

    final confidence =
        NutritionData.computeConfidence(LabelFormat.eu, nutrients);

    return NutritionData(
      format: LabelFormat.eu,
      nutrients: nutrients,
      capturedAt: capturedAt,
      confidence: confidence,
      per100g: per100g,
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
