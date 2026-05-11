import 'package:flutter/material.dart';
import '../models/nutrition_data.dart';

class NutritionTableWidget extends StatelessWidget {
  const NutritionTableWidget({super.key, required this.data});

  final NutritionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = data.nutrients.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(theme),
        const Divider(height: 1, thickness: 2),
        ...rows.map((e) => _row(context, e.key, e.value)),
        const Divider(height: 1, thickness: 2),
        _footer(theme),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    final formatLabel = switch (data.format) {
      LabelFormat.jp  => '栄養成分表示',
      LabelFormat.fda => 'Nutrition Facts',
      LabelFormat.eu  => 'Nutritional Information',
      LabelFormat.unknown => 'Nutrition',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        formatLabel,
        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _row(BuildContext context, Nutrient nutrient, NutrientValue nv) {
    final label = nutrientLabels[nutrient];
    final isJp = data.format == LabelFormat.jp;
    final displayName = isJp ? (label?.jp ?? nutrient.name) : (label?.en ?? nutrient.name);

    // Sub-nutrients are indented.
    const subNutrients = {
      Nutrient.saturatedFat,
      Nutrient.transFat,
      Nutrient.polyunsaturatedFat,
      Nutrient.monounsaturatedFat,
      Nutrient.addedSugars,
      Nutrient.sugars,
      Nutrient.dietaryFiber,
    };
    final isSubNutrient = subNutrients.contains(nutrient);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: EdgeInsets.only(
        left: isSubNutrient ? 20.0 : 0,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontWeight: isSubNutrient ? FontWeight.normal : FontWeight.bold,
                fontSize: isSubNutrient ? 13 : 15,
              ),
            ),
          ),
          Text(
            nv.toString(),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    if (data.format == LabelFormat.jp) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          data.servingSize != null ? '${data.servingSize} あたり' : '',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (data.format == LabelFormat.eu) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          data.per100g != null ? '${data.per100g} あたり' : '',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (data.format == LabelFormat.fda && data.servingsPerContainer != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '* % Daily Value based on 2,000 cal diet.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
