/// Structured output of a scanned nutrition label.
library;

enum LabelFormat { jp, fda, eu, unknown }

// Superset of JP / FDA / EU nutrients
enum Nutrient {
  energy,
  protein,
  fat,
  saturatedFat,
  transFat,
  polyunsaturatedFat,
  monounsaturatedFat,
  cholesterol,
  carbohydrate,
  sugars,
  addedSugars,
  dietaryFiber,
  sodium,
  salt,
  vitaminD,
  calcium,
  iron,
  potassium,
}

/// Human-readable labels per locale.
const Map<Nutrient, ({String jp, String en})> nutrientLabels = {
  Nutrient.energy:             (jp: '熱量',       en: 'Energy'),
  Nutrient.protein:            (jp: 'たんぱく質', en: 'Protein'),
  Nutrient.fat:                (jp: '脂質',       en: 'Total Fat'),
  Nutrient.saturatedFat:       (jp: '飽和脂肪酸', en: 'Saturated Fat'),
  Nutrient.transFat:           (jp: 'トランス脂肪酸', en: 'Trans Fat'),
  Nutrient.polyunsaturatedFat: (jp: '多価不飽和脂肪酸', en: 'Polyunsaturated Fat'),
  Nutrient.monounsaturatedFat: (jp: '一価不飽和脂肪酸', en: 'Monounsaturated Fat'),
  Nutrient.cholesterol:        (jp: 'コレステロール', en: 'Cholesterol'),
  Nutrient.carbohydrate:       (jp: '炭水化物',   en: 'Total Carbohydrate'),
  Nutrient.sugars:             (jp: '糖類',       en: 'Sugars'),
  Nutrient.addedSugars:        (jp: '添加糖類',   en: 'Added Sugars'),
  Nutrient.dietaryFiber:       (jp: '食物繊維',   en: 'Dietary Fiber'),
  Nutrient.sodium:             (jp: 'ナトリウム', en: 'Sodium'),
  Nutrient.salt:               (jp: '食塩相当量', en: 'Salt'),
  Nutrient.vitaminD:           (jp: 'ビタミンD',  en: 'Vitamin D'),
  Nutrient.calcium:            (jp: 'カルシウム', en: 'Calcium'),
  Nutrient.iron:               (jp: '鉄',         en: 'Iron'),
  Nutrient.potassium:          (jp: 'カリウム',   en: 'Potassium'),
};

class NutrientValue {
  const NutrientValue({
    required this.value,
    required this.unit,
    this.dailyValuePercent,
  });

  final double value;
  final String unit; // kcal, kJ, g, mg, mcg
  final double? dailyValuePercent; // % DV — FDA / EU only

  @override
  String toString() {
    final dv = dailyValuePercent != null
        ? ' (${dailyValuePercent!.toStringAsFixed(0)}% DV)'
        : '';
    return '${value % 1 == 0 ? value.toInt() : value}$unit$dv';
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'unit': unit,
        if (dailyValuePercent != null) 'dailyValuePercent': dailyValuePercent,
      };
}

class NutritionData {
  const NutritionData({
    required this.format,
    required this.nutrients,
    required this.capturedAt,
    required this.confidence,
    this.productName,
    this.servingSize,
    this.servingsPerContainer,
    this.per100g,
  });

  final LabelFormat format;
  final Map<Nutrient, NutrientValue> nutrients;
  final DateTime capturedAt;

  /// 0.0–1.0: fraction of format-required fields that were parsed.
  final double confidence;

  final String? productName;
  final String? servingSize;
  final String? servingsPerContainer;

  /// For EU/JP labels that always show per-100 g values.
  final String? per100g;

  Map<String, dynamic> toJson() => {
        'format': format.name.toUpperCase(),
        'capturedAt': capturedAt.toIso8601String(),
        'confidence': confidence,
        if (productName != null) 'productName': productName,
        if (servingSize != null) 'servingSize': servingSize,
        if (servingsPerContainer != null)
          'servingsPerContainer': servingsPerContainer,
        if (per100g != null) 'per100g': per100g,
        'nutrients': {
          for (final e in nutrients.entries)
            e.key.name: e.value.toJson(),
        },
      };

  /// Required nutrients for auto-complete confidence calculation.
  static const Map<LabelFormat, List<Nutrient>> _required = {
    LabelFormat.jp: [
      Nutrient.energy,
      Nutrient.protein,
      Nutrient.fat,
      Nutrient.carbohydrate,
      Nutrient.salt,
    ],
    LabelFormat.fda: [
      Nutrient.energy,
      Nutrient.fat,
      Nutrient.sodium,
      Nutrient.carbohydrate,
      Nutrient.protein,
    ],
    LabelFormat.eu: [
      Nutrient.energy,
      Nutrient.fat,
      Nutrient.saturatedFat,
      Nutrient.carbohydrate,
      Nutrient.sugars,
      Nutrient.protein,
      Nutrient.salt,
    ],
    LabelFormat.unknown: [],
  };

  static double computeConfidence(
      LabelFormat format, Map<Nutrient, NutrientValue> nutrients) {
    final required = _required[format] ?? [];
    if (required.isEmpty) return 0;
    final found = required.where(nutrients.containsKey).length;
    return found / required.length;
  }
}
