import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/models/nutrition_data.dart';
import 'package:nutri_vision/models/ocr_block.dart';
import 'package:nutri_vision/parser/jp_parser.dart';
import 'package:nutri_vision/parser/fda_parser.dart';
import 'package:nutri_vision/parser/eu_parser.dart';
import 'package:nutri_vision/parser/label_parser.dart';

OcrBlock _block(String text, {double y = 0}) => OcrBlock(
      text: text,
      boundingBox: Rect.fromLTWH(0.1, y, 0.8, 0.05),
    );

List<OcrBlock> _jpBlocks() => [
      _block('栄養成分表示（1食あたり）', y: 0.00),
      _block('熱量 358kcal',             y: 0.05),
      _block('たんぱく質 12.4g',         y: 0.10),
      _block('脂質 8.0g',                y: 0.15),
      _block('炭水化物 56.2g',           y: 0.20),
      _block('食塩相当量 1.8g',          y: 0.25),
    ];

List<OcrBlock> _fdaBlocks() => [
      _block('Nutrition Facts',           y: 0.00),
      _block('Serving Size 2/3 cup (55g)',y: 0.05),
      _block('Calories 230',              y: 0.10),
      _block('Total Fat 8g 10%',          y: 0.15),
      _block('Saturated Fat 1g 5%',       y: 0.20),
      _block('Trans Fat 0g',              y: 0.25),
      _block('Sodium 160mg 7%',           y: 0.30),
      _block('Total Carbohydrate 37g 13%',y: 0.35),
      _block('Dietary Fiber 4g 14%',      y: 0.40),
      _block('Total Sugars 12g',          y: 0.45),
      _block('Protein 3g',                y: 0.50),
    ];

List<OcrBlock> _euBlocks() => [
      _block('Nutritional Information',              y: 0.00),
      _block('per 100g',                             y: 0.05),
      _block('Energy 1539 kJ / 367 kcal',            y: 0.10),
      _block('Fat 7.5g',                             y: 0.15),
      _block('of which saturates 1.5g',              y: 0.20),
      _block('Carbohydrate 63g',                     y: 0.25),
      _block('of which sugars 22g',                  y: 0.30),
      _block('Fibre 3.0g',                           y: 0.35),
      _block('Protein 9.0g',                         y: 0.40),
      _block('Salt 0.50g',                           y: 0.45),
    ];

void main() {
  final now = DateTime(2026, 1, 1);

  group('JP parser', () {
    late NutritionData result;
    setUp(() => result = JpParser().parse(_jpBlocks(), now));

    test('format is JP', () => expect(result.format, LabelFormat.jp));
    test('energy', () => expect(result.nutrients[Nutrient.energy]?.value, 358));
    test('protein', () => expect(result.nutrients[Nutrient.protein]?.value, 12.4));
    test('fat',     () => expect(result.nutrients[Nutrient.fat]?.value,     8.0));
    test('carbohydrate', () => expect(result.nutrients[Nutrient.carbohydrate]?.value, 56.2));
    test('salt',    () => expect(result.nutrients[Nutrient.salt]?.value,    1.8));
    test('confidence >= 1.0', () => expect(result.confidence, 1.0));
  });

  group('FDA parser', () {
    late NutritionData result;
    setUp(() => result = FdaParser().parse(_fdaBlocks(), now));

    test('format is FDA', () => expect(result.format, LabelFormat.fda));
    test('calories', () => expect(result.nutrients[Nutrient.energy]?.value, 230));
    test('sodium unit is mg', () => expect(result.nutrients[Nutrient.sodium]?.unit, 'mg'));
    test('sodium value', () => expect(result.nutrients[Nutrient.sodium]?.value, 160));
    test('confidence >= 1.0', () => expect(result.confidence, 1.0));
  });

  group('EU parser', () {
    late NutritionData result;
    setUp(() => result = EuParser().parse(_euBlocks(), now));

    test('format is EU', () => expect(result.format, LabelFormat.eu));
    test('energy kcal', () => expect(result.nutrients[Nutrient.energy]?.value, 367));
    test('saturated fat', () => expect(result.nutrients[Nutrient.saturatedFat]?.value, 1.5));
    test('sugars',  () => expect(result.nutrients[Nutrient.sugars]?.value, 22));
    test('confidence >= 1.0', () => expect(result.confidence, 1.0));
  });

  group('LabelParser auto-detect', () {
    test('detects JP', () {
      final r = LabelParser.instance.parse(_jpBlocks());
      expect(r.format, LabelFormat.jp);
    });
    test('detects FDA', () {
      final r = LabelParser.instance.parse(_fdaBlocks());
      expect(r.format, LabelFormat.fda);
    });
    test('detects EU', () {
      final r = LabelParser.instance.parse(_euBlocks());
      expect(r.format, LabelFormat.eu);
    });
  });
}
