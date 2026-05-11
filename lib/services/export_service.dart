import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/nutrition_data.dart';

class ExportService {
  ExportService._();
  static final instance = ExportService._();

  final _fileDateFmt = DateFormat('yyyyMMdd_HHmmss');

  // ── JSON ──────────────────────────────────────────────────────────────────

  String toJsonString(NutritionData data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data.toJson());
  }

  Future<void> copyJsonToClipboard(NutritionData data) async {
    await Clipboard.setData(ClipboardData(text: toJsonString(data)));
  }

  Future<void> shareAsJson(NutritionData data) async {
    final json = toJsonString(data);
    final file = await _writeTempFile(
      name: 'nutrition_${_stamp(data)}.json',
      content: json,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Nutrition data',
    );
  }

  // ── CSV ───────────────────────────────────────────────────────────────────

  String toCsvString(NutritionData data) {
    final rows = <List<dynamic>>[
      ['nutrient', 'value', 'unit', 'dailyValuePercent'],
    ];

    for (final e in data.nutrients.entries) {
      final label = nutrientLabels[e.key];
      rows.add([
        label?.en ?? e.key.name,
        e.value.value,
        e.value.unit,
        e.value.dailyValuePercent ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<void> shareAsCsv(NutritionData data) async {
    final csv = toCsvString(data);
    final file = await _writeTempFile(
      name: 'nutrition_${_stamp(data)}.csv',
      content: csv,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Nutrition data',
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _stamp(NutritionData data) => _fileDateFmt.format(data.capturedAt);

  Future<File> _writeTempFile({
    required String name,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content, encoding: utf8);
    return file;
  }
}
